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
 *  NSTextView_RAdditions.m
 *
 *  Created by Hans-J. Bibiko on 19/03/2011.
 *
 */

#import "NSTextView_RAdditions.h"
#import "RTextView.h"
#import "RegexKitLite.h"
#import "RGUI.h"

static inline int RPARSERCONTEXTFORPOSITION (RTextView* self, NSUInteger index) 
{
	typedef int (*RPARSERCONTEXTFORPOSITIONMethodPtr)(RTextView*, SEL, NSUInteger);
	static RPARSERCONTEXTFORPOSITIONMethodPtr _RPARSERCONTEXTFORPOSITION;
	if (!_RPARSERCONTEXTFORPOSITION) _RPARSERCONTEXTFORPOSITION = (RPARSERCONTEXTFORPOSITIONMethodPtr)[self methodForSelector:@selector(parserContextForPosition:)];
	int r = _RPARSERCONTEXTFORPOSITION(self, @selector(parserContextForPosition:), index);
	return r;
}

@implementation NSTextView (NSTextView_RAdditions)

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
	NSMutableCharacterSet *wordCharSet = [NSMutableCharacterSet alphanumericCharacterSet];
	[wordCharSet addCharactersInString:@"_.\\"];

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

	SLog(@"NSTextView_RAdditions: returned range for current word: %@", NSStringFromRange(wordRange));

	return(wordRange);

}

/**
 * Select current word.
 *   finds: [| := caret]  |word  wo|rd  word|
 * If | is in between whitespaces nothing will be selected.
 */
- (IBAction)selectCurrentWord:(id)sender
{
	[self setSelectedRange:[self getRangeForCurrentWord]];
}

/**
 * Select current line.
 */
- (IBAction)selectCurrentLine:(id)sender
{
	NSRange lineRange = [[self string] lineRangeForRange:[self selectedRange]];
	if(lineRange.location != NSNotFound && lineRange.length) {
		if([(RTextView*)self isRConsole]
			&& ([[self string] lineRangeForRange:NSMakeRange([[self string] length]-1,0)].location+1 < [self selectedRange].location)) {
			lineRange.location+=2;
			lineRange.length-=2;
		}
		[self setSelectedRange:lineRange];
	}
	else
		NSBeep();
}

/**
 *
 */
- (IBAction)selectEnclosingBrackets:(id)sender
{

	NSUInteger caretPosition = [self selectedRange].location;
	NSUInteger stringLength = [[self string] length];

	CFStringRef parserStringRef = (CFStringRef)[self string];

	unichar co = ' '; // opening char
	unichar cc = ' '; // closing char
	
	if(caretPosition == 0 || caretPosition >= stringLength) return;
	
	NSInteger pcnt = 0; // ) counter
	NSInteger bcnt = 0; // ] counter
	NSInteger scnt = 0; // } counter
	NSInteger breakCounter = 10000;

	// look for the first non-balanced closing bracket
	for(NSUInteger i=caretPosition; i<stringLength; i++) {
		if(!breakCounter--) return;
		if(RPARSERCONTEXTFORPOSITION((RTextView*)self, i) != pcExpression) continue;
		switch(CFStringGetCharacterAtIndex(parserStringRef, i)) {
			case ')': 
				if(!pcnt) {
					co='(';cc=')';
					i=stringLength;
				}
				pcnt++; break;
			case '(': pcnt--; break;
			case ']': 
				if(!bcnt) {
					co='[';cc=']';
					i=stringLength;
				}
				bcnt++; break;
			case '[': bcnt--; break;
			case '}': 
				if(!scnt) {
					co='{';cc='}';
					i=stringLength;
				}
				scnt++; break;
			case '{': scnt--; break;
		}
	}

	NSInteger start = -1;
	NSInteger end = -1;
	NSInteger bracketCounter = 0;

	unichar c = CFStringGetCharacterAtIndex(parserStringRef, caretPosition);
	if(c == cc)
		bracketCounter--;
	if(c == co)
		bracketCounter++;

	breakCounter = 10000;
	for(NSInteger i=caretPosition; i>=0; i--) {
		if(!breakCounter--) return;
		if(RPARSERCONTEXTFORPOSITION((RTextView*)self, i) != pcExpression) continue;
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

	bracketCounter = 0;
	breakCounter = 10000;
	for(NSUInteger i=caretPosition; i<stringLength; i++) {
		if(!breakCounter--) return;
		if(RPARSERCONTEXTFORPOSITION((RTextView*)self, i) != pcExpression) continue;
		c = CFStringGetCharacterAtIndex(parserStringRef, i);
		if(c == co) {
			bracketCounter++;
		}
		if(c == cc) {
			if(!bracketCounter) {
				end = i+1;
				break;
			}
			bracketCounter--;
		}
	}

	if(end < 0 || bracketCounter || end-start < 1) return;

	[self setSelectedRange:NSMakeRange(start, end-start)];

}

/*
 * Change selection or current word to upper case and preserves the selection.
 */
- (IBAction)doSelectionUpperCase:(id)sender
{
	NSRange curRange = [self selectedRange];
	NSRange selRange = (curRange.length) ? curRange : [self getRangeForCurrentWord];
	[self setSelectedRange:selRange];
	[self insertText:[[[self string] substringWithRange:selRange] uppercaseString]];
	[self setSelectedRange:curRange];
}

/*
 * Change selection or current word to lower case and preserves the selection.
 */
- (IBAction)doSelectionLowerCase:(id)sender
{
	NSRange curRange = [self selectedRange];
	NSRange selRange = (curRange.length) ? curRange : [self getRangeForCurrentWord];
	[self setSelectedRange:selRange];
	[self insertText:[[[self string] substringWithRange:selRange] lowercaseString]];
	[self setSelectedRange:curRange];
}

/*
 * Change selection or current word to title case and preserves the selection.
 */
- (IBAction)doSelectionTitleCase:(id)sender
{
	NSRange curRange = [self selectedRange];
	NSRange selRange = (curRange.length) ? curRange : [self getRangeForCurrentWord];
	[self setSelectedRange:selRange];
	[self insertText:[[[self string] substringWithRange:selRange] capitalizedString]];
	[self setSelectedRange:curRange];
}

/*
 * Change selection or current word according to Unicode's NFD and preserves the selection.
 */
- (IBAction)doDecomposedStringWithCanonicalMapping:(id)sender
{
	NSRange curRange = [self selectedRange];
	NSRange selRange = (curRange.length) ? curRange : [self getRangeForCurrentWord];
	[self setSelectedRange:selRange];
	NSString* convString = [[[self string] substringWithRange:selRange] decomposedStringWithCanonicalMapping];
	[self insertText:convString];
	
	// correct range for combining characters
	if(curRange.length)
		[self setSelectedRange:NSMakeRange(selRange.location, [convString length])];
	else
		// if no selection place the caret at the end of the current word
	{
		NSRange newRange = [self getRangeForCurrentWord];
		[self setSelectedRange:NSMakeRange(newRange.location + newRange.length, 0)];
	}
}

/*
 * Change selection or current word according to Unicode's NFKD and preserves the selection.
 */
- (IBAction)doDecomposedStringWithCompatibilityMapping:(id)sender
{
	NSRange curRange = [self selectedRange];
	NSRange selRange = (curRange.length) ? curRange : [self getRangeForCurrentWord];
	[self setSelectedRange:selRange];
	NSString* convString = [[[self string] substringWithRange:selRange] decomposedStringWithCompatibilityMapping];
	[self insertText:convString];
	
	// correct range for combining characters
	if(curRange.length)
		[self setSelectedRange:NSMakeRange(selRange.location, [convString length])];
	else
		// if no selection place the caret at the end of the current word
	{
		NSRange newRange = [self getRangeForCurrentWord];
		[self setSelectedRange:NSMakeRange(newRange.location + newRange.length, 0)];
	}
}

/*
 * Change selection or current word according to Unicode's NFC and preserves the selection.
 */
- (IBAction)doPrecomposedStringWithCanonicalMapping:(id)sender
{
	NSRange curRange = [self selectedRange];
	NSRange selRange = (curRange.length) ? curRange : [self getRangeForCurrentWord];
	[self setSelectedRange:selRange];
	NSString* convString = [[[self string] substringWithRange:selRange] precomposedStringWithCanonicalMapping];
	[self insertText:convString];
	
	// correct range for combining characters
	if(curRange.length)
		[self setSelectedRange:NSMakeRange(selRange.location, [convString length])];
	else
		// if no selection place the caret at the end of the current word
	{
		NSRange newRange = [self getRangeForCurrentWord];
		[self setSelectedRange:NSMakeRange(newRange.location + newRange.length, 0)];
	}
}

- (IBAction)doRemoveDiacritics:(id)sender
{
	
	NSRange curRange = [self selectedRange];
	NSRange selRange = (curRange.length) ? curRange : [self getRangeForCurrentWord];
	[self setSelectedRange:selRange];
	NSString* convString = [[[self string] substringWithRange:selRange] decomposedStringWithCanonicalMapping];
	NSArray* chars;
	chars = [convString componentsSeparatedByCharactersInSet:[NSCharacterSet nonBaseCharacterSet]];
	NSString* cleanString = [chars componentsJoinedByString:@""];
	[self insertText:cleanString];
	if(curRange.length)
		[self setSelectedRange:NSMakeRange(selRange.location, [cleanString length])];
	else
		// if no selection place the caret at the end of the current word
	{
		NSRange newRange = [self getRangeForCurrentWord];
		[self setSelectedRange:NSMakeRange(newRange.location + newRange.length, 0)];
	}
	
}

/*
 * Change selection or current word according to Unicode's NFKC to title case and preserves the selection.
 */
- (IBAction)doPrecomposedStringWithCompatibilityMapping:(id)sender
{
	NSRange curRange = [self selectedRange];
	NSRange selRange = (curRange.length) ? curRange : [self getRangeForCurrentWord];
	[self setSelectedRange:selRange];
	NSString* convString = [[[self string] substringWithRange:selRange] precomposedStringWithCompatibilityMapping];
	[self insertText:convString];
	
	// correct range for combining characters
	if(curRange.length)
		[self setSelectedRange:NSMakeRange(selRange.location, [convString length])];
	else
		// if no selection place the caret at the end of the current word
	{
		NSRange newRange = [self getRangeForCurrentWord];
		[self setSelectedRange:NSMakeRange(newRange.location + newRange.length, 0)];
	}
}


/*
 * Transpose adjacent characters, or if a selection is given reverse the selected characters.
 * If the caret is at the absolute end of the text field it transpose the two last charaters.
 * If the caret is at the absolute beginnng of the text field do nothing.
 * TODO: not yet combining-diacritics-safe
 */
- (IBAction)doTranspose:(id)sender
{
	NSRange curRange = [self selectedRange];
	NSRange workingRange = curRange;
	
	if(!curRange.length)
		@try // caret is in between two chars
	{
		if(curRange.location+1 > [[self string] length])
		{
			// caret is at the end of a text field
			// transpose last two characters
			[self moveLeftAndModifySelection:self];
			[self moveLeftAndModifySelection:self];
			workingRange = [self selectedRange];
		}
		else if(curRange.location == 0)
		{
			// caret is at the beginning of the text field
			// do nothing
			workingRange.length = 0;
		}
		else
		{
			// caret is in between two characters
			// reverse adjacent characters 
			NSRange twoCharRange = NSMakeRange(curRange.location-1, 2);
			[self setSelectedRange:twoCharRange];
			workingRange = twoCharRange;
		}
	}
	@catch(id ae)
	{ workingRange.length = 0; }
	
	
	
	// reverse string : TODO not yet combining diacritics safe!
	NSUInteger len = workingRange.length;
	if (len > 1)
	{
		NSMutableString *reversedStr = [NSMutableString stringWithCapacity:len];
		while (len > 0)
			[reversedStr appendString:
			 [NSString stringWithFormat:@"%C", [[self string] characterAtIndex:--len+workingRange.location]]];
		
		[self insertText:reversedStr];
		[self setSelectedRange:curRange];
	}
}

/**
 * Move selected lines or current line one line up
 */
- (IBAction)moveSelectionLineUp:(id)sender;
{
	NSRange currentSelection = [self selectedRange];
	NSRange lineRange = [[self string] lineRangeForRange:currentSelection];
	if(lineRange.location > 0) {
		NSRange beforeLineRange = [[self string] lineRangeForRange:NSMakeRange(lineRange.location-1, 0)];
		NSRange insertPoint = NSMakeRange(beforeLineRange.location, 0);
		NSString *currentLine = [[self string] substringWithRange:lineRange];
		BOOL lastLine = NO;
		if([currentLine characterAtIndex:[currentLine length]-1] != '\n') {
			currentLine = [NSString stringWithFormat:@"%@\n", currentLine];
			lastLine = YES;
		}
		[self setSelectedRange:lineRange];
		[self insertText:@""];
		[self setSelectedRange:insertPoint];
		[self insertText:currentLine];
		if(lastLine) {
			[self setSelectedRange:NSMakeRange([[self string] length]-1,1)];
			[self insertText:@""];
			
		}
		if(currentSelection.length)
			insertPoint.length+=[currentLine length];
		[self setSelectedRange:insertPoint];
	}
}

/**
 * Move selected lines or current line one line down
 */
- (IBAction)moveSelectionLineDown:(id)sender
{
	
	NSRange currentSelection = [self selectedRange];
	NSRange lineRange = [[self string] lineRangeForRange:currentSelection];
	if(NSMaxRange(lineRange) < [[self string] length]) {
		NSRange afterLineRange = [[self string] lineRangeForRange:NSMakeRange(NSMaxRange(lineRange), 0)];
		NSRange insertPoint = NSMakeRange(lineRange.location + afterLineRange.length, 0);
		NSString *currentLine = [[self string] substringWithRange:lineRange];
		[self setSelectedRange:lineRange];
		[self insertText:@""];
		[self setSelectedRange:insertPoint];
		if([[self string] characterAtIndex:insertPoint.location-1] != '\n') {
			[self insertText:@"\n"];
			insertPoint.location++;
			currentLine = [currentLine substringToIndex:[currentLine length]-1];
		}
		[self insertText:currentLine];
		if(currentSelection.length)
			insertPoint.length+=[currentLine length];
		[self setSelectedRange:insertPoint];
	}
}

@end
