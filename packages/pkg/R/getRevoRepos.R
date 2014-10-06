"getRevoRepos" <- function(version = paste(unlist(unclass(getRversion()))[1:2], collapse="."), CRANmirror=FALSE)
{
	if (CRANmirror)
	{
		return("http://cran.revolutionanalytics.com")
	}
	else
	{
		return(paste("http://packages.revolutionanalytics.com/cran", version, "stable", sep="/"))
	}
}