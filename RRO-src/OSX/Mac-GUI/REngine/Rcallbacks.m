/*
 *  R.app : a Cocoa front end to: "R A Computer Language for Statistical Data Analysis"
 *  
 *  R.app Copyright notes:
 *                     Copyright (C) 2005  The R Foundation
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
 *
 *  Created by Simon Urbanek on Tue Jul 13 2004.
 *
 */

#include <R.h>
#include <Rinternals.h>
#include <Rversion.h>

#include <sys/select.h>
#include <unistd.h>
#include <stdio.h>
#include <sys/time.h>

#include <R_ext/Boolean.h>
#include <R_ext/Rdynload.h>
#include <R_ext/Parse.h>
#include <R_ext/eventloop.h>

#import "REngine.h"

/* any subsequent calls of ProcessEvents within the following time slice are ignored (in ms) */
#define MIN_DELAY_BETWEEN_EVENTS_MS   150

/* localization - we don't want to include GUI specific includes, so we define it manually */
#ifdef NLS
#undef NLS
#endif
#ifdef NLSC
#undef NLSC
#endif
#define NLS(S) NSLocalizedString(S,@"")
#define NLSC(S,C) NSLocalizedString(S,C)

#ifndef SLog
#if defined DEBUG_RGUI && defined PLAIN_STDERR
#define SLog(X,...) NSLog(X, ## __VA_ARGS__)
#else
#define SLog(X,...)
#endif
#endif

/* we have no access to config.h, so for the moment, let's disable i18n on C level - our files aren't even precessed by R anyway. */
#ifdef _
#undef _
#endif
#define _(A) (A)

int insideR = 0;

/* from Defn.h */
extern Rboolean R_Interactive;   /* TRUE during interactive use*/

extern FILE*    R_Consolefile;   /* Console output file */
extern FILE*    R_Outputfile;   /* Output file */

/* from src/unix/devUI.h */

extern void (*ptr_R_Suicide)(char *);
extern void (*ptr_R_ShowMessage)();
extern int  (*ptr_R_ReadConsole)(char *, unsigned char *, int, int);
extern void (*ptr_R_WriteConsole)(char *, int);
extern void (*ptr_R_ResetConsole)();
extern void (*ptr_do_flushconsole)();
extern void (*ptr_R_ClearerrConsole)();
extern void (*ptr_R_Busy)(int);
/* extern void (*ptr_R_CleanUp)(SA_TYPE, int, int); */
//extern int  (*ptr_R_ShowFiles)(int, char **, char **, char *, Rboolean, char *);
//extern int  (*ptr_R_EditFiles)(int, char **, char **, char *);
extern int  (*ptr_R_ChooseFile)(int, char *, int);
extern void (*ptr_R_loadhistory)(SEXP, SEXP, SEXP, SEXP);
extern void (*ptr_R_savehistory)(SEXP, SEXP, SEXP, SEXP);

//extern void (*ptr_R_StartCocoaRL)();

void Re_WritePrompt(char *prompt)
{
	NSString *s = [[NSString alloc] initWithUTF8String: prompt];
	insideR--;
    [[REngine mainHandler] handleWritePrompt:s];
	[s release];
	insideR++;
}

static long lastProcessEvents=0;

void Re_ProcessEvents(void){
	struct timeval rv;
	if (!gettimeofday(&rv,0)) {
		long curTime = (rv.tv_usec/1000)+(rv.tv_sec&0x1fffff)*1000;
		if (curTime - lastProcessEvents < MIN_DELAY_BETWEEN_EVENTS_MS) return;
	}
#ifdef USE_POOLS
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
#endif
	if ([[REngine mainEngine] allowEvents]) // if events are masked, we won't call the handler. we may re-think what we do about the timer, though ...
		[[REngine mainHandler] handleProcessEvents];
	if (!gettimeofday(&rv,0)) // use the exit time for the measurement of next events - handleProcessEvents may take long
		lastProcessEvents = (rv.tv_usec/1000)+(rv.tv_sec&0x1fffff)*1000;
#ifdef USE_POOLS
	[pool release];
#endif
}

static char *readconsBuffer=0;
static char *readconsPos=0;

int Re_ReadConsole(char *prompt, unsigned char *buf, int len, int addtohistory)
{
	insideR--;
	Re_WritePrompt(prompt);

	if (!readconsBuffer) {
	    char *newc = [[REngine mainHandler] handleReadConsole: addtohistory];
	    if (!newc) {
			insideR++;
			return 0;
		}
		readconsPos=readconsBuffer=newc;
	}
		
	if (readconsBuffer) {
		int skipPC=0;
		char *c = readconsPos;
		while (*c && *c!='\n' && *c!='\r') c++;
		if (*c=='\r') { /* convert PC and Mac endings to unix */
			*c='\n';
			if (c[1]=='\n') skipPC=1;
		}
        if (*c) c++; /* if not at the end, point past the content to use */
        if (c-readconsPos>=len) c=readconsPos+(len-1);
        memcpy(buf, readconsPos, c-readconsPos);
		buf[c-readconsPos]=0;
        if (skipPC) c++;
		if (*c)
			readconsPos=c;
		else
			readconsPos=readconsBuffer=0;
		[[REngine mainHandler] handleProcessingInput: (char*) buf];
insideR=YES;
		return 1;
	}

    return 0;
}

void Re_RBusy(int which)
{
	insideR--;
    [[REngine mainHandler] handleBusy: (which==0)?NO:YES];
	insideR++;
}


void Re_WriteConsoleEx(char *buf, int len, int otype)
{
	NSString *s = nil;
	if (buf[len]) { /* well, this is an ultima ratio, we are assuming null-terminated string, but one never knows ... */
		char *c = (char*) malloc(len+1);
		memcpy(c, buf, len);
		c[len]=0;
		s = [[NSString alloc] initWithUTF8String:c];
		free(c);
	} else s = [[NSString alloc] initWithUTF8String:buf];
    if (!s) {
		SLog(@"Rcallbacks:Re_WriteConsole: suspicious string of length %d doesn't parse as UTF8. Will use raw cString.", len);
		s = [[NSString alloc] initWithCString:buf length:len];
		SLog(@"Rcallbacks:Re_WriteConsole: string parsed as \"%@\"", s);
	}
    if (s) {
		[[REngine mainHandler] handleWriteConsole: s withType: otype];
		[s release];
	}
}

void Re_WriteConsole(char *buf, int len)
{
    Re_WriteConsoleEx(buf, len, 0);
}

/* Indicate that input is coming from the console */
void Re_ResetConsole()
{
}

/* Stdio support to ensure the console file buffer is flushed */
void Re_FlushConsole()
{
	insideR--;
	[[REngine mainHandler] handleFlushConsole];	
	insideR++;
}

/* Reset stdin if the user types EOF on the console. */
void Re_ClearerrConsole()
{
}

int Re_ChooseFile(int new, char *buf, int len)
{
	int r;
	insideR--;
	r=[[REngine mainHandler] handleChooseFile: buf len:len isNew:new];
	insideR++;
	return r;
}

void Re_ShowMessage(char *buf)
{
	insideR--;
	[[REngine mainHandler] handleShowMessage: buf];
	insideR++;
}

int  Re_Edit(char *file){
	int r;
	insideR--;
	r=[[REngine mainHandler] handleEdit: file];
	insideR++;
	return r;
}

int  Re_EditFiles(int nfile, char **file, char **wtitle, char *pager){
	int r;
	insideR--;
	r = [[REngine mainHandler] handleEditFiles: nfile withNames: file titles: wtitle pager: pager];
	insideR++;
	return r;
}

int Re_ShowFiles(int nfile, char **file, char **headers, char *wtitle, Rboolean del, char *pager)
{
	int r;
	insideR--;
	r = [[REngine mainHandler] handleShowFiles: nfile withNames: file headers: headers windowTitle: wtitle pager: pager andDelete: del];
	insideR++;
	return r;
}

//==================================================== the following callbacks are Cocoa-specific callbacks (see CocoaHandler)

int Re_system(const char *cmd) {
	int r;
	insideR--;
	if ([REngine cocoaHandler])
		r = [[REngine cocoaHandler] handleSystemCommand: cmd];
	else { // fallback in case there's no handler
		   // reset signal handlers
		signal(SIGINT, SIG_DFL);
		signal(SIGTERM, SIG_DFL);
		signal(SIGQUIT, SIG_DFL);
		signal(SIGALRM, SIG_DFL);
		signal(SIGCHLD, SIG_DFL);
		r = system(cmd);
	}
	insideR++;
	return r;
}

static int  Re_CustomPrint(const char *type, SEXP obj)
{
	insideR--;
	if ([REngine cocoaHandler]) {
		RSEXP *par = [[RSEXP alloc] initWithSEXP: obj];
		int res = [[REngine cocoaHandler] handleCustomPrint: type withObject: par];
		[par release];
		insideR++;
		return res;
	}
	insideR++;
	return -1;
}

SEXP customprint(SEXP objType, SEXP obj)
{
    if (!isString(objType) || LENGTH(objType) < 1) error("invalid arguments");
    const char *ct = CHAR(STRING_ELT(objType, 0));
    int cpr = Re_CustomPrint(ct, obj);
    return ScalarInteger(cpr);
}

SEXP pkgmanager(SEXP pkgstatus, SEXP pkgname, SEXP pkgdesc, SEXP pkgurl)
{
	SEXP ans; 
	int i, len;
	
	char **sName, **sDesc, **sURL;
	BOOL *bStat;
	
	if (![REngine cocoaHandler]) return R_NilValue;
  
	if(!isString(pkgname) || !isLogical(pkgstatus) || !isString(pkgdesc) || !isString(pkgurl))
		error("invalid arguments");
   
	len = LENGTH(pkgname);
	if (len!=LENGTH(pkgstatus) || len!=LENGTH(pkgdesc) || len!=LENGTH(pkgurl))
		error("invalid arguments (length mismatch)");

	if (len==0) {
		insideR--;
		[[REngine cocoaHandler] handlePackages: 0 withNames: 0 descriptions: 0 URLs: 0 status: 0];
		insideR++;
		return pkgstatus;
	}

	sName = (char**) malloc(sizeof(char*)*len);
	sDesc = (char**) malloc(sizeof(char*)*len);
	sURL  = (char**) malloc(sizeof(char*)*len);
	bStat = (BOOL*) malloc(sizeof(BOOL)*len);

	i = 0; // we don't copy since the Obj-C side is responsible for making copies if necessary
	while (i<len) {
		sName[i] = (char*)CHAR(STRING_ELT(pkgname, i));
		sDesc[i] = (char*)CHAR(STRING_ELT(pkgdesc, i));
		sURL [i] = (char*)CHAR(STRING_ELT(pkgurl, i));
		bStat[i] = (BOOL)LOGICAL(pkgstatus)[i];
		i++;
	}
	insideR--;
	[[REngine cocoaHandler] handlePackages: len withNames: sName descriptions: sDesc URLs: sURL status: bStat];
	insideR++;
	free(sName); free(sDesc); free(sURL);
	
	PROTECT(ans = allocVector(LGLSXP, len));
	for(i=0;i<len;i++)
		LOGICAL(ans)[i] = bStat[i];
	UNPROTECT(1);
	free(bStat);
	
  	return ans;
}

SEXP datamanager(SEXP dsets, SEXP dpkg, SEXP ddesc, SEXP durl)
{
  SEXP  ans;
  int i, len;
  
  char **sName, **sDesc, **sURL, **sPkg;
  BOOL *res;

  if (!isString(dsets) || !isString(dpkg) || !isString(ddesc)  || !isString(durl) )
	error("invalid arguments");

  len = LENGTH(dsets);
  if (LENGTH(dpkg)!=len || LENGTH(ddesc)!=len || LENGTH(durl)!=len)
	  error("invalid arguments (length mismatch)");
	  
  if (len==0) {
	  insideR--;
	  [[REngine cocoaHandler] handleDatasets: 0 withNames: 0 descriptions: 0 packages: 0 URLs: 0];
	  insideR++;
	  return R_NilValue;
  }

  sName = (char**) malloc(sizeof(char*)*len);
  sDesc = (char**) malloc(sizeof(char*)*len);
  sURL  = (char**) malloc(sizeof(char*)*len);
  sPkg  = (char**) malloc(sizeof(char*)*len);
  
  i = 0; // we don't copy since the Obj-C side is responsible for making copies if necessary
  while (i<len) {
	  sName[i] = (char*)CHAR(STRING_ELT(dsets, i));
	  sDesc[i] = (char*)CHAR(STRING_ELT(ddesc, i));
	  sURL [i] = (char*)CHAR(STRING_ELT(durl, i));
	  sPkg [i] = (char*)CHAR(STRING_ELT(dpkg, i));
	  i++;
  }

  insideR--;
  res = [[REngine cocoaHandler] handleDatasets: len withNames: sName descriptions: sDesc packages: sPkg URLs: sURL];
  insideR++;
  
  free(sName); free(sDesc); free(sPkg); free(sURL);
  
  if (res) {
	  PROTECT(ans=allocVector(LGLSXP, len));
	  i=0;
	  while (i<len) {
		  LOGICAL(ans)[i]=res[i];
		  i++;
	  }
	  UNPROTECT(1);
  } else {
	  // this should be the default:	  ans=R_NilValue;
	  // but until the R code is fixed to accept this, we have to fake a result
	  ans=allocVector(LGLSXP, 0);
  }
  
  return ans;
}

SEXP pkgbrowser(SEXP rpkgs, SEXP rvers, SEXP ivers, SEXP wwwhere,
		SEXP install_dflt)
{
  int i, len;

  char **sName, **sIVer, **sRVer;
  BOOL *bStat;

  if(!isString(rpkgs) || !isString(rvers) || !isString(ivers) || !isString(wwwhere) || !isLogical(install_dflt))
	  error("invalid arguments");

  len = LENGTH(rpkgs);
  if (LENGTH(rvers)!=len || LENGTH(ivers)!=len || LENGTH(wwwhere)<1 || LENGTH(install_dflt)!=len)
	  error("invalid arguments (length mismatch)");
	  
  if (len==0) {
	  insideR--;
	  [[REngine cocoaHandler] handleInstalledPackages: 0 withNames: 0 installedVersions: 0 repositoryVersions: 0 update: 0 label: 0];
	  insideR++;
	  return R_NilValue;
  }
  
  sName = (char**) malloc(sizeof(char*)*len);
  sIVer = (char**) malloc(sizeof(char*)*len);
  sRVer = (char**) malloc(sizeof(char*)*len);
  bStat = (BOOL*) malloc(sizeof(BOOL)*len);
  
  i = 0; // we don't copy since the Obj-C side is responsible for making copies if necessary
  while (i<len) {
	  sName[i] = (char*)CHAR(STRING_ELT(rpkgs, i));
	  sIVer[i] = (char*)CHAR(STRING_ELT(ivers, i));
	  sRVer[i] = (char*)CHAR(STRING_ELT(rvers, i));
	  bStat[i] = (BOOL)LOGICAL(install_dflt)[i];
	  i++;
  }
  
  insideR--;
  [[REngine cocoaHandler] handleInstalledPackages: len withNames: sName installedVersions: sIVer repositoryVersions: sRVer update: bStat label:(char*)CHAR(STRING_ELT(wwwhere,0))];
  insideR++;
  free(sName); free(sIVer); free(sRVer); free(bStat);
    
  return allocVector(LGLSXP, 0);
}

SEXP hsbrowser(SEXP h_topic, SEXP h_pkg, SEXP h_desc, SEXP h_wtitle,
	       SEXP h_url) 
{
	SEXP ans; 
	int i, len;
	char **sTopic, **sDesc, **sPkg, **sURL;
	
	if(!isString(h_topic) | !isString(h_pkg) | !isString(h_desc) )
		error("invalid arguments");
	
	len = LENGTH(h_topic);
	if (LENGTH(h_pkg)!=len || LENGTH(h_desc)!=len || LENGTH(h_wtitle)<1 || LENGTH(h_url)!=len)
		error("invalid arguments (length mismatch)");
	
	if (len==0) {
		insideR--;
		[[REngine cocoaHandler] handleHelpSearch: 0 withTopics: 0 packages: 0 descriptions: 0 urls: 0 title: 0];
		insideR++;
		return R_NilValue;
	}
	
	sTopic = (char**) malloc(sizeof(char*)*len);
	sDesc = (char**) malloc(sizeof(char*)*len);
	sPkg = (char**) malloc(sizeof(char*)*len);
	sURL = (char**) malloc(sizeof(char*)*len);
	
	i = 0; // we don't copy since the Obj-C side is responsible for making copies if necessary
	while (i<len) {
		sTopic[i] = (char*)CHAR(STRING_ELT(h_topic, i));
		sDesc[i]  = (char*)CHAR(STRING_ELT(h_desc, i));
		sPkg[i]   = (char*)CHAR(STRING_ELT(h_pkg, i));
		sURL[i]   = (char*)CHAR(STRING_ELT(h_url, i));
		i++;
	}
	
	insideR--;
	[[REngine cocoaHandler] handleHelpSearch: len withTopics: sTopic packages: sPkg descriptions: sDesc urls: sURL title:(char*)CHAR(STRING_ELT(h_wtitle,0))];
	insideR++;
	free(sTopic); free(sDesc); free(sPkg); free(sURL);
	
	PROTECT(ans = allocVector(LGLSXP, len));
	for(i=0;i<len;i++)
		LOGICAL(ans)[i] = 0;
	
	UNPROTECT(1);
	
	return ans;
}

SEXP Re_do_selectlist(SEXP call, SEXP op, SEXP args, SEXP rho)
{
    SEXP list, preselect, ans = R_NilValue;
    char **clist;
    int i, j = -1, n,  multiple, nsel = 0;
	Rboolean haveTitle;
	BOOL *itemStatus = 0;
	int selectListDone = 0;
	
//    checkArity(op, args);
    list = CAR(args);
    if(!isString(list)) error(_("invalid 'list' argument"));
    preselect = CADR(args);
    if(!isNull(preselect) && !isString(preselect))
		error(_("invalid 'preselect' argument"));
    multiple = asLogical(CADDR(args));
    if(multiple == NA_LOGICAL) multiple = 0;
    haveTitle = isString(CADDDR(args));
    if(!multiple && isString(preselect) && LENGTH(preselect) != 1)
		error(_("invalid 'preselect' argument"));
	
    n = LENGTH(list);
    clist = (char **) R_alloc(n + 1, sizeof(char *));
    itemStatus = (BOOL *) R_alloc(n + 1, sizeof(BOOL));
    for(i = 0; i < n; i++) {
		clist[i] = (char*)CHAR(STRING_ELT(list, i));
		itemStatus[i] = NO;
    }
    clist[n] = NULL;
	
    if(!isNull(preselect) && LENGTH(preselect)) {
		for(i = 0; i < n; i++)
			for(j = 0; j < LENGTH(preselect); j++)
				if(strcmp(clist[i], CHAR(STRING_ELT(preselect, j))) == 0) {
					itemStatus[i] = YES;
					break;
				};
    }
	
	insideR--;
	if (n==0)
		selectListDone = [[REngine cocoaHandler] handleListItems: 0 withNames: 0 status: 0 multiple: 0 title: @""];
	else
		selectListDone = [[REngine cocoaHandler] handleListItems: n withNames: clist status: itemStatus multiple: multiple
														   title: haveTitle
			?[NSString stringWithUTF8String: CHAR(STRING_ELT(CADDDR(args), 0))]
			:(multiple ? NLS(@"Select one or more") : NLS(@"Select one")) ];
	insideR++;
	
	if (selectListDone == 1) { /* Finish */
		for(i = 0; i < n; i++)  if(itemStatus[i]) nsel++;
		PROTECT(ans = allocVector(STRSXP, nsel));
		for(i = 0, j = 0; i < n; i++)
			if(itemStatus[i])
				SET_STRING_ELT(ans, j++, mkChar(clist[i]));
	} else { /* cancel */
		PROTECT(ans = allocVector(STRSXP, 0));
	}

    UNPROTECT(1);
    return ans;
}


//==================================================== the following callbacks need to be moved!!! (TODO)

#import "../WSBrowser.h"
#import "../REditor.h"
#import "../SelectList.h"

int freeWorkspaceList(int newlen);

int NumOfWSObjects;
int *ws_IDNum;              /* id          */
Rboolean *ws_IsRoot;        /* isroot      */
Rboolean *ws_IsContainer;   /* iscontainer */
UInt32 *ws_numOfItems;      /* numofit     */
int *ws_parID;           /* parid       */
char **ws_name;            /* name        */
char **ws_type;            /* type        */
char **ws_size;            /* objsize     */
int NumOfID = 0;         /* length of the vectors    */
                                /* We do not check for this */ 
 

BOOL WeHaveWorkspace;


SEXP wsbrowser(SEXP ids, SEXP isroot, SEXP iscont, SEXP numofit,
	       SEXP parid, SEXP name, SEXP type, SEXP objsize)
{
    if(!isInteger(ids)) error("'id' must be integer");      
    if(!isString(name)) error("invalid objects' name");
    if(!isString(type)) error("invalid objects' type");
    if(!isString(objsize)) error("invalid objects' size");
    if(!isLogical(isroot)) error("invalid 'isroot' definition");
    if(!isLogical(iscont)) error("invalid 'iscont' definition");
    if(!isInteger(numofit)) error("'numofit' must be integer");
    if(!isInteger(parid)) error("'parid' must be integer");
  
    int len = LENGTH(ids);

    if(len) {
	WeHaveWorkspace = YES;
	NumOfWSObjects = freeWorkspaceList(len);		
  
	for(int i = 0; i < NumOfWSObjects; i++) {
	    if (!isNull(STRING_ELT(name, i)))
		ws_name[i] = strdup(CHAR(STRING_ELT(name, i)));
	    else
		ws_name[i] = strdup(CHAR(R_BlankString));

	    if (!isNull(STRING_ELT(type, i)))
		ws_type[i] = strdup(CHAR(STRING_ELT(type, i)));
	    else
		ws_type[i] = strdup(CHAR(R_BlankString));

	    if (!isNull(STRING_ELT(objsize, i)))
		ws_size[i] = strdup(CHAR(STRING_ELT(objsize, i)));
	    else
		ws_size[i] = strdup(CHAR(R_BlankString));  

	    ws_IDNum[i] = INTEGER(ids)[i];
	    ws_numOfItems[i] = INTEGER(numofit)[i];
	    if(INTEGER(parid)[i] == -1)
		ws_parID[i] = -1;
	    else 
		ws_parID[i] = INTEGER(parid)[i]; 
	    ws_IsRoot[i] = LOGICAL(isroot)[i];
	    ws_IsContainer[i] = LOGICAL(iscont)[i];
	}
    }

    insideR--;
    [WSBrowser toggleWorkspaceBrowser];
    insideR++;

    return R_NilValue;
}

int freeWorkspaceList(int newlen)
{
	if(ws_name){
		free(ws_name);
		ws_name = 0;
	}
	
	if(ws_type){
		free(ws_type);
		ws_type = 0;
	}
	
	if(ws_size){
		free(ws_size);
		ws_size = 0;
	}
	
	if(ws_parID){
		free(ws_parID);
		ws_parID = 0;
	}
	
	if(ws_numOfItems){
		free(ws_numOfItems);
		ws_numOfItems = 0;
	}
	
	if(ws_IsRoot){
		free(ws_IsRoot);
		ws_IsRoot = 0;
	}
	
	if(ws_IsContainer){
		free(ws_IsContainer);
		ws_IsContainer = 0;
	}

	if(ws_IDNum){
		free(ws_IDNum);
		ws_IDNum = 0;
	}
	if(newlen <= 0)
		newlen = 0;
	else {
		ws_name = (char **)calloc(newlen, sizeof(char *) );
		ws_type = (char **)calloc(newlen, sizeof(char *) );
		ws_size = (char **)calloc(newlen, sizeof(char *) );
		ws_parID = (int *)calloc(newlen, sizeof(int));
		ws_numOfItems = (UInt32 *)calloc(newlen, sizeof(UInt32));
		ws_IsRoot = (Rboolean *)calloc(newlen, sizeof(Rboolean));
		ws_IsContainer = (Rboolean *)calloc(newlen, sizeof(Rboolean));
		ws_IDNum = (int *)calloc(newlen, sizeof(int));
	}
	
	return(newlen);
}		

SEXP work, names, lens;
PROTECT_INDEX wpi, npi, lpi;
SEXP ssNA_STRING;
double ssNA_REAL;
 int xmaxused, ymaxused;

#ifndef max
#define max(x,y) x<y?y:x;
#endif

extern BOOL IsDataEntry;
extern BOOL IsSelectList;
/*
   ssNewVector is just an interface to allocVector but it lets us
   set the fields to NA. We need to have a special NA for reals and
   strings so that we can differentiate between uninitialized elements
   in the vectors and user supplied NA's; hence ssNA_REAL and ssNA_STRING
 */

SEXP ssNewVector(SEXPTYPE type, int vlen)
{
    SEXP tvec;
    int j;

    tvec = allocVector(type, vlen);
    for (j = 0; j < vlen; j++)
	if (type == REALSXP)
	    REAL(tvec)[j] = ssNA_REAL;
	else if (type == STRSXP)
	    SET_STRING_ELT(tvec, j, STRING_ELT(ssNA_STRING, 0));
    SETLEVELS(tvec, 0);
    return (tvec);
}

int nprotect;
SEXP Re_dataentry(SEXP call, SEXP op, SEXP args, SEXP rho)
{

	SEXP colmodes, tnames, tvec, work2;
	SEXPTYPE type;
	int i, j, cnt;
	char clab[25];

	nprotect = 0; /* count the PROTECT()s */
	PROTECT_WITH_INDEX(work = duplicate(CAR(args)), &wpi); nprotect++;

	colmodes = CADR(args);
	tnames = getAttrib(work, R_NamesSymbol);

	if (TYPEOF(work) != VECSXP || TYPEOF(colmodes) != VECSXP)
		errorcall(call, "invalid argument");

	/* initialize the constants */
	ssNA_REAL = -NA_REAL;
	tvec = allocVector(REALSXP, 1);
	REAL(tvec)[0] = ssNA_REAL;
	PROTECT(ssNA_STRING = coerceVector(tvec, STRSXP)); nprotect++;

	/* setup work, names, lens */
	xmaxused = length(work); ymaxused = 0;
	PROTECT_WITH_INDEX(lens = allocVector(INTSXP, xmaxused), &lpi);
	nprotect++;
	if (isNull(tnames)) {
		PROTECT_WITH_INDEX(names = allocVector(STRSXP, xmaxused), &npi);
		for(i = 0; i < xmaxused; i++) {
			sprintf(clab, "var%d", i);
			SET_STRING_ELT(names, i, mkChar(clab));
		}
	} else 
		PROTECT_WITH_INDEX(names = duplicate(tnames), &npi);
	nprotect++;

	for (i = 0; i < xmaxused; i++) {
		int len = LENGTH(VECTOR_ELT(work, i));
		INTEGER(lens)[i] = len;
		ymaxused = max(len, ymaxused);
		type = TYPEOF(VECTOR_ELT(work, i));
		if (LENGTH(colmodes) > 0 && !isNull(VECTOR_ELT(colmodes, i)))
			type = str2type(CHAR(STRING_ELT(VECTOR_ELT(colmodes, i), 0)));
		if (type != STRSXP) type = REALSXP;
		if (isNull(VECTOR_ELT(work, i))) {
			if (type == NILSXP) type = REALSXP;
			SET_VECTOR_ELT(work, i, ssNewVector(type, 100));
		} else if (!isVector(VECTOR_ELT(work, i)))
			errorcall(call, "invalid type for value");
		else {
			if (TYPEOF(VECTOR_ELT(work, i)) != type)
				SET_VECTOR_ELT(work, i, coerceVector(VECTOR_ELT(work, i), type));
		}
	}

	/* start up the window, more initializing in here */
	IsDataEntry = YES;
	insideR--;
	[REditor startDataEntry];
	insideR++;
	IsDataEntry = NO;

	/* drop out unused columns */
	for(i = 0, cnt = 0; i < xmaxused; i++)
		if(!isNull(VECTOR_ELT(work, i))) cnt++;
	if (cnt < xmaxused) {
		PROTECT(work2 = allocVector(VECSXP, cnt)); nprotect++;
		for(i = 0, j = 0; i < xmaxused; i++) {
			if(!isNull(VECTOR_ELT(work, i))) {
				SET_VECTOR_ELT(work2, j, VECTOR_ELT(work, i));
				INTEGER(lens)[j] = INTEGER(lens)[i];
				SET_STRING_ELT(names, j, STRING_ELT(names, i));
				j++;
			}
		}
		REPROTECT(names = lengthgets(names, cnt), npi);
	} else work2 = work;

	setAttrib(work2, R_NamesSymbol, names);
	UNPROTECT(nprotect);

	[[REditor getDEController] clearData];

	return work2;

}

void Re_loadhistory(SEXP call, SEXP op, SEXP args, SEXP env)
{
    errorcall(call, "'loadhistory' is not currently implemented");
}

void Re_savehistory(SEXP call, SEXP op, SEXP args, SEXP env)
{
    errorcall(call, "'savehistory' is not currently implemented");
}

