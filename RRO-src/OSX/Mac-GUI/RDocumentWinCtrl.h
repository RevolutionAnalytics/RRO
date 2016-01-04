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
 *  Created by Simon Urbanek on 1/11/05.
 */

#import "CCComp.h"
#import "Preferences.h"
#import "RDocument.h"
#import "RScriptEditorTextView.h"

#import <WebKit/WebKit.h>
#import <WebKit/WebFrame.h>

// @class RRulerView;

extern NSColor *shColorNormal;
extern NSColor *shColorString;
extern NSColor *shColorNumber;
extern NSColor *shColorKeyword;
extern NSColor *shColorComment;
extern NSColor *shColorIdentifier;

@interface RDocumentWinCtrl : NSWindowController <PreferencesDependent>
{
	IBOutlet id textView;
	
	IBOutlet NSView *searchToolbarView;
	IBOutlet NSSearchField *searchToolbarField;
	
	IBOutlet NSView *fnListView;
	IBOutlet NSView *rdToolboxView;
	IBOutlet NSPopUpButton *fnListBox;
	
	IBOutlet NSDrawer *helpDrawer;
	IBOutlet WebView *helpWebView;
	
	IBOutlet NSPanel *goToLineSheet;
	IBOutlet NSTextField *goToLineField;

	IBOutlet NSTextField *statusLine;
	IBOutlet NSBox *horizontalLine;
	IBOutlet NSTextField *statusLineBackground;

	IBOutlet NSView *saveOpenAccView;
	
	BOOL useHighlighting; // if set to YES syntax highlighting is used
	BOOL showMatchingBraces; // if YES mathing braces are highlighted
	BOOL deleteBackward;
	BOOL plainFile; // overriders preferences - if YES syntax HL is disabled
	BOOL argsHints; // fn args hinting
	BOOL lastLineWasCodeIndented;
	BOOL isFormattingRcode;
	BOOL isFunctionScanning;

	int hsType; // help search type
	
	BOOL updating; // this flag is set while syntax coloring is changed to prevent recursive changes
	BOOL execNewlineFlag; // this flag is set to YES when <cmd><Enter> execute is used, becuase the <enter> must be ignored as an event
	
	NSString *helpTempFile; // path to temporary file used for help

	NSArray *texItems; // array of known tex macros for Rd file completion

	int currentHighlight; // currently highlighted character

	NSDictionary *functionMenuInvalidAttribute;
	NSDictionary *functionMenuCommentAttribute;
	NSDictionary *pragmaMenuAttribute;

}

- (void) replaceContentsWithString: (NSString*) strContents;
- (void) replaceContentsWithRtf: (NSData*) rtfContents;

- (void) highlightBracesWithShift: (int) shift andWarn: (BOOL) warn;
- (void) highlightBracesAfterDidProcessEditing;

- (IBAction)executeSelection:(id)sender;
- (IBAction)sourceCurrentDocument:(id)sender;
- (IBAction)printDocument:(id)sender;
- (IBAction)goToLine:(id)sender;
- (IBAction)goToLineCloseSheet:(id)sender;

- (IBAction)setHelpSearchType:(id)sender;
- (IBAction)goHelpSearch:(id)sender;
- (IBAction)reInterpretDocument:(id)sender;

- (IBAction)shiftRight:(id)sender;
- (IBAction)shiftLeft:(id)sender;

- (IBAction)tidyRCode: (id)sender;

- (IBAction)convertRd2HTML:(id)sender;
- (IBAction)convertRd2PDF:(id)sender;
- (IBAction)checkRdDocument:(id)sender;
- (IBAction)insertRdFunctionTemplate:(id)sender;
- (IBAction)insertRdDataTemplate:(id)sender;

- (void) setEditable: (BOOL) editable;

- (void) setStatusLineText: (NSString*) text;
- (NSString*) statusLineText;
- (BOOL) hintForFunction: (NSString*) fn; // same as in RConstroller - we should unify this ...

- (void) setPlain: (BOOL) plain; // plain = don't use highlighting even if preferences say so
- (BOOL) plain;

- (BOOL) isRdDocument;

- (int) fileEncoding;
- (void) setFileEncoding: (int) encoding;

- (void) setHighlighting: (BOOL) use;
- (void) updatePreferences;

- (NSData*) contentsAsRtf;
- (NSString*) contentsAsString;

- (NSTextView *) textView;
- (NSView*) searchToolbarView;
- (NSView*) fnListView;
- (NSView*) rdToolboxView;

- (NSView*) saveOpenAccView;

- (BOOL) isFunctionScanning;
- (void) functionRescan; // re-scans the functions it the document and updates function list/pop-up
- (void) functionGo: (id) sender; // invoked by function pop-up, the tag of the sender specifies the position to go to
- (void) functionReset; // reset all functions (will go away soon, user functionRescan instead)

- (void) helpSearchTypeChanged;

- (void) RDocumentDidResize: (NSNotification *)notification;

@end
