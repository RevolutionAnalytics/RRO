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

/* IMPORTANT: the entire REngine/REXP framework assumes that you're not returning contol to R in the life of a RSEXP. 
	If you do, make sure you copy the content of interest and release the RSEXP before returing constrol to R. Baiscally 
	the point is that all SEXP objects are unprotected before exiting the functions, so that we never get an unbalanced 
	stack. This implies that R may garbage-collect your objects if it gets control. Alternatively you may use 
	protect/uprotect methods, but make sure the calls are *always* balanced! 
*/

#import "RSEXP.h"

@implementation RSEXP

- (id) initWithSEXP: (SEXP) ct
{
    xp=ct;
    attr=nil;
    if (ATTRIB(ct) && TYPEOF(ATTRIB(ct))!=NILSXP && ATTRIB(ct)!=ct)
        attr=[[RSEXP alloc] initWithSEXP: ATTRIB(ct)];
    //NSLog(@"initWithSEXP result: %@", self);
    return self;
}

- (id) initWithString: (NSString*) str
{
    PROTECT(xp=allocVector(STRSXP, 1));
    SET_VECTOR_ELT(xp, 0, mkChar([str UTF8String]));
    UNPROTECT(1);
    attr=nil;
    //NSLog(@"initWithString result: %@", self);
    return self;
}

- (id) initWithDoubleArray: (double*) arr length: (int) len
{
    if (len<0) len=0;
    PROTECT(xp=allocVector(REALSXP, len));
    if (len>0)
        memcpy(REAL(xp),arr,sizeof(double)*len);
    UNPROTECT(1);
    attr=nil;
    //NSLog(@"initWithDoubleArray result: %@", self);
    return self;    
}

- (id) initWithIntArray: (int*) arr length: (int) len
{
    if (len<0) len=0;
    PROTECT(xp=allocVector(INTSXP, len));
    if (len>0)
        memcpy(INTEGER(xp),arr,sizeof(int)*len);
    UNPROTECT(1);
    attr=nil;
    //NSLog(@"initWithIntArray result: %@", self);
    return self;    
}

- (int) type
{
    return (xp)?TYPEOF(xp):NILSXP;
}

- (NSString*) typeName
{
    if (!xp) return @"<null>";
    switch(TYPEOF(xp)) {
        case NILSXP: return @"NULL";
        case SYMSXP: return @"symbol";
        case LISTSXP: return @"list";
        case CLOSXP: return @"closure";
        case ENVSXP: return @"environment";
        case PROMSXP: return @"promise";
        case LANGSXP: return @"lang.construct";
        case SPECIALSXP: return @"special";
        case BUILTINSXP: return @"built-in";
        case CHARSXP: return @"scalar-str";
        case LGLSXP: return @"logical";
        case INTSXP: return @"integer";
        case REALSXP: return @"real";
        case CPLXSXP: return @"complex";
        case STRSXP: return @"string";
        case DOTSXP: return @"...";
        case ANYSXP: return @"any";
        case VECSXP: return @"array";
        case EXPRSXP: return @"expressions";
        case BCODESXP: return @"byte-code";
        case EXTPTRSXP: return @"ext.ptr";
        case WEAKREFSXP: return @"weak-reference";
    }
    
    return @"<unknown>";
}

- (NSString*) description
{
    return [NSString stringWithFormat:@"RSEXP@%x, %@[%d]",xp, [self typeName],[self length]];
}

- (int) length
{
    if (!xp) return 0;
    switch (TYPEOF(xp)) {
        case VECSXP:
        case STRSXP:
        case INTSXP:
        case REALSXP:
        case CPLXSXP:
        case LGLSXP:
        case EXPRSXP:
            return LENGTH(xp);
    }
    return 1;
}

- (RSEXP*) attributes
{
    return attr;
}

- (RSEXP*) attr: (NSString*) name
{
	SEXP rx;
	if (!xp) return nil;
	rx=getAttrib(xp, install([name UTF8String]));
	if (!rx || rx==R_NilValue) return nil;
	return [[RSEXP alloc] initWithSEXP: rx];
}

- (RSEXP*) listHead
{
	SEXP h;
	if (!xp) return nil;
	if (TYPEOF(xp)!=LISTSXP) return nil;
	h = CAR(xp);
	if (!h || h==R_NilValue) return nil;
	return [[RSEXP alloc] initWithSEXP: h];
}

- (RSEXP*) listTail
{
	SEXP t;
	if (!xp) return nil;
	if (TYPEOF(xp)!=LISTSXP) return nil;
	t = CDR(xp);
	if (!t || t==R_NilValue) return nil;
	return [[RSEXP alloc] initWithSEXP: t];
}

- (RSEXP*) listTag
{
	SEXP t;
	if (!xp) return nil;
	if (TYPEOF(xp)!=LISTSXP) return nil;
	t = TAG(xp);
	if (!t || t==R_NilValue) return nil;
	return [[RSEXP alloc] initWithSEXP: t];
}

- (SEXP) directSEXP
{
    return xp;
}

- (void) protect
{
    PROTECT(xp);
}

- (void) unprotect
{
    UNPROTECT(1);
}

- (RSEXP*) elementAt: (int) index
{
    if (index<0 || index>=LENGTH(xp)) return nil; //XX
    return [[RSEXP alloc] initWithSEXP: VECTOR_ELT(xp, index)];
}

- (double*) doubleArray
{
    return (TYPEOF(xp)==REALSXP)?REAL(xp):NULL;
}

- (int*) intArray
{
    return (TYPEOF(xp)==INTSXP)?INTEGER(xp):NULL;
}

- (NSString*) string
{
    return (TYPEOF(xp)==STRSXP && LENGTH(xp)>0)?[NSString stringWithUTF8String: (char*) CHAR(STRING_ELT(xp, 0))]:nil;
}

- (NSString*) stringAt: (int) index
{
    return (TYPEOF(xp)==STRSXP && LENGTH(xp)>index)?[NSString stringWithUTF8String: (char*) CHAR(STRING_ELT(xp, index))]:nil;
}

- (int) integer
{
    return (TYPEOF(xp)==INTSXP)?INTEGER(xp)[0]:0;
}

- (double) real
{
    return (TYPEOF(xp)==REALSXP)?REAL(xp)[0]:0.0;
}

- (NSArray*) array
{
    if (TYPEOF(xp)==STRSXP) {
        int i=0, l=LENGTH(xp);
        id *cont=(id *) malloc(sizeof(id)*l);
        while (i<l) {
            cont[i]=[[NSString alloc] initWithUTF8String: (char*) CHAR(STRING_ELT(xp, i))];
            i++;
        }
        {
            NSArray *a = [NSArray arrayWithObjects: cont count:l];
            i=0;
            while (i<l) [cont[i++] release];
            free(cont);
            return a;
        }
    }
    if (TYPEOF(xp)==VECSXP) {
        int i=0, l=LENGTH(xp);
        id *cont=malloc(sizeof(id)*l);
        while (i<l) {
            cont[i]=[[RSEXP alloc] initWithSEXP: VECTOR_ELT(xp, i)];
            i++;
        }
        return [NSArray arrayWithObjects: cont count:l];
    }
    return nil;
}	

// low-level function, should be used only to allow selective creation of arrays (e.g. from matrices)
// please use -(NSArray*) array; instead
- (NSString**) strings {
	if (TYPEOF(xp)==STRSXP) {
        int i=0, l=LENGTH(xp);
        NSString **cont=(NSString **) malloc(sizeof(NSString*)*l);
        while (i<l) {
            cont[i]=[[NSString alloc] initWithUTF8String: (char*) CHAR(STRING_ELT(xp, i))];
            i++;
        }
		return cont;
	}
	return nil;
}
		
- (id) value
{
    switch (TYPEOF(xp)) {
        case NILSXP: return nil;
/*
        case STRSXP:
            if (LENGTH(xp)==1) {
                */
            }
    return nil;
}

@end



