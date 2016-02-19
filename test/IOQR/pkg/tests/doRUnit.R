if (require("RUnit", quietly=TRUE))
{
  library("IOQR")
  if (!IOQR:::IOQR(view=FALSE))
  {
    stop("RUnit failures/errors were encountered during the running of IOQR. See test reports for more information.")
  }
} else {
  warning("cannot run unit tests -- package RUnit is not available")
}
