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
 *  RScriptEditorLayoutManager.m
 *
 *  Created by Hans-J. Bibiko on 01/03/2012.
 *
 */

#import "RScriptEditorLayoutManager.h"
#import "RScriptEditorTypeSetter.h"
#import "RScriptEditorGlyphGenerator.h"
#import "RScriptEditorTextStorage.h"
#import "PreferenceKeys.h"

@implementation RScriptEditorLayoutManager

- (id)init
{

	self = [super init];
    
	if (nil == self) return nil;

	// Setup LineFoldingTypesetter
	RScriptEditorTypeSetter *typesetter = [[RScriptEditorTypeSetter alloc] init];
	[self setTypesetter:typesetter];
	[typesetter release];
	
	// Setup LineFoldingGlyphGenerator
	RScriptEditorGlyphGenerator *glyphGenerator = [[RScriptEditorGlyphGenerator alloc] init];
	[self setGlyphGenerator:glyphGenerator];
	[glyphGenerator release];

	[self setBackgroundLayoutEnabled:NO];

	return self;

}

- (void)dealloc
{
	if(_attributedString) [_attributedString release];
	[super dealloc];
}

- (void)replaceTextStorage:(id)textStorage
{
	if(_attributedString) [_attributedString release];
	_attributedString = [(RScriptEditorTextStorage*)textStorage retain];
	[(RScriptEditorGlyphGenerator*)[self glyphGenerator] setTextStorage:textStorage];
	[super replaceTextStorage:textStorage];
}

@end
