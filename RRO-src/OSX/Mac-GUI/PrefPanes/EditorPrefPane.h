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


#import <Foundation/Foundation.h>
#import "../AMPrefs/AMPrefPaneProtocol.h"
#import "Preferences.h"


@interface EditorPrefPane : NSObject <AMPrefPaneProtocol, PreferencesDependent> {
	NSString *identifier;
	NSString *label;
	NSString *category;
	NSImage *icon;
	
	IBOutlet NSView *mainView;
	IBOutlet NSMatrix *internalOrExternal;
	IBOutlet NSBox *builtInPrefs;
	IBOutlet NSBox *externalSettings;
	IBOutlet NSButton *showSyntaxColoring;
	IBOutlet NSButton *showBraceHighlighting;
	IBOutlet NSButton *showArgsHints;
	IBOutlet NSButton *matchingPairs;
	IBOutlet NSTextField *highlightInterval;
	IBOutlet NSButton *showLineNumbers;
	IBOutlet NSTextField *externalEditorName;
	IBOutlet NSMatrix *appOrCommand;
	IBOutlet NSButton *changeEditor;
	IBOutlet NSButton *enableLineWrapping;
	IBOutlet NSTextField *lineNumberGutterWidth;
	IBOutlet NSTextField *fragmentPaddingWidth;
	IBOutlet NSTextField *highlightIntervalText;
	IBOutlet NSTextField *highlightIntervalTextUnit;
	IBOutlet NSTextField *highlightNoteText;
	IBOutlet NSTextField *showLineNumbersText;
	IBOutlet NSTextField *editorText;
	IBOutlet NSTextField *commandText;
	IBOutlet NSTextField *lineNumberGutterWidthText;
	IBOutlet NSTextField *fragmentPaddingWidthText;
	IBOutlet NSTextField *editorFont;
	IBOutlet NSTextField *editorFontLabel;
	IBOutlet NSButton *editorFontSelectButton;
	IBOutlet NSButton *enableIndentNewLines;
	IBOutlet NSButton *hiliteCurrentLine;
	IBOutlet NSStepper *braceHiliteStepper;
	IBOutlet NSButton *autosaveDocuments;
}

- (id)initWithIdentifier:(NSString *)identifier label:(NSString *)label category:(NSString *)category;

	// AMPrefPaneProtocol
- (NSString *)identifier;
- (NSView *)mainView;
- (NSString *)label;
- (NSImage *)icon;
- (NSString *)category;

	// AMPrefPaneInformalProtocol
- (int)shouldUnselect;

	// Other methods

- (IBAction) changeEditor:(id)sender;
- (IBAction) changeInternalOrExternal:(id)sender;
- (IBAction) changeExternalEditorName:(id)sender;
- (IBAction) changeShowSyntaxColoring:(id)sender;
- (IBAction) changeShowBraceHighlighting:(id)sender;
// - (IBAction) changeHighlightInterval:(id)sender;
- (IBAction) changeFlag:(id)sender; // general for boolean button senders
- (IBAction) changeAppOrCommand:(id)sender;
- (IBAction) changeEnableLineWrapping:(id)sender;
- (IBAction) changeLineNumberGutterWidth:(id)sender;
- (IBAction) changeFragmentPaddingWidth:(id)sender;
- (IBAction) changeShowArgsHints:(id)sender;
- (IBAction) showFontPanel:(id)sender;

- (void) updatePreferences;

@end
