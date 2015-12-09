//
//  TestPrefPane.m
//  PrefsPane
//
//  Created by Andreas on Sun Feb 01 2004.
//  Copyright (c) 2004 Andreas Mayer. All rights reserved.
//

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

#import "../RController.h"
#import "ColorsPrefPane.h"


@interface ColorsPrefPane (Private)
- (void)setIdentifier:(NSString *)newIdentifier;
- (void)setLabel:(NSString *)newLabel;
- (void)setCategory:(NSString *)newCategory;
- (void)setIcon:(NSImage *)newIcon;
@end

@implementation ColorsPrefPane

- (id)initWithIdentifier:(NSString *)theIdentifier label:(NSString *)theLabel category:(NSString *)theCategory
{
	if ((self = [super init])) {
		[self setIdentifier:theIdentifier];
		[self setLabel:theLabel];
		[self setCategory:theCategory];
		NSImage *theImage = [[NSImage imageNamed:@"colorsPP"] copy];
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

- (void) awakeFromNib
{
	[self updatePreferences];
	[[Preferences sharedPreferences] addDependent:self];
	[[NSColorPanel sharedColorPanel] setShowsAlpha:YES];
}

- (void) dealloc
{
	[[Preferences sharedPreferences] removeDependent:self];
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
	if (!mainView) {
		[NSBundle loadNibNamed:@"ColorsPrefPane" owner:self];
	}
	return mainView;
}


// AMPrefPaneInformalProtocol

- (void)willSelect
{}

- (void)didSelect
{}

- (int)shouldUnselect
{
	// should be NSPreferencePaneUnselectReply
	return AMUnselectNow;
}

- (void)willUnselect
{
	// this is a hack to make sure no well is active since strange things happen if we close with an active well
	// (fixes PR#13625)
	[inputColorWell activate:YES];
	[inputColorWell deactivate];
	[outputColorWell activate:YES];
	[outputColorWell deactivate];
	[promptColorWell activate:YES];
	[promptColorWell deactivate];
	[backgColorWell activate:YES];
	[backgColorWell deactivate];
	[stderrColorWell activate:YES];
	[stderrColorWell deactivate];
	[stdoutColorWell activate:YES];
	[stdoutColorWell deactivate];
	[selectionColorWell activate:YES];
	[selectionColorWell deactivate];
}

- (void)didUnselect
{}

/* end of std methods implementation */


- (IBAction)changeInputColor:(id)sender {
	[Preferences setKey:inputColorKey withArchivedObject:[(NSColorWell*)sender color]];
}

- (IBAction)changeSelectionColor:(id)sender {
	[Preferences setKey:inputColorKey withArchivedObject:[(NSColorWell*)sender color]];
}

- (IBAction)changeOutputColor:(id)sender {
	[Preferences setKey:outputColorKey withArchivedObject:[(NSColorWell*)sender color]];
}

- (IBAction)changePromptColor:(id)sender {
	[Preferences setKey:promptColorKey withArchivedObject:[(NSColorWell*)sender color]];
}

- (IBAction)changeStdoutColor:(id)sender {
	[Preferences setKey:stdoutColorKey withArchivedObject:[(NSColorWell*)sender color]];
}

- (IBAction)changeStderrColor:(id)sender {
	[Preferences setKey:stderrColorKey withArchivedObject:[(NSColorWell*)sender color]];
}

- (IBAction)changeBackGColor:(id)sender {
	NSColor *well = [[backgColorWell color] colorUsingColorSpaceName:NSCalibratedRGBColorSpace];
	NSColor *bgc = [NSColor colorWithCalibratedRed: [well redComponent] green:[well greenComponent] blue:[well blueComponent] alpha:[alphaStepper floatValue]];
	[Preferences setKey:backgColorKey withArchivedObject:bgc];
}

- (IBAction) changeAlphaColor:(id)sender {
	[self changeBackGColor:sender];
}

- (IBAction) setDefaultColors:(id)sender {
    [[RController sharedController] setDefaultColors:sender];
}

- (void) updatePreferences
{
	NSColor *c=[Preferences unarchivedObjectForKey:inputColorKey withDefault:nil];
	if (c && ![c isEqualTo:[inputColorWell color]]) [inputColorWell setColor:c];
	c=[Preferences unarchivedObjectForKey:outputColorKey withDefault:nil];
	if (c && ![c isEqualTo:[outputColorWell color]]) [outputColorWell setColor:c];
	c=[Preferences unarchivedObjectForKey:selectionColorKey withDefault:nil];
	if (c && ![c isEqualTo:[selectionColorWell color]]) [selectionColorWell setColor:c];
	c=[Preferences unarchivedObjectForKey:promptColorKey withDefault:nil];
	if (c && ![c isEqualTo:[promptColorWell color]]) [promptColorWell setColor:c];
	c=[Preferences unarchivedObjectForKey:stdoutColorKey withDefault:nil];
	if (c && ![c isEqualTo:[stdoutColorWell color]]) [stdoutColorWell setColor:c];
	c=[Preferences unarchivedObjectForKey:stderrColorKey withDefault:nil];
	if (c && ![c isEqualTo:[stderrColorWell color]]) [stderrColorWell setColor:c];
	c=[Preferences unarchivedObjectForKey:backgColorKey withDefault:nil];
	if (c && ![c isEqualTo:[backgColorWell color]]) {
		[backgColorWell setColor:c];
		if ([alphaStepper floatValue]!=[c alphaComponent])
			[alphaStepper setFloatValue:[c alphaComponent]];
	}
}

@end
