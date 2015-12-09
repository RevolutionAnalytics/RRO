%{

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
 *  RScriptEditorTokens.l
 *
 *  Created by Hans-J. Bibiko on 15/02/2011.
 *
 *  Flex parser for syntax highlighting R code.
 *
 */

#import "RScriptEditorTokens.h"

size_t utf8strlen(const char * _s);
size_t yyuoffset, yyuleng;

//keep track of the current utf-8 character (not byte) offset and token length
#define YY_USER_ACTION { yyuoffset += yyuleng; yyuleng = utf8strlen(yytext); }
//ignore the output of unmatched characters
#define ECHO {}
%}
%option noyywrap
%option nounput
%option case-sensitive

s			[ \t\n\r]+
numeric		((0(x|X)[0-9a-fA-F]*)|([+-]?(([0-9]+\.[0-9]*)|([0-9]*\.[0-9]+)|([0-9]+))(e[+-]?[0-9]+)?(i|L)?))
alpha		[a-zA-Z_\.À-ﾟ]
ops			"+"|"-"|"*"|"/"|^|>|>=|<|<=|==|!=|!|&|\||\|\||~|$|:|@
fun			[ \t\n\r]*\(
decl		=|<-|<<-|->|-->
word		[a-zA-Z_\.0-9À-ﾟ@]
variable	[a-zA-ZÀ-ﾟ\.][a-zA-Z_\.0-9À-ﾟ]*
nonword		[^a-zA-Z_0-9À-ﾟ#\n\t\r\.]
keyword		(next|in|N(ULL|aN|A(_(c(haracter_|omplex_)|integer_|real_))?)|T(RUE)?|Inf|else|repeat|F(ALSE)?|break)
functions	(if|f(or|unction)|while)

%x equation
%x varequation
%%


\"([^"\\]|\\(.|[\n\r]))*\"?			{ return RPT_DOUBLE_QUOTED_TEXT;   }      /* double quoted strings          */
'([^'\\]|\\(.|[\n\r]))*'?			{ return RPT_SINGLE_QUOTED_TEXT;   }      /* single quoted strings          */
`[^`]*`?							{ return RPT_BACKTICK_QUOTED_TEXT; }      /* backtick quoted string         */


#[^\n\r]*(\n|\r)?			{ return RPT_COMMENT; }								/* # Comments                     */

{keyword}					{ return RPT_RESERVED_WORD; }						/* all R reserved keywords        */
{functions}/{fun}			{ return RPT_RESERVED_WORD; }						/* all R reserved functions       */

{variable}/{fun}			{ return RPT_OTHER; }								/* non-reserved functions         */

{variable}/{decl}			{ BEGIN(varequation); return RPT_VARIABLE; }		/* R variables before operator    */
<varequation>{decl}			{ BEGIN(INITIAL); return RPT_OTHER; }       		

{variable}/{ops}			{ BEGIN(varequation); return RPT_VARIABLE; }		/* R variables before operator    */
<varequation>{ops}			{ BEGIN(INITIAL); return RPT_OTHER; }       		
{variable}					{ return RPT_VARIABLE; }							/* R variables */

{numeric}/{ops}				{ BEGIN(equation); return RPT_NUMERIC; }			/* numeric before operator        */
<equation>{ops}				{ BEGIN(INITIAL); return RPT_OTHER; }				/* set operator after a numeric   */
{numeric}					{ return RPT_NUMERIC; }								/* single numeric value           */
{numeric}/{alpha}			{ return RPT_WORD; }								/* catch numeric followed by char */

{ops}						{ return RPT_OPERATOR; }							/* all operators                  */
{decl}						{ return RPT_DECLARATION; }							/* all declarations               */
{s}+						{  }												/* ignore spaces                  */

{word}+						{ return RPT_WORD; }								/* return any word                */

{nonword}					{ return RPT_OTHER; }								/* return anything else           */



<<EOF>>   						{
	BEGIN(INITIAL);   /* make sure we return to initial state when finished! */
	yy_delete_buffer(YY_CURRENT_BUFFER);
	return 0;
}
%%

#define ONEMASK ((size_t)(-1) / 0xFF)
// adapted from http://www.daemonology.net/blog/2008-06-05-faster-utf8-strlen.html
size_t utf8strlen(const char * _s)
{
	const char * s;
	size_t count = 0;
	size_t u;
	unsigned char b;
	
	/* Handle any initial misaligned bytes. */
	for (s = _s; (uintptr_t)(s) & (sizeof(size_t) - 1); s++) {
		b = *s;
		
		/* Exit if we hit a zero byte. */
		if (b == '\0')
			goto done;
		
		/* Is this byte NOT the first byte of a character? */
		count += (b >> 7) & ((~b) >> 6);
	}
	
	/* Handle complete blocks. */
	for (; ; s += sizeof(size_t)) {
		/* Prefetch 256 bytes ahead. */
		__builtin_prefetch(&s[256], 0, 0);
		
		/* Grab 4 or 8 bytes of UTF-8 data. */
		u = *(size_t *)(s);
		
		/* Exit the loop if there are any zero bytes. */
		if ((u - ONEMASK) & (~u) & (ONEMASK * 0x80))
			break;
		
		/* Count bytes which are NOT the first byte of a character. */
		u = ((u & (ONEMASK * 0x80)) >> 7) & ((~u) >> 6);
		count += (u * ONEMASK) >> ((sizeof(size_t) - 1) * 8);
	}
	
	/* Take care of any left-over bytes. */
	for (; ; s++) {
		b = *s;
		
		/* Exit if we hit a zero byte. */
		if (b == '\0')
			break;
		
		/* Is this byte NOT the first byte of a character? */
		count += (b >> 7) & ((~b) >> 6);
	}
	
done:
	return ((s - _s) - count);
}

/* un-optimized keywords:
break
else
F
FALSE
in
Inf
NA
NaN
NA_character_
NA_complex_
NA_integer_
NA_real_
next
NULL
repeat
T
TRUE
*/

/* un-optimized function keywords:
for
function
if
while
*/
