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
 *  Created by Simon Urbanek on Wed Dec 10 2003.
 *
 */

#import <Cocoa/Cocoa.h>

#import <Foundation/Foundation.h>
#import "RSEXP.h"
#import "Rcallbacks.h"

/* since R 2.0 parse is mapped to Rf_parse which is deadly ... 
   therefore REngine.h must be included *after* R headers */
#ifdef parse
#undef parse
#endif

#define RENGINE_BEGIN [self begin]
#define RENGINE_END   [self end]

extern int insideR;
extern BOOL preventReentrance;

@interface REngine : NSObject {
	/* the object handling all regular R callbacks - the Rcallback.h for the protocol definition - this one must be provided */
    id <REPLHandler> replHandler;
	/* this callback handler is optional and involves various GUI stuff. those callback are activated only if Aqua/Cocoa is specified as GUI */
	id <CocoaHandler> cocoaHandler;
	
	/* set to NO if the engine is initialized but activate was not called yet - that is R was not really initialized yet */
	BOOL active;

	/* set to YES if R REPL is running */
	BOOL loopRunning;

	BOOL protectedMode;
	
	/* last error string */
	NSString* lastError;
	
	/* if >0 ProcessEvents doesn't call the event handler */
	int maskEvents;

	/* initial arguments used by activate to initialize R */
	int  argc;
	char **argv;
	
	/* SaveAction (yes/no/ask - anything else is treated as ask) */
	NSString *saveAction;
}

+ (REngine*) mainEngine;
+ (id <REPLHandler>) mainHandler;
+ (id <CocoaHandler>) cocoaHandler;

- (id) init;
- (id) initWithHandler: (id <REPLHandler>) hand;
- (id) initWithHandler: (id <REPLHandler>) hand arguments: (char**) args;
- (BOOL) activate;

- (BOOL) isLoopRunning;
- (BOOL) isActive;

- (NSString*) lastError;

- (void) begin;
- (void) end;

- (BOOL) allowEvents;

- (BOOL) beginProtected;
- (void) endProtected;

// those must be called *before* activate and *after* init
- (void) setSaveAction: (NSString*) action; // yes/no/ask
- (NSString*) saveAction;
- (void) disableRSignalHandlers: (BOOL) disable;

// eval mode
- (RSEXP*) parse: (NSString*) str;
- (RSEXP*) parse: (NSString*) str withParts: (int) count;
- (RSEXP*) evaluateExpressions: (RSEXP*) expr;
- (RSEXP*) evaluateString: (NSString*) str;
- (RSEXP*) evaluateString: (NSString*) str withParts: (int) count;
- (BOOL)   executeString: (NSString*) str; // void eval

// REPL mode
- (id <REPLHandler>) handler;
- (id <CocoaHandler>) cocoaHandler; // beware, nil is legal!
- (void) setCocoaHandler: (id <CocoaHandler>) ch;
- (void) runREPL; // starts REPL and does not return until REPL finishes
- (void) runDelayedREPL; // starts REPL with delayed=1 thus returns immediately

@end
