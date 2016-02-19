## See : Task 6833892:Figure out wherer testR will get auxillary packages
## Task 6833849:Write entry script for MRO IOQ test.
## propose
## IOQR as a package like RevoIOQ.
##
## See Rich's spread sheet of what needs tested
##
## Should IOQR use latest OpenSource RUnit or ours with enhanced environment reporting?
##

Status: IOQR Seems to be working...

load package from git: IOQR
setwd("RRO/test")
load required package from nugit
load required package from mran
retval = IOQR()
# Result should be pass failed and html, xml, txt file showing results.

(powershell)
$env:Path="c:\Rtools-3.2.0.1948\bin;c:\Rtools-3.2.0.1948\gcc-4.6.3\bin;C:\Programs\MiKTeX2.9\miktex\bin;$env:Path"
echo $env:path


$WORKDIR="D:\MRO-Test-Harness\RRO\test"
cd $WORKDIR/IOQR/

R.exe CMD build pkg
R.exe CMD INSTALL IOQR*0.0.1.tar.gz
## R.exe CMD INSTALL pkg
search()
library("IOQR")

IOQR()


source("pkg/R/IOQR.R")



library(RUnit)
source("C:/Users/derbrown/R/win-library/3.2/IOQR/unitTests/R/common/runit-d-p-q-r-tests.R" )
d.p.q.r.tests.stress()
source("d:/MRO-Test-Harness/RUnit/pkg/R/testLogger.r")
source("d:/MRO-Test-Harness/RUnit/pkg/R/runit.r")
##RUnit:::.sourceTestFile("C:/Users/derbrown/R/win-library/3.2/IOQR/unitTests/R/common/runit-array-subset.R")

sapply(Sys.glob("d:/MRO-Test-Harness/RUnit/pkg/R/*.r" ),source,.GlobalEnv)
?list.files

file.sources = list.files(pattern="d:/MRO-Test-Harness/RUnit/pkg/R/*.r" )

dir("d:/MRO-Test-Harness/RUnit/pkg/R/" )
file.sources
sapply(file.sources,source,.GlobalEnv)


sapply(Sys.glob("/MRO-Test-Harness/RRO/test/IOQR/pkg/R/*.R" ),source,.GlobalEnv)
sapply(Sys.glob("d:/MRO-Test-Harness/RUnit/pkg/R/*.r" ),source,.GlobalEnv)

runTestFile("d:/MRO-Test-Harness/IOQR/unitTests/R/common/runit-array-subset.R" ,testFuncRegexp="^test.*",verbose=3)

R.exe CMD build RevoIOQ/pkg
R.exe CMD INSTALL RevoIOQ*.tar.gz

packageDescription("IOQR")
search()
library("RevoIOQ")
RevoIOQ()

cd d:\MRO-Test-Harness
R.exe CMD build RRO/test/IOQR/pkg
R.exe CMD INSTALL IOQR*.tar.gz
detach(package:IOQR,unload=TRUE)
library("IOQR")

IOQR(testFileRegexp="runit.package.loadability.R",
     testFuncRegexp="test.recommended.package.rpart.loadability",
     outdir=getwd(),
     printJUnit=FALSE)

dir()

remove.packages(c('IOQR'))
remove.packages(c('RUnit'))
list.packages()

####################
setwd("..")
install.packages("devtools")
library("devtools")
build("IOQR/pkg")
install.packages("IOQR/IOQR_0.0.2.tar.gz")
dir()
library("IOQR")
source("RunTest_IOQR.R")
