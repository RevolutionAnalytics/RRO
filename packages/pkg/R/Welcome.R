"isXP" <- function()
{
	length(grep("XP", utils::win.version())) > 0
}
"revo" <- function()
{
	onWindows <- .Platform$OS.type == "windows"
	RevoURL <- "http://www.revolutionanalytics.com/"
    if ((onWindows && isXP()) || (!onWindows && capabilities("X11") == FALSE)) {
        cat("For the latest information on Revolution Analytics, enter the following \nURL in your browser:\n",
            RevoURL, "\n")
    }
    else {
        browseURL(RevoURL)
    }   
    invisible(NULL)
}
"forum" <- function()
{
	onWindows <- .Platform$OS.type == "windows"
	ForumURL <- "https://revolutionanalytics.zendesk.com/forums"
    if ((onWindows && isXP()) || (!onWindows && capabilities("X11") == FALSE)) {
        cat("To post questions and find answers about Revolution products, enter \nthe following URL in your browser:\n",
            ForumURL, "\n")
    }
    else {
        browseURL(ForumURL)
    }      
    invisible(NULL)
}
"readme" <- function()
{
    onWindows <- .Platform$OS.type == "windows"
	isNetezza <- (!identical(system.file("DESCRIPTION", package="nzrserver") , "")) && identical(system.file("DESCRIPTION", package="RevoScaleR") , "")
    revoVersion <- paste(Revo.version$major, Revo.version$minor, sep=".")
	revoPrefix <- paste("http://packages.revolutionanalytics.com/doc/", revoVersion, "/", sep="")
    winEntUrl <- paste(revoPrefix, "README_RevoEnt_Windows_", revoVersion, ".pdf", sep="" )
    linuxEntUrl <- paste(revoPrefix, "README_RevoEnt_", ifelse(isNetezza, "INZA_", "Linux_"), revoVersion, ".pdf", sep="" )
    winComUrl <- paste(revoPrefix, "README_RevoCom_Windows_", revoVersion, ".pdf", sep="" )
    linuxComUrl <- paste(revoPrefix, "README_RevoCom_Linux_", revoVersion, ".pdf", sep="" )
    if (length(grep("Enterprise", Revo.version$version.string)) > 
        0) {
        if ((onWindows && isXP()) || (!onWindows && capabilities("X11") == FALSE)) {
            cat("For the latest information on Revolution R Enterprise, enter the following \nURL in your browser:\n",
                ifelse(onWindows,winEntUrl, linuxEntUrl), "\n")
        }
        else {
            browseURL(ifelse(onWindows, winEntUrl, linuxEntUrl))
        }
    }
    else {
         if ((onWindows && isXP()) || (!onWindows && capabilities("X11") == FALSE)) {
            cat("For the latest information on Revolution R Community, enter the following \nURL in your browser:\n",
                ifelse(onWindows,winComUrl, linuxComUrl), "\n")
        }
        else {
            browseURL(ifelse(onWindows, winComUrl, linuxComUrl))
        }
    }
    invisible(NULL)
}
"RevoLicense" <- function(pager=getOption("pager"))
{
    filename <-  if (length(grep("Enterprise", Revo.version$version.string)) > 0) {
             "RevolutionEnterpriseLicense"
         } else {
             "RevolutionLicense"
         }
    if (.Platform$OS.type=="windows") {
	   filename <- paste(filename, ".txt", sep="")
	   if (!hasArg("pager")) { 
		 pager <- "notepad"
         }
    }
    file.show(file.path(Revo.home("licenses"), filename), pager=pager)
    invisible(NULL)
}
