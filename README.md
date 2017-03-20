
<!-- README.md is generated from README.Rmd. Please edit that file -->
powsim: Power analysis for bulk and single cell RNA-seq experiments
===================================================================

Installation Guide
------------------

To install powsim, make sure you have installed the following R packages:

``` r
ipak <- function(pkg, repository = c("CRAN", "Bioconductor", "github")) {
    new.pkg <- pkg[!(pkg %in% installed.packages()[, "Package"])]
    if (length(new.pkg)) {
        if (repository == "CRAN") {
            install.packages(new.pkg, dependencies = TRUE)
        }
        if (repository == "Bioconductor") {
            source("https://bioconductor.org/biocLite.R")
            biocLite(new.pkg, dependencies = TRUE, ask = FALSE)
        }
        if (repository == "github") {
            devtools::install_github(pkg, build_vignettes = FALSE)
        }
    }
}

# CRAN PACKAGES
cranpackages <- c("gamlss.dist", "methods", "stats", "moments", "doParallel", 
    "parallel", "reshape2", "dplyr", "tidyr", "data.table", "ggplot2", "ggthemes", 
    "ggExtra", "cowplot", "scales", "fitdistrplus", "MASS", "pscl", "nonnest2", 
    "cobs", "msir", "drc", "devtools", "XML", "splines")
ipak(cranpackages, repository = "CRAN")

# BIOCONDUCTOR
biocpackages <- c("S4Vectors", "AnnotationDbi", "Biobase", "BiocParallel", "BiocStyle", 
    "scater", "scran", "edgeR", "limma", "DESeq2", "baySeq", "NOISeq", "EBSeq", 
    "DSS", "MAST", "ROTS", "IHW", "qvalue")
ipak(biocpackages, repository = "Bioconductor")

# GITHUB
githubpackages <- c("gu-mi/NBGOF", "hms-dbmi/scde", "nghiavtr/BPSC")
ipak(githubpackages, repository = "github")
devtools::install_github("kdkorthauer/scDD", build_vignettes = FALSE, ref = "develop")
```

After installing the dependencies, powsim can be installed by using devtools as well.

``` r
devtools::install_github("bvieth/powsim", build_vignettes = TRUE)
```

User Guide
----------

For examples and tips on using the package, please see the vignette PDF [here](https://github.com/bvieth/powsim/tree/master/vignettes/powsim.pdf) or open it in R by typing

``` r
browseVignettes("powsim")
```

A preprint paper describing powsim is now on [bioRxiv](https://doi.org/10.1101/117150).

Notes
-----

Please send bug reports and feature requests by opening a new issue on [this page](https://github.com/bvieth/powsim/issues).

Note that the error "maximal number of DLLs reached..." might occur due to the loading of many shared objects by Bioconductor packages. Restarting the R session after installing dependencies / powsim will help.

R Session Info
--------------

``` r
sessionInfo()
#> R version 3.3.3 (2017-03-06)
#> Platform: x86_64-pc-linux-gnu (64-bit)
#> Running under: Ubuntu 14.04.5 LTS
#> 
#> locale:
#>  [1] LC_CTYPE=en_GB.UTF-8       LC_NUMERIC=C              
#>  [3] LC_TIME=de_DE.UTF-8        LC_COLLATE=en_GB.UTF-8    
#>  [5] LC_MONETARY=de_DE.UTF-8    LC_MESSAGES=en_GB.UTF-8   
#>  [7] LC_PAPER=de_DE.UTF-8       LC_NAME=C                 
#>  [9] LC_ADDRESS=C               LC_TELEPHONE=C            
#> [11] LC_MEASUREMENT=de_DE.UTF-8 LC_IDENTIFICATION=C       
#> 
#> attached base packages:
#> [1] stats     graphics  grDevices utils     datasets  methods   base     
#> 
#> loaded via a namespace (and not attached):
#>  [1] backports_1.0.5 magrittr_1.5    rprojroot_1.2   formatR_1.4    
#>  [5] tools_3.3.3     htmltools_0.3.5 yaml_2.1.14     Rcpp_0.12.9    
#>  [9] stringi_1.1.2   rmarkdown_1.3   knitr_1.15.1    stringr_1.2.0  
#> [13] digest_0.6.12   evaluate_0.10
```
