Sys.setenv(LC_COLLATE = "C", LC_TIME = "C", LANGUAGE = "en")
library("tools")
testInstalledBasic("both")
testInstalledPackages(scope = "recommended")
