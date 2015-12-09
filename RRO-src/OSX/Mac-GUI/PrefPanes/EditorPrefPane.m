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

#import "../RGUI.h"
#import "EditorPrefPane.h"
#import "../RController.h"
#import "../Tools/Authorization.h"

@interface EditorPrefPane (Private)
- (void)setIdentifier:(NSString *)newIdentifier;
- (void)setLabel:(NSString *)newLabel;
- (void)setCategory:(NSString *)newCategory;
- (void)setIcon:(NSImage *)newIcon;
@end

@implementation EditorPrefPane

- (id)initWithIdentifier:(NSString *)theIdentifier label:(NSString *)theLabel category:(NSString *)theCategory
{
	if ((self = [super init])) {
		[self setIdentifier:theIdentifier];
		[self setLabel:theLabel];
		[self setCategory:theCategory];
		NSImage *theImage = [[NSImage imageNamed:@"Rdoc"] copy];
		[theImage setFlipped:NO];
		[theImage lockFocus];
		[[NSColor blackColor] set];
		//		[theIdentifier drawAtPoint:NSZeroPoint withAttributes:nil];
		[theImage unlockFocus];
		[theImage recache];
		[self setIcon:theImage];
	}
	return self;
}

- (void) dealloc
{
	[[Preferences sharedPreferences] removeDependent: self];
	[super dealloc];
}


- (NSString *)identifier
{
    return identifier;
}

- (void)setIdentifier:(NSString *)newIdentifier
{
    id old = nil;
	
    if (newIdentifier != identifier) {
        old = identifier;
        identifier = [newIdentifier copy];
        [old release];
    }
}

- (NSString *)label
{
    return label;
}

- (void)setLabel:(NSString *)newLabel
{
    id old = nil;
	
    if (newLabel != label) {
        old = label;
        label = [newLabel copy];
        [old release];
    }
}

- (NSString *)category
{
    return category;
}

- (void)setCategory:(NSString *)newCategory
{
    id old = nil;
	
    if (newCategory != category) {
        old = category;
        category = [newCategory copy];
        [old release];
    }
}

- (NSImage *)icon
{
    return icon;
}

- (void)setIcon:(NSImage *)newIcon
{
    id old = nil;
	
    if (newIcon != icon) {
        old = icon;
        icon = [newIcon retain];
        [old release];
    }
}


// AMPrefPaneProtocol
- (NSView *)mainView
{
	if (!mainView && [NSBundle loadNibNamed:@"EditorPrefPane" owner:self])
		[self updatePreferences];
	return mainView;
}

// AMPrefPaneInformalProtocol

- (int)shouldUnselect
{
	// should be NSPreferencePaneUnselectReply
	return AMUnselectNow;
}

- (void)willUnselect
{
	/* check for any uncommitted text fields */
	if (mainView) {
		NSWindow *w = [mainView window];
		if (w) {
			NSResponder *fr = [w firstResponder];
			if (fr && [fr isMemberOfClass:[NSTextView class]]) {
				SLog(@"%@ didUnselect: committing text in the current text field", self);				
				[fr insertNewline:self];
			}
		}
	}
}

/* end of std methods implementation */

- (void) awakeFromNib
{
	[self updatePreferences];
	[[Preferences sharedPreferences] addDependent:self];

}

- (void) updatePreferences
{
	BOOL flag=[Preferences flagForKey:appOrCommandKey withDefault: YES];
	if (flag)
		[appOrCommand selectCellAtRow:0 column:0];
	else
		[appOrCommand selectCellAtRow:1 column:0];

	flag=[Preferences flagForKey:internalOrExternalKey withDefault: YES];
	if (flag)
		[internalOrExternal selectCellAtRow:0 column:0];
	else
		[internalOrExternal selectCellAtRow:0 column:1];

	NSData *encodedFont = [[NSUserDefaults standardUserDefaults] dataForKey:RScriptEditorDefaultFont];
	if (encodedFont)
		[editorFont setFont:[NSUnarchiver unarchiveObjectWithData:encodedFont]];
	[showSyntaxColoring setEnabled:flag?NSOnState:NSOffState];
	[showBraceHighlighting setEnabled:flag?NSOnState:NSOffState];
	[showLineNumbers setEnabled:flag?NSOnState:NSOffState];
	[highlightInterval setEnabled:flag?NSOnState:NSOffState];
	[enableLineWrapping setEnabled:flag?NSOnState:NSOffState];
	[lineNumberGutterWidth setEnabled:flag?NSOnState:NSOffState];
	[fragmentPaddingWidth setEnabled:flag?NSOnState:NSOffState];
	[enableIndentNewLines setEnabled:flag?NSOnState:NSOffState];
	[braceHiliteStepper setEnabled:flag?NSOnState:NSOffState];
	[editorFont setEnabled:flag?NSOnState:NSOffState];
	[editorFontSelectButton setEnabled:flag?NSOnState:NSOffState];
	[showArgsHints setEnabled:flag?NSOnState:NSOffState];
	[showBraceHighlighting setEnabled:flag?NSOnState:NSOffState];
	[matchingPairs setEnabled:flag?NSOnState:NSOffState];
	[hiliteCurrentLine setEnabled:flag?NSOnState:NSOffState];
	[autosaveDocuments setEnabled:flag?NSOnState:NSOffState];
	if (flag) {
		[highlightIntervalText setTextColor:[NSColor blackColor]];
		[highlightInterval setTextColor:[NSColor blackColor]];
		[highlightIntervalTextUnit setTextColor:[NSColor blackColor]];
		[highlightNoteText setTextColor:[NSColor blackColor]];
		[showLineNumbersText setTextColor:[NSColor blackColor]];
		[editorText setTextColor:[NSColor grayColor]];
		[lineNumberGutterWidthText setTextColor:[NSColor blackColor]];
		[fragmentPaddingWidthText setTextColor:[NSColor blackColor]];
		[externalEditorName setTextColor:[NSColor grayColor]];
		[commandText setTextColor:[NSColor grayColor]];
		[editorFontLabel setTextColor:[NSColor blackColor]];
	} else {
		[highlightIntervalText setTextColor:[NSColor grayColor]];
		[highlightInterval setTextColor:[NSColor grayColor]];
		[highlightIntervalTextUnit setTextColor:[NSColor grayColor]];
		[highlightNoteText setTextColor:[NSColor grayColor]];
		[showLineNumbersText setTextColor:[NSColor grayColor]];
		[editorText setTextColor:[NSColor blackColor]];
		[lineNumberGutterWidthText setTextColor:[NSColor grayColor]];
		[fragmentPaddingWidthText setTextColor:[NSColor grayColor]];
		[externalEditorName setTextColor:[NSColor blackColor]];
		[commandText setTextColor:[NSColor blackColor]];
		[editorFontLabel setTextColor:[NSColor grayColor]];
	}
	
	[changeEditor setEnabled:(flag?NSOffState:NSOnState)];
	[appOrCommand setEnabled:(flag?NSOffState:NSOnState)];
	[externalEditorName setEnabled:(flag?NSOffState:NSOnState)];
	
	
	NSArray *pathComps = [[Preferences stringForKey:externalEditorNameKey withDefault: @"TextEdit"] componentsSeparatedByString:@"/"];
	NSString *name = [pathComps objectAtIndex: ([pathComps count] - 1)];
	pathComps = [name componentsSeparatedByString:@".app"];
	name = [pathComps objectAtIndex:0];
	[externalEditorName setStringValue:name];

	[showArgsHints setState:[Preferences flagForKey:prefShowArgsHints withDefault:YES]?NSOnState:NSOffState];

	[showSyntaxColoring setState:[Preferences flagForKey:showSyntaxColoringKey withDefault: YES]?NSOnState:NSOffState];

	[showBraceHighlighting setState:[Preferences flagForKey:showBraceHighlightingKey withDefault: YES]?NSOnState:NSOffState];

	[autosaveDocuments setState:[Preferences flagForKey:kEditorAutosaveKey withDefault: YES] ? NSOnState : NSOffState];

	// since 1.40 highlightIntervalKey is obsolete since it contains space in its name
	// which isn't allowed for key-value-bindings; instead using HighlightIntervalKey
	if([[NSUserDefaults standardUserDefaults] objectForKey:highlightIntervalKey]) {
		[[NSUserDefaults standardUserDefaults] setFloat:[[Preferences stringForKey:highlightIntervalKey] doubleValue] forKey:HighlightIntervalKey];
		[[NSUserDefaults standardUserDefaults] removeObjectForKey:highlightIntervalKey];
	}

	[showLineNumbers setState:[Preferences flagForKey:showLineNumbersKey withDefault: YES]?NSOnState:NSOffState];

	[matchingPairs setState:[Preferences flagForKey:kAutoCloseBrackets withDefault:YES]?NSOnState:NSOffState];
	
	// if (![Preferences flagForKey:showLineNumbersKey withDefault: YES]) {
	// 	[enableLineWrapping setEnabled:NSOffState];		
	// 	[lineNumberGutterWidth setEnabled:NSOffState];
	// 	[fragmentPaddingWidth setEnabled:NSOffState];
	// 	[lineNumberGutterWidthText setTextColor:[NSColor grayColor]];
	// 	[fragmentPaddingWidthText setTextColor:[NSColor grayColor]];
	// }
	[enableLineWrapping setState:[Preferences flagForKey:enableLineWrappingKey withDefault: YES]?NSOnState:NSOffState];
	
	[lineNumberGutterWidth setStringValue:[Preferences stringForKey:lineNumberGutterWidthKey withDefault: @"16.0"]];
	
	[fragmentPaddingWidth setStringValue:[Preferences stringForKey:lineFragmentPaddingWidthKey withDefault: @"6.0"]];
	
}

- (IBAction) showFontPanel:(id)sender
{
	[[NSFontPanel sharedFontPanel] setPanelFont:[NSUnarchiver unarchiveObjectWithData:[[NSUserDefaults standardUserDefaults] dataForKey:RScriptEditorDefaultFont]] isMultiple:NO];
	[[NSFontPanel sharedFontPanel] makeKeyAndOrderFront:self];
}

- (IBAction) changeInternalOrExternal:(id)sender
{
	BOOL flag;
	int res = (int)[sender selectedColumn];
	if (res)
		flag = NO;
	else
		flag = YES;
	[Preferences setKey:internalOrExternalKey withFlag:flag];
}

- (void)changeExternalEditorName:(id)sender {
	NSString *name = ([[sender stringValue] length] == 0)?@"TextEdit":[sender stringValue];
	[Preferences setKey:externalEditorNameKey withObject:name];
}

- (IBAction) changeShowSyntaxColoring:(id)sender {
	int tmp = (int)[sender state];
	BOOL flag = tmp?YES:NO;
	[Preferences setKey:showSyntaxColoringKey withFlag:flag];
}

- (IBAction) changeShowBraceHighlighting:(id)sender {
	int tmp = (int)[sender state];
	BOOL flag = tmp?YES:NO;
	[Preferences setKey:showBraceHighlightingKey withFlag:flag];
}

- (IBAction) changeShowArgsHints:(id)sender {
	int tmp = (int)[sender state];
	BOOL flag = tmp?YES:NO;
	[Preferences setKey:prefShowArgsHints withFlag:flag];
}

// - (IBAction) changeHighlightInterval:(id)sender {
// 	NSString *interval = ([[sender stringValue] length] == 0)?@"0.2":[sender stringValue];
// 	if ([interval length] == 0) {
// 		interval = @"0.2";
// 	} else {
// 		double value = [interval doubleValue];
// 		if (value < 0.1)
// 			interval = @"0.1";
// 		else if (value > 0.8)
// 			interval = @"0.8";
// 	}
// 	[Preferences setKey:highlightIntervalKey withObject:interval];
// }

- (IBAction) changeFlag:(id)sender {
	int tmp = (int)[sender state];
	BOOL flag = tmp ? YES : NO;
	NSString *key = nil;
	if (sender == autosaveDocuments) key = kEditorAutosaveKey;
	if (sender == showLineNumbers)   key = showLineNumbersKey;
	if (sender == matchingPairs)     key = kAutoCloseBrackets;
	if (key)
		[Preferences setKey:key withFlag:flag];
	else {
		SLog(@"WARNING: changeFlag called by %@ which corresponds to no key!", sender);
	}
}

- (IBAction) changeMatchingPairs:(id)sender {
	int tmp = (int)[sender state];
	BOOL flag = tmp?YES:NO;
	[Preferences setKey:kAutoCloseBrackets withFlag:flag];
}

- (IBAction) changeAppOrCommand:(id)sender {
	BOOL flag;
	int res = (int)[sender selectedRow];
	if (res)
		flag = NO;
	else
		flag = YES;
	[Preferences setKey:appOrCommandKey withFlag:flag];
}

- (IBAction) changeEditor:(id)sender;
{
	int answer;
	NSOpenPanel *sp;
	sp = [NSOpenPanel openPanel];
	[sp setTitle:NLS(@"Select editor application")];
	answer = [sp runModalForDirectory:@"/Applications" file:nil types:nil];
	if(answer == NSOKButton) {
		[Preferences setKey:externalEditorNameKey withObject:[sp filename]];
	}
}

- (IBAction) changeEnableLineWrapping:(id)sender {
	int tmp = (int)[sender state];
	BOOL flag = tmp?YES:NO;
	[Preferences setKey:enableLineWrappingKey withFlag:flag];
	
}

- (IBAction) changeLineNumberGutterWidth:(id)sender {
	NSString *interval = ([[sender stringValue] length] == 0)?@"0.2":[sender stringValue];
	if ([interval length] == 0) {
		interval = @"16.0";
	} else {
		double value = [interval doubleValue];
		if (value < 6.0)
			interval = @"6.0";
	}
	[Preferences setKey:lineNumberGutterWidthKey withObject:interval];	
}

- (IBAction) changeFragmentPaddingWidth:(id)sender {
	NSString *interval = ([[sender stringValue] length] == 0)?@"0.2":[sender stringValue];
	if ([interval length] == 0) {
		interval = @"6.0";
	} else {
		double value = [interval doubleValue];
		if (value < 3.0)
			interval = @"3.0";
		else if (value > 20.0)
			interval = @"20.0";
	}
	[Preferences setKey:lineFragmentPaddingWidthKey withObject:interval];	
}

@end
