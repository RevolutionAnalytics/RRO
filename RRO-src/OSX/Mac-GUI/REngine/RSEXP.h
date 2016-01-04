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

/* important note: unlike other Obj-C classes, if the result of a function is a RSEXP copy, then it's allocated and NOT auto-released! The reason for this is that we need to force early release to keep in sync with R. This removes overhead necessary for full-blown retention on R side and auto-releasing. However it breaks the principle of you-release-what-you-allocate, so please, be aware of this exception. */

#import <Cocoa/Cocoa.h>

#import <Foundation/Foundation.h>
#include <Rinternals.h>
#include <Rversion.h>

@interface RSEXP : NSObject {
    SEXP xp;
    RSEXP *attr;
}

/** constructors */
- (id) initWithSEXP: (SEXP) ct;
- (id) initWithString: (NSString*) str;
- (id) initWithDoubleArray: (double*) arr length: (int) len;
- (id) initWithIntArray: (int*) arr length: (int) len;

/** main methods */
- (int) type;
- (int) length;

- (RSEXP*) attributes; // this one shouldn't be used directly - it's for low-level access only

- (RSEXP*) attr: (NSString*) name;

/** direct access (avoid if possible) */
- (void) protect;
- (void) unprotect;
- (SEXP) directSEXP;

/** non-converting accessor methods */
- (int) integer;
- (double) real;
// the following methods return *references*, not copies, so make sure you copy its contents before R gets control back!
- (double*) doubleArray;
- (int*) intArray;

// note: no caching is done, each RSEXP is allocated anew! don't forget to release!
- (RSEXP*) listHead;  // = CAR
- (RSEXP*) listTail;  // = CDR (hence either a list or nil)
- (RSEXP*) listTag;   // = TAG

/** the array may containg NSString* (for STRSXP) or RSEXP* (for VECSXP) - make sure you take that into account; strings are always copies */
- (NSArray*) array;
- (NSString*) string; // in fact this is just a shortcut for stringAt: 0
- (NSString*) stringAt: (int) index;

/** low-level function, should be used only to allow selective creation of arrays (e.g. from matrices)
	please use -(NSArray*) array; instead */
- (NSString**) strings;
	
- (id) value;
- (RSEXP*) elementAt: (int) index;

/** other/debug */
- (NSString*) typeName;

@end
