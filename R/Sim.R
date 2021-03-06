###############################################################
## run simulation and DE detection
###############################################################
#' @name simulateDE
#' @aliases simulateDE
#' @title Simulate Differential Expression
#' @description This function simulates RNA-seq count matrices considering differential expression specifications (number of samples per group, effect size, number of differential expressed genes etc.). The return object contains DE test results from all simulations as well as descriptive statistics.
#' @details simulateDE is the main function to simulate differential expression for RNA-seq experiments. The simulation parameters are specified with  \code{\link{SimSetup}}. The user needs to specify the number of samples per group and the differential expression analysis method. \cr
#' It only stores and returns the DE test results (i.e. p-values). The error matrix calculations will be conducted with \code{\link{evaluateSim}}.\cr
#' @usage simulateDE(n1=c(20,50,100),
#' n2=c(30,60,120),
#' sim.settings,
#' ncores=NULL,
#' DEmethod,
#' verbose=TRUE)
#' @param n1,n2 Integer vectors specifying the number of biological replicates in each group. Default values are n1=c(20,50,100) and n2=c(30,60,120).
#' @param sim.settings This object specifies the simulation setup. This must be the return object from \code{\link{SimSetup}}.
#' @param ncores integer positive number of cores for parallel processing, default is NULL, ie 1 core.
#' @param DEmethod String to specify the DE detection method to be used. Available options are: limma, edgeR, DESeq2, ROTS, baySeq, NOISeq, EBSeq, DSS, MAST, scde, BPSC, scDD.
#' @param verbose Logical value to indicate whether to show progress report of simulations. Default is TRUE.
#' @return A list with the following fields. The dimensions for the 3D arrays are ngenes * N * nsims:
#' \item{pvalue, fdr}{3D array for p-values and FDR from each simulation. Note that FDR values will be empty and the calculation will be done by \code{\link{evaluateSim}} whenever applicable.}
#' \item{mu,disp,dropout}{3D array for mean, dispersion and dropout of library size factor normalized read counts}
#' \item{n1,n2}{The input number of biological replicates in each group. The vectors must have the same length.}
#' \item{time.taken}{The time taken for each simulation, given for read count simulation, DEA and moment estimation. }
#' @author Beate Vieth
#' @seealso \code{\link{estimateNBParam}},  \code{\link{insilicoNBParam}} for negative binomial parameter specifications;\cr
#'  \code{\link{DESetup}}, \code{\link{SimSetup}} for simulation setup
#' @examples
#' \dontrun{
#' # download count table
#' githubURL <- "https://github.com/bvieth/powsimRData/raw/master/data-raw/kolodziejczk_cnts.rda"
#' download.file(url = githubURL, destfile= "kolodziejczk_cnts.rda", method = "wget")
#' load('kolodziejczk_cnts.rda')
#' kolodziejczk_cnts <- kolodziejczk_cnts[, grep('standard', colnames(kolodziejczk_cnts))]
#' ## estimate NB parameters:
#' TwoiLIF.params = estimateNBParam(countData = kolodziejczk_cnts,
#' cData = NULL, design = NULL,
#' RNAseq = 'singlecell', estFramework = 'MatchMoments',
#' sigma= 1.96)
#' ## define DE settings:
#' desettings <- DESetup(ngenes=10000,
#' nsims=25, p.DE=0.2,
#' LFC=function(x) sample(c(-1,1), size=x,replace=TRUE)*rgamma(x, 3, 3))
#' ## define simulation settings for Kolodziejczk:
#' simsettings <- SimSetup(desetup=desettings, params=TwoiLIF.params, size.factors='given')
#' ## run simulations:
#' simres <- simulateDE(n1=c(24,48,96,192,384,800),
#' n2=c(24,48,96,192,384,800),
#' sim.settings=simsettings,
#' ncores=10, DEmethod="MAST", verbose=TRUE)
#' ## if parallel computation unavailable, consider ROTS as DEmethod
#' }
#' @rdname simulateDE
#' @export
simulateDE <- function(n1=c(20,50,100), n2=c(30,60,120), sim.settings, ncores=NULL, DEmethod, verbose=TRUE) {
  if (!length(n1) == length(n2))
    stop("n1 and n2 must have the same length!")

  if(!is.null(ncores) && DEmethod %in% c("edgeR", 'limma', "NOISeq", "DSS", "EBSeq", "ROTS")) {
    message(paste0(DEmethod, " has no parallel computation option. Number of cores will be set to 1!"))
  }

  if(sim.settings$RNAseq == "singlecell" && DEmethod %in% c("edgeR", "DESeq2", "baySeq", "NOISeq", "DSS", "EBSeq")) {
    message(paste0(DEmethod, " is developed for bulk RNA-seq experiments."))
  }

  if(sim.settings$RNAseq == "bulk" && DEmethod %in% c("MAST", 'BPSC')) {
    message(paste0(DEmethod, " is developed for single cell RNA-seq experiments."))
  }

  if(sim.settings$RNAseq == "bulk" && DEmethod %in% c('scde', 'scDD')) {
    stop(cat(DEmethod, " is only developed and implemented for single cell RNA-seq experiments."))
  }

  max.n = max(n1,n2)
  nsims = sim.settings$nsims

  sim.settings$ncores = ncores

  #set up output arrays
  pvalues = fdrs = mus = disps = dropouts = array(NA,dim=c(sim.settings$ngenes,length(n1), nsims))
  time.taken = array(NA,dim = c(3,length(n1), nsims), dimnames = list(c("params", "DE", "NB"), NULL, NULL))

  ## start simulation
  for (i in 1:nsims) {
    if (verbose)
    message(paste0("Simulation number ", i, "\n"))
    ## update the simulation options by extracting the ith set and change sim.seed
    tmp.simOpts = sim.settings
    tmp.simOpts$DEid = tmp.simOpts$DEid[[i]]
    tmp.simOpts$lfc = tmp.simOpts$lfc[[i]]
    tmp.simOpts$sim.seed = tmp.simOpts$sim.seed[[i]]

    ## generate read counts
    dat.sim = .simRNAseq(simOptions = tmp.simOpts, n1 = max.n, n2 = max.n)

    ##  for different sample sizes
    for (j in seq(along=n1)) {
      Nrep1 = n1[j]
      Nrep2 = n2[j]

      ## take a subsample of the simulated counts
      idx = c(1:Nrep1, max.n + (1:Nrep2))
      tmp.design = dat.sim$designs[idx]
      tmp.cnts = dat.sim$counts[,idx]
      ## filter out zero expression genes
      ix.valid = rowSums(tmp.cnts) > 0
      tmp.cnts.red = tmp.cnts[ix.valid,, drop = FALSE]

      ## create an object to pass into DE detection with mean, disp, dropout estimation
      data0 = list(counts = tmp.cnts.red,
                   designs = tmp.design,
                   p.DEs = tmp.simOpts$p.DE,
                   RNAseq = tmp.simOpts$RNAseq,
                   ncores = tmp.simOpts$ncores)

      # methods developed for bulk
        if (DEmethod == "edgeR")
          res = .run.edgeRglm(data0)
        # if (DEmethod == "edgeRQL")
        #   res = .run.edgeRql(data0)
        if (DEmethod == "DESeq2")
          res = .run.DESeq2(data0)
        if (DEmethod == "limma")
          res = .run.limma(data0)
        if (DEmethod == "ROTS")
          res = .run.ROTS(data0)
        if (DEmethod == "baySeq")
          res = .run.baySeq(data0)
        if (DEmethod == "NOISeq")
          res = .run.NOISeq(data0)
        if (DEmethod == "DSS")
          res = .run.DSS(data0)
        if (DEmethod=='EBSeq')
          res = .run.EBSeq(data0)
        # if (DEmethod == "TSPM")
        #   res = .run.TSPM(data0)
      # methods developed for single cell
       if (DEmethod == "MAST")
          res = .run.MAST(data0)
       if (DEmethod == "scde")
          res = .run.scde(data0)
       if (DEmethod == "BPSC")
          res = .run.BPSC(data0)
       # if (DEmethod == "monocle")
       #    res = .run.monocle(data0)
      if (DEmethod == "scDD")
          res = .run.scDD(data0)

      ## extract results of DE testing
      res.tmp = res$result
      # generate empty vectors
      pval = fdr = rep(NA, nrow(tmp.cnts))
      mu.tmp = rep(NA, nrow(tmp.cnts))
      disp.tmp = rep(NA, nrow(tmp.cnts))
      p0.tmp = rep(NA, nrow(tmp.cnts))
      # fill in with results
      pval[ix.valid] = res.tmp[, "pval"]
      fdr[ix.valid] = res.tmp[, "fdr"]
      mu.tmp[ix.valid] = res.tmp$means
      disp.tmp[ix.valid] = res.tmp$dispersion
      p0.tmp[ix.valid] = res.tmp$dropout
      # copy it in 3D array of results
      pvalues[,j,i] = pval
      fdrs[,j,i] = fdr
      mus[,j,i] = mu.tmp
      disps[,j,i] = disp.tmp
      dropouts[,j,i] = p0.tmp

      # copy time taken in 2D array of time taken
      time.taken[,j,i] = res$timing
    }
  }

  ## return
  list(pvalue = pvalues,
       fdr = fdrs,
       mu = mus,
       disp = disps,
       dropout = dropouts,
       n1 = n1,
       n2 = n2,
       time.taken = time.taken,
       DEmethod = DEmethod,
       sim.settings = sim.settings)
}

#####################################################
## create simulated scRNAseq data for 2-grp comparison
#####################################################
#' @importFrom stats model.matrix
.simRNAseq <- function(simOptions, n1, n2) {

  ## make group labels
  design <- c(rep(-1, n1), rep(1, n2))
  ## make model matrix
  mod = stats::model.matrix(~-1 + design)

  # generate read counts:
  if (simOptions$RNAseq == "singlecell") {
    simcounts = .scRNAseq_counts(sim.options = simOptions, modelmatrix = mod)
  }
  if (simOptions$RNAseq == "bulk") {
    simcounts = .bulkRNAseq_counts(sim.options = simOptions, modelmatrix = mod)
  }

  simcounts <- apply(simcounts,2,function(x) {storage.mode(x) <- 'integer'; x})
  colnames(simcounts) <- paste0("S", 1:ncol(simcounts))
  rownames(simcounts) <- paste0("G", 1:nrow(simcounts))

  ## return
  list(counts = simcounts, designs = design, simOptions = simOptions)
}

#####################################################
## draw read counts
#####################################################
#' @importFrom stats rnorm rnbinom
.scRNAseq_counts <- function(sim.options, modelmatrix) {

  set.seed(sim.options$sim.seed)
  print(sim.options$sim.seed)

  nsamples = nrow(modelmatrix)
  ngenes = sim.options$ngenes
  mod = modelmatrix
  beta = cbind(sim.options$lfc)

  if (attr(sim.options, 'param.type') == 'estimated') {
    # define NB params
    mu = sim.options$means
    meansizefit = sim.options$meansizefit

    # sample from the mean parameter observed
    index = sample(1:length(mu), size = ngenes, replace = T)
    true.means = mu[index]

    # estimate size parameter associated with mean values
    lmu = log2(true.means + 1)
    predsize.mean = approx(meansizefit$x, meansizefit$y, xout = lmu)$y
    predsize.sd = approx(meansizefit$x, meansizefit$sd, xout = lmu)$y
    sizevec = rnorm(n = length(lmu), mean = predsize.mean, sd = predsize.sd)


    # capture efficiency (size factor)
    if (sim.options$size.factors == "equal") {
      all.facs <- rep(1, nsamples)
    }
    if (sim.options$size.factors == "given") {
      if (is.function(sim.options$sf)) {
        all.facs <- sim.options$sf(nsamples)
      }
      if (is.vector(sim.options$sf)) {
        all.facs <- sample(sim.options$sf, nsamples, replace = TRUE)
      }
      if (is.null(sim.options$sf)) {
        all.facs <- rep(1, nsamples)
      }
    }

    # effective means
    effective.means <- outer(true.means, all.facs, "*")

    # make mean expression with beta coefficients added as defined by model matrix
    ind = !apply(mod, 2, function(x) { all(x == 1) })
    mod = cbind(mod[, ind])
    beta = cbind(beta[, ind])
    mumat = log2(effective.means + 1) + beta %*% t(mod)
    mumat[mumat < 0] = 0

    # result count matrix
    counts = matrix(stats::rnbinom(nsamples * ngenes, mu = 2 ^ mumat - 1, size = 2 ^ sizevec), ncol = nsamples, nrow = ngenes)
  }

  if (attr(sim.options, 'param.type') == 'insilico') {

    # sample from the mean function provided
    true.means = sim.options$means(ngenes)

    # associate with dispersion parameter
    if (length(sim.options$dispersion) == 1) {
      disp = sim.options$dispersion
    }
    if (is.function(sim.options$dispersion)) {
      disp = sim.options$dispersion(true.means)
    }

    # capture efficiency (size factor)
    if (sim.options$size.factors == "equal") {
      all.facs <- rep(1, nsamples)
    }
    if (sim.options$size.factors == "given") {
      if (is.function(sim.options$sf)) {
        all.facs <- sim.options$sf(nsamples)
      }
      if (is.vector(sim.options$sf)) {
        all.facs <- sample(sim.options$sf, nsamples, replace = TRUE)
      }
      if (is.null(sim.options$sf)) {
        all.facs <- rep(1, nsamples)
      }
    }

    # effective means
    effective.means <- outer(true.means, all.facs, "*")

    # make mean expression with beta coefficients added as defined by model matrix
    ind = !apply(mod, 2, function(x) { all(x == 1) })
    mod = cbind(mod[, ind])
    beta = cbind(beta[, ind])
    mumat = log2(effective.means + 1) + beta %*% t(mod)
    mumat[mumat < 0] = 0

    # result count matrix
    counts = matrix(stats::rnbinom(nsamples * ngenes, mu = 2 ^ mumat - 1, size = 1/disp), ncol = nsamples, nrow = ngenes)
  }

  return(counts)
}

#####################################################
## draw read counts
#####################################################
#' @importFrom stats rnorm rbinom rnbinom approx
.bulkRNAseq_counts <- function(sim.options, modelmatrix) {

  set.seed(sim.options$sim.seed)
  print(sim.options$sim.seed)

  nsamples = nrow(modelmatrix)
  ngenes = sim.options$ngenes
  mod = modelmatrix
  beta = cbind(sim.options$lfc)

  if (attr(sim.options, 'param.type') == 'estimated') {
    # define NB params
    mu = sim.options$means
    meansizefit = sim.options$meansizefit

    # sample from the mean parameter observed
    index = sample(1:length(mu), size = ngenes, replace = T)
    true.means = mu[index]

    # estimate size parameter associated with mean values
    lmu = log2(true.means + 1)
    predsize.mean = stats::approx(meansizefit$x, meansizefit$y, xout = lmu)$y
    predsize.sd = stats::approx(meansizefit$x, meansizefit$sd, xout = lmu)$y
    sizevec = stats::rnorm(n = length(lmu), mean = predsize.mean, sd = predsize.sd)

    # associate dropout probability with mean parameter
    p0vec = rep(0, ngenes)
    p0s = ifelse(lmu < sim.options$p0.cut, sample(x = sim.options$p0,size = 1), p0vec)
    p0mat = t(sapply(p0s, function(x) {
      stats::rbinom(nsamples, prob = 1 - x, size = 1)
    }, simplify = T))

    # capture efficiency (size factor)
    if (sim.options$size.factors == "equal") {
      all.facs <- rep(1, nsamples)
    }
    if (sim.options$size.factors == "given") {
      if (is.function(sim.options$sf)) {
        all.facs <- sim.options$sf(nsamples)
      }
      if (is.vector(sim.options$sf)) {
        all.facs <- sample(sim.options$sf, nsamples, replace = TRUE)
      }
      if (is.null(sim.options$sf)) {
        all.facs <- rep(1, nsamples)
      }
    }

    # effective means
    effective.means <- outer(true.means, all.facs, "*")

    # make mean expression with beta coefficients added as defined by model matrix
    ind = !apply(mod, 2, function(x) { all(x == 1) })
    mod = cbind(mod[, ind])
    beta = cbind(beta[, ind])
    mumat = log2(effective.means + 1) + beta %*% t(mod)
    mumat[mumat < 0] = 0

    # result count matrix
    cnts = matrix(stats::rnbinom(nsamples * ngenes, mu = 2 ^ mumat - 1, size = 2 ^ sizevec), ncol = nsamples, nrow = ngenes)
    counts = p0mat * cnts
  }

  if (attr(sim.options, 'param.type') == 'insilico') {

    # sample from the mean function provided
    true.means = sim.options$means(ngenes)

    # sample dropout parameter
    if (is.null(sim.options$p0)) {
      p0s <- rep(0, ngenes)
    }
    if (is.function(sim.options$p0)) {
      p0s <- sim.options$p0(ngenes)
    }
    p0mat = t(sapply(p0s, function(x) {
      stats::rbinom(nsamples, prob = 1 - x, size = 1)
    }, simplify = T))

    # associate with dispersion parameter
    if (length(sim.options$dispersion) == 1) {
      disp = sim.options$dispersion
    }
    if (is.function(sim.options$dispersion)) {
      disp = sim.options$dispersion(true.means)
    }

    # capture efficiency (size factor)
    if (sim.options$size.factors == "equal") {
      all.facs <- rep(1, nsamples)
    }
    if (sim.options$size.factors == "given") {
      if (is.function(sim.options$sf)) {
        all.facs <- sim.options$sf(nsamples)
      }
      if (is.vector(sim.options$sf)) {
        all.facs <- sample(sim.options$sf, nsamples, replace = TRUE)
      }
      if (is.null(sim.options$sf)) {
        all.facs <- rep(1, nsamples)
      }
    }

    # effective means
    effective.means <- outer(true.means, all.facs, "*")

    # make mean expression with beta coefficients added as defined by model matrix
    ind = !apply(mod, 2, function(x) { all(x == 1) })
    mod = cbind(mod[, ind])
    beta = cbind(beta[, ind])
    mumat = log2(effective.means + 1) + beta %*% t(mod)
    mumat[mumat < 0] = 0

    # result count matrix
    cnts = matrix(stats::rnbinom(nsamples * ngenes, mu = 2 ^ mumat - 1, size = 1/disp), ncol = nsamples, nrow = ngenes)
    counts = p0mat * cnts
  }

  return(counts)
}
