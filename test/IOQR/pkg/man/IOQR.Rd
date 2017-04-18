\name{IOQR}
\alias{IOQR}
\title{R Services Quality Assurance}
\description{This package defines tests to be run as installation and operation qualification of R.}
\usage{
IOQR(printText=TRUE, printHTML=TRUE, outdir=if (file.access(getwd(), mode=2)) file.path(tempdir(),"IOQR") else file.path(getwd(),"IOQR"),
        basename=paste("IOQR-Report", format(Sys.time(), "\%m-\%d-\%Y-\%H-\%M-\%S"), sep="-"),
        view=TRUE, clean=TRUE, runTestFileInOwnProcess=TRUE, testLocal = FALSE )
}
\arguments{
  \item{printText}{logical flag. If \code{TRUE}, an RUnit test report in ASCII text format is produced.}
  \item{printHTML}{logical flag. If \code{TRUE}, an RUnit test report in HTML format is produced.}
  \item{outdir}{character string representing path to output report directory.}
  \item{basename}{character string denoting the name of the output file (sans the extension).}
  \item{view}{logical flag. If \code{TRUE} and either \code{printText=TRUE} or \code{printHTML=TRUE}, then
  the resulting output file is shown, respectively.}
  \item{clean}{logical flag. If \code{TRUE}, then graphics files created during the tests are removed.}
  \item{runTestFileInOwnProcess}{logical flag. If \code{TRUE}, each test file
  is run in a separate R process.}
  \item{testLocal}{logical flag. If \code{TRUE}, a set of basic tests is created and run for all locally-installed packages.}
}

\value{
    \code{TRUE} if all tests are successful, \code{FALSE} otherwise.
}

\examples{
IOQR()
}

\keyword{package}
