\name{setMKLthreads}
\alias{setMKLthreads}
\alias{getMKLthreads}
\title{Set the Number of Threads for Math Kernel Library}
\description{Set (or get) the maximum number of threads that can be started by the Math
Kernel Library BLAS. This should be less than or equal to the number of 
processing cores on your computer. }
\usage{
setMKLthreads(n)
getMKLthreads()
}
\arguments{
  \item{n}{an integer specifying the maximum number of threads. If missing, all available processors will be used.}
}

\examples{

# by default using all cores available
getMKLthreads() 
setMKLthreads(1)
getMKLthreads()
setMKLthreads()
getMKLthreads()
setMKLthreads(1)
try (setMKLthreads(1000), silent=TRUE)
getMKLthreads()
}
\keyword{programming}
