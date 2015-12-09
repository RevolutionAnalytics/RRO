//
//  NoodleLineNumberView.m
//  Line View Test
//
//  Created by Paul Kim on 9/28/08.
//  Copyright (c) 2008 Noodlesoft, LLC. All rights reserved.
//
// Permission is hereby granted, free of charge, to any person
// obtaining a copy of this software and associated documentation
// files (the "Software"), to deal in the Software without
// restriction, including without limitation the rights to use,
// copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the
// Software is furnished to do so, subject to the following
// conditions:
// 
// The above copyright notice and this permission notice shall be
// included in all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
// EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
// OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
// NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
// HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
// WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
// FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
// OTHER DEALINGS IN THE SOFTWARE.
//

// This version of the NoodleLineNumberView was improved by the Sequel Pro team
// http://www.sequelpro.com which removes marker
// functionality, adds selection by clicking/dragging on the ruler, and 
// it was optimised for speed.

#import "NoodleLineNumberView.h"
#import "RScriptEditorTextView.h"
#import "RScriptEditorTextStorage.h"
#import "PreferenceKeys.h"
#import "RWindow.h"

#include <tgmath.h>


#pragma mark NSCoding methods

#define NOODLE_FONT_CODING_KEY              @"font"
#define NOODLE_TEXT_COLOR_CODING_KEY        @"textColor"
// #define NOODLE_ALT_TEXT_COLOR_CODING_KEY    @"alternateTextColor"
// #define NOODLE_BACKGROUND_COLOR_CODING_KEY  @"backgroundColor"

#pragma mark -

#define DEFAULT_THICKNESS  22.0f
#define RULER_MARGIN        5.0f
#define RULER_MARGIN2       RULER_MARGIN * 2

// Cache loop methods for speed

#pragma mark -

@interface NoodleLineNumberView (Private)

- (NSArray *)lineIndices;
- (void)calculateLines;
- (void)invalidateLineIndices;
- (void)updateGutterThicknessConstants;

@end

@implementation NoodleLineNumberView

// @synthesize alternateTextColor;
// @synthesize backgroundColor;

- (id)initWithScrollView:(NSScrollView *)aScrollView
{

	if ((self = [super initWithScrollView:aScrollView orientation:NSVerticalRuler]) != nil)
	{
		[self setClientView:[aScrollView documentView]];

		isFoldingEnabled = NO;
		if (floor(NSAppKitVersionNumber) > NSAppKitVersionNumber10_6) {
			isFoldingEnabled = YES;
		}

		cvTextStorage = (RScriptEditorTextStorage*)[[aScrollView documentView] textStorage];
		// [self setAlternateTextColor:[NSColor whiteColor]];
		lineIndices = nil;
		textAttributes = [[NSDictionary dictionaryWithObjectsAndKeys:
			[self font], NSFontAttributeName, 
			[self textColor], NSForegroundColorAttributeName,
			nil] retain];
		NSSize s = [[NSString stringWithString:@"8"] sizeWithAttributes:textAttributes];
		maxWidthOfGlyph = s.width;
		maxHeightOfGlyph = s.height;
		[self updateGutterThicknessConstants];
		currentRuleThickness = 0.0f;

		// Cache loop methods for speed
		lineNumberForCharacterIndexSel = @selector(lineNumberForCharacterIndex:);
		lineNumberForCharacterIndexIMP = [self methodForSelector:lineNumberForCharacterIndexSel];
		lineRangeForRangeSel = @selector(lineRangeForRange:);
		addObjectSel = @selector(addObject:);
		numberWithUnsignedIntegerSel = @selector(numberWithUnsignedInteger:);
		numberWithUnsignedIntegerIMP = [NSNumber methodForSelector:numberWithUnsignedIntegerSel];
		rangeOfLineSel = @selector(getLineStart:end:contentsEnd:forRange:);

		currentNumberOfLines = 1;
		lineWrapping = NO;
		numberClass = [NSNumber class];
		
		normalBackgroundColor = [[NSColor colorWithCalibratedWhite: 0.95 alpha: 1.0] retain];
		foldedBackgroundColor = [[NSColor colorWithCalibratedWhite: 0.85 alpha: 1.0] retain];

		top          = [[NSImage imageNamed:@"Folding Top"] retain];
		topHoover    = [[NSImage imageNamed:@"Folding Top Hoover"] retain];
		bottom       = [[NSImage imageNamed:@"Folding Bottom"] retain];
		bottomHoover = [[NSImage imageNamed:@"Folding Bottom Hoover"] retain];
		folded       = [[NSImage imageNamed:@"Folding Collapsed"] retain];
		foldedHoover = [[NSImage imageNamed:@"Folding Collapsed Hoover"] retain];


		NSTrackingArea *trackingArea = [[NSTrackingArea alloc] initWithRect:[self visibleRect] options:NSTrackingMouseEnteredAndExited|NSTrackingMouseMoved|NSTrackingActiveInKeyWindow owner:self userInfo:nil];
		[self addTrackingArea:trackingArea];
		[trackingArea release];
		mouseHoveringAtPoint = NSMakePoint(-1,-1);
	}

	return self;
}

- (void)awakeFromNib
{
	[self setClientView:[[self scrollView] documentView]];	
}

- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];

	for(NSTrackingArea *trackingArea in self.trackingAreas)
		[self removeTrackingArea:trackingArea];

	[top release];
	[topHoover release];
	[bottom release];
	[bottomHoover release];
	[folded release];
	[foldedHoover release];

	if (lineIndices) [lineIndices release];
	if (textAttributes) [textAttributes release];
	if (font) [font release];
	if (textColor) [textColor release];
	[normalBackgroundColor release];
	[foldedBackgroundColor release];
	[super dealloc];
}

#pragma mark -

- (void)windowDidResignKey:(NSNotification*)notification
{
	[self mouseExited:nil];
}

- (void)setLineWrappingMode:(BOOL)mode
{
	lineWrapping = mode;
}

- (void)setFont:(NSFont *)aFont
{
	if (font != aFont)
	{
		[font autorelease];
		font = [aFont retain];
		if (textAttributes) [textAttributes release];
		textAttributes = [[NSDictionary dictionaryWithObjectsAndKeys:
			font, NSFontAttributeName, 
			[self textColor], NSForegroundColorAttributeName,
			nil] retain];
		NSSize s = [[NSString stringWithString:@"8"] sizeWithAttributes:textAttributes];
		maxWidthOfGlyph = s.width;
		maxHeightOfGlyph = s.height;
		[self updateGutterThicknessConstants];
	}
}

- (NSFont *)font
{
	if (font == nil)
		return [NSFont labelFontOfSize:[NSFont systemFontSizeForControlSize:NSMiniControlSize]];

	return font;
}

- (void)setTextColor:(NSColor *)color
{
	if (textColor != color)
	{
		[textColor autorelease];
		textColor  = [color retain];
		if (textAttributes) [textAttributes release];
		textAttributes = [[NSDictionary dictionaryWithObjectsAndKeys:
			[self font], NSFontAttributeName, 
			textColor, NSForegroundColorAttributeName,
			nil] retain];
		NSSize s = [[NSString stringWithString:@"8"] sizeWithAttributes:textAttributes];
		maxWidthOfGlyph = s.width;
		maxHeightOfGlyph = s.height;
		[self updateGutterThicknessConstants];
	}
}

- (NSColor *)textColor
{
	if (textColor == nil)
		return [NSColor colorWithCalibratedWhite:0.42 alpha:1.0];

	return textColor;
}

- (void)setClientView:(NSView *)aView
{
	id oldClientView = [self clientView];

	if ((oldClientView != aView) && [oldClientView isKindOfClass:[NSTextView class]])
		[[NSNotificationCenter defaultCenter] removeObserver:self name:NSTextStorageDidProcessEditingNotification object:[(NSTextView *)oldClientView textStorage]];

	[super setClientView:aView];

	if ((aView != nil) && [aView isKindOfClass:[NSTextView class]])
	{
		layoutManager  = [(NSTextView *)aView layoutManager];
		container      = [(NSTextView *)aView textContainer];
		clientView     = (NSTextView*)[self clientView];

		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(textDidChange:) name:NSTextStorageDidProcessEditingNotification object:[clientView textStorage]];
		[self invalidateLineIndices];
	}

}

#pragma mark -

- (void)refresh
{
	if(![(RScriptEditorTextView*)clientView lineNumberingEnabled]) return;
	[self invalidateLineIndices];
	[self setNeedsDisplayInRect:[self visibleRect]];
}

- (void)textDidChange:(NSNotification *)notification
{

	if(!clientView) return;

	if(![(RScriptEditorTextView*)clientView lineNumberingEnabled]) return;

	// Invalidate the line indices only if text view was changed in length but not if the font was changed.
	// They will be recalculated and recached on demand.
	if([[clientView textStorage] editedMask] != 1) {
		[self invalidateLineIndices];
		[self setNeedsDisplayInRect:[self visibleRect]];
	}

}

- (NSUInteger)lineNumberForLocation:(CGFloat)location
{
	NSUInteger      line, count, rectCount;
	NSRectArray     rects;
	NSRect          visibleRect;
	NSRange         nullRange;
	NSArray         *lines;

	visibleRect = [[[self scrollView] contentView] bounds];

	lines = [self lineIndices];

	location += NSMinY(visibleRect);
	
	nullRange = NSMakeRange(NSNotFound, 0);
	count = [lines count];

	// Find the characters that are currently visible
	NSRange range = [layoutManager characterRangeForGlyphRange:[layoutManager glyphRangeForBoundingRect:visibleRect inTextContainer:container] actualGlyphRange:NULL];

	// Fudge the range a tad in case there is an extra new line at end.
	// It doesn't show up in the glyphs so would not be accounted for.
	range.length++;

	for (line = (NSUInteger)(*lineNumberForCharacterIndexIMP)(self, lineNumberForCharacterIndexSel, range.location); line < count; line++)
	{

		rects = [layoutManager rectArrayForCharacterRange:NSMakeRange([NSArrayObjectAtIndex(lines, line) unsignedIntegerValue], 0)
							 withinSelectedCharacterRange:nullRange
										  inTextContainer:container
												rectCount:&rectCount];

		if(!rectCount) return NSNotFound;

		if ((location >= NSMinY(rects[0])) && (location < NSMaxY(rects[0])))
			return line + 1;

	}

	return NSNotFound;
}

- (NSUInteger)lineNumberForCharacterIndex:(NSUInteger)index
{
	NSUInteger      left, right, mid, lineStart;
	NSArray  *lines;

	lines = [self lineIndices];

	// Binary search
	left = 0;
	right = [lines count];

	while ((right - left) > 1)
	{

		mid = (right + left) >> 1;
		lineStart = [NSArrayObjectAtIndex(lines, mid) unsignedIntegerValue];

		if (index < lineStart)
			right = mid;
		else if (index > lineStart)
			left = mid;
		else
			return mid;

	}
	return left;
}

- (void)drawBackgroundInRect:(NSRect)rect
{
  [normalBackgroundColor set];
  [NSBezierPath fillRect: rect];
}

- (void)drawHashMarksAndLabelsInRect:(NSRect)aRect
{

	NSRect bounds = [self bounds];

	// if (backgroundColor != nil)
	// {
	// 	[backgroundColor set];
	// 	NSRectFill(bounds);
	// 
	// 	[[NSColor colorWithCalibratedWhite:0.58 alpha:1.0] set];
	// 	[NSBezierPath strokeLineFromPoint:NSMakePoint(NSMaxX(bounds) - 0.5, NSMinY(bounds)) toPoint:NSMakePoint(NSMaxX(bounds) - 0.5, NSMaxY(bounds))];
	// }

	NSRect           visibleRect;
	NSRange          range, nullRange;
	NSString         *labelText;
	NSUInteger       rectCount, index, line, count;
	NSRectArray      rects;
	CGFloat          yinset;
	NSArray          *lines;

	nullRange      = NSMakeRange(NSNotFound, 0);

	yinset         = [clientView textContainerInset].height;
	visibleRect    = [[[self scrollView] contentView] bounds];

	lines          = [self lineIndices];
	count          = [lines count];

	if(!count) return;

	// Find the characters that are currently visible

	range = [layoutManager characterRangeForGlyphRange:[layoutManager glyphRangeForBoundingRect:visibleRect inTextContainer:container] actualGlyphRange:NULL];

	// Fudge the range a tad in case there is an extra new line at end.
	// It doesn't show up in the glyphs so would not be accounted for.
	range.length++;

	CGFloat boundsRULERMargin2 = NSWidth(bounds) - RULER_MARGIN2;
	CGFloat boundsWidthRULER   = NSWidth(bounds) - RULER_MARGIN + 1;
	CGFloat yinsetMinY         = yinset - NSMinY(visibleRect);
	CGFloat foldBackWidth      = NSWidth(bounds) - 1;
	CGFloat foldx              = boundsWidthRULER - 9;
	CGFloat rectHeight;
	CGFloat last_y = -10.0f;
	CGFloat y;
	BOOL isHoveringRect = YES;
	BOOL flipped = [self isFlipped];


	for (line = (NSUInteger)(*lineNumberForCharacterIndexIMP)(self, lineNumberForCharacterIndexSel, range.location); line < count; line++)
	{
		index = [NSArrayObjectAtIndex(lines, line) unsignedIntegerValue];

		if (NSLocationInRange(index, range))
		{
			rects = [layoutManager rectArrayForCharacterRange:NSMakeRange(index, 0)
				withinSelectedCharacterRange:nullRange
				inTextContainer:container
				rectCount:&rectCount];

			if (rectCount > 0)
			{
				// Note that the ruler view is only as tall as the visible
				// portion. Need to compensate for the clipview's coordinates.

				rectHeight = NSHeight(rects[0]);
				y = yinsetMinY + NSMinY(rects[0]) + ((NSInteger)(rectHeight - maxHeightOfGlyph) >> 1);
				if(y != last_y) {

					// Check for folding markers
					NSRange r;
					NSImage *foldImage = nil;
					if(line < [lines count]-1) {
						r = NSMakeRange(index, [NSArrayObjectAtIndex(lines, line+1) unsignedIntegerValue]-1-index);
					} else {
						r = NSMakeRange(index, [[clientView string] length]-index);
					}

					if(isFoldingEnabled) {
						isHoveringRect = NSMouseInRect(mouseHoveringAtPoint, NSMakeRect(foldx, y,
								boundsRULERMargin2, rectHeight), flipped);

						// for soft wrapped text view continue if line range is partially
						// (r.location > a range.location) in a folded range
						if(lineWrapping && [cvTextStorage inFoldedRangeForRange:r]) continue;

						if([cvTextStorage foldedAtIndex:NSMaxRange(r)] > -1) {
							foldImage = (isHoveringRect) ? foldedHoover : folded;
							[foldedBackgroundColor setFill];
							NSRectFill(NSMakeRect(0, y, foldBackWidth, rectHeight-5));
						}
						else if(r.length) {						
							switch([(RScriptEditorTextView*)clientView foldStatusAtIndex:NSMaxRange(r)-1]) {
								case 0:
								foldImage = nil;
								break;
								case 1:
								foldImage = (isHoveringRect) ? bottomHoover : bottom;
								break;
								case 2:
								foldImage = (isHoveringRect) ? topHoover : top;
								break;
							}
						}
					}

					// How many digits has the current line number?
					NSUInteger idx = line + 1;
					NSInteger numOfDigits = 2; // 2 := folding marker width
					while(idx) { numOfDigits++; idx/=10; }

					// Line numbers are internally stored starting at 0
					labelText = [NSString stringWithFormat:@"%lu", (NSUInteger)(line + 1)];

					// Draw string flush right, centered vertically within the line
					[labelText drawInRect:
						NSMakeRect(boundsWidthRULER - (maxWidthOfGlyph * numOfDigits), y,
							boundsRULERMargin2, rectHeight)
						withAttributes:textAttributes];

					// Draw fold marker if any
					if(isFoldingEnabled && foldImage)
						[foldImage drawInRect:NSMakeRect(foldx, y, 12, 12) 
								 fromRect:NSZeroRect 
								operation:NSCompositeSourceOver fraction:1.0];


				}
				last_y = y;
			}
		}

		if (index > NSMaxRange(range))
			break;

	}

}

- (void)mouseDown:(NSEvent *)theEvent
{

	NSUInteger  line;
	NSTextView  *view;

	if (![[self clientView] isKindOfClass:[NSTextView class]]) return;
	view = (NSTextView *)[self clientView];

	NSPoint p = [self convertPoint:[theEvent locationInWindow] fromView:nil];

	line = [self lineNumberForLocation:p.y];

	// Check if click was inside folding marker
	if(isFoldingEnabled && ((NSWidth([self bounds]) - RULER_MARGIN)+3) - p.x >= 0 && ((NSWidth([self bounds]) - RULER_MARGIN)-3) - p.x < 7) {

		NSUInteger caretPosition = 0;
		NSArray *lines           = [self lineIndices];
		NSInteger index = [NSArrayObjectAtIndex(lines, line-1) unsignedIntegerValue];
		
		// Check for folding markers
		NSRange r;
		NSUInteger selectionEnd = 0;
		if (line < [lines count]) {
			selectionEnd = [NSArrayObjectAtIndex(lines, line) unsignedIntegerValue] - 1;
		} else {
			selectionEnd = [[clientView string] length];
		}

		if(index < 0 || (selectionEnd - index) >= [[clientView string] length]) {
			return;
		}

		r = NSMakeRange(index, selectionEnd - index);

		NSInteger foldItem = 0;
		unichar c;

		if(r.length) {
			foldItem = [(RScriptEditorTextView*)clientView foldStatusAtIndex:NSMaxRange(r)-1];
		}
		
		if(foldItem < 2) {
			caretPosition = [NSArrayObjectAtIndex([self lineIndices], line) unsignedIntegerValue];
			if(caretPosition > 0) caretPosition--;
		} else {
			caretPosition = index;
		}

		NSUInteger stringLength = [[clientView string] length];
		if(!stringLength) return;
		if(caretPosition == 0 || caretPosition >= stringLength) return;
		

		CFStringRef parserStringRef = (CFStringRef)[clientView string];

		unichar co = '{'; // opening char
		unichar cc = '}'; // closing char
	
		NSInteger start = -1;
		NSInteger end = -1;
		NSInteger bracketCounter = 0;

		c = CFStringGetCharacterAtIndex(parserStringRef, caretPosition);
		if(c == cc)
			bracketCounter--;
		if(c == co)
			bracketCounter++;

		for(NSInteger i=caretPosition; i>=0; i--) {
			if([(RScriptEditorTextView*)clientView parserContextForPosition:i] != pcExpression) continue;
			c = CFStringGetCharacterAtIndex(parserStringRef, i);
			if(c == co) {
				if(!bracketCounter) {
					start = i;
					break;
				}
				bracketCounter--;
			}
			if(c == cc) {
				bracketCounter++;
			}
		}
		if(start < 0 ) return;

		// go up for lines like "} else {"
		if(start && [(RScriptEditorTextView*)clientView foldStatusAtIndex:start-1] == 0) {
			for(NSInteger i=start-1; i>=0; i--) {
				c = CFStringGetCharacterAtIndex(parserStringRef, i);
				if(c == '\n' || c == '\r') break;
				if([(RScriptEditorTextView*)clientView parserContextForPosition:i] != pcExpression) continue;
				if(c == cc && i > 0) {
					bracketCounter = 0;
					for(NSInteger j=i-1; j>=0; j--) {
						if([(RScriptEditorTextView*)clientView parserContextForPosition:j] != pcExpression) continue;
						c = CFStringGetCharacterAtIndex(parserStringRef, j);
						if(c == co) {
							if(!bracketCounter) {
								start = j;
								break;
							}
							bracketCounter--;
						}
						if(c == cc) {
							bracketCounter++;
						}
					}
					break;
				}
			}
		}		


		bracketCounter = 0;
		for(NSUInteger i=caretPosition; i<stringLength; i++) {
			if([(RScriptEditorTextView*)clientView parserContextForPosition:i] != pcExpression) continue;
			c = CFStringGetCharacterAtIndex(parserStringRef, i);
			if(c == co) {
				bracketCounter++;
			}
			if(c == cc) {
				if(!bracketCounter) {
					end = i+1;
					BOOL goAhead = NO;
					//go ahead for lines a la  "} else {"
					for(NSUInteger j=end; j<stringLength; j++) {
						c = CFStringGetCharacterAtIndex(parserStringRef, j);
						if(c == '\n' || c == '\r') {
							break;
						}
						if(c == '\t' || c == ' ') {
							continue;
						}
						if([(RScriptEditorTextView*)clientView parserContextForPosition:j] != pcExpression) continue;
						if(c == co) {
							goAhead = YES;
							break;
						}
					}
					if(!goAhead) break;
				}
				bracketCounter--;
			}
		}

		if(end < 0 || bracketCounter || end-start < 1) return;

		NSRange foldRange = NSMakeRange(start, end-start);

		if(foldItem) {
			if(![(RScriptEditorTextStorage*)[clientView textStorage] existsFoldedRange:foldRange]) {
				[(RScriptEditorTextView*)clientView foldLinesInRange:foldRange blockMode:NO];
			} else {
				[(RScriptEditorTextView*)clientView unfoldLinesContainingCharacterAtIndex:foldRange.location+1];
			}
			return;
		}
		
		//if user didn't click at a folding marker
		//select balanced bracket range for convenience
		[clientView setSelectedRange:foldRange];

		return;

	}
	dragSelectionStartLine = line;

	if (line != NSNotFound)
	{
		NSUInteger selectionStart, selectionEnd;
		NSArray *lines = [self lineIndices];

		selectionStart = [NSArrayObjectAtIndex(lines, (line - 1)) unsignedIntegerValue];
		if (line < [lines count]) {
			selectionEnd = [NSArrayObjectAtIndex(lines, line) unsignedIntegerValue];
		} else {
			selectionEnd = [[view string] length];
		}
		[view setSelectedRange:NSMakeRange(selectionStart, selectionEnd - selectionStart)];
	}
}

- (void)mouseDragged:(NSEvent *)theEvent
{

	NSUInteger   line, startLine, endLine;
	NSTextView   *view;

	if (![[self clientView] isKindOfClass:[NSTextView class]] || dragSelectionStartLine == NSNotFound) return;
	view = (NSTextView *)[self clientView];

	line = [self lineNumberForLocation:[self convertPoint:[theEvent locationInWindow] fromView:nil].y];

	if (line != NSNotFound)
	{
		NSUInteger selectionStart, selectionEnd;
		NSArray *lines = [self lineIndices];
		if (line >= dragSelectionStartLine) {
			startLine = dragSelectionStartLine;
			endLine = line;
		} else {
			startLine = line;
			endLine = dragSelectionStartLine;
		}

		selectionStart = [NSArrayObjectAtIndex(lines, (startLine - 1)) unsignedIntegerValue];
		if (endLine < [lines count]) {
			selectionEnd = [NSArrayObjectAtIndex(lines, endLine) unsignedIntegerValue];
		} else {
			selectionEnd = [[view string] length];
		}
		[view setSelectedRange:NSMakeRange(selectionStart, selectionEnd - selectionStart)];
	}

	[view autoscroll:theEvent];
}

#pragma mark -

- (id)initWithCoder:(NSCoder *)decoder
{
	if ((self = [super initWithCoder:decoder]) != nil)
	{
		if ([decoder allowsKeyedCoding])
		{
			font = [[decoder decodeObjectForKey:NOODLE_FONT_CODING_KEY] retain];
			textColor = [[decoder decodeObjectForKey:NOODLE_TEXT_COLOR_CODING_KEY] retain];
			// alternateTextColor = [[decoder decodeObjectForKey:NOODLE_ALT_TEXT_COLOR_CODING_KEY] retain];
			// backgroundColor = [[decoder decodeObjectForKey:NOODLE_BACKGROUND_COLOR_CODING_KEY] retain];
		}
		else
		{
			font = [[decoder decodeObject] retain];
			textColor = [[decoder decodeObject] retain];
			// alternateTextColor = [[decoder decodeObject] retain];
			// backgroundColor = [[decoder decodeObject] retain];
		}
	}
	return self;
}

- (void)encodeWithCoder:(NSCoder *)encoder
{
	[super encodeWithCoder:encoder];
	
	if ([encoder allowsKeyedCoding])
	{
		[encoder encodeObject:font forKey:NOODLE_FONT_CODING_KEY];
		[encoder encodeObject:textColor forKey:NOODLE_TEXT_COLOR_CODING_KEY];
		// [encoder encodeObject:alternateTextColor forKey:NOODLE_ALT_TEXT_COLOR_CODING_KEY];
		// [encoder encodeObject:backgroundColor forKey:NOODLE_BACKGROUND_COLOR_CODING_KEY];
	}
	else
	{
		[encoder encodeObject:font];
		[encoder encodeObject:textColor];
		// [encoder encodeObject:alternateTextColor];
		// [encoder encodeObject:backgroundColor];
	}
}

#pragma mark -
#pragma mark PrivateAPI

- (NSArray *)lineIndices
{

	if (lineIndices == nil)
		[self calculateLines];

	return lineIndices;

}

- (void)invalidateLineIndices
{

	if (lineIndices) [lineIndices release], lineIndices = nil;

}

- (void)calculateLines
{

	NSUInteger index, stringLength, lineEnd, contentEnd;
	NSString   *textString;
	CGFloat    newThickness;

	textString   = [clientView string];
	stringLength = [textString length];

	// Switch off line numbering if text larger than 6MB
	// for performance reasons.
	// TODO improve performance maybe via threading
	if(stringLength>3000000)
		return;

	lineIndices = [[NSMutableArray alloc] initWithCapacity:currentNumberOfLines];

	index = 0;

	// Cache loop methods for speed
	IMP rangeOfLineIMP = [textString methodForSelector:rangeOfLineSel];
	addObjectIMP = [lineIndices methodForSelector:addObjectSel];

	do
	{
		(void)(*addObjectIMP)(lineIndices, addObjectSel, (*numberWithUnsignedIntegerIMP)(numberClass, numberWithUnsignedIntegerSel, index));
		(*rangeOfLineIMP)(textString, rangeOfLineSel, NULL, &index, NULL, NSMakeRange(index, 0));
	}
	while (index < stringLength);

	// Check if text ends with a new line.
	(*rangeOfLineIMP)(textString, rangeOfLineSel, NULL, &lineEnd, &contentEnd, NSMakeRange([[lineIndices lastObject] intValue], 0));
	if (contentEnd < lineEnd)
		(void)(*addObjectIMP)(lineIndices, addObjectSel, (*numberWithUnsignedIntegerIMP)(numberClass, numberWithUnsignedIntegerSel, index));

	NSUInteger lineCount = [lineIndices count];
	if(lineCount < 100)
		newThickness = maxWidthOfGlyph2;
	else if(lineCount < 1000)
		newThickness = maxWidthOfGlyph3;
	else if(lineCount < 10000)
		newThickness = maxWidthOfGlyph4;
	else if(lineCount < 100000)
		newThickness = maxWidthOfGlyph5;
	else if(lineCount < 1000000)
		newThickness = maxWidthOfGlyph6;
	else if(lineCount < 10000000)
		newThickness = maxWidthOfGlyph7;
	else if(lineCount < 100000000)
		newThickness = maxWidthOfGlyph8;
	else
		newThickness = 100;

	newThickness += 12.0f;

	currentNumberOfLines = lineCount;

	if (currentRuleThickness != newThickness)
	{

		currentRuleThickness = newThickness;

		// Not a good idea to resize the view during calculations (which can happen during
		// display). Do a delayed perform (using NSInvocation since arg is a float).
		NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:[self methodSignatureForSelector:@selector(setRuleThickness:)]];
		[invocation setSelector:@selector(setRuleThickness:)];
		[invocation setTarget:self];
		[invocation setArgument:&newThickness atIndex:2];

		[invocation performSelector:@selector(invoke) withObject:nil afterDelay:0.0];
	}

}

- (void)updateGutterThicknessConstants
{
	// maxWidthOfGlyph1 = ceil(MAX(DEFAULT_THICKNESS, maxWidthOfGlyph     + RULER_MARGIN2));
	maxWidthOfGlyph2 = ceil(MAX(DEFAULT_THICKNESS, maxWidthOfGlyph * 2 + RULER_MARGIN2));
	maxWidthOfGlyph3 = ceil(MAX(DEFAULT_THICKNESS, maxWidthOfGlyph * 3 + RULER_MARGIN2));
	maxWidthOfGlyph4 = ceil(MAX(DEFAULT_THICKNESS, maxWidthOfGlyph * 4 + RULER_MARGIN2));
	maxWidthOfGlyph5 = ceil(MAX(DEFAULT_THICKNESS, maxWidthOfGlyph * 5 + RULER_MARGIN2));
	maxWidthOfGlyph6 = ceil(MAX(DEFAULT_THICKNESS, maxWidthOfGlyph * 6 + RULER_MARGIN2));
	maxWidthOfGlyph7 = ceil(MAX(DEFAULT_THICKNESS, maxWidthOfGlyph * 7 + RULER_MARGIN2));
	maxWidthOfGlyph8 = ceil(MAX(DEFAULT_THICKNESS, maxWidthOfGlyph * 8 + RULER_MARGIN2));
}

- (void)mouseMoved:(NSEvent*)event
{
	mouseHoveringAtPoint = [self convertPoint:[event locationInWindow] fromView:nil];
	[self setNeedsDisplayInRect:[self visibleRect]];
}

- (void)mouseExited:(NSEvent*)event
{
	mouseHoveringAtPoint = NSMakePoint(-1, -1);
	[self setNeedsDisplayInRect:[self visibleRect]];
}

- (void)scrollWheel:(NSEvent*)event
{
	[clientView scrollWheel:event];
	[self mouseMoved:event];
}

- (void)updateTrackingAreas
{
	[super updateTrackingAreas];
	NSTrackingArea* trackingArea = [[NSTrackingArea alloc] initWithRect:[self visibleRect] options:NSTrackingMouseEnteredAndExited|NSTrackingMouseMoved|NSTrackingActiveInKeyWindow owner:self userInfo:nil];
	[self addTrackingArea:trackingArea];
	[trackingArea release];
	mouseHoveringAtPoint = NSMakePoint(-1,-1);
}

@end
