"makeRevoVersion" <- function(){
	haveRevoScaleR <- !identical(system.file("DESCRIPTION", package="RevoScaleR") , "")
    if (haveRevoScaleR){
		if (.Platform$OS.type == "windows" && !file.exists(file.path(RevoMods::Revo.home(), "IDE32"))){
			RevoEdition <- "Revolution R Enterprise (Compute Node)"
		} else {
			RevoEdition <- "Revolution R Enterprise"
		}
    } else {
        RevoEdition <- "Revolution R Community"
    }
    Revobase.version <- as.character(utils::packageVersion("Revobase"))
    Revobase.version.components <- strsplit(Revobase.version, "\\.")[[1]]
    Revo.version <- version
    Revo.version$major <- Revobase.version.components[1]
    Revo.version$minor <- paste(Revobase.version.components[2], Revobase.version.components[3], sep=".")
    buildDate <- strsplit(utils::packageDescription("Revobase", field="Built"),"; ")[[1]][3]
	buildDate2 <- strsplit(strsplit(buildDate, " ")[[1]][1], "-")[[1]]
	Revo.version$year <- buildDate2[1]
    Revo.version$month <- buildDate2[2]
    Revo.version$day <- buildDate2[3]
	Revo.version$"svn rev" <- NULL
    Revo.version$"BuildID" <- scan(file.path(RevoMods::Revo.home(), "BuildID"), what="", quiet=TRUE)
    if (haveRevoScaleR) {
        Revo.version$"RevoScaleR BuildID" <- utils::packageDescription("RevoScaleR", field="RevoBuildId")
    }
    Revo.version$version.string <- paste(RevoEdition, " version " , Revobase.version, " (", buildDate, ")", sep="")
    Revo.version
}


