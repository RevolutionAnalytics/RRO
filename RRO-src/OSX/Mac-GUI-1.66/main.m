/*
 *  R.app : a Cocoa front end to: "R A Computer Language for Statistical Data Analysis"
 *  
 *  R.app Copyright notes:
 *                     Copyright (C) 2004-5  The R Foundation
 *                     written by Stefano M. Iacus and Simon Urbanek
 *
 *                  
 *  R Copyright notes:
 *                     Copyright (C) 1995-1996   Robert Gentleman and Ross Ihaka
 *                     Copyright (C) 1998-2001   The R Development Core Team
 *                     Copyright (C) 2002-2004   The R Foundation
 *
 *  This program is free software; you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation; either version 2 of the License, or
 *  (at your option) any later version.
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  A copy of the GNU General Public License is available via WWW at
 *  http://www.gnu.org/copyleft/gpl.html.  You can also obtain it by
 *  writing to the Free Software Foundation, Inc., 59 Temple Place,
 *  Suite 330, Boston, MA  02111-1307  USA.
 *
 *  Created by Stefano Iacus on 7/26/04.
 *  $Id: main.m 6477 2013-04-04 11:53:04Z ripley $
 */

#import <Cocoa/Cocoa.h>
#import "RGUI.h"
#import "REngine/REngine.h"
#import "Preferences.h"
#import "PreferenceKeys.h"
#import "RController.h"
#import "Rversion.h"

#import <ExceptionHandling/NSExceptionHandler.h>
#import "Tools/GlobalExHandler.h"

#include <string.h>
#include <stdlib.h>
#include <sys/utsname.h> /* for uname */

/* we need the following two to implement RappQuit and register it with R */
#include "R_ext/Rdynload.h"
#include "R_ext/RStartup.h"

/* those are exported in RGUI.h */
NSString *Rapp_R_version_short;
NSString *Rapp_R_version;
double    os_version;
char     *os_version_string;

/* this is called by the R.app q/quit function */
static SEXP RappQuit(SEXP save, SEXP status, SEXP runLast) {
	int sc, rl, save_flag = -1, cancel = 0; /* 1=yes, 0=no, -1=ask */
	const char *sv;
	if (!isString(save) || LENGTH(save) != 1) Rf_error("'save' must be a character vector of length one.");
	sc = asInteger(status);
	rl = asInteger(runLast);
	sv = CHAR(STRING_ELT(save, 0));
	if (!strcmp(sv, "yes")) save_flag = 1;
	else if (!strcmp(sv, "no")) save_flag = 0;
	else if (!strcmp(sv, "ask")) save_flag = -1;
	else if (strcmp(sv, "default"))
	    Rf_error("unrecognized value of 'save'");
	if ([RController sharedController])
		cancel = [[RController sharedController] quitRequest: save_flag withCode: sc last: rl];
	if (!cancel) /* no cancel and we're still here -> run the internal version */
		R_CleanUp((save_flag == 0) ? SA_NOSAVE : ((save_flag == -1) ? SA_SAVEASK : SA_SAVE), sc, rl);
	Rf_error("cancelled by user");
	return R_NilValue;
}

/* this is called by the R.app prompt() function in interactive mode */
static SEXP RappPrompt(SEXP filename, SEXP isTempFile) {
	BOOL isTemp = (asInteger(isTempFile) == 1) ? YES : NO;
	const char *fp;
	NSString *filepath = nil;
	if (TYPEOF(filename) == STRSXP && LENGTH(filename) > 0) {
		if (LENGTH(filename) > 1)
			Rf_warning("`filename' has more than one element, using only the first one.");
		fp = Rf_translateCharUTF8(STRING_ELT(filename, 0));
		if (fp)
			filepath = [NSString stringWithCString:fp encoding:NSUTF8StringEncoding];
	}
	if(filepath && [filepath length])
		[[RController sharedController] handlePromptRdFileAtPath:[filepath stringByExpandingTildeInPath] isTempFile:isTemp];
	else
		Rf_error("in interactive mode the argument 'filename' has to be either a valid path or NULL or NA");
	return R_NilValue;
}

SEXP pkgbrowser(SEXP rpkgs, SEXP rvers, SEXP ivers, SEXP wwwhere,
		SEXP install_dflt);
SEXP hsbrowser(SEXP h_topic, SEXP h_pkg, SEXP h_desc, SEXP h_wtitle,
	       SEXP h_url);
SEXP pkgmanager(SEXP pkgstatus, SEXP pkgname, SEXP pkgdesc, SEXP pkgurl);
SEXP datamanager(SEXP dsets, SEXP dpkg, SEXP ddesc, SEXP durl);
SEXP customprint(SEXP objType, SEXP obj);
SEXP wsbrowser(SEXP ids, SEXP isroot, SEXP iscont, SEXP numofit,
	       SEXP parid, SEXP name, SEXP type, SEXP objsize);


static R_CallMethodDef mainCallMethods[]  = {
	{"RappQuit", (DL_FUNC) &RappQuit, 3},
	{"RappPrompt", (DL_FUNC) &RappPrompt, 2},
	{"pkgbrowser", (DL_FUNC) &pkgbrowser, 5},
	{"hsbrowser", (DL_FUNC) &hsbrowser, 5},
	{"pkgmanager", (DL_FUNC) &pkgmanager, 4},
	{"datamanager", (DL_FUNC) &datamanager, 4},
	{"aqua.custom.print", (DL_FUNC) &customprint, 2},
	{"wsbrowser", (DL_FUNC) &wsbrowser, 8},
	{NULL, NULL, 0}
};

static struct utsname os_uname;

int main(int argc, const char *argv[])
{
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

    uname(&os_uname);
    os_version_string = strdup(os_uname.release);
    os_version = atof(os_uname.release);

    if ([Preferences flagForKey:@"Debug all exceptions"] == YES) {
	// add an independent exception handler
	[[GlobalExHandler alloc] init]; // the init method also registers the handler
	[[NSExceptionHandler defaultExceptionHandler] setExceptionHandlingMask: 1023]; // hang+log+handle all
    }

    Rapp_R_version_short = [[NSString alloc] initWithFormat:@"%d.%d", (R_VERSION >> 16), (R_VERSION >> 8)&255];
    Rapp_R_version = [[NSString alloc] initWithFormat:@"%s.%s", R_MAJOR, R_MINOR];
	
    [NSApplication sharedApplication];
    [NSBundle loadNibNamed:@"MainMenu" owner:NSApp];
	
    SLog(@" - initalizing R");
    if (![[REngine mainEngine] activate]) {
	NSRunAlertPanel(NLS(@"Cannot start R"),[NSString stringWithFormat:NLS(@"Unable to start R: %@"), [[REngine mainEngine] lastError]],NLS(@"OK"),nil,nil);
	exit(-1);
    }
	 
    SLog(@" - load R code for R.app");
    R_registerRoutines(R_getEmbeddingDllInfo(), 0, mainCallMethods, 0, 0);
	
    NSString *codePath = [[NSBundle mainBundle] pathForResource:@"GUI-tools.R" ofType:@""];
    SLog(@" - loading code from '%@'", codePath);
    [[REngine mainEngine] executeString: [NSString stringWithFormat:@"try(local(source(\"%@\",local=TRUE,echo=FALSE,verbose=FALSE,encoding='UTF-8',keep.source=FALSE)))", codePath]];
	
    SLog(@" - set R options");
    // force html-help, because that's the only format we can handle ATM
    [[REngine mainEngine] executeString: @"options(help_type='html')"];	

    SLog(@" - set default CRAN mirror");
    {
	NSString *url = [Preferences stringForKey:defaultCRANmirrorURLKey withDefault:@""];
	if (![url isEqualToString:@""])
	    [[REngine mainEngine] executeString:[NSString stringWithFormat:@"try(local({ r <- getOption('repos'); r['CRAN']<-gsub('/$', '', \"%@\"); options(repos = r) }),silent=TRUE)", url]];
    }
	 
    SLog(@" - loading secondary NIBs");
    if (![NSBundle loadNibNamed:@"Vignettes" owner:NSApp]) {
	SLog(@" * unable to load Vignettes.nib!");
    }

    SLog(@"main: finish launching");
    [NSApp finishLaunching];
 
    // torture
    [pool release];
    pool = [[NSAutoreleasePool alloc] init];

    // ready to rock
    SLog(@"main: entering REPL");
    [[REngine mainEngine] runREPL];
	 
    SLog(@"main: returned from REPL");
    [pool release];
	 
    SLog(@"main: exiting with status 0");
    return 0;
}
