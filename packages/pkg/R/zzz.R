".onLoad" <- function(libname, pkgname){
  tryCatch(library.dynam("Revobase", pkgname, libname),
      error=function(e) {
          if (any(nzchar(e$message))) {
              Revo.warning(e$message, ignore=isUnix())
          } else {
              Revo.warning("Unknown problem in call to library.dynam", ignore=isUnix())
          }
      })
  if (!isOSX()) 
  	.Default.Revo.Threads <<- getMKLthreads()
}

.Last.lib <- function (libpath){
  Revobase:::unlinkDeleteList()
  tryCatch(library.dynam.unload("Revobase", libpath),
      error=function(e) {
          if (any(nzchar(e$message))) {
              Revo.warning(e$message, ignore=isUnix())
          } else {
              Revo.warning("Unknown problem in call to library.dynam", ignore=isUnix())
          }
      })
 }

# A placeholder for .Default.Revo.Threads: 
# It will be replaced when Revobase.dll is available
.Default.Revo.Threads <- -1L 
