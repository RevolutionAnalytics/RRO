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
 *  RScriptEditorTokens.h
 *
 *  Created by Hans-J. Bibiko on 17/01/2012.
 *
 *  This file defines all the tokens used for symbols in R script 
 *  like functions, methods, pragmas via a lexer.
 *
 */

#define RSYM_FUNCTION             1
#define RSYM_METHOD1              2
#define RSYM_METHOD2              3
#define RSYM_CLASS                4
#define RSYM_PRAGMA               5
#define RSYM_PRAGMA_LINE          6
#define RSYM_INV_FUNCTION         7
#define RSYM_LEVEL_UP             8
#define RSYM_LEVEL_DOWN           9
#define RSYM_OTHER               10
