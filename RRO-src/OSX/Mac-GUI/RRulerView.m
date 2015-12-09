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
 *  Added by Rob Goedman on 2/3/05 based on an example by
 *  Carl Sziebert on Thu May 13 2004
 *  inspired by LineNumbering example authored by Koen van der Drift.
 */

#import "RRulerView.h"
#import "RGUI.h"

@interface RRulerView (PrivateMethods)

- (void)drawEmptyMargin:(NSRect)aRect;
- (void)drawNumbersInMargin:(NSRect)aRect;
- (void)drawOneNumberInMargin:(unsigned) aNumber inRect:(NSRect)r;

@end

@implementation RRulerView

- (id)initWithScrollView:(NSScrollView *)aScrollView orientation:(NSRulerOrientation)orientation showLineNumbers:(BOOL) use textView:(NSTextView *) tv {
	SLog(@"RRulerView.initWithScrollView setting up line No ruler");
    if ((self = [super initWithScrollView: aScrollView orientation: orientation]) )
    {
        myTextView = tv;
        showLineNos = use;

        fontSize = ([[tv font] pointSize] <= 10.0) ? 8.0 : 9.0;
     
		[self updatePreferences];
		[[Preferences sharedPreferences] addDependent:self];
		
        marginAttributes = [[NSMutableDictionary alloc] init];
        [marginAttributes setObject:[NSFont boldSystemFontOfSize: fontSize] forKey: NSFontAttributeName];
        [marginAttributes setObject:[NSColor disabledControlTextColor] forKey: NSForegroundColorAttributeName];
        
        NSMutableParagraphStyle *paragraphStyle = [[NSMutableParagraphStyle alloc] init];
        [paragraphStyle setAlignment: NSRightTextAlignment];
        
        [marginAttributes setObject:paragraphStyle forKey: NSParagraphStyleAttributeName];
            [paragraphStyle release];
		
        NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
        [nc addObserver:self selector:@selector(windowDidUpdate:) name: NSWindowDidUpdateNotification object: myTextView];
    }
	SLog(@" - line No ruler is done");
    return self;
}

- (void)dealloc
{
	[[Preferences sharedPreferences] removeDependent:self];
    [[NSNotificationCenter defaultCenter] removeObserver: self];
    [marginAttributes release];
    [super dealloc];
}

 - (void)windowDidUpdate:(NSNotification *)notification
{
    if (showLineNos && (myTextView == [[[NSDocumentController sharedDocumentController] currentDocument] textView]))
		[self updateView];		
}

- (void)updateView
{
	[self setNeedsDisplay: YES];
}

// Ruler callback to actually draw
- (void)drawHashMarksAndLabelsInRect:(NSRect)aRect
{
	[self drawEmptyMargin: aRect];        
	[self drawNumbersInMargin: aRect];
}

-(void)drawEmptyMargin:(NSRect)aRect
{
    [self setRuleThickness: gutterThickness];
    
    [[NSColor controlHighlightColor] set];
    [NSBezierPath fillRect: aRect]; 
    
    NSPoint top = NSMakePoint(aRect.size.width, [self bounds].size.height);
    NSPoint bottom = NSMakePoint(aRect.size.width, 0);
    
    [[NSColor controlShadowColor] set];
    [NSBezierPath setDefaultLineWidth: 1.0];
    [NSBezierPath strokeLineFromPoint:top toPoint:bottom];
}

-(void)drawNumbersInMargin:(NSRect)aRect
{
    unsigned		index, numberOfLines, numberOfGlyphs, rLineNumber;
    NSRange		lineRange;
    NSLayoutManager	*lm;
    NSRect              docRect, lineRect, numRect;
	BOOL displayNextLineNumber;

    //SLog(@"RRulerView.drawNumbersInMargin: %f:%f %f:%f", aRect.origin.x, aRect.origin.y, aRect.size.width, aRect.size.height);
    docRect = [[self scrollView] documentVisibleRect];
    id textView = [[[NSDocumentController sharedDocumentController] currentDocument] textView];
    
    lm = [textView layoutManager];    
    numberOfGlyphs = [lm numberOfGlyphs];
    
	NSTextStorage *ts = [textView textStorage];
	NSString *s = [ts string];
	unichar c;
	displayNextLineNumber = YES;
    for ( rLineNumber = 1, numberOfLines = 1, index = 0; index < numberOfGlyphs; numberOfLines++ )
    {
        lineRect = [lm lineFragmentRectForGlyphAtIndex:index effectiveRange:&lineRange];
		// This offsets the margin of our rulerView so that it scrolls with the textView properly.
		lineRect = NSOffsetRect(lineRect, -docRect.origin.x, -docRect.origin.y);
		numRect = NSMakeRect(aRect.origin.x, lineRect.origin.y, aRect.size.width, lineRect.size.height);
		index = NSMaxRange( lineRange );
		//SLog(@" - draw rect %f:%f %f:%f", numRect.origin.x, numRect.origin.y, numRect.size.width, numRect.size.height);
		c = [s characterAtIndex:lineRange.location + lineRange.length - 1];
		{
			BOOL drawIt = lineRect.origin.y+lineRect.size.height>=aRect.origin.y && lineRect.origin.y<=aRect.origin.y+aRect.size.height;
			if (displayNextLineNumber) {
				if (drawIt) [self drawOneNumberInMargin: rLineNumber inRect: numRect];
				rLineNumber++;
				if (!(c=='\n')) {
					displayNextLineNumber = NO;	
				} 
			} else {
				if (drawIt) [self drawOneNumberInMargin: 0 inRect: numRect];
				if (c=='\n') {
					displayNextLineNumber = YES;			
				} else {
					displayNextLineNumber = NO;
				}			
			}
		}
    }
    lineRect = [lm extraLineFragmentRect];
	// This offsets the margin of our rulerView so that it scrolls with the textView properly.
    lineRect = NSOffsetRect(lineRect, -docRect.origin.x, -docRect.origin.y);
    numRect = NSMakeRect(aRect.origin.x, lineRect.origin.y, aRect.size.width, lineRect.size.height);
	if (lineRect.origin.y+lineRect.size.height>=aRect.origin.y && lineRect.origin.y<=aRect.origin.y+aRect.size.height)
		[self drawOneNumberInMargin: rLineNumber inRect: numRect];
	//SLog(@" - done drawing numbers");
}

-(void)drawOneNumberInMargin:(unsigned) aNumber inRect:(NSRect)r
{
    NSString    *s;
    NSSize      stringSize;
	
    if (aNumber == 0)
		s = [NSString stringWithFormat:@"."];
	else
		s = [NSString stringWithFormat:@"%d", aNumber, nil];
    stringSize = [s sizeWithAttributes:marginAttributes];
    
    [s drawInRect: NSMakeRect(r.origin.x, r.origin.y + ((r.size.height / 2) - (stringSize.height / 2)), [self ruleThickness] - 2, r.size.height) withAttributes: marginAttributes];
}

- (void) updatePreferences {
	gutterThickness = [[Preferences stringForKey:lineNumberGutterWidthKey withDefault: @"16.0"] floatValue];
}


@end
