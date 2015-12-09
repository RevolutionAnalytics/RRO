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
 *  $Id: RTextView.m 6438 2013-02-06 20:39:41Z urbaneks $
 */


#import "RTextView.h"
#import "HelpManager.h"
#import "RGUI.h"
#import "RegexKitLite.h"
#import "RController.h"
#import "NSTextView_RAdditions.h"
#import "RDocumentWinCtrl.h"
#import "NSString_RAdditions.h"

// linked character attributes
#define kTALinked    @"link"
#define kTAVal       @"x"

// some helper functions for handling rectangles and points
// needed in roundedBezierPathAroundRange:
static inline CGFloat RRectTop(NSRect rectangle) { return rectangle.origin.y; }
static inline CGFloat RRectBottom(NSRect rectangle) { return rectangle.origin.y+rectangle.size.height; }
static inline CGFloat RRectLeft(NSRect rectangle) { return rectangle.origin.x; }
static inline CGFloat RRectRight(NSRect rectangle) { return rectangle.origin.x+rectangle.size.width; }
static inline CGFloat RPointDistance(NSPoint a, NSPoint b) { return sqrtf( (a.x-b.x)*(a.x-b.x) + (a.y-b.y)*(a.y-b.y) ); }
static inline NSPoint RPointOnLine(NSPoint a, NSPoint b, CGFloat t) { return NSMakePoint(a.x*(1.0f-t) + b.x*t, a.y*(1.0f-t) + b.y*t); }

static inline int RPARSERCONTEXTFORPOSITION (RTextView* self, NSUInteger index) 
{
	typedef int (*RPARSERCONTEXTFORPOSITIONMethodPtr)(RTextView*, SEL, NSUInteger);
	static RPARSERCONTEXTFORPOSITIONMethodPtr _RPARSERCONTEXTFORPOSITION;
	if (!_RPARSERCONTEXTFORPOSITION) _RPARSERCONTEXTFORPOSITION = (RPARSERCONTEXTFORPOSITIONMethodPtr)[self methodForSelector:@selector(parserContextForPosition:)];
	int r = _RPARSERCONTEXTFORPOSITION(self, @selector(parserContextForPosition:), index);
	return r;
}


// declared external
BOOL RTextView_autoCloseBrackets = YES;

#if MAC_OS_X_VERSION_MIN_REQUIRED < MAC_OS_X_VERSION_10_7
// declare the following methods to avoid compiler warnings
@interface NSTextView (SuppressWarnings)
- (void)swipeWithEvent:(NSEvent *)event;
- (void)setAutomaticTextReplacementEnabled:(BOOL)flag;
- (void)setAutomaticSpellingCorrectionEnabled:(BOOL)flag;
- (void)setAutomaticDataDetectionEnabled:(BOOL)flag;
- (void)setAutomaticDashSubstitutionEnabled:(BOOL)flag;
@end
#endif

#pragma mark -
#pragma mark Private API

@interface RTextView (Private)

- (void)selectMatchingPairAt:(int)position;
- (NSString*)functionNameForCurrentScope;

@end

#pragma mark -

@implementation RTextView

- (id) initWithCoder: (NSCoder*) coder
{
	self = [super initWithCoder:coder];
	if (self) {
		separatingTokensSet = [[NSCharacterSet characterSetWithCharactersInString: @"()'\"+-=/* ,\t]{}^|&!;<>?`\n\\"] retain];
		undoBreakTokensSet = [[NSCharacterSet characterSetWithCharactersInString: @"+- .,|&*/:!?<>=\n"] retain];
		wordCharSet = [NSMutableCharacterSet alphanumericCharacterSet];
		[wordCharSet addCharactersInString:@"_.\\"];
		[wordCharSet retain];
	}
	return self;
}


- (void)awakeFromNib
{
	SLog(@"RTextView: awakeFromNib %@", self);
	// commentTokensSet    = [[NSCharacterSet characterSetWithCharactersInString: @"#"] retain];
	console = NO;
	RTextView_autoCloseBrackets = YES;
    SLog(@" - delegate: %@", [self delegate]);

	isRdDocument = NO;
	if([[self window] windowController] && [[[self window] windowController] respondsToSelector:@selector(isRdDocument)])
		isRdDocument = ([[[self window] windowController] isRdDocument]);

	// work-arounds for brain-dead "features" in Lion
	if ([self respondsToSelector:@selector(setAutomaticQuoteSubstitutionEnabled:)])
		[self setAutomaticQuoteSubstitutionEnabled:NO];
	if ([self respondsToSelector:@selector(setAutomaticTextReplacementEnabled:)])
		[self setAutomaticTextReplacementEnabled:NO];
	if ([self respondsToSelector:@selector(setAutomaticSpellingCorrectionEnabled:)])
		[self setAutomaticSpellingCorrectionEnabled:NO];
	if ([self respondsToSelector:@selector(setAutomaticLinkDetectionEnabled:)])
		[self setAutomaticLinkDetectionEnabled:NO];
	if ([self respondsToSelector:@selector(setAutomaticDataDetectionEnabled:)])
		[self setAutomaticDataDetectionEnabled:NO];
	if ([self respondsToSelector:@selector(setAutomaticDashSubstitutionEnabled:)])
		[self setAutomaticDashSubstitutionEnabled:NO];

	[self endSnippetSession];

}

- (void)dealloc
{
	if(separatingTokensSet) [separatingTokensSet release];
	if(undoBreakTokensSet) [undoBreakTokensSet release];
	if(wordCharSet) [wordCharSet release];
	// if(commentTokensSet) [commentTokensSet release];
	[super dealloc];
}

- (BOOL)acceptsFirstResponder
{

	// Close sharedColorPanel if visible to avoid color changes
	if([[NSColorPanel sharedColorPanel] isVisible])
		[[NSColorPanel sharedColorPanel] close];

	return YES;

}
- (NSBezierPath*)roundedBezierPathAroundRange:(NSRange)aRange
{

	// This method was modified taken from the open source project "Sequel Pro"
	//   http://www.sequelpro.com
	//
	// which follows the 
	// GNU GENERAL PUBLIC LICENSE
	// http://www.gnu.org/licenses/old-licenses/gpl-2.0.html
	//
	// more details:
	//   http://www.sequelpro.com/legal/
	//   http://www.sequelpro.com/developers/

	// parameters for snippet highlighting
	CGFloat kappa = 0.5522847498f; // magic number from http://www.whizkidtech.redprince.net/bezier/circle/
	CGFloat radius = 6;
	CGFloat horzInset = -3;
	CGFloat vertInset = 0.3f;
	BOOL connectDisconnectedPartsWithLine = NO;

	NSBezierPath *framePath = [NSBezierPath bezierPath];
	NSUInteger rectCount;
	NSRectArray rects = [[self layoutManager] rectArrayForCharacterRange: aRange
											withinSelectedCharacterRange: aRange
														 inTextContainer: [self textContainer]
															   rectCount: &rectCount ];
	if (rectCount>2 || (rectCount>1 && (RRectRight(rects[1]) >= RRectLeft(rects[0]) || connectDisconnectedPartsWithLine))) {
		// highlight complicated multiline snippet
		NSRect lineRects[4];
		lineRects[0] = rects[0];
		lineRects[1] = rects[1];
		lineRects[2] = rects[rectCount-2];
		lineRects[3] = rects[rectCount-1];
		for(int j=0;j<4;j++) lineRects[j] = NSInsetRect(lineRects[j], horzInset, vertInset);
		NSPoint vertices[8];
		vertices[0] = NSMakePoint( RRectLeft(lineRects[0]),  RRectTop(lineRects[0])    ); // point a
		vertices[1] = NSMakePoint( RRectRight(lineRects[0]), RRectTop(lineRects[0])    ); // point b
		vertices[2] = NSMakePoint( RRectRight(lineRects[2]), RRectBottom(lineRects[2]) ); // point c
		vertices[3] = NSMakePoint( RRectRight(lineRects[3]), RRectBottom(lineRects[2]) ); // point d
		vertices[4] = NSMakePoint( RRectRight(lineRects[3]), RRectBottom(lineRects[3]) ); // point e
		vertices[5] = NSMakePoint( RRectLeft(lineRects[3]),  RRectBottom(lineRects[3]) ); // point f
		vertices[6] = NSMakePoint( RRectLeft(lineRects[1]),  RRectTop(lineRects[1])    ); // point g
		vertices[7] = NSMakePoint( RRectLeft(lineRects[0]),  RRectTop(lineRects[1])    ); // point h

		for (NSUInteger j=0; j<8; j++) {
			NSPoint curr = vertices[j];
			NSPoint prev = vertices[(j+8-1)%8];
			NSPoint next = vertices[(j+1)%8];

			CGFloat s = radius/RPointDistance(prev, curr);
			if (s>0.5) s = 0.5f;
			CGFloat t = radius/RPointDistance(curr, next);
			if (t>0.5) t = 0.5f;

			NSPoint a = RPointOnLine(curr, prev, 0.5f);
			NSPoint b = RPointOnLine(curr, prev, s);
			NSPoint c = curr;
			NSPoint d = RPointOnLine(curr, next, t);
			NSPoint e = RPointOnLine(curr, next, 0.5f);

			if (j==0) [framePath moveToPoint:a];
			[framePath lineToPoint: b];
			[framePath curveToPoint:d controlPoint1:RPointOnLine(b, c, kappa) controlPoint2:RPointOnLine(d, c, kappa)];
			[framePath lineToPoint: e];
		}
	} else {
		//highlight disconnected snippet parts (or single line snippet)
		for (NSUInteger j=0; j<rectCount; j++) {
			NSRect rect = rects[j];
			rect = NSInsetRect(rect, horzInset, vertInset);
			[framePath appendBezierPathWithRoundedRect:rect xRadius:radius yRadius:radius];
		}
	}
	return framePath;
}

- (void)drawRect:(NSRect)rect {


	// Draw background only for screen display but not while printing
	if([NSGraphicsContext currentContextDrawingToScreen]) {

		// Draw textview's background since due to the snippet highlighting we're responsible for it.
		NSColor *bgColor = [NSColor clearColor];
		NSColor *frameColor = [NSColor clearColor];
		if([[self delegate] isKindOfClass:[RController class]])
			frameColor = [Preferences unarchivedObjectForKey:selectionColorKey withDefault:[NSColor colorWithCalibratedRed:0.71f green:0.835f blue:1.0f alpha:1.0f]];
		else
			frameColor = [Preferences unarchivedObjectForKey:editorSelectionBackgroundColorKey withDefault:[NSColor colorWithCalibratedRed:0.71f green:0.835f blue:1.0f alpha:1.0f]];
		
		bgColor = [frameColor colorWithAlphaComponent:0.4];

		// Highlight snippets
		if(snippetControlCounter > -1) {
			// Is the caret still inside a snippet
			if([self checkForCaretInsideSnippet]) {
				for(NSInteger i=0; i<snippetControlMax; i++) {
					if(snippetControlArray[i][0] > -1) {
						// choose the colors for the snippet parts
						if(i == currentSnippetIndex) {
							[bgColor setFill];
							[frameColor setStroke];
						} else {
							[bgColor setFill];
							[frameColor setStroke];
						}
						NSBezierPath *snippetPath = [self roundedBezierPathAroundRange: NSMakeRange(snippetControlArray[i][0],snippetControlArray[i][1]) ];
						[snippetPath fill];
						[snippetPath stroke];
					}
				}
			} else {
				[self endSnippetSession];
			}
		}
	}

	[super drawRect:rect];
}

- (void)keyDown:(NSEvent *)theEvent
{

	if(![self isEditable]) {
		[super keyDown:theEvent];
		return;
	}

	NSString *rc = [theEvent charactersIgnoringModifiers];
	NSString *cc = [theEvent characters];
	unsigned int modFlags = [theEvent modifierFlags];
	long allFlags = (NSShiftKeyMask|NSControlKeyMask|NSAlternateKeyMask|NSCommandKeyMask);
	long curFlags = (modFlags & allFlags);

	BOOL hilite = NO;

	SLog(@"RTextView: keyDown: %@ *** \"%@\" %d", theEvent, rc, modFlags);

	if([rc length] && [undoBreakTokensSet characterIsMember:[rc characterAtIndex:0]]) [self breakUndoCoalescing];

	if ([rc isEqual:@"."] && (modFlags&allFlags)==NSControlKeyMask) {
		SLog(@" - send complete: to self");
		[self complete:self];
		return;
	}
	if ([rc isEqual:@"="]) {
		int mf = modFlags&allFlags;
		if ( mf ==NSControlKeyMask) {
			[self breakUndoCoalescing];
			[self insertText:@"<-"];
			return;
		}
		if ( mf == NSAlternateKeyMask ) {
			[self breakUndoCoalescing];
			[self insertText:@"!="];
			return;
		}
	}
	if ([rc isEqual:@"-"] && (modFlags&allFlags)==NSAlternateKeyMask) {
		[self breakUndoCoalescing];
		[self insertText:[NSString stringWithFormat:@"%@<- ", 
			([self selectedRange].location && [[self string] characterAtIndex:[self selectedRange].location-1] != ' ')?@" ":@""]];
		return;
	}
	if ([rc isEqual:@"h"] && (modFlags&allFlags)==NSControlKeyMask) {
		SLog(@" - send showHelpForCurrentFunction to self");
		[self showHelpForCurrentFunction];
		return;
	}
	// Detect if matching bracket should be highlighted
	if(cc && [cc length]==1 && [[[NSUserDefaults standardUserDefaults] objectForKey:showBraceHighlightingKey] isEqualToString:@"YES"]) {
		switch([cc characterAtIndex:0]) {
			case '(':
			case '[':
			case '{':
			case ')':
			case ']':
			case '}':
			hilite = YES;
		}
	}
	if (cc && [cc length]==1 && [[[NSUserDefaults standardUserDefaults] objectForKey:kAutoCloseBrackets] isEqualToString:@"YES"]) {
		unichar ck = [cc characterAtIndex:0];
		NSString *complement = nil;
		NSRange r = [self selectedRange];
		BOOL acCheck = NO;
		switch (ck) {
			case '{':
				complement = @"}";
			case '(':
				if (!complement) complement = @")";
			case '[':
				if (!complement) complement = @"]";
			case '"':
				if (!complement) {
					complement = @"\"";
					acCheck = YES;
					if ([self parserContextForPosition:r.location] != pcExpression) break;
				}
			case '`':
				if (!complement) {
					complement = @"`";
					acCheck = YES;
					if ([self parserContextForPosition:r.location] != pcExpression) break;
				}
			case '\'':
				if (!complement) {
					complement = @"\'";
					acCheck = YES;
					if ([self parserContextForPosition:r.location] != pcExpression) break;
				}

				// Check if something is selected and wrap it into matching pair characters and preserve the selection
				// - in RConsole only if selection is in the last line
				if(((([self isRConsole] && ([[self string] lineRangeForRange:NSMakeRange([[self string] length]-1,0)].location+1 < r.location)) || ![self isRConsole])) 
					&& [self wrapSelectionWithPrefix:[NSString stringWithFormat:@"%c", ck] suffix:complement]) {
					SLog(@"RTextView: selection was wrapped with auto-pairs");
					return;
				}

				// Try to suppress unnecessary auto-pairing
				if( !isRdDocument && [self isCursorAdjacentToAlphanumCharWithInsertionOf:ck] && ![self isNextCharMarkedBy:kTALinked withValue:kTAVal] && ![self selectedRange].length ){ 
					SLog(@"RTextView: suppressed auto-pairing");
					[super keyDown:theEvent];
					if(hilite && [[self delegate] respondsToSelector:@selector(highlightBracesWithShift:andWarn:)])
						[(id)[self delegate] highlightBracesWithShift:-1 andWarn:YES];
					return;
				}

				SLog(@"RTextView: open bracket chracter %c", ck);
				[super keyDown:theEvent];
				{
					r = [self selectedRange];
					if (r.location != NSNotFound) {
						// NSAttributedString *as = [[NSAttributedString alloc] initWithString:complement attributes:
						// [NSDictionary dictionaryWithObject:TAVal forKey:kTALinked]];
						NSTextStorage *ts = [self textStorage];
						// Register the auto-pairing for undo and insert the complement
						[self shouldChangeTextInRange:r replacementString:complement];
						[self replaceCharactersInRange:r withString:complement];
						r.length=1;
						[ts addAttribute:kTALinked value:kTAVal range:r];
						r.length=0;
						[self setSelectedRange:r];
					}
					return;
				}
			case '}':
			case ')':
			case ']':
				acCheck = YES;
		}

		if (acCheck) {
			NSRange r = [self selectedRange];
			if (r.location != NSNotFound && r.length == 0) {
				NSTextStorage *ts = [self textStorage];
				id attr = nil;
				@try {
					attr = [ts attribute:kTALinked atIndex:r.location effectiveRange:0];
				}
				@catch (id ue) {}
				if (attr) {
					unsigned int cuc = [[ts string] characterAtIndex:r.location];
					SLog(@"RTextView: encountered linked character '%c', while writing '%c'", cuc, ck);
					if (cuc == ck) {
						r.length = 1;
						SLog(@"RTextView: selecting linked character for removal on type");
						[self setSelectedRange:r];
					}
				}
			}
			SLog(@"RTextView: closing bracket chracter %c", ck);
		}
	}

	// Check for {SHIFT}TAB to try to insert snippet via TAB trigger
	// or if snippet mode select next/prev snippet
	if ([theEvent keyCode] == 48 && [self isEditable]){

		NSRange targetRange = [self getRangeForCurrentWord];
		NSString *tabTrigger = [[self string] substringWithRange:targetRange];

		// Is TAB trigger active change selection according to {SHIFT}TAB
		if(snippetControlCounter > -1){

			if(curFlags==(NSShiftKeyMask)) { // select previous snippet

				currentSnippetIndex--;

				// Look for previous defined snippet since snippet numbers must not serial like 1, 5, and 12 e.g.
				while(snippetControlArray[currentSnippetIndex][0] == -1 && currentSnippetIndex > -2)
					currentSnippetIndex--;

				if(currentSnippetIndex < 0) {
					currentSnippetIndex = 0;
					while(snippetControlArray[currentSnippetIndex][0] == -1 && currentSnippetIndex < 20)
						currentSnippetIndex++;
					NSBeep();
				}

				[self selectCurrentSnippet];
				return;

			} else { // select next snippet

				currentSnippetIndex++;

				// Look for next defined snippet since snippet numbers must not serial like 1, 5, and 12 e.g.
				while(snippetControlArray[currentSnippetIndex][0] == -1 && currentSnippetIndex < 20)
					currentSnippetIndex++;

				if(currentSnippetIndex > snippetControlMax) { // for safety reasons
					[self endSnippetSession];
				} else {
					[self selectCurrentSnippet];
					return;
				}
			}

			[self endSnippetSession];
			return;

		}

		// Check if tab trigger is defined; if so insert it, otherwise pass through event
		if(snippetControlCounter < 0 && [tabTrigger length]) {
			// TODO will come soon [HJBB]
			[super keyDown:theEvent];
			return;
		}

	}


	[super keyDown:theEvent];

	if(hilite && [[self delegate] respondsToSelector:@selector(highlightBracesWithShift:andWarn:)])
		[(id)[self delegate] highlightBracesWithShift:-1 andWarn:YES];
}

- (void)deleteBackward:(id)sender
{

	NSRange r = [self selectedRange];
	if (r.length == 0 && r.location > 0)
		[self selectMatchingPairAt:r.location];

	[super deleteBackward:sender];

}

- (void)deleteForward:(id)sender
{

	NSRange r = [self selectedRange];
	if (r.length == 0)
		[self selectMatchingPairAt:r.location + 1];

	[super deleteForward:sender];

}

/**
 * If the textview has a selection, wrap it with the supplied prefix and suffix strings;
 * return whether or not any wrap was performed.
 */
- (BOOL) wrapSelectionWithPrefix:(NSString *)prefix suffix:(NSString *)suffix
{

	NSRange currentRange = [self selectedRange];

	// Only proceed if a selection is active
	if (currentRange.length == 0 || ![self isEditable])
		return NO;

	NSString *selString = [[self string] substringWithRange:currentRange];

	// Replace the current selection with the selected string wrapped in prefix and suffix
	[self insertText:[NSString stringWithFormat:@"%@%@%@", prefix, selString, suffix]];
	
	// Re-select original selection
	NSRange innerSelectionRange = NSMakeRange(currentRange.location+1, [selString length]);
	[self setSelectedRange:innerSelectionRange];

	// Mark last autopair character as autopair-linked
	[[self textStorage] addAttribute:kTALinked value:kTAVal range:NSMakeRange(NSMaxRange(innerSelectionRange), 1)];

	return YES;
}

/**
 * Returns the parser context for the passed cursor position
 *
 * @param position The cursor position to test
 */
- (int)parserContextForPosition:(int)position
{

	int context = pcExpression;

	if (position < 1)
		return context;

	CFStringRef string = (CFStringRef)[self string];
	if (position > [[self string] length])
		position = [[self string] length];


	// NSRange thisLine = [string lineRangeForRange:NSMakeRange(position, 0)];

	CFIndex lineStart;

	CFStringGetLineBounds(string, CFRangeMake(position, 0), &lineStart, NULL, NULL);

	// we do NOT support multi-line strings, so the line always starts as an expression
	if (lineStart == position)
		return context;

	SLog(@"RTextView: parserContextForPosition: %d, line start: %ld", position, lineStart);

	int i = lineStart;
	BOOL skip = NO;
	unichar c;
	unichar commentSign = (isRdDocument) ? '%' : '#';
	
	while (i < position) {
		c = CFStringGetCharacterAtIndex(string, i);
		if (skip) {
			skip = NO;
		} else {
			if (c == '\\' && (context < pcComment)) {
				skip = YES;
			}
			else if (c == '"') {
				if (context == pcStringDQ)
					context = pcExpression;
				else if (context == pcExpression)
					context = pcStringDQ;
			}
			else if (c == '\'') {
				if (context == pcStringSQ)
					context = pcExpression;
				else if (context == pcExpression)
					context = pcStringSQ;
			}
			else if (c == '`') {
				if (context == pcStringBQ)
					context = pcExpression;
				else if (context == pcExpression)
					context = pcStringBQ;
			}
			else if(context == pcExpression) {
				if(c == commentSign)
					context = pcComment;
			}

		}
		i++;
	}

	return context;

}

/**
 * Returns the range for user completion
 */
- (NSRange)rangeForUserCompletion
{

	NSRange userRange = NSMakeRange(NSNotFound, 0);
	NSRange selection = [self selectedRange];
	NSString *string  = [self string];
	int cursor = NSMaxRange(selection); // we complete at the end of the selection
	int context = [self parserContextForPosition:cursor];

	SLog(@"RTextView: rangeForUserCompletion: parser context: %d", context);

	if (context == pcComment) return NSMakeRange(NSNotFound,0); // no completion in comments

	if (context == pcStringDQ || context == pcStringSQ) // we're in a string, hence file completion
														// the beginning of the range doesn't matter, because we're guaranteed to find a string separator on the same line
		userRange = [string rangeOfCharacterFromSet:[NSCharacterSet characterSetWithCharactersInString:(context == pcStringDQ) ? @"\" /" : @"' /"]
											options:NSBackwardsSearch|NSLiteralSearch
											  range:NSMakeRange(0, selection.location)];

	if (context == pcExpression || context == pcStringBQ) // we're in an expression or back-quote, so use R separating tokens (we could be smarter about the BQ but well..)
		userRange = [string rangeOfCharacterFromSet:separatingTokensSet
											options:NSBackwardsSearch|NSLiteralSearch
											  range:NSMakeRange(0, selection.location)];

	if( userRange.location == NSNotFound )
		// everything is one expression - we're guaranteed to be in the first line (because \n would match)
		return NSMakeRange(0, cursor);

	if( userRange.length < 1 ) // nothing to complete
		return NSMakeRange(NSNotFound, 0);

	if( userRange.location == selection.location - 1 ) { // just before cursor means empty completion
		userRange.location++;
		userRange.length = 0;
	} else { // normal completion
		userRange.location++; // skip past first bad one
		userRange.length = selection.location - userRange.location;
		SLog(@" - returned range: %ld:%ld", userRange.location, userRange.length);

		// FIXME: do we really need to change it? Cocoa should be doing it .. (and does in Lion)
		if (os_version < 11.0)
			[self setSelectedRange:userRange];
	}

	return userRange;

}

/**
 * Checks if the char after the current caret position/selection matches a supplied attribute
 */
- (BOOL) isNextCharMarkedBy:(id)attribute withValue:(id)aValue
{
	NSUInteger caretPosition = [self selectedRange].location;

	// Perform bounds checking
	if (caretPosition >= [[self string] length]) return NO;
	
	// Perform the check
	if ([[[self textStorage] attribute:attribute atIndex:caretPosition effectiveRange:nil] isEqualToString:aValue])
		return YES;

	return NO;
}

/**
 * Checks if the caret adjoins to an alphanumeric char  |word or word| or wo|rd
 * Exception for word| and char is a “(” or “[” to allow e.g. auto-pairing () for functions
 */
- (BOOL) isCursorAdjacentToAlphanumCharWithInsertionOf:(unichar)aChar
{
	NSUInteger caretPosition = [self selectedRange].location;
	NSCharacterSet *alphanum = [NSCharacterSet alphanumericCharacterSet];
	BOOL leftIsAlphanum = NO;
	BOOL rightIsAlphanum = NO;
	BOOL charIsOpenBracket = (aChar == '(' || aChar == '[');
	NSUInteger bufferLength = [[self string] length];

	if(!bufferLength) return NO;
	
	// Check previous/next character for being alphanum
	// @try block for bounds checking
	@try
	{
		if(caretPosition==0)
			leftIsAlphanum = NO;
		else
			leftIsAlphanum = [alphanum characterIsMember:[[self string] characterAtIndex:caretPosition-1]] && !charIsOpenBracket;
	} @catch(id ae) { }
	@try {
		if(caretPosition >= bufferLength)
			rightIsAlphanum = NO;
		else
			rightIsAlphanum= [alphanum characterIsMember:[[self string] characterAtIndex:caretPosition]];
		
	} @catch(id ae) { }

	return (leftIsAlphanum ^ rightIsAlphanum || (leftIsAlphanum && rightIsAlphanum));
}

/**
 * Sets the console mode
 *
 * @param isConsole If self is in console mode (YES) or not (NO)
 */
- (void)setConsoleMode:(BOOL)isConsole
{
	console = isConsole;
	SLog(@"RTextView: set console flag to %@ (%@)", isConsole?@"yes":@"no", self);
}

/**
 * Shows the Help page for the current function relative to the current cursor position or
 * if something is selected for the selection in the HelpManager
 *
 * Notes:
 *  - if the cursor is in between or adjacent to an alphanumeric word take this one if it not a pure numeric value
 *  - if nothing found try to parse backwards from cursor position to find the active function name according to opened and closed parentheses
 *      examples | := cursor
 *        a(b(1,2|,3)) -> b
 *        a(b(1,2,3)|) -> a
 * - if nothing found set the input focus to the Help search field either in RConsole or in R script editor
 */
- (void) showHelpForCurrentFunction
{

	NSString *helpString = [self functionNameForCurrentScope];

	if(helpString && [helpString length]) {
		int oldSearchType = [[HelpManager sharedController] searchType];
		[[HelpManager sharedController] setSearchType:kExactMatch];
		[[HelpManager sharedController] showHelpFor:helpString];
		[[HelpManager sharedController] setSearchType:oldSearchType];
		return;
	}

	id aSearchField = nil;

	NSWindow *keyWin = [NSApp keyWindow];

	if(![[keyWin toolbar] isVisible])
		[keyWin toggleToolbarShown:nil];

	if([[self delegate] respondsToSelector:@selector(searchToolbarView)])
		aSearchField = [(id)[self delegate] searchToolbarView];

	if(aSearchField == nil || ![aSearchField isKindOfClass:[NSSearchField class]]) return;

	[aSearchField setStringValue:[[self string] substringWithRange:[self getRangeForCurrentWord]]];

	if([[aSearchField stringValue] length])
		[[HelpManager sharedController] showHelpFor:[aSearchField stringValue]];
	else
		[[NSApp keyWindow] makeFirstResponder:aSearchField];

}


- (void)currentFunctionHint
{

	NSString *helpString = [self functionNameForCurrentScope];

	if(helpString && ![helpString isMatchedByRegex:@"(?s)[\\s\\[\\]\\(\\)\\{\\};\\?!]"] && [[self delegate] respondsToSelector:@selector(hintForFunction:)]) {
		SLog(@"RTextView: currentFunctionHint for '%@'", helpString);
		[(RController*)[self delegate] hintForFunction:helpString];
	}

}

/**
 * Shifts the selection, if any, rightwards by indenting any selected lines with one tab.
 * If the caret is within a line, the selection is not changed after the index; if the selection
 * has length, all lines crossed by the length are indented and fully selected.
 * Returns whether or not an indentation was performed.
 */
- (BOOL) shiftSelectionRight
{
	NSString *textViewString = [[self textStorage] string];
	NSRange currentLineRange;
	NSRange selectedRange = [self selectedRange];

	if (selectedRange.location == NSNotFound || ![self isEditable]) return NO;

	NSString *indentString = @"\t";
	// if ([prefs soft]) {
	// 	NSUInteger numberOfSpaces = [prefs soft width];
	// 	if(numberOfSpaces < 1) numberOfSpaces = 1;
	// 	if(numberOfSpaces > 32) numberOfSpaces = 32;
	// 	NSMutableString *spaces = [NSMutableString string];
	// 	for(NSUInteger i = 0; i < numberOfSpaces; i++)
	// 		[spaces appendString:@" "];
	// 	indentString = [NSString stringWithString:spaces];
	// }

	// Indent the currently selected line if the caret is within a single line
	if (selectedRange.length == 0) {

		// Extract the current line range based on the text caret
		currentLineRange = [textViewString lineRangeForRange:selectedRange];

		// Register the indent for undo
		[self shouldChangeTextInRange:NSMakeRange(currentLineRange.location, 0) replacementString:indentString];

		// Insert the new tab
		[self replaceCharactersInRange:NSMakeRange(currentLineRange.location, 0) withString:indentString];

		return YES;
	}

	// Otherwise, something is selected
	NSRange firstLineRange = [textViewString lineRangeForRange:NSMakeRange(selectedRange.location,0)];
	NSUInteger lastLineMaxRange = NSMaxRange([textViewString lineRangeForRange:NSMakeRange(NSMaxRange(selectedRange)-1,0)]);
	
	// Expand selection for first and last line to begin and end resp. but not the last line ending
	NSRange blockRange = NSMakeRange(firstLineRange.location, lastLineMaxRange - firstLineRange.location);
	if([textViewString characterAtIndex:NSMaxRange(blockRange)-1] == '\n' || [textViewString characterAtIndex:NSMaxRange(blockRange)-1] == '\r')
		blockRange.length--;

	// Replace \n by \n\t of all lines in blockRange
	NSString *newString;
	// check for line ending
	if([textViewString characterAtIndex:NSMaxRange(firstLineRange)-1] == '\r')
		newString = [indentString stringByAppendingString:
			[[textViewString substringWithRange:blockRange] 
				stringByReplacingOccurrencesOfString:@"\r" withString:[NSString stringWithFormat:@"\r%@", indentString]]];
	else
		newString = [indentString stringByAppendingString:
			[[textViewString substringWithRange:blockRange] 
				stringByReplacingOccurrencesOfString:@"\n" withString:[NSString stringWithFormat:@"\n%@", indentString]]];


	// Do insertion via insertText in order to ensure proper layouting
	[self setSelectedRange:blockRange];
	[self insertText:newString];
	[self setSelectedRange:NSMakeRange(blockRange.location, [newString length])];

	if(blockRange.length == [newString length])
		return NO;
	else
		return YES;

}


/**
 * Shifts the selection, if any, leftwards by un-indenting any selected lines by one tab if possible.
 * If the caret is within a line, the selection is not changed after the undent; if the selection has
 * length, all lines crossed by the length are un-indented and fully selected.
 * Returns whether or not an indentation was performed.
 */
- (BOOL) shiftSelectionLeft
{
	NSString *textViewString = [[self textStorage] string];
	NSRange currentLineRange;

	if ([self selectedRange].location == NSNotFound || ![self isEditable]) return NO;

	// Undent the currently selected line if the caret is within a single line
	if ([self selectedRange].length == 0) {

		// Extract the current line range based on the text caret
		currentLineRange = [textViewString lineRangeForRange:[self selectedRange]];

		// Ensure that the line has length and that the first character is a tab
		if (currentLineRange.length < 1
			|| ([textViewString characterAtIndex:currentLineRange.location] != '\t' && [textViewString characterAtIndex:currentLineRange.location] != ' '))
			return NO;

		NSRange replaceRange;

		// Check for soft indention
		NSUInteger indentStringLength = 1;
		// if ([prefs soft]) {
		// 	NSUInteger numberOfSpaces = [prefs soft width];
		// 	if(numberOfSpaces < 1) numberOfSpaces = 1;
		// 	if(numberOfSpaces > 32) numberOfSpaces = 32;
		// 	indentStringLength = numberOfSpaces;
		// 	replaceRange = NSIntersectionRange(NSMakeRange(currentLineRange.location, indentStringLength), NSMakeRange(0,[[self string] length]));
		// 	// Correct length for only white spaces
		// 	NSString *possibleIndentString = [[[self textStorage] string] substringWithRange:replaceRange];
		// 	NSUInteger numberOfLeadingWhiteSpaces = [possibleIndentString rangeOfRegex:@"^(\\s*)" capture:1L].length;
		// 	if(numberOfLeadingWhiteSpaces == NSNotFound) numberOfLeadingWhiteSpaces = 0;
		// 	replaceRange = NSMakeRange(currentLineRange.location, numberOfLeadingWhiteSpaces);
		// } else {
			replaceRange = NSMakeRange(currentLineRange.location, indentStringLength);
		// }

		// Register the undent for undo
		[self shouldChangeTextInRange:replaceRange replacementString:@""];

		// Remove the tab
		[self replaceCharactersInRange:replaceRange withString:@""];

		return YES;
	}

	// Otherwise, something is selected
	NSRange firstLineRange = [textViewString lineRangeForRange:NSMakeRange([self selectedRange].location,0)];
	NSUInteger lastLineMaxRange = NSMaxRange([textViewString lineRangeForRange:NSMakeRange(NSMaxRange([self selectedRange])-1,0)]);
	
	// Expand selection for first and last line to begin and end resp. but the last line ending
	NSRange blockRange = NSMakeRange(firstLineRange.location, lastLineMaxRange - firstLineRange.location);
	if([textViewString characterAtIndex:NSMaxRange(blockRange)-1] == '\n' || [textViewString characterAtIndex:NSMaxRange(blockRange)-1] == '\r')
		blockRange.length--;

	// Check for soft or hard indention
	NSString *indentString = @"\t";
	NSUInteger indentStringLength = 1;
	// if ([prefs soft]) {
	// 	indentStringLength = [prefs soft width];
	// 	if(indentStringLength < 1) indentStringLength = 1;
	// 	if(indentStringLength > 32) indentStringLength = 32;
	// 	NSMutableString *spaces = [NSMutableString string];
	// 	for(NSUInteger i = 0; i < indentStringLength; i++)
	// 		[spaces appendString:@" "];
	// 	indentString = [NSString stringWithString:spaces];
	// }

	// Check if blockRange starts with SPACE or TAB
	// (this also catches the first line of the entire text buffer or
	// if only one line is selected)
	NSInteger leading = 0;
	if([textViewString characterAtIndex:blockRange.location] == ' ' 
		|| [textViewString characterAtIndex:blockRange.location] == '\t')
		leading += indentStringLength;

	// Replace \n[ \t] by \n of all lines in blockRange
	NSString *newString;
	// check for line ending
	if([textViewString characterAtIndex:NSMaxRange(firstLineRange)-1] == '\r')
		newString = [[textViewString substringWithRange:NSMakeRange(blockRange.location+leading, blockRange.length-leading)] 
			stringByReplacingOccurrencesOfString:[NSString stringWithFormat:@"\r%@", indentString] withString:@"\r"];
	else
		newString = [[textViewString substringWithRange:NSMakeRange(blockRange.location+leading, blockRange.length-leading)] 
		stringByReplacingOccurrencesOfString:[NSString stringWithFormat:@"\n%@", indentString] withString:@"\n"];
	
	// Do insertion via insertText in order to ensure proper layouting
	[self setSelectedRange:blockRange];
	[self insertText:newString];
	[self setSelectedRange:NSMakeRange(blockRange.location, [newString length])];

	if(blockRange.length == [newString length])
		return NO;
	else
		return YES;
}

#pragma mark -

/**
 * Selects matching pairs if the character before position and at position are linked
 *
 * @param position The cursor position to test
 */
- (void)selectMatchingPairAt:(int)position
{

	if(position < 1 || position >= [[self string] length])
		return;

	unichar c = [[self string] characterAtIndex:position - 1];
	unichar cc = 0;
	switch (c) {
		case '(': cc=')'; break;
		case '{': cc='}'; break;
		case '[': cc=']'; break;
		case '"':
		case '`':
		case '\'':
			cc=c; break;
	}
	if (cc) {
		unichar cs = [[self string] characterAtIndex:position];
		if (cs == cc) {
			id attr = [[self textStorage] attribute:kTALinked atIndex:position effectiveRange:0];
			if (attr) {
				[self setSelectedRange:NSMakeRange(position - 1, 2)];
				SLog(@"RTextView: selected matching pair");
			}
		}
	}

}

- (NSString*)functionNameForCurrentScope
{

	NSString *helpString;
	NSString *parseString = [self string];
	NSRange  selectedRange = [self selectedRange];
	NSRange parseRange = NSMakeRange(0, [parseString length]);
	NSInteger breakCounter = 1000;

	int parentheses = 0;
	int index       = 0;

	SLog(@"RTextView: functionNameForCurrentScope");

	// if user selected something take the selection only; otherwise take the current word
	if (selectedRange.length) {
		helpString = [parseString substringWithRange:selectedRange];
		SLog(@" - return selection");
		return helpString;
	} else {
		helpString = [parseString substringWithRange:[self getRangeForCurrentWord]];
	}

	SLog(@" - current word “%@”", helpString);

	// if a word was found and the word doesn't represent a numeric value
	// and a ( follows then return word
	if([helpString length] && ![[[NSNumber numberWithFloat:[helpString floatValue]] stringValue] isEqualToString:helpString]) {
		int start = NSMaxRange(selectedRange);
		if(start < [parseString length]) {
			BOOL found = NO;
			int i = 0;
			int end = ([parseString length] > 100) ? 100 : [parseString length];
			unichar c;
			for(i = start; i < end; i++) {
                if ((c = CFStringGetCharacterAtIndex((CFStringRef)parseString, i)) == '(') {
					found = YES;
					break;
				}
				if (c != ' ' || c != '\t' || c != '\n' || c != '\r') break;
			}
			if(found) {
				SLog(@" - caret was inside function name; return it");
				return helpString;
			}
		}
	}

	SLog(@" - invalid current word -> start parsing for current function scope");

	// if we're in the RConsole don't parse beyond committedLength
	//  we have to check class since it runs in its own thread (but not sure - if one uses
	//  [self isRConsole] it doesn't work)
	if([[self delegate] isKindOfClass:[RController class]] & ([[RController sharedController] lastCommittedLength] <= selectedRange.location)) {
		parseRange = NSMakeRange([(id)[self delegate] lastCommittedLength],
				[parseString length]-[(id)[self delegate] lastCommittedLength]);
	}

	// sanety check; if it fails bail
	if(selectedRange.location - parseRange.location <= 0) {
		SLog(@" - parse range invalid - bail");
		return nil;
	}

	// set the to be parsed range
	parseRange.length =  selectedRange.location - parseRange.location;

	// go back according opened/closed parentheses
	BOOL opened, closed;
	BOOL found = NO;

	for(index = NSMaxRange(parseRange) - 1; index > parseRange.location; index--) {
		if(!breakCounter--) return nil;
		unichar c = CFStringGetCharacterAtIndex((CFStringRef)parseString, index);
		closed = (c == ')');
		opened = (c == '(');
		// Check if we're not inside of quotes or comments
		if( ( closed || opened)
			&& (index > parseRange.location)
			&& [self parserContextForPosition:(index)] != pcExpression) {
			continue;
		}
		if(closed) parentheses--;
		if(opened) parentheses++;
		if(parentheses > 0) {
			found = YES;
			break;
		}
	}

	if(!found) {
		SLog(@" - parsing unsuccessfull; bail");
		return nil;
	}

	SLog(@" - first not closed ( found at index: %d", index);

	// check if we still are in the parse range; otherwise bail
	if(parseRange.location > index) {
		SLog(@" - found index invalid - bail");
		return nil;
	}

	// check if char in front of ( is not a white space; if so go back
	if(index > 0) {
		breakCounter = 1000;
		while(index > 0 && index >= parseRange.location) {
			if(!breakCounter--) return nil;
			unichar c = CFStringGetCharacterAtIndex((CFStringRef)parseString, --index);
			if(c == ' ' || c == '\t' || c == '\n' || c == '\r') {
				;
			} else {
				break;
			}
		}
	}

	SLog(@" - function name found at index: %d", index);

	// check if we still are in the parse range; otherwise bail
	if(parseRange.location > index) {
		SLog(@" - found index invalid - bail");
		return nil;
	}

	// get the adjacent word according
	helpString = [parseString substringWithRange:[self getRangeForCurrentWordOfRange:NSMakeRange(index, 0)]];

	SLog(@" - found function name: “%@”", helpString);
	// if a word was found and the word doesn't represent a numeric value return it
	if([helpString length] && ![[[NSNumber numberWithFloat:[helpString floatValue]] stringValue] isEqualToString:helpString]) {
		SLog(@" - return found function name");
		return helpString;
	}

	SLog(@" - found function name wasn't valid, i.e. empty or represents a numeric value; return nil");
	return nil;

}

- (BOOL) isRConsole
{
	return ([self delegate] && [[self delegate] isKindOfClass:[RController class]]);
}

- (IBAction)makeASCIIconform:(id)sender
{

	
	NSString *strToConvert = nil;
	NSRange replaceRange;
	if([self selectedRange].length)
		replaceRange = [self selectedRange];
	else if([self getRangeForCurrentWord].length)
		replaceRange = [self getRangeForCurrentWord];
	else
		return;

	// for Rconsole only allow non-committed strings
	if([self isRConsole] & ([[RController sharedController] lastCommittedLength] > replaceRange.location)) {
		NSUInteger cl = [[RController sharedController] lastCommittedLength];
		if(NSMaxRange(replaceRange) < cl) {
			NSBeep();
			return;
		}
		replaceRange = NSMakeRange(cl, NSMaxRange(replaceRange) - cl);
	}

	strToConvert = [[self string] substringWithRange:replaceRange];

	NSMutableString *theEncodedString = [NSMutableString stringWithString:@""];
	unichar c;
	NSInteger theCharIndex;
	NSInteger theCharIndexInTextView = replaceRange.location;
	for (theCharIndex=0; theCharIndex<[strToConvert length]; theCharIndex++, theCharIndexInTextView++) {

		c = CFStringGetCharacterAtIndex((CFStringRef)strToConvert, theCharIndex);
		// if c is non-ASCII and inside of "" or '' quotes transform it
		//  - this ignores all c inside of comments
		if (c > 127 && RPARSERCONTEXTFORPOSITION((RTextView*)self, theCharIndexInTextView) < pcStringBQ)
			[theEncodedString appendFormat: @"\\u%04x", c];
		else
			[theEncodedString appendFormat: @"%C", c];

	}

	// register for undo
	[self shouldChangeTextInRange:replaceRange replacementString:theEncodedString];
	[self replaceCharactersInRange:replaceRange withString:theEncodedString];

}

- (IBAction)unescapeUnicode:(id)sender
{

	NSRange replaceRange;
	if([self selectedRange].length)
		replaceRange = [self selectedRange];
	else if([self getRangeForCurrentWord].length)
		replaceRange = [self getRangeForCurrentWord];
	else
		return;

	// for Rconsole only allow non-committed strings
	if([self isRConsole] & ([[RController sharedController] lastCommittedLength] > replaceRange.location)) {
		NSUInteger cl = [[RController sharedController] lastCommittedLength];
		if(NSMaxRange(replaceRange) < cl) {
			NSBeep();
			return;
		}
		replaceRange = NSMakeRange(cl, NSMaxRange(replaceRange) - cl);
	}

	NSMutableString *strToConvert = [NSMutableString stringWithString:[[self string] substringWithRange:replaceRange]];

	NSString *re = @"(\\\\[uU]([0-9a-fA-F]{1,4}))";
	NSRange searchRange = NSMakeRange(0, [strToConvert length]);
	while([strToConvert isMatchedByRegex:re inRange:searchRange]) {
		[strToConvert flushCachedRegexData];
		NSRange replaceRange = [strToConvert rangeOfRegex:re capture:0L];
		NSRange escSeqRange  = [strToConvert rangeOfRegex:re capture:2L];
		[strToConvert replaceCharactersInRange:replaceRange withString:
			[NSString stringWithFormat:@"%C", (unichar) strtol([[strToConvert substringWithRange:escSeqRange] UTF8String], NULL, 16)]];
		[strToConvert flushCachedRegexData];
		searchRange = NSMakeRange(replaceRange.location, [strToConvert length]-replaceRange.location);
	}

	[self shouldChangeTextInRange:replaceRange replacementString:strToConvert];
	[self replaceCharactersInRange:replaceRange withString:strToConvert];

}

- (BOOL)validateMenuItem:(NSMenuItem *)menuItem
{

	if ([menuItem action] == @selector(undo:))
		return ([[self undoManager] canUndo]);

	if ([menuItem action] == @selector(redo:))
		return ([[self undoManager] canRedo]);

	if ([menuItem action] == @selector(makeASCIIconform:))
		return ([self selectedRange].length || (([(RTextView*)self getRangeForCurrentWord].length) && RPARSERCONTEXTFORPOSITION((RTextView*)self, [self selectedRange].location) < pcStringBQ)) ? YES : NO;

	if ([menuItem action] == @selector(unescapeUnicode:))
		return ([self selectedRange].length || ([(RTextView*)self getRangeForCurrentWord].length)) ? YES : NO;

	return YES;

}

#pragma mark -

- (void)changeFont:(id)sender
{

	NSFont *font= [[NSFontPanel sharedFontPanel] panelConvertFont:
			[NSUnarchiver unarchiveObjectWithData:
				[[NSUserDefaults standardUserDefaults] dataForKey:[self isRConsole] ? RConsoleDefaultFont : RScriptEditorDefaultFont]]];

	if(!font) return;

	// If user selected something change the selection's font only
	if(![self isRConsole] & ([[[[self window] windowController] document] isRTF] || [self selectedRange].length)) {
		// register font change for undo
		NSRange r = [self selectedRange];
		[self shouldChangeTextInRange:r replacementString:[[self string] substringWithRange:r]];
		[[self textStorage] addAttribute:NSFontAttributeName value:font range:r];
		[self setAllowsUndo:NO];
		[self setSelectedRange:NSMakeRange(r.location, 0)];
		[self insertText:@""];
		[self setSelectedRange:r];
		[self setAllowsUndo:YES];
		[self setNeedsDisplay:YES];
	// otherwise update view and save new font in Preferences
	} else {
		[[RController sharedController] fontSizeChangedBy:0.0f withSender:nil];
	}

}

#pragma mark -
#pragma mark drag&drop

- (BOOL)performDragOperation:(id <NSDraggingInfo>)sender
{

	NSPasteboard *pboard = [sender draggingPasteboard];

	// textClip stuff handles the system
	if ( [[pboard types] containsObject:NSFilenamesPboardType] 
		&& [[pboard types] containsObject:@"CorePasteboardFlavorType 0x54455854"])
		return [super performDragOperation:sender];

	// if a file path is dragged check for R or Rdata files or if user has set a template
	// passed via the file extension
	if ( [[pboard types] containsObject:NSFilenamesPboardType] ) {

		NSArray *files = [pboard propertyListForType:NSFilenamesPboardType];

		NSInteger i = 0;
		NSInteger snip_cnt = 0;
		NSString *suffix = ([files count] > 1) ? @"\n" : @"";

		NSString *curDir = @"";
		// Get current directory of source document's file path
		if([[[[self window] windowController] document] retain]) {
			NSString *path = [[[[[self window] windowController] document] fileURL] path];
			curDir = [path stringByReplacingOccurrencesOfRegex:[NSString stringWithFormat:@"%@$", [path lastPathComponent]] withString:@""];
		// otherwise take the current working directory
		} else
			curDir = [[[RController sharedController] currentWorkingDirectory] stringByAppendingString:@"/"];

		NSString *appSupportPath = [[RController sharedController] getAppSupportPath];
		NSError *anError = nil;
		NSFileManager *fm = [NSFileManager defaultManager];
		NSString *userDragActionDir = (appSupportPath) ? [NSString stringWithFormat:@"%@/%@/", appSupportPath, kDragActionFolderName] : nil;

		NSMutableDictionary *env = [NSMutableDictionary dictionary];
		NSDictionary *cdic = [self getCurrentEnvironment];
		if(cdic) [env setDictionary:cdic];

		// Set the new insertion point
		NSPoint draggingLocation = [sender draggingLocation];
		draggingLocation = [self convertPoint:draggingLocation fromView:nil];
		NSUInteger characterIndex = [self characterIndexOfPoint:draggingLocation];
		if([[self delegate] isKindOfClass:[RController class]])
			if(characterIndex < [(id)[self delegate] lastCommittedLength])
				characterIndex = [(id)[self delegate] lastCommittedLength];
		[self setSelectedRange:NSMakeRange(characterIndex,0)];

		NSMutableString *insertionString = [NSMutableString string];
		[insertionString setString:@""];

		for(i = 0; i < [files count]; i++) {

			snip_cnt++;
			if(snip_cnt>19) snip_cnt=19;

			NSString *filepath = [[pboard propertyListForType:NSFilenamesPboardType] objectAtIndex:i];

			// Check if user pressed ALT while dragging for inserting relative file path
			if([sender draggingSourceOperationMask] == 1)
			{
				[insertionString appendString:
					[[[filepath stringByReplacingOccurrencesOfRegex:
						[NSString stringWithFormat:@"^%@", curDir] withString:@""] stringByAbbreviatingWithTildeInPath] 
							stringByAppendingString:(i < ([files count]-1)) ? suffix : @""]];
			}
			else {

				[env setObject:filepath forKey:kShellVarNameDraggedFilePath];
				[env setObject:[[filepath stringByReplacingOccurrencesOfRegex:[NSString stringWithFormat:@"^%@", curDir] withString:@""] stringByAbbreviatingWithTildeInPath] forKey:kShellVarNameDraggedRelativeFilePath];
				[env setObject:[NSNumber numberWithInt:snip_cnt] forKey:kShellVarNameCurrentSnippetIndex];

				NSString *extension = [[filepath pathExtension] lowercaseString];

				// handle *.R for source()
				if([extension isEqualToString:@"r"]) {
					if((userDragActionDir && [fm fileExistsAtPath:[NSString stringWithFormat:@"%@r/%@", userDragActionDir, kUserCommandFileName]])) {
						anError = nil;
						NSString *cmd = [NSString stringWithContentsOfFile:[NSString stringWithFormat:@"%@r/%@", userDragActionDir, kUserCommandFileName] encoding:NSUTF8StringEncoding error:&anError];
						if(anError == nil) {
							[(id)[self delegate] setStatusLineText:NLS(@"press ⌘. to cancel")];
							NSString *res = [cmd evaluateAsBashCommandWithEnvironment:env atPath:[NSString stringWithFormat:@"%@r", userDragActionDir] error:&anError];
							[(id)[self delegate] setStatusLineText:@""];
							if(anError != nil) {
								NSAlert *alert = [NSAlert alertWithMessageText:NLS(@"Snippet Error") 
										defaultButton:NLS(@"OK") 
										alternateButton:nil 
										otherButton:nil 
										informativeTextWithFormat:[[anError userInfo] objectForKey:NSLocalizedDescriptionKey]];

								[alert setAlertStyle:NSWarningAlertStyle];
								[alert runModal];
								[[self window] makeKeyAndOrderFront:self];
								[[self window] makeFirstResponder:self];
								return NO;
							}
							if(res && [res length]) {
								[insertionString appendString:res];
								[insertionString appendString:(i < ([files count]-1)) ? suffix : @""];
								NSArray *snipcounters = [res componentsMatchedByRegex:@"(?s)(?<!\\\\)\\$\\{(\\d+):" capture:1L];
								NSInteger k=0;
								NSInteger lastSnipCnt = 0;
								for(k=0 ; k<[snipcounters count]; k++)
									if([[snipcounters objectAtIndex:k] intValue] > lastSnipCnt)
										lastSnipCnt = [[snipcounters objectAtIndex:k] intValue];
								snip_cnt = lastSnipCnt;
							}
						} else {
							NSBeep();
							NSLog(@"Drag Action: Couldn't read '%@'", [NSString stringWithFormat:@"%@r/%@", userDragActionDir, kUserCommandFileName]);
							return NO;
						}
					} else {
						if([sender draggingSourceOperationMask] == 4) {
							[insertionString appendString:[NSString stringWithFormat:@"source('%@'${%ld:, chdir = ${%ld:%@}})%@",
								[[filepath stringByReplacingOccurrencesOfRegex:
									[NSString stringWithFormat:@"^%@", curDir] withString:@""] stringByAbbreviatingWithTildeInPath], snip_cnt, snip_cnt+1, 
										([filepath rangeOfString:@"/"].length) ? @"TRUE" : @"FALSE" , 
											(i < ([files count]-1)) ? suffix : @""]];
							snip_cnt++;
						}
						else if([sender draggingSourceOperationMask] == 5)
							[insertionString appendString:[NSString stringWithFormat:@"%@%@", 
								[filepath stringByAbbreviatingWithTildeInPath], 
											(i < ([files count]-1)) ? suffix : @""]];
						else {
							[insertionString appendString:[NSString stringWithFormat:@"source('%@'${%ld:, chdir = ${%ld:%@}})%@",
								[filepath stringByAbbreviatingWithTildeInPath], snip_cnt, snip_cnt+1,
								([filepath rangeOfString:@"/"].length) ? @"TRUE" : @"FALSE" , (i < ([files count]-1)) ? suffix : @""]];
							snip_cnt++;
						}
					}
				}

				// handle *.Rdata for load()
				else if([extension isEqualToString:@"rdata"]) {
					if((userDragActionDir && [fm fileExistsAtPath:[NSString stringWithFormat:@"%@/rdata/%@", userDragActionDir, kUserCommandFileName]])) {
						anError = nil;
						[(id)[self delegate] setStatusLineText:NLS(@"press ⌘. to cancel")];
						NSString *cmd = [NSString stringWithContentsOfFile:[NSString stringWithFormat:@"%@rdata/%@", userDragActionDir, kUserCommandFileName] encoding:NSUTF8StringEncoding error:&anError];
						[(id)[self delegate] setStatusLineText:@""];
						if(anError == nil) {
							NSString *res = [cmd evaluateAsBashCommandWithEnvironment:env atPath:[NSString stringWithFormat:@"%@rdata", userDragActionDir] error:&anError];
							if(anError != nil) {
								NSAlert *alert = [NSAlert alertWithMessageText:NLS(@"Snippet Error") 
										defaultButton:NLS(@"OK") 
										alternateButton:nil 
										otherButton:nil 
										informativeTextWithFormat:[[anError userInfo] objectForKey:NSLocalizedDescriptionKey]];

								[alert setAlertStyle:NSWarningAlertStyle];
								[alert runModal];
								[[self window] makeKeyAndOrderFront:self];
								[[self window] makeFirstResponder:self];
								return NO;
							}
							if(res && [res length]) {
								[insertionString appendString:res];
								[insertionString appendString:(i < ([files count]-1)) ? suffix : @""];
								NSArray *snipcounters = [res componentsMatchedByRegex:@"(?s)(?<!\\\\)\\$\\{(\\d+):" capture:1L];
								NSInteger k=0;
								NSInteger lastSnipCnt = 0;
								for(k=0 ; k<[snipcounters count]; k++)
									if([[snipcounters objectAtIndex:k] intValue] > lastSnipCnt)
										lastSnipCnt = [[snipcounters objectAtIndex:k] intValue];
								snip_cnt = lastSnipCnt;
							}
						} else {
							NSBeep();
							NSLog(@"Drag Action: Couldn't read '%@'", [NSString stringWithFormat:@"%@rdata/%@", userDragActionDir, kUserCommandFileName]);
							return NO;
						}
					} else {
						if([sender draggingSourceOperationMask] == 4)
							[insertionString appendString:[NSString stringWithFormat:@"load('%@')%@", 
								[[filepath stringByReplacingOccurrencesOfRegex:
									[NSString stringWithFormat:@"^%@", curDir] withString:@""] stringByAbbreviatingWithTildeInPath], 
										(i < ([files count]-1)) ? suffix : @""]];
						else if([sender draggingSourceOperationMask] == 5)
							[insertionString appendString:[NSString stringWithFormat:@"%@%@", 
								[filepath stringByAbbreviatingWithTildeInPath], 
											(i < ([files count]-1)) ? suffix : @""]];
						else
						[insertionString appendString:[NSString stringWithFormat:@"load('%@')%@", 
							[filepath stringByAbbreviatingWithTildeInPath], 
								(i < ([files count]-1)) ? suffix : @""]];
					}
				}

				// look for user-defined commands due to extension
				else if((userDragActionDir && [fm fileExistsAtPath:[NSString stringWithFormat:@"%@/%@/%@", userDragActionDir, extension, kUserCommandFileName]])) {
					anError = nil;
					NSString *cmd = [NSString stringWithContentsOfFile:[NSString stringWithFormat:@"%@%@/%@", userDragActionDir, extension, kUserCommandFileName] encoding:NSUTF8StringEncoding error:&anError];
					if(anError == nil) {
						[(id)[self delegate] setStatusLineText:NLS(@"press ⌘. to cancel")];
						NSString *res = [cmd evaluateAsBashCommandWithEnvironment:env atPath:[NSString stringWithFormat:@"%@%@", userDragActionDir, extension] error:&anError];
						[(id)[self delegate] setStatusLineText:@""];
						if(anError != nil) {
							NSAlert *alert = [NSAlert alertWithMessageText:NLS(@"Snippet Error") 
									defaultButton:NLS(@"OK") 
									alternateButton:nil 
									otherButton:nil 
									informativeTextWithFormat:[[anError userInfo] objectForKey:NSLocalizedDescriptionKey]];

							[alert setAlertStyle:NSWarningAlertStyle];
							[alert runModal];
							[[self window] makeKeyAndOrderFront:self];
							[[self window] makeFirstResponder:self];
							return NO;
						}
						if(res && [res length]) {
							[insertionString appendString:res];
							[insertionString appendString:(i < ([files count]-1)) ? suffix : @""];
							NSArray *snipcounters = [res componentsMatchedByRegex:@"(?s)(?<!\\\\)\\$\\{(\\d+):" capture:1L];
							NSInteger k=0;
							NSInteger lastSnipCnt = 0;
							for(k=0 ; k<[snipcounters count]; k++)
								if([[snipcounters objectAtIndex:k] intValue] > lastSnipCnt)
									lastSnipCnt = [[snipcounters objectAtIndex:k] intValue];
							snip_cnt = lastSnipCnt;
						}
					} else {
						NSBeep();
						NSLog(@"Drag Action: Couldn't read '%@'", [NSString stringWithFormat:@"%@%@/%@", userDragActionDir, extension, kUserCommandFileName]);
						return NO;
					}
				}

				else
					[insertionString appendString:[[filepath stringByAbbreviatingWithTildeInPath] stringByAppendingString:(i < ([files count]-1)) ? suffix : @""]];
			}
		}

		[self insertAsSnippet:insertionString atRange:[self selectedRange]];

		return YES;
	}

	return [super performDragOperation:sender];

}

/**
 * Convert a NSPoint, usually the mouse location, to
 * a character index of the text view.
 */
- (NSUInteger)characterIndexOfPoint:(NSPoint)aPoint
{
	NSUInteger glyphIndex;
	NSLayoutManager *layoutManager = [self layoutManager];
	CGFloat fractionalDistance;
	NSRange range;

	range = [layoutManager glyphRangeForTextContainer:[self textContainer]];
	glyphIndex = [layoutManager glyphIndexForPoint:aPoint
		inTextContainer:[self textContainer]
		fractionOfDistanceThroughGlyph:&fractionalDistance];

	if( fractionalDistance > 0.5f && fractionalDistance < 1.0f) glyphIndex++;

	if( glyphIndex == NSMaxRange(range) )
		return  [[self textStorage] length];
	else {
		glyphIndex = [layoutManager characterIndexForGlyphAtIndex:glyphIndex];
		return glyphIndex;
	}

}

#pragma mark -
#pragma mark snippet handler

/**
 * Reset snippet controller variables to end a snippet session
 */
- (void)endSnippetSession
{

	snippetControlCounter = -1;
	currentSnippetIndex   = -1;
	snippetControlMax     = -1;
	mirroredCounter       = -1;
	snippetWasJustInserted = NO;

	// remove all snippet frames
	[self setNeedsDisplayInRect:[self visibleRect] avoidAdditionalLayout:NO];

}

/**
 * Update all mirrored snippets and adjust any involved instances
 */
- (void)processMirroredSnippets
{
	if(mirroredCounter > -1) {

		isProcessingMirroredSnippets = YES;

		NSInteger i, j, k, deltaLength;
		NSRange mirroredRange;

		// Go through each defined mirrored snippet and update it
		for(i=0; i<=mirroredCounter; i++) {
			if(snippetMirroredControlArray[i][0] == currentSnippetIndex) {

				deltaLength = snippetControlArray[currentSnippetIndex][1]-snippetMirroredControlArray[i][2];

				mirroredRange = NSMakeRange(snippetMirroredControlArray[i][1], snippetMirroredControlArray[i][2]);
				NSString *mirroredString = nil;

				// For safety reasons
				@try{
					mirroredString = [[self string] substringWithRange:NSMakeRange(snippetControlArray[currentSnippetIndex][0], snippetControlArray[currentSnippetIndex][1])];
				}
				@catch(id ae) {
					NSLog(@"Error while parsing for mirrored snippets. %@", [ae description]);
					NSBeep();
					[self endSnippetSession];
					return;
				}

				// Register for undo
				[self shouldChangeTextInRange:mirroredRange replacementString:mirroredString];

				[self replaceCharactersInRange:mirroredRange withString:mirroredString];
				snippetMirroredControlArray[i][2] = snippetControlArray[currentSnippetIndex][1];

				// If a completion list is open adjust the theCharRange and theParseRange if a mirrored snippet
				// was updated which is located before the initial position 
				// if(completionIsOpen && snippetMirroredControlArray[i][1] < (NSInteger)completionParseRangeLocation)
				// 	[completionPopup adjustWorkingRangeByDelta:deltaLength];

				// Adjust all other snippets accordingly
				for(j=0; j<=snippetControlMax; j++) {
					if(snippetControlArray[j][0] > -1) {
						if(snippetControlArray[j][0]+snippetControlArray[j][1]>=snippetMirroredControlArray[i][1]) {
							snippetControlArray[j][0] += deltaLength;
						}
					}
				}
				// Adjust all mirrored snippets accordingly
				for(k=0; k<=mirroredCounter; k++) {
					if(i != k) {
						if(snippetMirroredControlArray[k][1] > snippetMirroredControlArray[i][1]) {
							snippetMirroredControlArray[k][1] += deltaLength;
						}
					}
				}
			}
		}

		isProcessingMirroredSnippets = NO;
		[self didChangeText];
		
	}
}


/**
 * Selects the current snippet defined by “currentSnippetIndex”
 */
- (void)selectCurrentSnippet
{
	if( snippetControlCounter  > -1 
		&& currentSnippetIndex >= 0 
		&& currentSnippetIndex <= snippetControlMax
		)
	{

		[self breakUndoCoalescing];

		// Place the caret at the end of snippet
		// and finish snippet editing
		if(currentSnippetIndex == snippetControlMax) {
			NSRange r = NSMakeRange(snippetControlArray[snippetControlMax][0] + snippetControlArray[snippetControlMax][1], 0);
			if(r.location >= [[self string] length])
				r = NSMakeRange([[self string] length], 0);
			else
				r = NSIntersectionRange(NSMakeRange(0,[[self string] length]), r);
			[self setSelectedRange:r];
			[self scrollRangeToVisible:r];
			[self endSnippetSession];
			return;
		}

		if(currentSnippetIndex >= 0 && currentSnippetIndex < 20) {
			if(snippetControlArray[currentSnippetIndex][2] == 0) {

				NSRange r1 = NSMakeRange(snippetControlArray[currentSnippetIndex][0], snippetControlArray[currentSnippetIndex][1]);

				NSRange r2;
				// Ensure the selection for nested snippets if it is at very end of the text buffer
				// because NSIntersectionRange returns {0, 0} in such a case
				if(r1.location == [[self string] length])
					r2 = NSMakeRange([[self string] length], 0);
				else
					r2 = NSIntersectionRange(NSMakeRange(0,[[self string] length]), r1);

				if(r1.location == r2.location && r1.length == r2.length) {
					[self setSelectedRange:r2];
					[self scrollRangeToVisible:r2];
					NSString *snip = [[self string] substringWithRange:r2];
					
 					if([snip length] > 2 && [snip hasPrefix:@"¦"] && [snip hasSuffix:@"¦"]) {
						;
					}
				} else {
					[self endSnippetSession];
				}
			}
		} else { // for safety reasons
			[self endSnippetSession];
		}
	} else { // for safety reasons
		[self endSnippetSession];
	}
}

/**
 * Inserts a chosen snippet and initialze a snippet session if user defined any
 */
- (void)insertAsSnippet:(NSString*)theSnippet atRange:(NSRange)targetRange
{

	// Do not allow the insertion of a snippet if snippets are active
	if(snippetControlCounter > -1) {
		NSBeep();
		return;
	}

	NSInteger i, j;
	mirroredCounter = -1;

	// reset snippet array
	for(i=0; i<20; i++) {
		snippetControlArray[i][0] = -1; // snippet location
		snippetControlArray[i][1] = -1; // snippet length
		snippetControlArray[i][2] = -1; // snippet task : -1 not valid, 0 select snippet
		snippetMirroredControlArray[i][0] = -1; // mirrored snippet index
		snippetMirroredControlArray[i][1] = -1; // mirrored snippet location
		snippetMirroredControlArray[i][2] = -1; // mirrored snippet length
	}

	if(theSnippet == nil || ![theSnippet length]) return;

	NSMutableString *snip = [[NSMutableString alloc] initWithCapacity:[theSnippet length]];

	@try{
		NSString *re = @"(?s)(?<!\\\\)\\$\\{(1?\\d):(.{0}|[^\\{\\}]*?[^\\\\])\\}";
		NSString *mirror_re = @"(?<!\\\\)\\$(1?\\d)(?=\\D)";

		if(targetRange.length)
			targetRange = NSIntersectionRange(NSMakeRange(0,[[self string] length]), targetRange);
		[snip setString:theSnippet];

		if (snip == nil) return;
		if (![snip length]) {
			[snip release];
			return;
		}

		// Replace `${x:…}` by ${x:`…`} for convience 
		[snip replaceOccurrencesOfRegex:@"`(?s)(?<!\\\\)\\$\\{(1?\\d):(.{0}|.*?[^\\\\])\\}`" withString:@"${$1:`$2`}"];
		[snip flushCachedRegexData];

		snippetControlCounter = -1;
		snippetControlMax     = -1;
		currentSnippetIndex   = -1;

		// Suppress snippet range calculation in [self textStorageDidProcessEditing] while initial insertion
		snippetWasJustInserted = YES;

		while([snip isMatchedByRegex:re]) {
			[snip flushCachedRegexData];
			snippetControlCounter++;

			NSRange snipRange = [snip rangeOfRegex:re capture:0L];
			NSInteger snipCnt = [[snip substringWithRange:[snip rangeOfRegex:re capture:1L]] intValue];
			NSRange hintRange = [snip rangeOfRegex:re capture:2L];

			// Check for snippet number 19 (to simplify regexp)
			if(snipCnt>18 || snipCnt<0) {
				NSLog(@"Only snippets in the range of 0…18 allowed.");
				[self endSnippetSession];
				break;
			}

			// Remember the maximal snippet number defined by user
			if(snipCnt>snippetControlMax)
				snippetControlMax = snipCnt;

			// Replace internal variables
			NSMutableString *theHintString = [[NSMutableString alloc] initWithCapacity:hintRange.length];
			[theHintString setString:[snip substringWithRange:hintRange]];

			// Handle escaped characters
			[theHintString replaceOccurrencesOfRegex:@"\\\\(\\$\\(|\\}|\\$R_)" withString:@"$1"];
			[theHintString flushCachedRegexData];

			// If inside the snippet hint $(…) is defined run … as BASH command
			// and replace $(…) by the return string of that command. Please note
			// only one $(…) statement is allowed within one ${…} snippet environment.
			NSRange tagRange = [theHintString rangeOfRegex:@"(?s)(?<!\\\\)\\$\\((.*)\\)"];
			if(tagRange.length) {
				[theHintString flushCachedRegexData];
				NSRange cmdRange = [theHintString rangeOfRegex:@"(?s)(?<!\\\\)\\$\\(\\s*(.*)\\s*\\)" capture:1L];
				if(cmdRange.length) {
					NSError *err = nil;
					NSString *cmdResult = [[theHintString substringWithRange:cmdRange] evaluateAsBashCommandAndError:&err];
					if(err == nil) {
						[theHintString replaceCharactersInRange:tagRange withString:cmdResult];
					} else if([err code] != 9) { // Suppress an error message if command was killed
						// NSString *errorMessage  = [err localizedDescription];
						// NSBeginAlertSheet(NSLocalizedString(@"BASH Error", @"bash error"), NSLocalizedString(@"OK", @"OK button"), nil, nil, [self window], self, nil, nil,
						// 				  [NSString stringWithFormat:@"%@ “%@”:\n%@", NSLocalizedString(@"Error for", @"error for message"), [theHintString substringWithRange:cmdRange], errorMessage]);
					}
				} else {
					[theHintString replaceCharactersInRange:tagRange withString:@""];
				}
			}
			[theHintString flushCachedRegexData];

			[snip replaceCharactersInRange:snipRange withString:theHintString];
			[snip flushCachedRegexData];

			// Store found snippet range
			snippetControlArray[snipCnt][0] = snipRange.location + targetRange.location;
			snippetControlArray[snipCnt][1] = [theHintString length];
			snippetControlArray[snipCnt][2] = 0;

			[theHintString release];

			// Adjust successive snippets
			for(i=0; i<20; i++)
				if(snippetControlArray[i][0] > -1 && i != snipCnt && snippetControlArray[i][0] > snippetControlArray[snipCnt][0])
					snippetControlArray[i][0] -= 3+((snipCnt>9)?2:1);

		}

		// Parse for mirrored snippets
		while([snip isMatchedByRegex:mirror_re]) {
			mirroredCounter++;
			if(mirroredCounter > 19) {
				NSLog(@"Only 20 mirrored snippet placeholders allowed.");
				NSBeep();
				break;
			} else {

				NSRange snipRange = [snip rangeOfRegex:mirror_re capture:0L];
				NSInteger snipCnt = [[snip substringWithRange:[snip rangeOfRegex:mirror_re capture:1L]] intValue];

				// Check for snippet number 19 (to simplify regexp)
				if(snipCnt>18 || snipCnt<0) {
					NSLog(@"Only snippets in the range of 0…18 allowed.");
					[self endSnippetSession];
					break;
				}

				[snip replaceCharactersInRange:snipRange withString:@""];
				[snip flushCachedRegexData];

				// Store found mirrored snippet range
				snippetMirroredControlArray[mirroredCounter][0] = snipCnt;
				snippetMirroredControlArray[mirroredCounter][1] = snipRange.location + targetRange.location;
				snippetMirroredControlArray[mirroredCounter][2] = 0;

				// Adjust successive snippets
				for(i=0; i<20; i++)
					if(snippetControlArray[i][0] > -1 && snippetControlArray[i][0] > snippetMirroredControlArray[mirroredCounter][1])
						snippetControlArray[i][0] -= 1+((snipCnt>9)?2:1);

				[snip flushCachedRegexData];
			}
		}
		// Preset mirrored snippets with according snippet content
		if(mirroredCounter > -1) {
			for(i=0; i<=mirroredCounter; i++) {
				if(snippetControlArray[snippetMirroredControlArray[i][0]][0] > -1 && snippetControlArray[snippetMirroredControlArray[i][0]][1] > 0) {
					[snip replaceCharactersInRange:NSMakeRange(snippetMirroredControlArray[i][1]-targetRange.location, snippetMirroredControlArray[i][2]) 
										withString:[snip substringWithRange:NSMakeRange(snippetControlArray[snippetMirroredControlArray[i][0]][0]-targetRange.location, snippetControlArray[snippetMirroredControlArray[i][0]][1])]];
					snippetMirroredControlArray[i][2] = snippetControlArray[snippetMirroredControlArray[i][0]][1];
				}
				// Adjust successive snippets
				for(j=0; j<20; j++)
					if(snippetControlArray[j][0] > -1 && snippetControlArray[j][0] > snippetMirroredControlArray[i][1])
						snippetControlArray[j][0] += snippetControlArray[snippetMirroredControlArray[i][0]][1];
				// Adjust successive mirrored snippets
				for(j=0; j<=mirroredCounter; j++)
					if(snippetMirroredControlArray[j][1] > snippetMirroredControlArray[i][1])
						snippetMirroredControlArray[j][1] += snippetControlArray[snippetMirroredControlArray[i][0]][1];
			}
		}

		if(snippetControlCounter > -1) {
			// Store the end for tab out
			snippetControlMax++;
			snippetControlArray[snippetControlMax][0] = targetRange.location + [snip length];
			snippetControlArray[snippetControlMax][1] = 0;
			snippetControlArray[snippetControlMax][2] = 0;
		}

		// unescape escaped snippets and re-adjust successive snippet locations : \${1:a} → ${1:a}
		NSString *ure = @"(?s)\\\\\\$\\{(1?\\d):(.{0}|.*?[^\\\\])\\}";
		while([snip isMatchedByRegex:ure]) {
			NSRange escapeRange = [snip rangeOfRegex:ure capture:0L];
			[snip replaceCharactersInRange:escapeRange withString:[snip substringWithRange:NSMakeRange(escapeRange.location+1,escapeRange.length-1)]];
			NSInteger loc = escapeRange.location + targetRange.location;
			[snip flushCachedRegexData];
			for(i=0; i<=snippetControlMax; i++)
				if(snippetControlArray[i][0] > -1 && snippetControlArray[i][0] > loc)
					snippetControlArray[i][0]--;
			// Adjust mirrored snippets
			if(mirroredCounter > -1)
				for(i=0; i<=mirroredCounter; i++)
					if(snippetMirroredControlArray[i][0] > -1 && snippetMirroredControlArray[i][1] > loc)
						snippetMirroredControlArray[i][1]--;
		}

		// Insert snippet by selecting the tab trigger if any
		[self setSelectedRange:targetRange];

		// Registering for undo
		[self breakUndoCoalescing];
		[self insertText:snip];

		// If autopair is enabled check whether snip begins with ( and ends with ), if so mark ) as pair-linked
		if (

				[[NSUserDefaults standardUserDefaults] objectForKey:kAutoCloseBrackets] &&

				 (([snip hasPrefix:@"("] && [snip hasSuffix:@")"])
						|| ([snip hasPrefix:@"`"] && [snip hasSuffix:@"`"])
						|| ([snip hasPrefix:@"'"] && [snip hasSuffix:@"'"])
						|| ([snip hasPrefix:@"\""] && [snip hasSuffix:@"\""])))
		{
			[[self textStorage] addAttribute:kTALinked value:kTAVal range:NSMakeRange([self selectedRange].location - 1, 1)];
		}

		// Any snippets defined?
		if(snippetControlCounter > -1) {
			// Find and select first defined snippet
			currentSnippetIndex = 0;
			// Look for next defined snippet since snippet numbers must not serial like 1, 5, and 12 e.g.
			while(snippetControlArray[currentSnippetIndex][0] == -1 && currentSnippetIndex < 20)
				currentSnippetIndex++;
			[self selectCurrentSnippet];
		}

		snippetWasJustInserted = NO;
	}
	@catch(id ae) { // For safety reasons catch exceptions
		NSLog(@"Snippet Error: %@", [ae description]);
		[self endSnippetSession];
		snippetWasJustInserted = NO;
	}

	if(snip)[snip release];

}

/**
 * Checks whether the current caret position in inside of a defined snippet range
 */
- (BOOL)checkForCaretInsideSnippet
{

	if(snippetWasJustInserted) return YES;

	BOOL isCaretInsideASnippet = NO;

	if(snippetControlCounter < 0 || currentSnippetIndex == snippetControlMax) {
		[self endSnippetSession];
		return NO;
	}
	
	[[self textStorage] ensureAttributesAreFixedInRange:[self selectedRange]];
	NSInteger caretPos = [self selectedRange].location;
	NSInteger i, j;
	NSInteger foundSnippetIndices[20]; // array to hold nested snippets

	j = -1;

	// Go through all snippet ranges and check whether the caret is inside of the
	// current snippet range. Remember matches 
	// in foundSnippetIndices array to test for nested snippets.
	for(i=0; i<=snippetControlMax; i++) {
		j++;
		foundSnippetIndices[j] = 0;
		if(snippetControlArray[i][0] != -1 
			&& caretPos >= snippetControlArray[i][0]
			&& caretPos <= snippetControlArray[i][0] + snippetControlArray[i][1]) {

			foundSnippetIndices[j] = 1;
			if(i == currentSnippetIndex)
				isCaretInsideASnippet = YES;

		}
	}
	// If caret is not inside the current snippet range check if caret is inside of
	// another defined snippet; if so set currentSnippetIndex to it (this allows to use the
	// mouse to activate another snippet). If the caret is inside of overlapped snippets (nested)
	// then select this snippet which has the smallest length.
	if(!isCaretInsideASnippet && foundSnippetIndices[currentSnippetIndex] == 1) {
		isCaretInsideASnippet = YES;
	} else if(![self selectedRange].length) {
		NSInteger curIndex = -1;
		NSInteger smallestLength = -1;
		for(i=0; i<snippetControlMax; i++) {
			if(foundSnippetIndices[i] == 1) {
				if(curIndex == -1) {
					curIndex = i;
					smallestLength = snippetControlArray[i][1];
				} else {
					if(smallestLength > snippetControlArray[i][1]) {
						curIndex = i;
						smallestLength = snippetControlArray[i][1];
					}
				}
			}
		}
		// Reset the active snippet
		if(curIndex > -1 && smallestLength > -1) {
			currentSnippetIndex = curIndex;
			isCaretInsideASnippet = YES;
		}
	}
	return isCaretInsideASnippet;

}

/**
 * Return YES if user interacts with snippets (is needed mainly for suppressing
 * the highlighting of the current line)
 */
- (BOOL)isSnippetMode
{
	return (snippetControlCounter > -1) ? YES : NO;
}

- (void)checkSnippets
{
	// Re-calculate snippet ranges if snippet session is active
	if(snippetControlCounter > -1 && !snippetWasJustInserted && !isProcessingMirroredSnippets) {
		// Remove any fully nested snippets relative to the current snippet which was edited
		NSInteger currentSnippetLocation = snippetControlArray[currentSnippetIndex][0];
		NSInteger currentSnippetMaxRange = snippetControlArray[currentSnippetIndex][0] + snippetControlArray[currentSnippetIndex][1];
		NSInteger i;
		for(i=0; i<snippetControlMax; i++) {
			if(snippetControlArray[i][0] > -1
				&& i != currentSnippetIndex
				&& snippetControlArray[i][0] >= currentSnippetLocation
				&& snippetControlArray[i][0] <= currentSnippetMaxRange
				&& snippetControlArray[i][0] + snippetControlArray[i][1] >= currentSnippetLocation
				&& snippetControlArray[i][0] + snippetControlArray[i][1] <= currentSnippetMaxRange
				) {
					snippetControlArray[i][0] = -1;
					snippetControlArray[i][1] = -1;
					snippetControlArray[i][2] = -1;
			}
		}

		NSInteger editStartPosition = [[self textStorage] editedRange].location;
		NSUInteger changeInLength = [[self textStorage] changeInLength];

		// Adjust length change to current snippet
		snippetControlArray[currentSnippetIndex][1] += changeInLength;
		// If length < 0 break snippet input
		if(snippetControlArray[currentSnippetIndex][1] < 0) {
			[self endSnippetSession];
		} else {
			// Adjust start position of snippets after caret position
			for(i=0; i<=snippetControlMax; i++) {
				if(snippetControlArray[i][0] > -1 && i != currentSnippetIndex) {
					if(editStartPosition < snippetControlArray[i][0]) {
						snippetControlArray[i][0] += changeInLength;
					} else if(editStartPosition >= snippetControlArray[i][0] && editStartPosition <= snippetControlArray[i][0] + snippetControlArray[i][1]) {
						snippetControlArray[i][1] += changeInLength;
					}
				}
			}
			// Adjust start position of mirrored snippets after caret position
			if(mirroredCounter > -1)
				for(i=0; i<=mirroredCounter; i++) {
					if(editStartPosition < snippetMirroredControlArray[i][1]) {
						snippetMirroredControlArray[i][1] += changeInLength;
					}
				}
		}

		if(mirroredCounter > -1 && snippetControlCounter > -1) {
			[self performSelector:@selector(processMirroredSnippets) withObject:nil afterDelay:0.0];
		}
	}
}

- (NSDictionary*)getCurrentEnvironment
{
	NSMutableDictionary *env = [NSMutableDictionary dictionary];

	NSString *cword = [[self string] substringWithRange:
		[self getRangeForCurrentWord]];

	NSString *cline = [[self string] substringWithRange:
		[[self string] lineRangeForRange:[self selectedRange]]];

	NSString *cpath = @"";
	NSURL *anURL = [[[[self window] windowController] document] fileURL];
	if(anURL)
		cpath = [anURL path];
	else if([[self delegate] isKindOfClass:[RController class]])
		cpath = @"RConsole";

	NSString *stext = [[self string] substringWithRange:
		[self selectedRange]];

	if(cword)
		[env setObject:cword forKey:kShellVarNameCurrentWord];
	if(cline)
		[env setObject:cline forKey:kShellVarNameCurrentLine];
	if(cpath)
		[env setObject:cpath forKey:kShellVarNameCurrentFilePath];
	if(stext)
		[env setObject:stext forKey:kShellVarNameSelectedText];

	return (NSDictionary*)env;
}

/**
 * Returns the range of the current word.
 *   finds: [| := caret]  |word  wo|rd  word|
 * If | is in between whitespaces nothing will be selected.
 */
- (NSRange)getRangeForCurrentWord
{
	return [self getRangeForCurrentWordOfRange:[self selectedRange]];
}

- (NSRange)getRangeForCurrentWordOfRange:(NSRange)curRange
{

	if (curRange.length) return curRange;

	NSString *str = [self string];
	int curLocation = curRange.location;
	int start = curLocation;
	int end = curLocation;
	unsigned int strLen = [[self string] length];

	if(start) {
		start--;
		if(CFStringGetCharacterAtIndex((CFStringRef)str, start) != '\n' || CFStringGetCharacterAtIndex((CFStringRef)str, start) != '\r') {
			while([wordCharSet characterIsMember:CFStringGetCharacterAtIndex((CFStringRef)str, start)]) {
				start--;
				if(start < 0) break;
			}
		}
		start++;
	}

	while(end < strLen && [wordCharSet characterIsMember:CFStringGetCharacterAtIndex((CFStringRef)str, end)])
		end++;

	// correct range if found range ends with a .
	NSRange wordRange = NSMakeRange(start, end-start);
	if(wordRange.length && CFStringGetCharacterAtIndex((CFStringRef)str, NSMaxRange(wordRange)-1) == '.')
		wordRange.length--;

	SLog(@"RTextView: returned range for current word: %@", NSStringFromRange(wordRange));

	return(wordRange);

}

#pragma mark -
#pragma mark multi-touch trackpad support

/**
 * Trackpad two-finger zooming gesture for in/decreasing the font size
 */
- (void) magnifyWithEvent:(NSEvent *)anEvent
{
	[[RController sharedController] fontSizeChangedBy:([anEvent deltaZ]/100) withSender:self];
}

@end
