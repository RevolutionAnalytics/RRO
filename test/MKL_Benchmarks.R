#library(Revobase)
runMKLBenchmarks<-function()
{
#  cat("MKL Threads being used: ", getMKLthreads(), "\n")
  cat("Matrix Multiply\n")
  set.seed (1)
  m <- 10000
  n <-  5000
  A <- matrix (runif (m*n),m,n)
  print(system.time (B <- crossprod(A)))

  cat("Cholesky Factorization\n")
  print(system.time (C <- chol(B)))
  cat("Singular Value Deomposition\n")
  m <- 10000
  n <- 2000
  A <- matrix (runif (m*n),m,n)
  print(system.time (S <- svd (A,nu=0,nv=0)) )

  cat("Principal Components Analysis\n")
  m <- 10000
  n <- 2000
  A <- matrix (runif (m*n),m,n)
  print(system.time (P <- prcomp(A)) )

  cat("Linear Discriminant Analysis\n")
  require ('MASS')
  g <- 5
  k <- round (m/2)
  A <- data.frame (A, fac=sample (LETTERS[1:g],m,replace=TRUE))
  train <- sample(1:m, k)
  print(system.time (L <- lda(fac ~., data=A, prior=rep(1,g)/g, subset=train)))
}

#getMKLthreads()
runMKLBenchmarks()

#setMKLthreads(1)
#runMKLBenchmarks()

