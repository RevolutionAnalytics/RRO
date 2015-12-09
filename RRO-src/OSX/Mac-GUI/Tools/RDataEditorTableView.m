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
 *  RDataEditorTableView.m
 *
 *  Created by Hans-J. Bibiko on 21/06/2011.
 *
 */

#import "RDataEditorTableView.h"
#import "RGUI.h"
#import "../REditor.h"
#import "../NSArray_RAdditions.h"

@implementation RDataEditorTableView


/**
 * Handles the general Copy action of selected rows as tab delimited data
 */
- (void)copy:(id)sender
{
	NSString *tmp = nil;

	switch([sender tag]) {
		case 0:
		tmp = ([self numberOfSelectedRows]) ? [self rowsAsTabStringWithHeaders:YES] : [self columnsAsTabStringWithHeaders:YES];
		break;
		case 1:
		tmp = ([self numberOfSelectedRows]) ? [self rowsAsCsvStringWithHeaders:YES] : [self columnsAsCsvStringWithHeaders:YES];
		break;
		default:
		NSBeep();
		return;
	}

	if ( nil != tmp )
	{
		NSPasteboard *pb = [NSPasteboard generalPasteboard];

		[pb declareTypes:[NSArray arrayWithObjects:
								NSTabularTextPboardType,
								NSStringPboardType,
								nil]
				   owner:nil];

		[pb setString:tmp forType:NSStringPboardType];
		[pb setString:tmp forType:NSTabularTextPboardType];
	}

}

- (NSUInteger)draggingSourceOperationMaskForLocal:(BOOL)isLocal
{
	return ([[self selectedRowIndexes] count]) ? NSDragOperationCopy : NSDragOperationNone;
}

- (NSString *)rowsAsTabStringWithHeaders:(BOOL)withHeaders
{
	if (![self numberOfSelectedRows]) return nil;

	NSIndexSet *selectedRows = [self selectedRowIndexes];

	NSUInteger i;
	NSArray *columns = [self tableColumns];
	NSUInteger numColumns = [columns count];
	NSMutableString *result = [NSMutableString stringWithCapacity:2000];

	// Add the table headers if requested to do so
	if (withHeaders) {
		for(i = 0; i < numColumns; i++ ){
			if([result length])
				[result appendString:@"\t"];
			[result appendString:[[NSArrayObjectAtIndex([self tableColumns], i) headerCell] title]];
		}
		[result appendString:@"\n"];
	}

	// Loop through the rows, adding their descriptive contents
	NSUInteger rowIndex = [selectedRows firstIndex];
	NSArray *ds = [[self delegate] objectData];
	while ( rowIndex != NSNotFound )
	{
		for ( i = 0; i < numColumns; i++ )
			[result appendFormat:@"%@\t", NSArrayObjectAtIndex(NSArrayObjectAtIndex(ds, i), rowIndex)];

		// Remove the trailing tab and add the linebreak
		if ([result length])
			[result deleteCharactersInRange:NSMakeRange([result length]-1, 1)];

		[result appendString:@"\n"];
	
		// Select the next row index
		rowIndex = [selectedRows indexGreaterThanIndex:rowIndex];
	}
	
	// Remove the trailing line end
	if ([result length]) {
		[result deleteCharactersInRange:NSMakeRange([result length]-1, 1)];
	}

	return result;

}

- (NSString *)rowsAsCsvStringWithHeaders:(BOOL)withHeaders
{
	if (![self numberOfSelectedRows]) return nil;

	NSIndexSet *selectedRows = [self selectedRowIndexes];

	NSUInteger i;
	NSArray *columns = [self tableColumns];
	NSUInteger numColumns = [columns count];
	NSMutableString *result = [NSMutableString stringWithCapacity:2000];

	// Add the table headers if requested to do so
	if (withHeaders) {
		for( i = 0; i < numColumns; i++ ){
			if([result length])
				[result appendString:@","];
			[result appendFormat:@"\"%@\"", [[[NSArrayObjectAtIndex([self tableColumns], i) headerCell] title] stringByReplacingOccurrencesOfString:@"\"" withString:@"\"\""]];
		}
		[result appendString:@"\n"];
	}

	// Loop through the rows, adding their descriptive contents
	NSUInteger rowIndex = [selectedRows firstIndex];
	NSArray *ds = [[self delegate] objectData];
	NSArray *columnTypes = [[self delegate] objectColumnTypes];

	NSInteger types[[columnTypes count]];

	for( i = 0; i < numColumns; i++ )
		types[i] = [NSArrayObjectAtIndex(columnTypes, i) intValue];

	while ( rowIndex != NSNotFound )
	{

		for ( i = 0; i < numColumns; i++ )
			if(types[i] == 1)
				[result appendFormat:@"%@,", NSArrayObjectAtIndex(NSArrayObjectAtIndex(ds, i), rowIndex)];
			else
				[result appendFormat:@"\"%@\",", [NSArrayObjectAtIndex(NSArrayObjectAtIndex(ds, i), rowIndex) stringByReplacingOccurrencesOfString:@"\"" withString:@"\"\""]];

		// Remove the trailing comma and add the linebreak
		if ([result length]){
			[result deleteCharactersInRange:NSMakeRange([result length]-1, 1)];
		}
		[result appendString:@"\n"];

		// Select the next row index
		rowIndex = [selectedRows indexGreaterThanIndex:rowIndex];
	}

	// Remove the trailing line end
	if ([result length]) {
		[result deleteCharactersInRange:NSMakeRange([result length]-1, 1)];
	}

	return result;
}

- (NSString *)columnsAsTabStringWithHeaders:(BOOL)withHeaders
{
	if (![self numberOfSelectedColumns]) return nil;

	NSIndexSet *selectedCols = [self selectedColumnIndexes];
	NSUInteger colIndex = [selectedCols firstIndex];

	NSUInteger i;
	NSMutableString *result = [NSMutableString stringWithCapacity:2000];

	// Add the table headers if requested to do so
	if (withHeaders) {
		while ( colIndex != NSNotFound ) {
			if([result length])
				[result appendString:@"\t"];
			[result appendString:[[NSArrayObjectAtIndex([self tableColumns], colIndex) headerCell] title]];

			// Select the next column index
			colIndex = [selectedCols indexGreaterThanIndex:colIndex];
		}
		[result appendString:@"\n"];
	}

	// Loop through the rows, adding their descriptive contents
	NSArray *ds = [[self delegate] objectData];
	for ( i = 0; i < [NSArrayObjectAtIndex(ds, 0) count]; i++ )
	{
		colIndex = [selectedCols firstIndex];
		while ( colIndex != NSNotFound ) {
			[result appendFormat:@"%@\t", NSArrayObjectAtIndex(NSArrayObjectAtIndex(ds, colIndex), i)];
			// Select the next column index
			colIndex = [selectedCols indexGreaterThanIndex:colIndex];
		}

		// Remove the trailing tab and add the linebreak
		if ([result length])
			[result deleteCharactersInRange:NSMakeRange([result length]-1, 1)];

		[result appendString:@"\n"];
	
	}
	
	// Remove the trailing line end
	if ([result length]) {
		[result deleteCharactersInRange:NSMakeRange([result length]-1, 1)];
	}

	return result;

}

- (NSString *)columnsAsCsvStringWithHeaders:(BOOL)withHeaders
{
	if (![self numberOfSelectedColumns]) return nil;

	NSIndexSet *selectedCols = [self selectedColumnIndexes];
	NSUInteger colIndex = [selectedCols firstIndex];

	NSUInteger i;
	NSMutableString *result = [NSMutableString stringWithCapacity:2000];

	// Add the table headers if requested to do so
	if (withHeaders) {
		while ( colIndex != NSNotFound ) {
			if([result length])
				[result appendString:@","];

			[result appendString:[NSString stringWithFormat:@"\"%@\"",[[[NSArrayObjectAtIndex([self tableColumns], colIndex) headerCell] title] stringByReplacingOccurrencesOfString:@"\"" withString:@"\"\""]]];

			// Select the next column index
			colIndex = [selectedCols indexGreaterThanIndex:colIndex];
		}
		[result appendString:@"\n"];
	}

	// Loop through the rows, adding their descriptive contents
	NSArray *ds = [[self delegate] objectData];
	NSArray *columnTypes = [[self delegate] objectColumnTypes];

	NSInteger types[[columnTypes count]];

	for( i = 0; i < [columnTypes count]; i++ )
		types[i] = [NSArrayObjectAtIndex(columnTypes, i) intValue];

	for ( i = 0; i < [NSArrayObjectAtIndex(ds, 0) count]; i++ )
	{
		colIndex = [selectedCols firstIndex];
		while ( colIndex != NSNotFound ) {

			if(types[colIndex] == 1)
				[result appendFormat:@"%@,", NSArrayObjectAtIndex(NSArrayObjectAtIndex(ds, colIndex), i)];
			else
				[result appendFormat:@"\"%@\",", [NSArrayObjectAtIndex(NSArrayObjectAtIndex(ds, colIndex), i) stringByReplacingOccurrencesOfString:@"\"" withString:@"\"\""]];

			// Select the next column index
			colIndex = [selectedCols indexGreaterThanIndex:colIndex];
		}

		// Remove the trailing comma and add the linebreak
		if ([result length]){
			[result deleteCharactersInRange:NSMakeRange([result length]-1, 1)];
		}
		[result appendString:@"\n"];

	}
	
	// Remove the trailing line end
	if ([result length]) {
		[result deleteCharactersInRange:NSMakeRange([result length]-1, 1)];
	}

	return result;

}

- (CGFloat)widthForColumn:(NSInteger)columnIndex andHeaderName:(NSString*)colName
{

	CGFloat        columnBaseWidth;
	NSString       *contentString;
	NSUInteger     cellWidth, maxCellWidth, i;
	NSRange        linebreakRange;
	double         rowStep;

	NSDictionary *stringAttributes = [NSDictionary dictionaryWithObject:[NSFont systemFontOfSize:[NSFont smallSystemFontSize]]
	 															 forKey:NSFontAttributeName];

	NSCharacterSet *newLineCharSet = [NSCharacterSet newlineCharacterSet];

	NSInteger rowsToCheck = 100;
	NSUInteger maxRows = [[self delegate] numberOfRowsInTableView:self];

	// Check the number of rows available to check, sampling every n rows
	if (maxRows < rowsToCheck)
		rowStep = 1;
	else
		rowStep = floor(maxRows / rowsToCheck);

	rowsToCheck = (rowsToCheck > maxRows) ? maxRows : rowsToCheck;

	// Set a default padding for this column
	columnBaseWidth = 32.0f;

	// Iterate through the data store rows, checking widths
	id ds = [[self delegate] objectData];
	maxCellWidth = 0;
	for (i = 0; i < maxRows; i += rowStep) {

		contentString = NSArrayObjectAtIndex(NSArrayObjectAtIndex(ds, columnIndex), i);
		if ([contentString length] > 500) {
			contentString = [contentString substringToIndex:500];
		}

		// If any linebreaks are present, use only the visible part of the string
		linebreakRange = [contentString rangeOfCharacterFromSet:newLineCharSet];
		if (linebreakRange.location != NSNotFound) {
			contentString = [contentString substringToIndex:linebreakRange.location];
		}

		// Calculate the width, using it if it's higher than the current stored width
		cellWidth = [contentString sizeWithAttributes:stringAttributes].width;
		if (cellWidth > maxCellWidth) maxCellWidth = cellWidth;
		if (maxCellWidth > 400) {
			maxCellWidth = 400;
			break;
		}
	}

	// Add the padding
	maxCellWidth += columnBaseWidth;

	// If the header width is wider than this expanded width, use it instead
	if(colName) {
		cellWidth = [colName sizeWithAttributes:[NSDictionary dictionaryWithObject:[NSFont labelFontOfSize:[NSFont smallSystemFontSize]] forKey:NSFontAttributeName]].width;
		if (cellWidth + columnBaseWidth > maxCellWidth) maxCellWidth = cellWidth + columnBaseWidth;
		if (maxCellWidth > 400) maxCellWidth = 400;
	}

	return maxCellWidth;
}

- (void)setFont:(NSFont *)font;
{
	NSArray *tableColumns = [self tableColumns];
	NSUInteger columnIndex = [tableColumns count];
	
	while (columnIndex--) 
	{
		[[(NSTableColumn *)[tableColumns objectAtIndex:columnIndex] dataCell] setFont:font];
	}
}

- (BOOL)control:(NSControl *)control textView:(NSTextView *)textView doCommandBySelector:(SEL)command
{

	SLog(@"RDataEditorTableView received selector %@", NSStringFromSelector(command));

	NSInteger row, column;

	row = [self editedRow];
	column = [self editedColumn];

	// Trap down arrow key
	if ( [textView methodForSelector:command] == [textView methodForSelector:@selector(moveDown:)] )
	{

		NSInteger newRow = row+1;
		if (newRow >= [[self delegate] numberOfRowsInTableView:self]) return YES; //check if we're already at the end of the list

		[[control window] makeFirstResponder:control];

		[self selectRowIndexes:[NSIndexSet indexSetWithIndex:newRow] byExtendingSelection:NO];
		[self editColumn:column row:newRow withEvent:nil select:YES];
		return YES;

	}

	// Trap up arrow key
	else if ( [textView methodForSelector:command] == [textView methodForSelector:@selector(moveUp:)] )
	{

		if (row==0) return YES; //already at the beginning of the list
		NSInteger newRow = row-1;

		if (newRow>=[[self delegate] numberOfRowsInTableView:self]) return YES; // saveRowToTable could reload the table and change the number of rows
		[[control window] makeFirstResponder:control];

		[self selectRowIndexes:[NSIndexSet indexSetWithIndex:newRow] byExtendingSelection:NO];
		[self editColumn:column row:newRow withEvent:nil select:YES];
		return YES;
	}

	return NO;

}

- (void)keyDown:(NSEvent*)theEvent
{
	long allFlags = (NSShiftKeyMask|NSControlKeyMask|NSAlternateKeyMask|NSCommandKeyMask);
	long curFlags = ([theEvent modifierFlags] & allFlags);

	// Check if user pressed ⌥ to allow composing of accented characters.
	// e.g. for US keyboard "⌥u a" to insert ä
	// or for non-US keyboards to allow to enter dead keys
	// e.g. for German keyboard ` is a dead key, press space to enter `
	if ((curFlags & allFlags) == NSAlternateKeyMask || [[theEvent characters] length] == 0) {
		[super keyDown:theEvent];
		return;
	}

	NSString *charactersIgnMod = [theEvent charactersIgnoringModifiers];

	// ⇧⌥⌘C - add col as CHARACTER
	if(((curFlags & allFlags) == (NSCommandKeyMask|NSAlternateKeyMask|NSShiftKeyMask)) && [charactersIgnMod isEqualToString:@"C"]) {
		NSMenuItem *m = [[NSMenuItem alloc] initWithTitle:@"" action:nil keyEquivalent:@""];
		[m setTag:2];
		[[self delegate] addCol:m];
		[m release];
		return;
	}

	// ⌥⌘C - add col as NUMERIC
	if(((curFlags & allFlags) == (NSCommandKeyMask|NSAlternateKeyMask)) && [charactersIgnMod isEqualToString:@"c"]) {
		NSMenuItem *m = [[NSMenuItem alloc] initWithTitle:@"" action:nil keyEquivalent:@""];
		[m setTag:1];
		[[self delegate] addCol:m];
		[m release];
		return;
	}

	// ⌥⌘A - add row
	if(((curFlags & allFlags) == (NSCommandKeyMask|NSAlternateKeyMask)) && [charactersIgnMod isEqualToString:@"a"]) {
		[[self delegate] addRow:nil];
		return;
	}

	// ^⌥⌘⎋ cancel editing without saving data
	if(((curFlags & allFlags) == (NSControlKeyMask|NSAlternateKeyMask|NSCommandKeyMask)) && [theEvent keyCode] == 51) {
		[[self delegate] cancelEditing:nil];
		return;
	}

	// ⌘⌫ delete selected rows or columns according to selection
	if((curFlags & allFlags) == NSCommandKeyMask && [theEvent keyCode] == 51) {
		if([[self selectedColumnIndexes] count])
			[[self delegate] remCols:nil];
		else if([[self selectedRowIndexes] count])
			[[self delegate] remRows:nil];
		else
			NSBeep();
		return;
	}

	[super keyDown:theEvent];

}

- (BOOL)validateMenuItem:(NSMenuItem*)menuItem
{
	if ([menuItem action] == @selector(copy:)) {
		return ([self numberOfSelectedRows] > 0 || [self numberOfSelectedColumns] > 0);
	}
	if ([menuItem action] == @selector(remSelection:)) {
		return ([[self selectedColumnIndexes] count] || [[self selectedRowIndexes] count]);
	}

	return YES;

}

@end
