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
 *                     Copyright (C) 1998-2012   The R Development Core Team
 *                     Copyright (C) 2002-2005   The R Foundation
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
 */

#include <Rversion.h>
#if R_VERSION < R_Version(3,0,0)
#error R >= 3.0.0 is required
#endif

#define R_INTERFACE_PTRS 1
#define CSTACK_DEFNS 1

#include <R.h>
#include <Rinternals.h>
#include "Rinit.h"
#include "Rcallbacks.h"
#include <R_ext/Parse.h>

#include <R_ext/GraphicsEngine.h>

#include <Rembedded.h>

/* This constant defines the maximal length of single ReadConsole input, which usually corresponds to the maximal length of a single line. The buffer is allocated dynamically, so an arbitrary size is fine. */
#ifndef MAX_R_LINE_SIZE
#define MAX_R_LINE_SIZE 32767
#endif

#include <Rinterface.h>

/* and SaveAction is not officially exported */
extern SA_TYPE SaveAction;

extern SEXP (*ptr_do_wsbrowser)(SEXP, SEXP, SEXP, SEXP);
extern int  (*ptr_Raqua_CustomPrint)(char *, SEXP); /* custom print proxy */

// Private hook used from src/main/sysutils.c
extern int  (*ptr_CocoaSystem)(const char *);

int end_Rmainloop(void);    /* from src/main.c */
int Rf_initialize_R(int ac, char **av); /* from src/unix/system.c */

/*--- note: the REPL code was modified, R_ReplState is not the same as used internally in R */

typedef struct {
  ParseStatus    status;
  int            prompt_type;
  int            browselevel;
  int            buflen;
  unsigned char *buf;
  unsigned char *bufp;
} R_ReplState;

/*---------- implementation -----------*/

static R_ReplState state = {0, 1, 0, (MAX_R_LINE_SIZE+1), NULL, NULL};

char *lastInitRError = 0;

/* Note: R_SignalHandlers are evaluated in setup_Rmainloop which is called inside initR */
int initR(int argc, char **argv, int save_action) 
{
    if (!getenv("R_HOME")) {
        lastInitRError = "R_HOME is not set. Please set all required environment variables before running this program.";
        return -1;
    }
    
    int stat=Rf_initialize_R(argc, argv);
    if (stat<0) {
        lastInitRError = "Failed to initialize R!";;
        return -2;
    }

	if (state.buflen<128) state.buflen=1024;
	state.buf=(unsigned char*) malloc(state.buflen);
	
   // printf("R primary initialization done. Setting up parameters.\n");

    R_Outputfile = NULL;
    R_Consolefile = NULL;
    R_Interactive = 1;
    SaveAction = (save_action==Rinit_save_yes)?SA_SAVE:((save_action==Rinit_save_no)?SA_NOSAVE:SA_SAVEASK);

    /* ptr_R_Suicide = Re_Suicide; */
    /* ptr_R_CleanUp = Re_CleanUp; */
    ptr_R_ShowMessage = Re_ShowMessage;
    ptr_R_ReadConsole =  Re_ReadConsole;
    ptr_R_WriteConsole = NULL;
    ptr_R_WriteConsoleEx = Re_WriteConsoleEx;
    ptr_R_ResetConsole = Re_ResetConsole;
    ptr_R_FlushConsole = Re_FlushConsole;
    ptr_R_ClearerrConsole = Re_ClearerrConsole;
    ptr_R_Busy = Re_RBusy;
    ptr_R_ProcessEvents =  Re_ProcessEvents;
    ptr_do_dataentry = Re_dataentry;
    ptr_do_selectlist = Re_do_selectlist;
    ptr_R_loadhistory = Re_loadhistory;
    ptr_R_savehistory = Re_savehistory;

    ptr_R_EditFile = Re_Edit;
	
    ptr_R_ShowFiles = Re_ShowFiles;
    ptr_R_EditFiles = Re_EditFiles;
    ptr_R_ChooseFile = Re_ChooseFile;
	
    ptr_CocoaSystem = Re_system;
    setup_Rmainloop();

    return 0;
}

static int firstRun=1;

void setRSignalHandlers(int val) {
    R_SignalHandlers = val;
}

 
/* code for more recent R providing proper event loop embedding.
 * note that R < 2.10 is unsafe due to missing SETJMP in the init part */

volatile static NSAutoreleasePool *main_loop_pool;
volatile static int main_loop_result = 0;

void run_REngineRmainloop(int delayed)
{
    /* do not use any local variables for the safety of SIGJMP return in case of an error */ 
    firstRun = delayed;
    /* guarantee that there is an autorelease pool in place */
    main_loop_pool = [[NSAutoreleasePool alloc] init];

    R_ReplDLLinit();

    if (firstRun) {
	firstRun = 0;
	return;
    }

    main_loop_result = 1;
    while (main_loop_result > 0) {
	@try {
#ifdef USE_POOLS
	    if (main_loop_pool) {
		[main_loop_pool release];
		main_loop_pool = nil;
	    }
	    main_loop_pool = [[NSAutoreleasePool alloc] init];
#endif
	    main_loop_result = R_ReplDLLdo1();
#ifdef USE_POOLS
	    [main_loop_pool release];
	    main_loop_pool = nil;
#endif
	}
	@catch (NSException *foo) {
	    NSLog(@"*** run_REngineRmainloop: exception %@ caught during REPL iteration. Update to the latest GUI version and consider reporting this properly (see FAQ) if it persists and is not known.\nConsider saving your work soon in case this develops into a problem.", foo);
	}
    }
}
