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
	 *  Created by Hans-J. Bibiko on 09/01/2012.
	 *
	 *  Flex parser for syntax highlighting Rd code.
	 *
	 */
	
#import "RdScriptEditorTokens.h"

size_t utf8strlenRd(const char * _s);
size_t yyuoffset, yyuleng;

//keep track of the current utf-8 character (not byte) offset and token length
#define YY_USER_ACTION { yyuoffset += yyuleng; yyuleng = utf8strlenRd(yytext); }
//ignore the output of unmatched characters
#define ECHO {}
%}
%option prefix="rd"
%option noyywrap
%option nounput
%option case-sensitive


s				[ \t\n\r]+
break			[^a-zA-Z_0-9À-ﾟ]

section			\\(s(ynopsis|ource|ubsection|e(ction|ealso))|Rd(Opts|version)|n(ote|ame)|concept|title|Sexpr|d(ocType|e(scription|tails))|usage|e(ncoding|xamples)|value|keyword|format|a(uthor|lias|rguments)|references)
macrowarg		\\(s(trong|pecial|amp|Quote)|href|newcommand|c(ite|o(de|mmand))|t(estonly|abular)|i(tem(ize)?|f(else)?)|S(3method|4method)|o(ut|ption)|d(ont(show|test|run)|e(scribe|qn)|fn|Quote)|CRANpkg|url|p(kg|reformatted)|e(n(c|d|umerate|v)|qn|m(ph|ail))|v(erb|ar)|kbd|fi(le|gure)|link(S4class)?|acronym|renewcommand|method|b(old|egin))
macrowoarg		\\(R|cr|tab|item|dots|l(dots|eft)|right|ge)
macrogen		\\[a-zA-Z0-9_]+

%x verbatim

%%

\\(%)																			/* ignore escaped comment sign */
\\(\\)																			/* ignore escaped \ sign */
%[^\n\r]*(\n|\r)?						{ return RDPT_COMMENT; }				/* % Comments                     */
^#ifn?def/[ \t]							{ return RDPT_DIRECTIVE; }
^#endif/[ \t\n\r]						{ return RDPT_DIRECTIVE; }
\\verb/\{								{ BEGIN(verbatim); return RDPT_MACRO_ARG; }
<verbatim>[^\}]																	/* ignore everything inside \verb{} */
<verbatim>\\\}																	/* ignore everything inside \verb{} */
<verbatim>\\(%)																	/* ignore everything inside \verb{} */
<verbatim>%[^\n\r]*(\n|\r)?				{ return RDPT_COMMENT; }				/* % sign is valid inside \verb{}   */
<verbatim>\}							{ BEGIN(INITIAL); }						/* verbatim end */
{section}/\{							{ return RDPT_SECTION; }				/* section macros                 */
\\Sexpr/\[								{ return RDPT_SECTION; }				/* section macros                 */
{macrowarg}/\{							{ return RDPT_MACRO_ARG; }				/* macros with arguments          */
\\link/\[								{ return RDPT_MACRO_ARG; }				/* macros with arguments          */
{macrowoarg}/(\\|{s}|%|{break})			{ return RDPT_MACRO_ARG; }				/* macros without arguments       */
{macrogen}								{ return RDPT_MACRO_GEN; }				/* unknown macros                 */
.										{ return RDPT_OTHER; }

<<EOF>>   						{
	BEGIN(INITIAL);   /* make sure we return to initial state when finished! */
	yy_delete_buffer(YY_CURRENT_BUFFER);
	return 0;
}
%%

#define ONEMASK ((size_t)(-1) / 0xFF)
// adapted from http://www.daemonology.net/blog/2008-06-05-faster-utf8-strlen.html
size_t utf8strlenRd(const char * _s)
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

/*

section:
RdOpts
Rdversion
Sexpr
alias
arguments
author
concept
description
details
docType
encoding
examples
format
keyword
name
note
references
section
seealso
source
subsection
synopsis
title
usage
value

macros with argument:
CRANpkg
S3method
S4method
acronym
begin
bold
cite
code
command
dQuote
deqn
describe
dfn
dontrun
dontshow
donttest
email
emph
enc
end
enumerate
env
eqn
file
figure
href
if
ifelse
item
itemize
kbd
link
linkS4class
method
newcommand
option
out
pkg
preformatted
renewcommand
sQuote
samp
special
strong
tabular
testonly
url
var
verb

macro without argument:
R
cr
dots
ge
item
ldots
left
right
tab
*/
