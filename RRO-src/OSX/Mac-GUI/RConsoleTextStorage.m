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

#import "RConsoleTextStorage.h"
#import "RController.h" // for currentFont

@implementation RConsoleTextStorage

- (id) init
{
	self = [super init];
	if (self) {
		cont = [[NSMutableAttributedString alloc] init];
		theFont = [[[RController sharedController] currentFont] retain];
		lastUsedColor = nil;
	}
	return self;
}

- (void) dealloc
{
	[cont release];
	[theFont release];
	if(lastUsedColor) [lastUsedColor release];
	[super dealloc];
}

// mandatory primitive methods

- (NSString*) string
{
	return [cont string];
}

- (NSDictionary *) attributesAtIndex:(NSUInteger)index effectiveRange:(NSRangePointer)aRange
{
	return [cont attributesAtIndex:index effectiveRange:aRange];
}

- (void) replaceCharactersInRange:(NSRange)aRange withString:(NSString *)aString
{
	//NSLog(@"replace [%d/%d] by %d chars [%@]", aRange.location, aRange.length, [aString length], aString);
	[cont replaceCharactersInRange:aRange withString:aString];
	[self edited:NSTextStorageEditedCharacters range:aRange changeInLength:[aString length]-aRange.length];
}

- (void)setAttributes:(NSDictionary *)attributes range:(NSRange)aRange
{
	//NSLog(@"attrs set at [%d/%d] which amounts to [:%d] and cur len is %d",  aRange.location, aRange.length, aRange.location+aRange.length, [cont length]);
	[cont setAttributes:attributes range:aRange];
	[self edited:NSTextStorageEditedAttributes range:aRange changeInLength:0];
}

// end of primitive methods

// This is the default method for writing text to the console. Note that the application should use begin/endEditing and in addition to textStorage methods it may want to use setSelectedRange: and scrollRangeToVisible: of textView to update the text caret.
- (void) insertText: (NSString*) text atIndex: (int) index withColor: (NSColor*) color
{
	//NSLog(@"insert %d chars at %d to result in %d length", [text length], index, [cont length]+[text length]);
	[cont replaceCharactersInRange: NSMakeRange(index,0) withString: text];
	// cont will use the current attributes at cursor location, change them only if color or font were changed
	if(!lastUsedColor || lastUsedColor != color) {
		if(lastUsedColor) [lastUsedColor release];
		lastUsedColor = [color retain];
		[cont addAttributes:[NSDictionary dictionaryWithObjectsAndKeys:
				theFont, NSFontAttributeName, 
				color, NSForegroundColorAttributeName,
			nil] range:NSMakeRange(index, [text length])];
	}
	[self edited:NSTextStorageEditedCharacters|NSTextStorageEditedAttributes range: NSMakeRange(index,0) changeInLength:[text length]];
}

- (void)setFont:(NSFont*)aFont
{
	if(theFont) [theFont release], theFont = nil;
	theFont = [aFont retain];
	if(lastUsedColor) [lastUsedColor release], lastUsedColor = nil;
}

@end
