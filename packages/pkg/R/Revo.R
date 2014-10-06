setMKLthreads <- function(n=.Default.Revo.Threads){
    if (n == -1L){
        warning("this system does not appear to support MKL thread control")
        return(-1L)
    }
    if (n <= 0) {
	  stop ("n must be a positive number.")
    }
    m <- getMKLthreads()
    tryCatch(.C("setThreads", n=as.integer(n), PACKAGE="Revobase"),
        error=function(e) {
            if (any(nzchar(e$message))) {
                warning(e$message)
            } else {
                warning("Unknown problem in call to setThreads")
            }
            return(-1L)
        }
    )
	if (is.loaded("RxSetMKLthreads")){
		 # this essentially re-implements RevoScaleR's rxCall without loading RevoScaleR
	     PACKAGE <- ifelse(.Platform$OS.type == "windows", "RxLink", "libRxLink.so.2")
		 if (.Platform$OS.type == "windows") {
			oldPath <- Sys.getenv("PATH")
			on.exit(Sys.setenv(PATH = oldPath), add=TRUE)
			rxOpts <- getOption("rxOptions")
			if (!is.null(rxOpts)) {
				libDir <- rxOpts$libDir
			}
			if (!is.null(libDir)) {
				Sys.setenv(PATH = sprintf("%s:%s", oldPath, libDir))
			}
		}
		.Call("RxSetMKLthreads", list(n=n), PACKAGE = PACKAGE)
	}
    n1 <- getMKLthreads()
    if (n1!=n && n1 > 0) {
        if (m == n1) {
            cat ("\nNumber of threads at maximum: no change has been made.\n\n")
        } else {
            cat("\nMKL threads are not set as requested:\n", n1, " instead of ", n, " threads are used.\n\n")
        }
    }
    invisible(m)
}

getMKLthreads <- function() {
    x <- tryCatch(.C("getThreads", n=as.integer(1), PACKAGE="Revobase"),
        error=function(e) {
            if (any(nzchar(e$message))) {
                warning(e$message)
            } else {
                warning("Unknown problem in call to getThreads")
            }
            list(n=-1L)
        }
    )
    x$n
}

version.MKL <- function()
{
    sub("\\s+$","",
        capture.output(tmp <- tryCatch(.C("getVersionString", PACKAGE="Revobase"),
                                       error=function(e) {
                                           if (any(nzchar(e$message))) {
                                               warning(e$message)
                                           } else {
                                               warning("Unknown problem in call to getVersionString")
                                           }
                                           "No MKL version found"
                                       }
                                       )))
}

Revo.warning <- function(..., ignore=FALSE)
{
  if (!ignore) warning(...)
}

isOSX <- function() length(grep("^darwin", R.version$os)) > 0
isUnix <- function() .Platform$OS.type == "unix"

