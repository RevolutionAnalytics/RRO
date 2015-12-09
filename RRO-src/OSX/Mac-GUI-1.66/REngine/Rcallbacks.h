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
 *  Created by Simon Urbanek on Tue Jul 13 2004.
 *
 */

/* Rcallbacks define the interface between R and Cocoa.
   Each callback in R is mapped to the corresponding methods of the callback object. The current callback object should be always obtained dynamically fromt he REngine to ensure correct communication, potentially across threads. The acutal implementation of the functionality is left to the object implementing the callback interface. */

#ifndef __R_CALLBACKS__H__
#define __R_CALLBACKS__H__

/* this part is relevant only in included in Obj-C files */
#ifdef __OBJC__

#import "RSEXP.h"

/* protocol defining the callback interface on the Cocoa side, that is the receiving object. */
@protocol REPLHandler
- (void)  handleWriteConsole: (NSString*) msg withType: (int) oType;
- (char*) handleReadConsole: (int) addtohist;
- (void)  handleBusy: (BOOL) which;
- (void)  handleFlushConsole;
- (void)  handleWritePrompt: (NSString*) prompt;
- (void)  handleProcessEvents;
- (int)   handleChooseFile: (char*) buf len: (int) length isNew: (int) new;
- (void)  handleShowMessage: (char*) msg;
- (void)  handleProcessingInput: (char*) cmd;
- (int)   handleEdit: (char*) file;
- (int)   handleEditFiles: (int) nfile withNames: (char**) file titles: (char**) wtitle pager: (char*) pager;
- (int)   handleShowFiles: (int) nfile withNames: (char**) file headers: (char**) headers windowTitle: (char*) wtitle pager: (char*) pages andDelete: (BOOL) del;
@end

/* protocol defining additional callbacks specific to Aqua/Cocoa GUI */
@protocol CocoaHandler
// return value is unused so far - the return value on R side is 'stat', so any changes to that parameter are propagated to R
- (int) handlePackages: (int) count withNames: (char**) name descriptions: (char**) desc URLs: (char**) url status: (BOOL*) stat;
// return value: 0=cancel, 1=ok
- (int) handleListItems: (int) count withNames: (char**) name status: (BOOL*) stat multiple: (BOOL) multiple title: (NSString*) title;
// returns either nil or array of booleans of the size 'count' specifying which datasets to load
- (BOOL*) handleDatasets: (int) count withNames: (char**) name descriptions: (char**) desc packages: (char**) pkg URLs: (char**) url;
// return value is unused so far
- (int) handleInstalledPackages: (int) count withNames: (char**) name installedVersions: (char**) iver repositoryVersions: (char**) rver update: (BOOL*) stat label: (char*) label;
// its usage is identical to that of the 'system' command
- (int) handleSystemCommand: (char*) cmd;
- (int) handleHelpSearch: (int) count withTopics: (char**) topics packages: (char**) pkgs descriptions: (char**) descs urls: (char**) urls title: (char*) title;
- (int) handleCustomPrint: (char*) type withObject: (RSEXP*) obj;
@end

#endif /* end of Obj-C code */

#include <R.h>
#include <Rinternals.h>
#include <stdio.h>

/* functions provided as R callbacks */
int  Re_ReadConsole(char *prompt, unsigned char *buf, int len, int addtohistory);
void Re_RBusy(int which);
void Re_WriteConsole(char *buf, int len);
void Re_WriteConsoleEx(char *buf, int len, int oType);
void Re_ResetConsole();
void Re_FlushConsole();
void Re_ClearerrConsole();
int  Re_ChooseFile(int new, char *buf, int len);
void Re_ShowMessage(char *buf);
void Re_read_history(char *buf);
void Re_loadhistory(SEXP call, SEXP op, SEXP args, SEXP env);
void Re_savehistory(SEXP call, SEXP op, SEXP args, SEXP env);
int  Re_ShowFiles(int nfile, char **file, char **headers, char *wtitle, Rboolean del, char *pager);
int  Re_EditFiles(int nfile, char **file, char **title, char *pager);
int  Re_Edit(char *file);
int  Re_system(const char *cmd);

void Re_ProcessEvents(void);
SEXP Re_packagemanger(SEXP call, SEXP op, SEXP args, SEXP env);
SEXP Re_datamanger(SEXP call, SEXP op, SEXP args, SEXP env);
SEXP Re_browsepkgs(SEXP call, SEXP op, SEXP args, SEXP env);
SEXP Re_do_wsbrowser(SEXP call, SEXP op, SEXP args, SEXP env);
SEXP Re_do_hsbrowser(SEXP call, SEXP op, SEXP args, SEXP env);
SEXP Re_dataentry(SEXP call, SEXP op, SEXP args, SEXP rho);
SEXP Re_do_selectlist(SEXP call, SEXP op, SEXP args, SEXP rho);

#endif
