/*
 *  R.app : a Cocoa front end to: "R A Computer Language for Statistical Data Analysis"
 *  
 *  R.app Copyright notes:
 *                     Copyright (C) 2004-11  The R Foundation
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
 *  RDataEditorTableHeaderCell.m
 *
 *  Created by Hans-J. Bibiko on 24/06/2011.
 *
 */

#import "RDataEditorTableHeaderCell.h"


@implementation RDataEditorTableHeaderCell

- (id)initTextCell:(NSString *)aString
{
	if(orgTitle) [orgTitle release];
	if(!aString) aString = @"";
	orgTitle = [aString copy];
	return [super initTextCell:aString];
}

- (BOOL)isEditable
{
	return YES;
}

- (BOOL)acceptsFirstResponder
{
	return YES;
}

- (BOOL)refusesFirstResponder
{
	return NO;
}

- (NSString*)titleBeforeEditing
{
	return (orgTitle) ? orgTitle : @"";
}

- (void)hideTitle
{
	if(orgTitle) [orgTitle release];
	orgTitle = [[self title] retain];
	[self setTitle:@""];
}

- (void)dealloc
{
	if(orgTitle) [orgTitle release];
	[super dealloc];
}

- (id)copyWithZone:(NSZone *)zone
{
	id newCopy = [super copyWithZone:zone];
	[orgTitle retain];
	return newCopy;
}

@end
