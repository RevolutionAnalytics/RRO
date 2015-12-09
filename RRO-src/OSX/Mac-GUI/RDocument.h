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


#import "CCComp.h"
#import "Preferences.h"

@class RDocumentWinCtrl;

@interface RDocument : NSDocument
{
	// since contents can be loaded in "-init", when NIB is not loaded yet, we need to store the contents until NIB is loaded.
	NSData *initialContents;
	NSString *initialContentsType;
	
	BOOL isEditable; // determines whether this document can be edited
	BOOL isREdit; // set to YES by R_Edit to exit modal state on close
	BOOL fileTypeWasChangedWhileSaving;
	BOOL rdToolsAreWorking;
	
	NSPopUpButton *encodingPopUp;

	NSStringEncoding documentEncoding;

	RDocumentWinCtrl *myWinCtrl;
}

+ (void) changeDocumentTitle: (NSDocument *)document Title:(NSString *)title;

- (void) loadInitialContents;
- (void) reinterpretInEncoding: (NSStringEncoding) encoding;
- (void) setEditable: (BOOL) editable;
- (BOOL) editable;
- (void) setREditFlag: (BOOL) flag;
- (BOOL) hasREditFlag;

- (int) fileEncoding;
- (void) setFileEncoding: (int) encoding;

- (BOOL) isRTF;

- (BOOL) convertRd2HTML;
- (BOOL) convertRd2PDF;
- (BOOL) checkRdDocument;
- (BOOL) checkRdDocumentWithFilePath:(NSString*)inputFile reportSuccess:(BOOL)reportSuccess;
- (void) insertRdFunctionTemplate;
- (void) insertRdDataTemplate;

- (void) removeFiles:(NSArray*)files;

- (NSTextView *)textView;

@end
