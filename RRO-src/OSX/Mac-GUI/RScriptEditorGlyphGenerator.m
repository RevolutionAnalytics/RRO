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
 *  RScriptEditorGlyphGenerator.m
 *
 *  Created by Hans-J. Bibiko on 01/03/2012.
 *
 */

#import "RScriptEditorGlyphGenerator.h"
#import "RScriptEditorTypesetter.h"
#import "RScriptEditorTextStorage.h"
#import "RScriptEditorLayoutManager.h"
#import "PreferenceKeys.h"

static SEL _attrStrSel;
static SEL _foldSel;
static SEL _foldindSel;

@implementation RScriptEditorGlyphGenerator

+ (void)initialize
{
	if ([self class] == [RScriptEditorGlyphGenerator class]) {
		_attrStrSel = @selector(attributedString);
		_foldSel    = @selector(foldedRangeAtIndex:);
		_foldindSel = @selector(foldedForIndicatorAtIndex:);
	}
}

- (id)init
{
	self = [super init];

	if (self != nil) {
		_attrStrImp = [self methodForSelector:_attrStrSel];
		nullGlyph = NSNullGlyph;
		sizeOfNSGlyph = sizeof(NSGlyph);
	}

	return self;
}

- (void)dealloc{
	if(theTextStorage) [theTextStorage release];
	[super dealloc];
}

- (void)setTextStorage:(RScriptEditorTextStorage*)textStorage
{
	if(theTextStorage) [theTextStorage release];
	theTextStorage = [textStorage retain];
	_foldImp = [theTextStorage methodForSelector:_foldSel];
	_foldindImp = [theTextStorage methodForSelector:_foldindSel];
}

- (void)generateGlyphsForGlyphStorage:(id <NSGlyphStorage>)glyphStorage desiredNumberOfCharacters:(NSUInteger)nChars glyphIndex:(NSUInteger *)glyphIndex characterIndex:(NSUInteger *)charIndex
{
	// Stash the original requester
	_destination = glyphStorage;
	[[NSGlyphGenerator sharedGlyphGenerator] generateGlyphsForGlyphStorage:self desiredNumberOfCharacters:nChars glyphIndex:glyphIndex characterIndex:charIndex];
	_destination = nil;
}

#pragma mark -
#pragma mark NSGlyphStoragePrimitives

- (void)insertGlyphs:(const NSGlyph *)glyphs length:(NSUInteger)length forStartingGlyphAtIndex:(NSUInteger)glyphIndex characterIndex:(NSUInteger)charIndex
{
	NSGlyph *buffer = NULL;
	NSInteger folded = (NSInteger)(*_foldindImp)(theTextStorage, _foldSel, charIndex);

	if (folded > -1) {
		NSRange effectiveRange = [theTextStorage foldedRangeAtIndex:folded];
		if(effectiveRange.length) {
			NSInteger size = sizeOfNSGlyph * length;
			buffer = NSZoneMalloc(NULL, size);
			memset_pattern4(buffer, &nullGlyph, size);
			if ((effectiveRange.location+1) == charIndex) buffer[0] = NSControlGlyph;
			glyphs = buffer;
		}
	}

	[_destination insertGlyphs:glyphs length:length forStartingGlyphAtIndex:glyphIndex characterIndex:charIndex];

	if (buffer) NSZoneFree(NULL, buffer);
}

- (void)setIntAttribute:(NSInteger)attributeTag value:(NSInteger)val forGlyphAtIndex:(NSUInteger)glyphIndex
{
	[_destination setIntAttribute:attributeTag value:val forGlyphAtIndex:glyphIndex];
}

- (NSAttributedString *)attributedString
{
	return [_destination attributedString];
}

- (NSUInteger)layoutOptions
{
	return [_destination layoutOptions] | NSShowControlGlyphs;
}

@end
