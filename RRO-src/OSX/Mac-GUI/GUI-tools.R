## R GUI supplementary code and tools (loaded since R 2.9.0)

## target environment for all this
.e <- attach(NULL, name = "tools:RGUI")

if (getRversion() < "3.0.0") error(" NOTE: your R version is too old")

add.fn <- function(name, FN) {
    assign(name, FN, .e)
    environment(.e[[name]]) <- .e
}


## print.hsearch is our way to display search results internally
add.fn("print.hsearch", function (x, ...)
{
    if (.Platform$GUI == "AQUA") {
        db <- x$matches
        rows <- NROW(db)
        if (rows == 0) {
            writeLines(strwrap(paste("No help files found matching",
                                     sQuote(x$pattern), "using", x$type, "matching\n\n")))
        } else {
	    ## someone changed the case of some variables in R 3.2.0 so we have to ignore it
	    names(db) <- tolower(names(db))
            url = character(rows)
            for (i in 1:rows) {
		lib <- dirname(db[i, "libpath"])
                tmp <- as.character(help(db[i, "topic"],
                                         package = db[i, "package"],
                                         lib.loc = lib, help_type = 'html'))
                if (length(tmp) > 0)
                    url[i] <- gsub(lib, '/library', tmp, fixed = TRUE)
            }
            wtitle <- paste("Help topics matching", sQuote(x$pattern))
            showhelp <- which(.Call("hsbrowser", db[, "topic"],
                                    db[, "package"], db[, "title"],
                                    wtitle, url))
            for (i in showhelp)
                print(help(db[i, "topic"], package = db[i, "package"]))
        }
        invisible(x)
    }
    else utils:::printhsearchInternal(x, ...)
})

## --- the following functions are compatibility functions that wil go away very soon!

add.fn("browse.pkgs", function (repos = getOption("repos"), contriburl = contrib.url(repos, type), type = getOption("pkgType"))
{
    if (.Platform$GUI != "AQUA")
        stop("this function is intended to work with the Aqua GUI")
    x <- installed.packages()
    i.pkgs <- as.character(x[, 1])
    i.vers <- as.character(x[, 3])
    label <- paste("(", type, ") @", contriburl)
    y <- available.packages(contriburl = contriburl)
    c.pkgs <- as.character(y[, 1])
    c.vers <- as.character(y[, 2])
    idx <- match(i.pkgs, c.pkgs)
    vers2 <- character(length(c.pkgs))
    xx <- idx[which(!is.na(idx))]
    vers2[xx] <- i.vers[which(!is.na(idx))]
    i.vers <- vers2
    want.update <- rep(FALSE, length(i.vers))
    .Call("pkgbrowser", c.pkgs, c.vers, i.vers, label, want.update)
})

add.fn("Rapp.updates", function ()
{
    if (.Platform$GUI != "AQUA")
        stop("this function is intended to work with the Aqua GUI")
    cran.ver <- readLines("http://cran.r-project.org/bin/macosx/VERSION")
    ver <- strsplit(cran.ver, "\\.")
    cran.ver <- as.numeric(ver[[1]])
    rapp.ver <- paste(R.Version()$major, ".", R.version$minor, sep = "")
    ver <- strsplit(rapp.ver, "\\.")
    rapp.ver <- as.numeric(ver[[1]])
    this.ver <- sum(rapp.ver * c(10000, 100, 1))
    new.ver <- sum(cran.ver * c(10000, 100, 1))
    if (new.ver > this.ver) {
        cat("\nThis version of R is", paste(rapp.ver, collapse = "."))
        cat("\nThere is a newer version of R on CRAN which is",
            paste(cran.ver, collapse = "."), "\n")
        action <- readline("Do you want to visit CRAN now? ")
        if (substr(action, 1, 1) == "y")
            system("open http://cran.r-project.org/bin/macosx/")
    } else cat("\nYour version of R is up to date\n")
})

add.fn("package.manager", function ()
{
    if (.Platform$GUI != "AQUA")
        stop("this function is intended to work with the Aqua GUI")
    loaded.pkgs <- .packages()
    x <- library()
    x <- x$results[x$results[, 1] != "base", ]
    pkgs <- x[, 1]
    pkgs.desc <- x[, 3]
    is.loaded <- !is.na(match(pkgs, loaded.pkgs))
    pkgs.status <- character(length(is.loaded))
    pkgs.status[which(is.loaded)] <- "loaded"
    pkgs.status[which(!is.loaded)] <- " "
    pkgs.url <- file.path(find.package(pkgs, quiet=TRUE), "html", "00Index.html")
    load.idx <-
        .Call("pkgmanager", is.loaded, pkgs, pkgs.desc, pkgs.url)
    toload <- which(load.idx & !is.loaded)
    tounload <- which(is.loaded & !load.idx)
    for (i in tounload) {
        cat("unloading package:", pkgs[i], "\n")
        do.call("detach", list(paste("package", pkgs[i], sep = ":")))
    }
    for (i in toload) {
        cat("loading package:", pkgs[i], "\n")
        library(pkgs[i], character.only = TRUE)
    }
})

add.fn("rcompgen.completion", function (x)
{
    utils:::.assignLinebuffer(x)
    utils:::.assignEnd(nchar(x))
    utils:::.guessTokenFromLine()
    utils:::.completeToken()
    utils:::.CompletionEnv[["comps"]]
})

add.fn("data.manager", function ()
{
    if (.Platform$GUI != "AQUA")
        stop("this function is intended to work with the Aqua GUI")
    data.by.name <- function(datanames) {
        aliases <- sub("^.+ +\\((.+)\\)$", "\\1", datanames)
        data(list = ifelse(aliases == "", datanames, aliases))
    }
    x <- suppressWarnings(data(package = .packages(all.available = TRUE)))
    dt <- x$results[, 3]
    pkg <- x$results[, 1]
    desc <- x$results[, 4]
    len <- NROW(dt)
    url <- character(len)
    for (i in 1:len) {
        tmp <- as.character(help(dt[i], package = pkg[i], help_type = "html"))
        if (length(tmp) > 0)
            url[i] <- tmp
    }
    as.character(help("BOD", package = "datasets", help_type = "html"))
    load.idx <- which(.Call("datamanager", dt, pkg, desc, url))
    for (i in load.idx) {
        cat("loading dataset:", dt[i], "\n")
        data.by.name(dt[i])
    }
})

# added "interactive" argument to "prompt(...)"
# if interactive == TRUE the generated Rd doc will be opened in R.app
#   for filename = NA or filename == NULL -> an untitled new Rd doc for passed function
#   for filename = a_path -> a_path will be opened for passed function

add.fn("prompt", function (object, filename = NULL, name = NULL, interactive = FALSE, ...)
{
    if(interactive == FALSE) {
        ## call default prompt()
        ## the name setting here is necessary to avoid taking 'object'
        ## as passed name - TODO has to be improved
        if(missing(name))
            name <- if(is.character(object))
                object
            else {
                name <- substitute(object)
                if(is.name(name))
                    as.character(name)
                else if(is.call(name)
                        && (as.character(name[[1L]]) %in% c("::", ":::", "getAnywhere"))) {
                    name <- as.character(name)
                    name[length(name)]
                }
                else
                    stop("cannot determine a usable name")
            }
        return(utils:::prompt(object, filename = filename, name= name, ...))
    } else {
        ## let R.app handle the result of prompt()
        isTempFile <- FALSE
        if(is.null(filename) || is.na(filename)) {
            ## if no filename was passed we do it on a temporary file
            ## which will be removed by 'RappPrompt->RController.handlePromptRdFileAtPath
            isTempFile <- TRUE
            filename <- tempfile()
        }
        ## call default prompt() by suppressing the outputted messages since
        ## we're in interactive mode
        suppressMessages(utils:::prompt(object=object, filename = filename, name = name, ...))
        ## let RappPrompt - defined in main.m - handle the generated Rd file
        invisible(.Call("RappPrompt", filename, isTempFile))
    }
})

## we catch q/quit to make sure users don't use it inadvertently
if (!isTRUE(getOption("RGUI.base.quit"))) {
add.fn("q", function (save = "default", status = 0, runLast = TRUE)
       .Call("RappQuit", save, status, runLast))
add.fn("quit", function (save = "default", status = 0, runLast = TRUE)
       .Call("RappQuit", save, status, runLast))
}

.e[[".__RGUI__..First"]] <- .GlobalEnv$.First


add.fn("aqua.browser", function(x, ...) {
    .Call("aqua.custom.print", "help-files", x)
    invisible(x)})

add.fn("main.help.url",
       function() help.start(browser = function(x, ...) {
           .Call("aqua.custom.print", "help-files", x)
           invisible(x)
       })
)

add.fn("wsbrowser", function(IDS, IsRoot, Container, ItemsPerContainer,
                            ParentID, NAMES, TYPES, DIMS)
{
    .Call("wsbrowser", as.integer(IDS), IsRoot, Container,
          as.integer(ItemsPerContainer), as.integer(ParentID),
          NAMES, TYPES, DIMS)
    invisible()
})

## As from R 2.15.x the BioC version cannot be determined algorithmically

add.fn("setBioCversion", function()
{
    old <- getOption('BioC.Repos')
    if(!is.null(old)) return(old)
    mirror <- getOption("BioC_mirror", "http://www.bioconductor.org")
    ## as of R 3.2.0 it is a function and not a scalar
    ver <- as.character(if (is.function(tools:::.BioC_version_associated_with_R_version)) tools:::.BioC_version_associated_with_R_version() else tools:::.BioC_version_associated_with_R_version)
    options("BioC.Repos" = paste(mirror, "packages",
            ver, c("bioc", "data/annotation", "data/experiment", "extra"),
            sep = "/"))
    getOption('BioC.Repos')
})

if (nzchar(Sys.getenv("R_GUI_APP_VERSION"))) {
    cat("[R.app GUI ",
        Sys.getenv("R_GUI_APP_VERSION")," (",
        Sys.getenv("R_GUI_APP_REVISION"),") ",
        R.version$platform,"]\n\n", sep = '')
} else {
    cat("[Warning: GUI-tools are intended for internal use by the R.app GUI only]\n")
}
