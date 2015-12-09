/*
 *  R.app : a Cocoa front end to: "R A Computer Language for Statistical Data Analysis"
 *  
 *  R.app Copyright notes:
 *                     Copyright (C) 2004-12  The R Foundation
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
 *  FoldingSignTextAttachmentCell.h
 *
 *  Created by Hans-J. Bibiko on 01/03/2012.
 *
 */

#import "FoldingSignTextAttachmentCell.h"
#import "RScriptEditorTextView.h"
#import "RScriptEditorTextStorage.h"

#define HorizontalInset (4.0)
#define VerticalInset (1.0)
#define MaxWidth (100.0)

@implementation FoldingSignTextAttachmentCell

static NSLayoutManager *scratchLayoutManager = nil;

+ (void)initialize
{
	if (self == [FoldingSignTextAttachmentCell class]) {
		NSTextContainer *textContainer = [[NSTextContainer alloc] initWithContainerSize:NSZeroSize];

		scratchLayoutManager = [[NSLayoutManager alloc] init];
		[scratchLayoutManager addTextContainer:textContainer];
		[textContainer release];
	}
}

- (void)drawWithFrame:(NSRect)cellFrame inView:(NSView *)controlView characterIndex:(NSUInteger)charIndex layoutManager:(NSLayoutManager *)layoutManager
{

	// don't render for scratchLayoutManager
	if (layoutManager == scratchLayoutManager) return;

	CGFloat h = cellFrame.size.height;
	CGFloat y = cellFrame.origin.y;

	y += h/4;
	h -= h/2;

	NSRect p = NSMakeRect(cellFrame.origin.x+4.0f, y, cellFrame.size.width-8.0f, h);
	NSBezierPath *path = [NSBezierPath bezierPathWithRoundedRect:p xRadius:4.0 yRadius:4.0];

	NSColor *col = [[layoutManager textStorage] foregroundColor];

	[[col colorWithAlphaComponent:0.6f] setFill];
	[path fill];
	[path stroke];

	// [col setFill];
	// p = NSMakeRect(cellFrame.origin.x+4.0f+5.0f, y+h/2-1.0f, 3.0f, 3.0f);
	// NSRectFill(p);
	// p.origin.x+=5.0f;
	// NSRectFill(p);
	// p.origin.x+=5.0f;
	// NSRectFill(p);

}

- (BOOL)wantsToTrackMouseForEvent:(NSEvent *)theEvent inRect:(NSRect)cellFrame ofView:(NSView *)controlView atCharacterIndex:(NSUInteger)charIndex
{
	return YES;
}

- (BOOL)trackMouse:(NSEvent *)theEvent inRect:(NSRect)cellFrame ofView:(NSView *)controlView atCharacterIndex:(NSUInteger)charIndex untilMouseUp:(BOOL)flag
{

	if ([(RScriptEditorTextView *)controlView respondsToSelector:@selector(unfoldLinesContainingCharacterAtIndex:)]) {
		BOOL success = [(RScriptEditorTextView *)controlView unfoldLinesContainingCharacterAtIndex:charIndex];
		return success;
	}

	return NO;
}

- (NSRect)cellFrameForTextContainer:(NSTextContainer *)textContainer proposedLineFragment:(NSRect)lineFrag glyphPosition:(NSPoint)position characterIndex:(NSUInteger)charIndex
{

	NSLayoutManager *layoutManager = [textContainer layoutManager];

	// we don't do layout for scratchLayoutManager
	if (layoutManager == scratchLayoutManager) return NSZeroRect;

	NSTextStorage *textStorage = [layoutManager textStorage];
	NSTextContainer *scratchContainer = [[scratchLayoutManager textContainers] objectAtIndex:0];
	NSRect textFrame;
	NSRange glyphRange;
	NSRect frame;

	if ([scratchLayoutManager textStorage] != textStorage) {
		[textStorage addLayoutManager:scratchLayoutManager];
	}

	if (!NSEqualSizes([textContainer containerSize], [scratchContainer containerSize])) [scratchContainer setContainerSize:[textContainer containerSize]];

	[scratchLayoutManager ensureLayoutForCharacterRange:NSMakeRange(charIndex, 1)];
	textFrame = [scratchLayoutManager lineFragmentRectForGlyphAtIndex:[scratchLayoutManager glyphIndexForCharacterAtIndex:charIndex] effectiveRange:&glyphRange];

	frame.origin = NSZeroPoint;
	frame.size = NSMakeSize(30.0f, NSHeight(lineFrag)); 
	frame.origin.y -= [[scratchLayoutManager typesetter] baselineOffsetInLayoutManager:scratchLayoutManager glyphIndex:glyphRange.location];

	return frame;
}

@end
