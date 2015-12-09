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
 *  RScriptEditorTypeSetter.m
 *
 *  Created by Hans-J. Bibiko on 01/03/2012.
 *
 */

#import "RScriptEditorTypeSetter.h"
#import "PreferenceKeys.h"


@implementation RScriptEditorTypeSetter

static SEL _foldSel;

- (id)init
{
	self = [super init];
	if (nil == self) return nil;
	_attributedString = nil;
	_foldSel = @selector(foldedForIndicatorAtIndex:);
	return self;
}

- (void)dealloc
{
	if(_attributedString) [_attributedString release];
	[super dealloc];
}

- (void)setTextStorage:(RScriptEditorTextStorage*)textStorage
{
	if(_attributedString) [_attributedString release];
	_attributedString = [textStorage retain];
	_foldImp  = [_attributedString methodForSelector:_foldSel];

}

- (NSTypesetterControlCharacterAction)actionForControlCharacterAtIndex:(NSUInteger)charIndex
{
	if ((NSInteger)(*_foldImp)(_attributedString, _foldSel, charIndex) > -1) return NSTypesetterZeroAdvancementAction;
	return [super actionForControlCharacterAtIndex:charIndex];
}

@end
 