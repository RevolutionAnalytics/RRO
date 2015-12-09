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
 *  Created by Simon Urbanek on 5/11/05.
 *  $Id: RTextView.h 6230 2012-08-11 16:19:16Z bibiko $
 */

#import "CCComp.h"

/* RTextView is a subclass of NSTextView with some additional properties:
   - responds to <Ctrl><.> by sending complete: to self
   - responds to <Ctrl><h> by sending showHelpForCurrentFunction: to self
   - handle deleteBackward/Forward for linked matchin pairs

 Used by: console and editor

 */

// parser context in text
#define pcStringSQ   1
#define pcStringDQ   2
#define pcStringBQ   3
#define pcComment    4
#define pcExpression 5

extern BOOL RTextView_autoCloseBrackets;

@interface RTextView : NSTextView
{
	BOOL console;
	BOOL isRdDocument;

	NSInteger snippetControlArray[20][3];
	NSInteger snippetMirroredControlArray[20][3];
	NSInteger snippetControlCounter;
	NSInteger snippetControlMax;
	NSInteger currentSnippetIndex;
	NSInteger mirroredCounter;
	BOOL snippetWasJustInserted;
	BOOL isProcessingMirroredSnippets;


@private
	NSCharacterSet *separatingTokensSet;
	NSCharacterSet *undoBreakTokensSet;
	NSMutableCharacterSet *wordCharSet;
}

// Both methods are already implemented in NSTextView_RAddition but there
// one cannot init instance variable. That's why it is overwritten here to 
// be able to speed up getRangeForCurrentWordOfRange enormously
- (NSRange)getRangeForCurrentWord;
- (NSRange)getRangeForCurrentWordOfRange:(NSRange)curRange;

- (void)setConsoleMode:(BOOL)isConsole;

- (int)  parserContextForPosition:(int)position;
- (void) showHelpForCurrentFunction;
- (void) currentFunctionHint;
- (BOOL) wrapSelectionWithPrefix:(NSString *)prefix suffix:(NSString *)suffix;
- (BOOL) isNextCharMarkedBy:(id)attribute withValue:(id)aValue;
- (BOOL) isCursorAdjacentToAlphanumCharWithInsertionOf:(unichar)aChar;
- (BOOL) shiftSelectionRight;
- (BOOL) shiftSelectionLeft;
- (BOOL) isRConsole;

- (IBAction)makeASCIIconform:(id)sender;
- (IBAction)unescapeUnicode:(id)sender;

- (NSUInteger)characterIndexOfPoint:(NSPoint)aPoint;

- (void)endSnippetSession;
- (void)processMirroredSnippets;
- (void)selectCurrentSnippet;
- (void)insertAsSnippet:(NSString*)theSnippet atRange:(NSRange)targetRange;
- (BOOL)checkForCaretInsideSnippet;
- (BOOL)isSnippetMode;
- (void)checkSnippets;
- (NSDictionary*)getCurrentEnvironment;


@end
