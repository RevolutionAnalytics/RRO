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
 */

#ifndef __R_INIT__H__
#define __R_INIT__H__

extern char* lastInitRError;

/* The default R behavior is achieved by using delayed=0. Setting delayed to 1 causes Rmainloop to return immediatelly. This is useful if you need to start the loop from a different event loop context, which can be achieved by using delayed start and sending a break to R at a later point. Since the top level context was created in Rmainloop, the next longjmp will in fact resume in the Rmainloop. At that point the delay flag is already cleared thus resuming the regular operation of R. All this is pretty much hacked, so you should fully understand what you're doing! */
void run_REngineRmainloop(int delayed);

#define Rinit_save_yes 0
#define Rinit_save_no  1
#define Rinit_save_ask 2

int initR(int argc, char **argv, int save_action);
void setRSignalHandlers(int val);

#endif
