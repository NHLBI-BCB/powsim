% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/plotting.R
\name{plotEvalDist}
\alias{plotEvalDist}
\title{Visualize distribution assessment}
\usage{
plotEvalDist(evalDist, annot=TRUE)
}
\arguments{
\item{evalDist}{The output of \code{\link{evaluateDist}}.}

\item{annot}{A logical vector. If \code{TRUE}, a short description of the plot is included.}
}
\value{
A ggplot object.
}
\description{
This function plots the results of \code{\link{evaluateDist}} to assess goodness-of-fit testing.
}
\examples{
## for example see \\code{\\link{evaluateDist}}
}
\author{
Beate Vieth, Ines Hellmann
}
