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
	 *  RSymbolTokens.l
	 *
	 *  Created by Hans-J. Bibiko on 17/01/2012.
	 *
	 *  Flex parser for symbols in R script like functions, methods, pragmas.
	 *
	 */
	
#import "RSymbolTokens.h"

size_t utf8strlenSym(const char * _s);
size_t symuoffset, symuleng;
int bcnt = 0;

//keep track of the current utf-8 character (not byte) offset and token length
#define YY_USER_ACTION { symuoffset += symuleng; symuleng = utf8strlenSym(symtext); }
//ignore the output of unmatched characters
#define ECHO {}
%}
%option prefix="sym"
%option noyywrap
%option nounput
%option case-sensitive


s				[ \t\n\r]
sw				[ \t]
nf				[\(,]
alphanum		[0-9a-zA-Z_\.À-ﾟ]
finv1			\.?[0-9]+[0-9a-zA-Z_\.À-ﾟ]+
finv2			[0-9]+\.[0-9a-zA-Z_\.À-ﾟ]+
finv3			_[0-9a-zA-Z_\.À-ﾟ]+
fname			[0-9a-zA-Z_\.À-ﾟ]+
assign			[ \t\n\r]*(<<?-|=)[ \t\n\r]*
line			[\-]+

%x paren
%x classparen

%%

\"([^"\\]|\\(.|[\n\r]))*\"?									;			    	/* ignore double quoted strings          */
'([^'\\]|\\(.|[\n\r]))*'?									;			    	/* ignore single quoted strings          */
`[^`]*`?													;			    	/* ignore backtick quoted string         */


^#pragma{sw}+mark{sw}+{line}						{ return RSYM_PRAGMA_LINE; }
^#pragma{sw}+mark{sw}+[^\n\r]*						{ return RSYM_PRAGMA; }


#.*															;

;															;
{s}+														;

\(													{ BEGIN(paren); }
<paren>\"([^"\\]|\\(.|[\n\r]))*\"?							;			    	/* ignore double quoted strings          */
<paren>'([^'\\]|\\(.|[\n\r]))*'?							;			    	/* ignore single quoted strings          */
<paren>`[^`]*`?												;			    	/* ignore backtick quoted string         */
<paren>#.*													;
<paren>[^\)"'`#]+											;
<paren>\)											{ BEGIN(INITIAL); }

<classparen>\"([^"\\]|\\(.|[\n\r]))*\"?						;			    	/* ignore double quoted strings          */
<classparen>'([^'\\]|\\(.|[\n\r]))*'?						;			    	/* ignore single quoted strings          */
<classparen>`[^`]*`?										;			    	/* ignore backtick quoted string         */
<classparen>#.*												;
<classparen>\(											{ bcnt++; }
<classparen>[^\(\)"'`#]+									;
<classparen>\)										{ bcnt--; if(bcnt <= 0)BEGIN(INITIAL); }

\{													{ return RSYM_LEVEL_DOWN; }
\}													{ return RSYM_LEVEL_UP; }

{finv1}{assign}function{s}*\(						{ return RSYM_INV_FUNCTION; }
{finv2}{assign}function{s}*\(						{ return RSYM_INV_FUNCTION; }
{finv3}{assign}function{s}*\(						{ return RSYM_INV_FUNCTION; }
{nf}{s}*{fname}{assign}function{s}*\(							;
{fname}{assign}function{s}*\(						{ return RSYM_FUNCTION; }

set(Replace)?Method{s}*\({s}*(f{s}*=)?.*{s}*,{s}*(signature{s}*=)?.*{s}*,	{ bcnt=1; BEGIN(classparen); return RSYM_METHOD1; }
set(Replace)?Method{s}*\({s}*signature{s}*=.*{s}*,{s}*f{s}*=.*{s}*,			{ bcnt=1; BEGIN(classparen); return RSYM_METHOD2; }

setClass{s}*\({s}*(Class{s}*=)?{s}*["][^"]+["]{s}*\)		{ return RSYM_CLASS; }
setClass{s}*\({s}*(Class{s}*=)?{s}*['][^']+[']{s}*\)		{ return RSYM_CLASS; }
setClass{s}*\({s}*(Class{s}*=)?{s}*["][^"]+["]{s}*,			{ bcnt=1; BEGIN(classparen); return RSYM_CLASS; }
setClass{s}*\({s}*(Class{s}*=)?{s}*['][^']+[']{s}*,			{ bcnt=1; BEGIN(classparen); return RSYM_CLASS; }

<<EOF>>   						{
	BEGIN(INITIAL);   /* make sure we return to initial state when finished! */
	yy_delete_buffer(YY_CURRENT_BUFFER);
	return 0;
}
%%

#define ONEMASK ((size_t)(-1) / 0xFF)
// adapted from http://www.daemonology.net/blog/2008-06-05-faster-utf8-strlen.html
size_t utf8strlenSym(const char * _s)
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

