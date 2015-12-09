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

#import "RConsoleController.h"
#import "PreferenceKeys.h"
#import "RGUI.h"

@implementation RConsoleController

- (id) init
{
	NSLog(@"RConsoleControlelr created");
	self = [super init];
	if (self) {
		consoleColorsKeys = [[NSArray alloc] initWithObjects:
			backgColorKey, inputColorKey, outputColorKey, promptColorKey,
			stderrColorKey, stdoutColorKey, rootColorKey, nil];
		defaultConsoleColors = [[NSArray alloc] initWithObjects: // default colors
			[NSColor whiteColor], [NSColor blueColor], [NSColor blackColor], [NSColor purpleColor],
			[NSColor redColor], [NSColor grayColor], [NSColor purpleColor], nil];
		consoleColors = [defaultConsoleColors mutableCopy];		
	}
	return self;
}

- (void) windowDidLoad
{
	[self updatePreferences];
	[[Preferences sharedPreferences] addDependent:self];
	
	outputPosition = promptPosition = committedLength = 0;
	
	[[self window] setBackgroundColor:[defaultConsoleColors objectAtIndex:iBackgroundColor]];
	[[self window] setOpaque:NO]; // Needed so we can see through it when we have clear stuff on top
	[console setDrawsBackground:NO];
	[[console enclosingScrollView] setDrawsBackground:NO];
	
	[console setFont:[NSFont userFixedPitchFontOfSize:currentFontSize]];

	// make sure the input caret has the right color
	if (0) {
		NSMutableDictionary *md = [[console typingAttributes] mutableCopy];
		[md setObject: [consoleColors objectAtIndex:iInputColor] forKey: @"NSColor"];
		[console setTypingAttributes:[NSDictionary dictionaryWithDictionary:md]];
		[md release];
	}
	
	[console setContinuousSpellCheckingEnabled:NO]; // force 'no spell checker'
	
	[console display];
}

- (NSUndoManager*) windowWillReturnUndoManager: (NSWindow*) sender
{
	return [[self document] undoManager];
}

- (void) updatePreferences {
	currentFontSize = [Preferences floatForKey: FontSizeKey withDefault: 11.0];
	
	{
		int i = 0, ccs = [consoleColorsKeys count];
		while (i<ccs) {
			NSColor *c = [Preferences unarchivedObjectForKey: [consoleColorsKeys objectAtIndex:i] withDefault: [consoleColors objectAtIndex:i]];
			if (c != [consoleColors objectAtIndex:i]) {
				[consoleColors replaceObjectAtIndex:i withObject:c];
				if (i == iBackgroundColor) {
					[[self window] setBackgroundColor:c];
					[[self window] display];
				}
			}
			i++;
		}
	}
	[console setNeedsDisplay:YES];
}

- (NSString *)windowTitleForDocumentDisplayName:(NSString *)displayName
{
	return NLS(@"R Console");
}

@end
