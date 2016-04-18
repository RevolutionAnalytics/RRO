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
 *  REditor.m
 *
 */

#include <R.h>
#include <R_ext/Boolean.h>
#include <R_ext/Rdynload.h>
#include <Rinternals.h>
#include <Rversion.h>
void Rf_PrintDefaults(void);
const char *Rf_EncodeElement(SEXP, int, int, char);

#import "RGUI.h"
#import "REditor.h"
#import "Tools/RDataEditorTableHeaderCell.h"
#import "NSArray_RAdditions.h"

#ifndef max
#define max(x,y) x<y?y:x;
#endif

static id sharedDEController;

extern SEXP work, names, lens, ssNA_STRING;
extern SEXP ssNewVector(SEXPTYPE type, int vlen);
extern int xmaxused, ymaxused, nprotect;
extern double ssNA_REAL;
extern PROTECT_INDEX wpi, npi, lpi;

typedef enum { UP, DOWN, LEFT, RIGHT } DE_DIRECTION;
typedef enum { UNKNOWNN, NUMERIC, CHARACTER } CellType;

int newvar;

BOOL IsDataEntry;

const char *get_col_name(int col)
{
	static char clab[25];
	if (col <= xmaxused) {
		// don't use NA labels
		SEXP tmp = STRING_ELT(names, col);
		if(tmp != NA_STRING) return(CHAR(tmp));
	}
	sprintf(clab, "var%d", col);
	return clab;
}

void printelt(SEXP invec, int vrow, char *strp)
{

	if(!strp) return;

	Rf_PrintDefaults();
	if (TYPEOF(invec) == REALSXP) {
		if (REAL(invec)[vrow] != ssNA_REAL) {
			strcpy(strp, Rf_EncodeElement(invec, vrow, 0, '.'));
			return;
		}
	}
	else if (TYPEOF(invec) == STRSXP) {
		if(CHAR(STRING_ELT(invec, vrow))){
			if ( strcmp( CHAR(STRING_ELT(invec, vrow)),
						  CHAR(STRING_ELT(ssNA_STRING, 0)) ) ) {
				strcpy(strp, Rf_EncodeElement(invec, vrow, 0, '.'));
				return;
			}
		}
	}
	else
		error("dataentry: internal memory error"); // FIXME: localize
}

@implementation REditor

- (id)init
{

	self = [super init];
	if (self) {
		if (!sharedDEController)
			sharedDEController = [self retain];

		// Add your subclass-specific initialization here.
		// If an error occurs here, send a [self release] message and return nil.

		toolbar = nil;
		editedColumnNameIndex = -1;
		objectData = [[NSMutableArray alloc] initWithCapacity:10];
		objectColumnNames = [[NSMutableArray alloc] initWithCapacity:10];
		objectColumnTypes = [[NSMutableArray alloc] initWithCapacity:10];
		numberOfColumns = 0;
		numberOfRows = 0;
	}

	return self;

}

- (void)awakeFromNib
{

	[editorSource setColumnAutoresizingStyle:NSTableViewUniformColumnAutoresizingStyle];
	[self setupToolbar];
	// Since the window will be listed in the main menu > windows after closing
	// let it not listed there at all (and due to the fact that it's a modal window
	// it's not needed to have it there)
	[dataWindow setExcludedFromWindowsMenu:YES];

}

#pragma mark -

+ (id)getDEController
{
	return sharedDEController;
}


+ (void)startDataEntry
{

	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

	newvar = 0;

	[[REditor getDEController] setDataTable:YES];
	[[[REditor getDEController] window] orderFront:self];

	NSInteger ret = [NSApp runModalForWindow:[[REditor getDEController] window]];

	// if modal session was aborted cancel edit()
	if( ret == NSRunAbortedResponse )
		error([NLS(@"editing cancelled") UTF8String]);

	[pool release];

}

#define NA_CHARS " <NA> "
- (BOOL)writeDataBackToObject
{
	NSInteger buflen = 256;
	NSInteger i, j;
	NSInteger nCols = [[editorSource tableColumns] count];
	NSInteger nRows = (nCols) ? [[objectData objectAtIndex:0] count] : 0;
	NSInteger colType;
	SEXP work3, names3;

	numberOfRows = 0;

	PROTECT(work3  = allocVector(VECSXP, nCols)); nprotect++;
	PROTECT(names3 = allocVector(STRSXP, nCols)); nprotect++;

	for(i = 0; i < nCols; i++) {

		SET_VECTOR_ELT(work3, i, ssNewVector(([NSArrayObjectAtIndex(objectColumnTypes, i) intValue] == NUMERIC) ? REALSXP : STRSXP, nRows));

		SEXP tmp = VECTOR_ELT(work3, i);
		SET_STRING_ELT(names3, i, mkChar([NSArrayObjectAtIndex(objectColumnNames, i) UTF8String]));

		colType = [NSArrayObjectAtIndex(objectColumnTypes, i) intValue];
		for(j = 0; j < nRows; j++) {

			NSString *anObject = NSArrayObjectAtIndex(NSArrayObjectAtIndex(objectData, i), j);
			buflen = 256;

			// get the number of utf-8 bytes for CHARACTER type
			if(colType == CHARACTER)
				buflen = strlen([anObject UTF8String])+2;

			char buf[buflen];
			buf[0] = '\0';

			CFStringGetCString((CFStringRef)anObject, buf, buflen-1, kCFStringEncodingUTF8);

			switch(colType) {

				case NUMERIC:
				if(buf[0] == '\0')
					REAL(tmp)[j] = NA_REAL;
				 else {
					char *endp;
					double new = R_strtod(buf, &endp);
					REAL(tmp)[j] = new;
				 }
				break;

				case CHARACTER:
//				if(buf[0] == '\0')
				    if(strcmp(buf, NA_CHARS) == 0)
					SET_STRING_ELT(tmp, j, NA_STRING);
				 else
					SET_STRING_ELT(tmp, j, mkChar(buf));

				break;

				default:
				return NO;
				break;

			}
		}
	}
	
	REPROTECT(work  = allocVector(VECSXP, nCols), wpi);
	REPROTECT(names = allocVector(STRSXP, nCols), npi);

	xmaxused = nCols;

	for (i = 0; i < nCols; i++) {
		SET_VECTOR_ELT(work,  i, VECTOR_ELT(work3,  i));
		SET_STRING_ELT(names, i, STRING_ELT(names3, i));
		INTEGER(lens)[i] = nRows;
	}

	return YES;
}

- (BOOL)initData
{

	numberOfRows = 0;
	numberOfColumns = 0;

	if(objectData) [objectData release], objectData = nil;
	if(objectColumnNames) [objectColumnNames release], objectColumnNames = nil;
	if(objectColumnTypes) [objectColumnTypes release], objectColumnTypes = nil;
	objectData = [[NSMutableArray alloc] initWithCapacity:xmaxused];
	objectColumnNames = [[NSMutableArray alloc] initWithCapacity:xmaxused];
	objectColumnTypes = [[NSMutableArray alloc] initWithCapacity:xmaxused];

	numberOfRows = ymaxused;

	NSInteger i;
	NSNumber *charNumber = [NSNumber numberWithInt:CHARACTER];
	NSNumber *numNumber  = [NSNumber numberWithInt:NUMERIC];

	for(i = 0; i < xmaxused; i++) {
		SEXP tmp = VECTOR_ELT(work, i);
		if (isNull(tmp)) {
			NSBeep();
			error([NLS(@"R Data Editor - error while reading object data") UTF8String]);
			return NO;
			break;
		}
		CFArrayAppendValue((CFMutableArrayRef)objectColumnTypes, (TYPEOF(tmp) == STRSXP) ? charNumber : numNumber);
		CFArrayAppendValue((CFMutableArrayRef)objectColumnNames, CFStringCreateWithCString(NULL, get_col_name(i), kCFStringEncodingUTF8));
		if(TYPEOF(tmp) == STRSXP) {

			NSUInteger k=0, l=LENGTH(tmp);
			id *cont=(id *)malloc(sizeof(id)*l);
			while (k<l) {
				if ( strcmp( CHAR(STRING_ELT(tmp, k)), CHAR(STRING_ELT(ssNA_STRING, 0)) ) )
					cont[k] = (NSString*)CFStringCreateWithCString(NULL, CHAR(STRING_ELT(tmp, k)), kCFStringEncodingUTF8);
				else
					cont[k] = @NA_CHARS;
				k++;
			}
			NSArray *a = [NSArray arrayWithObjects:cont count:l];
			k=0;
			while (k<l) [cont[k++] release];
			free(cont);

			CFArrayAppendValue((CFMutableArrayRef)objectData, [a mutableCopy]);

		}
		else if(TYPEOF(tmp) == REALSXP){

			NSUInteger k=0, l=LENGTH(tmp);
			id *cont = malloc(sizeof(id)*l);
			while (k<l) {

				cont[k] = (NSString*)CFStringCreateWithCString(NULL, Rf_EncodeElement(tmp, k, 0, '.'), kCFStringEncodingASCII);

				k++;
			}
			NSArray *a = [NSArray arrayWithObjects:cont count:l];
			k=0;
			while (k<l) [cont[k++] release];
			free(cont);

			CFArrayAppendValue((CFMutableArrayRef)objectData, [a mutableCopy]);

		}
		else {
			NSBeep();
			error([NLS(@"R Data Editor - error while reading object data") UTF8String]);
			return NO;
		}
	}

	numberOfColumns = xmaxused;

	return YES;

}

- (void)setDataTable:(BOOL)removeAll
{

	if(removeAll)
		if(![self initData]) return;

	NSInteger i;
	NSArray *theColumns = [editorSource tableColumns];

	while ([theColumns count])
		[editorSource removeTableColumn:NSArrayObjectAtIndex(theColumns ,0)];

	if(!objectData) return;

	for (i = 0; i < numberOfColumns; i++) {
		NSTableColumn *col = [[NSTableColumn alloc] initWithIdentifier:[NSString stringWithFormat:@"%ld", i]];
		NSString *colName  = NSArrayObjectAtIndex(objectColumnNames, i);
		NSInteger colType  = [NSArrayObjectAtIndex(objectColumnTypes, i) intValue];
		if(colName) {
			RDataEditorTableHeaderCell *c = [[RDataEditorTableHeaderCell alloc] initTextCell:colName];
			[col setHeaderCell:c];
			[c release];
			[[col headerCell] setAlignment:NSCenterTextAlignment];
			[col setHeaderToolTip:[NSString stringWithFormat:@"%@\n  (%@)", colName,
				(colType == NUMERIC) ? @"numeric" : @"character"]];
		}
		[col setResizingMask:NSTableColumnUserResizingMask];
		[col setEditable:YES];
		// set text cell alignment to 'right' for numeric values
		if(colType == NUMERIC) [[col dataCell] setAlignment:NSRightTextAlignment];
		[col setMinWidth:18.0f];
		[col setMaxWidth:1000.0f];
		[editorSource addTableColumn:col];
		[col release];
	}

	// column auto-sizing
	for(i = 0; i < numberOfColumns; i++) {
		[[editorSource tableColumnWithIdentifier:[NSString stringWithFormat:@"%ld", i]] setWidth:
				[editorSource widthForColumn:i andHeaderName:NSArrayObjectAtIndex(objectColumnNames, i)]];
		if(i+1 < numberOfColumns)
			[[[[editorSource tableColumnWithIdentifier:[NSString stringWithFormat:@"%ld", i]] headerCell] controlView] setNextKeyView:[[[editorSource tableColumnWithIdentifier:[NSString stringWithFormat:@"%ld", i+1]] headerCell] controlView]];
		else if(i-1 == numberOfColumns)
			[[[[editorSource tableColumnWithIdentifier:[NSString stringWithFormat:@"%ld", i]] headerCell] controlView] setNextKeyView:editorSource];
	}

	[editorSource sizeLastColumnToFit];

	//tries to fix problem with last row
	if ( [[editorSource tableColumnWithIdentifier:[NSString stringWithFormat:@"%ld", numberOfColumns-1]] width] < 30 )
		[[editorSource tableColumnWithIdentifier:[NSString stringWithFormat:@"%ld", numberOfColumns-1]]
				setWidth:[[editorSource tableColumnWithIdentifier:[NSString stringWithFormat:@"%ld", 0L]] width]];

	[editorSource reloadData];

}

- (void)editColumnNameOfTableColumn:(NSTableColumn *)aTableColumn
{

	RDataEditorTableHeaderCell *headerCellEditor = [aTableColumn headerCell];
	NSText *editor = [[[REditor getDEController] window] fieldEditor:YES forObject:headerCellEditor];
	editedColumnNameIndex = [[aTableColumn identifier] intValue];
	[editor setFieldEditor:YES];
	NSRect r = [[editorSource headerView] headerRectOfColumn:editedColumnNameIndex];
	r = NSInsetRect(r, 0.0f, 1.0f);
	[headerCellEditor editWithFrame: r
							 inView:[editorSource headerView] 
							 editor:editor 
						   delegate:self 
							  event:nil];

	[headerCellEditor hideTitle];
	[editor selectAll:nil];

}

- (NSArray*)objectData
{
	return objectData;
}

- (NSArray*)objectColumnTypes
{
	return objectColumnTypes;
}

- (void)clearData
{
	[objectColumnTypes removeAllObjects];
	[objectColumnNames removeAllObjects];
	[objectData removeAllObjects];
}

- (void)dealloc
{
	if(objectColumnTypes) [objectColumnTypes release];
	if(objectColumnNames) [objectColumnNames release];
	if(objectData) [objectData release];
	[super dealloc];
}

#pragma mark -

- (id)window
{
	return dataWindow;
}

#pragma mark -
#pragma mark NSWindow delegates

- (BOOL)windowShouldClose:(id)sender
{

	// Make sure that any pending changes will be stored before closing
	if(editedColumnNameIndex > -1)
		[self textView:(NSTextView*)[[NSApp keyWindow] firstResponder] doCommandBySelector:@selector(insertNewline:)];
	[[[REditor getDEController] window] makeFirstResponder:editorSource];

	if(![self writeDataBackToObject]) {
		error([NLS(@"R Data Editor couldn't write object data") UTF8String]);
	}

	if(IsDataEntry){
		[NSApp stopModal];
		IsDataEntry = NO;
	}

	return YES;

}

#pragma mark -
#pragma mark NSTableView delegates

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView
{
	return numberOfRows;
}

- (void)tableViewSelectionIsChanging:(NSNotification *)aNotification
{
	if([[[NSApp keyWindow] firstResponder] isKindOfClass:[NSTableView class]] && editedColumnNameIndex > -1) {
		// Submit pending changes
		[self textView:(NSTextView*)[[NSApp keyWindow] firstResponder] doCommandBySelector:@selector(insertNewline:)];
		editedColumnNameIndex = -1;
	}
}

- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{
	if(row < 0) return @"…";
	int col = (int) [[tableColumn identifier] intValue];
	if (col >= [objectData count]) return @"…";
	NSArray *a = NSArrayObjectAtIndex(objectData, col);
	if (!a || row >= [a count]) return @"…";
	return NSArrayObjectAtIndex(a, row);
}

- (void)tableView:(NSTableView *)aTableView setObjectValue:(id)anObject forTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{

	if(row < 0) return;

	NSInteger col = [[tableColumn identifier] intValue];

	if([[objectColumnTypes objectAtIndex:col] intValue] == NUMERIC) {
		// validate NUMERIC value
		char *endp;
		(void)R_strtod([anObject UTF8String], &endp);
		if(strlen(endp))
			[[objectData objectAtIndex:col] replaceObjectAtIndex:row withObject:@"NA"];
		else {
			[[objectData objectAtIndex:col] replaceObjectAtIndex:row withObject:anObject];
		}
	} else {
		[[objectData objectAtIndex:col] replaceObjectAtIndex:row withObject:anObject];
	}

	// resize column width
	CGFloat newSize = [editorSource widthForColumn:col andHeaderName:(NSString*)anObject];
	if(newSize > [tableColumn width]) [tableColumn setWidth:newSize];

	return;

}

/**
 * Enable drag from tableview
 */
- (BOOL)tableView:(NSTableView *)aTableView writeRowsWithIndexes:(NSIndexSet *)rows toPasteboard:(NSPasteboard*)pboard
{

	if (aTableView == editorSource) {
		NSString *tmp;

		// By holding ⌘ or/and ⌥ copies selected rows as CSV
		// otherwise \t delimited lines
		if([[NSApp currentEvent] modifierFlags] & (NSCommandKeyMask|NSAlternateKeyMask))
			tmp = [editorSource rowsAsCsvStringWithHeaders:YES];
		else
			tmp = [editorSource rowsAsTabStringWithHeaders:YES];

		if ( nil != tmp && [tmp length] )
		{
			[pboard declareTypes:[NSArray arrayWithObjects:NSTabularTextPboardType,
								  NSStringPboardType, nil]
						   owner:nil];

			[pboard setString:tmp forType:NSStringPboardType];
			[pboard setString:tmp forType:NSTabularTextPboardType];
			return YES;
		}
	}

	return NO;
}

- (void)tableView:(NSTableView *)tableView mouseDownInHeaderOfTableColumn:(NSTableColumn *)tableColumn
{
	// Go into column name editing mode if user did a double-click at the column's header
	if([[NSApp currentEvent] clickCount] > 1) {
		[self editColumnNameOfTableColumn:tableColumn];
	}

}

#pragma mark -
#pragma mark NSText delegates

- (BOOL)textView:(NSTextView *)aTextView doCommandBySelector:(SEL)commandSelector
{

	SLog(@"REditor:textView:doCommandBySelector: %@ %@", [aTextView class], NSStringFromSelector(commandSelector));

	if(editedColumnNameIndex < 0) return NO;

	// Trap ESC while editing column names to cancel editing
	if (@selector(cancelOperation:) == commandSelector) {
		NSTableColumn *col = [editorSource tableColumnWithIdentifier:[NSString stringWithFormat:@"%ld", editedColumnNameIndex]];
		[[col headerCell] setTitle:[[col headerCell] titleBeforeEditing]];
		editedColumnNameIndex = -1;
		[[[[REditor getDEController] window] fieldEditor:NO forObject:[col headerCell]] setFieldEditor:YES];
		[[[REditor getDEController] window] makeFirstResponder:editorSource];
		[[[REditor getDEController] window] endEditingFor:[col headerCell]];
		[[editorSource headerView] setNeedsDisplay:YES];
		return YES;
	}

	// Trap RETURN, TAB, SHIFT+TAB while editing column names to end editing and 
	// storing the new column name after validation; in addition for TABs edit
	// the next/previous column name if possible
	if (   @selector(insertNewline:) == commandSelector
		|| @selector(insertTab:)     == commandSelector
		|| @selector(insertBacktab:) == commandSelector
		) {

		NSTableColumn *col = [editorSource tableColumnWithIdentifier:[NSString stringWithFormat:@"%ld", editedColumnNameIndex]];
		if(![[[REditor getDEController] window] fieldEditor:NO forObject:[col headerCell]]) return NO;
		NSString *newColumnName = [[[[[REditor getDEController] window] fieldEditor:NO forObject:[col headerCell]] string] copy];

		// validate newColumnName
		BOOL newNameIsValid = YES;
		if(!newColumnName || ![newColumnName length]) newNameIsValid = NO;
		if(newNameIsValid) {
			NSArray *allCols = [editorSource tableColumns];
			NSInteger i;
			for(i = 0; i < [allCols count]; i++) {
				if([[[[allCols objectAtIndex:i] headerCell] title] isEqualToString:newColumnName]) {
					newNameIsValid = NO;
					break;
				}
			}
		}

		if(newNameIsValid) {
			[[col headerCell] setTitle:newColumnName];
			[col setHeaderToolTip:[NSString stringWithFormat:@"%@\n  (%@)", newColumnName,
				([[objectColumnTypes objectAtIndex:editedColumnNameIndex] intValue] == NUMERIC) ? @"numeric" : @"character"]];
			[objectColumnNames replaceObjectAtIndex:[[col identifier] intValue] withObject:newColumnName];
		} else {
			[[col headerCell] setTitle:[[col headerCell] titleBeforeEditing]];
			if([aTextView isKindOfClass:[NSTextView class]] && ![[[col headerCell] title] isEqualToString:newColumnName])
				NSBeep();
		}

		[[[[REditor getDEController] window] fieldEditor:NO forObject:[col headerCell]] setFieldEditor:YES];
		[[[REditor getDEController] window] makeFirstResponder:editorSource];
		[[[REditor getDEController] window] endEditingFor:[col headerCell]];

		[[[col headerCell] controlView] display];
		[[editorSource headerView] display];
		[newColumnName release];
		// TAB select next column name if any
		if(@selector(insertTab:) == commandSelector) {
			if(editedColumnNameIndex + 1 < [[editorSource tableColumns] count]) {
				NSInteger i = editedColumnNameIndex;
				editedColumnNameIndex = -1;
				[self editColumnNameOfTableColumn:[[editorSource tableColumns] objectAtIndex:i+1]];
				return YES;
			}
		}
		// SHIFT+TAB select previous column name if any
		else if(@selector(insertBacktab:) == commandSelector) {
			if(editedColumnNameIndex > 0) {
				NSInteger i = editedColumnNameIndex;
				editedColumnNameIndex = -1;
				[self editColumnNameOfTableColumn:[[editorSource tableColumns] objectAtIndex:i-1]];
				return YES;
			}
		}

		editedColumnNameIndex = -1;

		return (![aTextView isKindOfClass:[NSTextView class]]);
	}

	return NO;

}

/**
 * Trap ESC,⇡, and ⇣ inside TableView
 */
- (BOOL)control:(NSControl*)control textView:(NSTextView*)aTextView doCommandBySelector:(SEL)command
{

	if([control isKindOfClass:[RDataEditorTableView class]]) {

		// Check firstly if RDataEditorTableView can handle command (handle ⇡ ⇣)
		if([editorSource control:control textView:aTextView doCommandBySelector:(SEL)command])
			return YES;

		// Trap the escape key to abort editing
		if ([[control window] methodForSelector:command] == [[control window] methodForSelector:@selector(cancelOperation:)])
		{
			// Abort editing
			[control abortEditing];
			[[[REditor getDEController] window] makeFirstResponder:editorSource];
			return YES;
		}

	}

	return NO;

}

#pragma mark -
#pragma mark Toolbar Methods

- (void)setupToolbar
{

	// Create a new toolbar instance, and attach it to our document window
	toolbar = [[NSToolbar alloc] initWithIdentifier:DataEditorToolbarIdentifier];

	// Set up toolbar properties: Allow customization, give a default display mode, and remember state in user defaults
	[toolbar setAllowsUserCustomization:YES];
	[toolbar setAutosavesConfiguration:YES];
	[toolbar setDisplayMode:NSToolbarDisplayModeIconOnly];

	// We are the delegate
	[toolbar setDelegate:self];

	// Attach the toolbar to the document window
	[dataWindow setToolbar:toolbar];
}

- (NSToolbarItem *)toolbar:(NSToolbar *)toolbar itemForItemIdentifier:(NSString *)itemIdent willBeInsertedIntoToolbar:(BOOL)willBeInserted
{
	// Required delegate method:  Given an item identifier, this method returns an item
	// The toolbar will use this method to obtain toolbar items that can be displayed in the customization sheet, or in the toolbar itself
	// NSLog(@"toolbar: %@ itemForItemIdentifier:%@ willBeInsertedIntoToolbar:%d\n", toolbar, itemIdent, willBeInserted);
	NSToolbarItem *toolbarItem = [[[NSToolbarItem alloc] initWithItemIdentifier:itemIdent] autorelease];

	if ([itemIdent isEqual:AddColToolbarItemIdentifier]) {
		// Set the text label to be displayed in the toolbar and customization palette
		[toolbarItem setLabel:NLSC(@"Add Col", @"Add column - label for a toolbar, keep short!")];
		[toolbarItem setPaletteLabel:NLS(@"Add Column")];

		// Set up a reasonable tooltip, and image   Note, these aren't localized, but you will likely want to localize many of the item's properties
		[toolbarItem setToolTip:[NSString stringWithFormat:
			NLS(@"Adds a new column to the right of a group of selected columns or just at the end of the data. The new column type complies with that column left of it.\n\n(%@)\tAdd column of type ‘CHARACTER’\n(%@)\tAdd column of type ‘NUMERIC’"), @"⇧⌥⌘C", @"⌥⌘C"]];
		[toolbarItem setImage:[NSImage imageNamed:@"add_col"]];

		// Tell the item what message to send when it is clicked
		[toolbarItem setTarget:self];
		[toolbarItem setAction:@selector(addCol:)];
	} else  if ([itemIdent isEqual:RemoveColsToolbarItemIdentifier]) {
		// Set the text label to be displayed in the toolbar and customization palette
		[toolbarItem setLabel:NLSC(@"Remove Col",v@"Remove columns - label for a toolbar, keep short!")];
		[toolbarItem setPaletteLabel:NLS(@"Remove Columns")];

		// Set up a reasonable tooltip, and image   Note, these aren't localized, but you will likely want to localize many of the item's properties
		[toolbarItem setToolTip:[NSString stringWithFormat:@"%@ (⌘⌫)", NLS(@"Remove selected columns")]];
		[toolbarItem setImage:[NSImage imageNamed:@"rem_col"]];

		// Tell the item what message to send when it is clicked
		[toolbarItem setTarget:self];
		[toolbarItem setAction:@selector(remCols:)];
	} else  if ([itemIdent isEqual:AddRowToolbarItemIdentifier]) {
		// Set the text label to be displayed in the toolbar and customization palette
		[toolbarItem setLabel:NLSC(@"Add Row", @"Add row - label for a toolbar, keep short!")];
		[toolbarItem setPaletteLabel:NLS(@"Add New Row")];

		// Set up a reasonable tooltip, and image   Note, these aren't localized, but you will likely want to localize many of the item's properties
		[toolbarItem setToolTip:[NSString stringWithFormat:@"%@ (⌥⌘A)", NLS(@"Adds a row below a group of selected rows or at the bottom of the data")]];
		[toolbarItem setImage:[NSImage imageNamed:@"add_row"]];

		// Tell the item what message to send when it is clicked
		[toolbarItem setTarget:self];
		[toolbarItem setAction:@selector(addRow:)];
	} else  if ([itemIdent isEqual:RemoveRowsToolbarItemIdentifier]) {
		// Set the text label to be displayed in the toolbar and customization palette
		[toolbarItem setLabel:NLSC(@"Remove Row", @"Remove row - label for a toolbar, keep short!")];
		[toolbarItem setPaletteLabel:NLS(@"Remove Rows")];

		// Set up a reasonable tooltip, and image   Note, these aren't localized, but you will likely want to localize many of the item's properties
		[toolbarItem setToolTip:[NSString stringWithFormat:@"%@ (⌘⌫)", NLS(@"Removes selected rows")]];
		[toolbarItem setImage:[NSImage imageNamed:@"rem_row"]];

		// Tell the item what message to send when it is clicked
		[toolbarItem setTarget:self];
		[toolbarItem setAction:@selector(remRows:)];
	} else  if ([itemIdent isEqual:CancelEditToolbarItemIdentifier]) {
		// Set the text label to be displayed in the toolbar and customization palette
		[toolbarItem setLabel:NLSC(@"Cancel Editing", @"Cancel Editing - label for a toolbar, keep short!")];
		[toolbarItem setPaletteLabel:NLS(@"Cancel Editing")];

		// Set up a reasonable tooltip, and image   Note, these aren't localized, but you will likely want to localize many of the item's properties
		[toolbarItem setToolTip:[NSString stringWithFormat:@"%@ (⌃⌥⌘⎋)", NLS(@"Cancels object editing without passing data back to R and closes the editor window")]];
		[toolbarItem setImage:[NSImage imageNamed:@"stop"]];

		// Tell the item what message to send when it is clicked
		[toolbarItem setTarget:self];
		[toolbarItem setAction:@selector(cancelEditing:)];
	} else {
		// itemIdent refered to a toolbar item that is not provide or supported by us or cocoa
		// Returning nil will inform the toolbar this kind of item is not supported
		toolbarItem = nil;
	}
	return toolbarItem;
}


- (NSArray *)toolbarDefaultItemIdentifiers:(NSToolbar *)toolbar
{
	// Required delegate method:  Returns the ordered list of items to be shown in the toolbar by default
	// If during the toolbar's initialization, no overriding values are found in the user defaults, or if the
	// user chooses to revert to the default items this set will be used
	return [NSArray arrayWithObjects:AddColToolbarItemIdentifier, RemoveColsToolbarItemIdentifier,
		AddRowToolbarItemIdentifier, RemoveRowsToolbarItemIdentifier, CancelEditToolbarItemIdentifier
		, nil];
}


- (NSArray *)toolbarAllowedItemIdentifiers:(NSToolbar *)toolbar
{
	// Required delegate method:  Returns the list of all allowed items by identifier.  By default, the toolbar
	// does not assume any items are allowed, even the separator.  So, every allowed item must be explicitly listed
	// The set of allowed items is used to construct the customization palette
	return [NSArray arrayWithObjects:AddColToolbarItemIdentifier, RemoveColsToolbarItemIdentifier,
		AddRowToolbarItemIdentifier, RemoveRowsToolbarItemIdentifier, CancelEditToolbarItemIdentifier
		, nil];
}

- (void)toolbarWillAddItem:(NSNotification *)notification
{
	// Optional delegate method:  Before an new item is added to the toolbar, this notification is posted.
	// This is the best place to notice a new item is going into the toolbar.  For instance, if you need to
	// cache a reference to the toolbar item or need to set up some initial state, this is the best place
	// to do it.  The notification object is the toolbar to which the item is being added.  The item being
	// added is found by referencing the @"item" key in the userInfo
	//NSToolbarItem *addedItem = [[notif userInfo] objectForKey: @"item"];
	//NSLog(@"toolbarWillAddItem: %@", addedItem);
}

- (void)toolbarDidRemoveItem:(NSNotification *)notification
{
	// Optional delegate method:  After an item is removed from a toolbar, this notification is sent.   This allows
	// the chance to tear down information related to the item that may have been cached.   The notification object
	// is the toolbar from which the item is being removed.  The item being added is found by referencing the @"item"
	// key in the userInfo
	//NSToolbarItem *removedItem = [[notif userInfo] objectForKey: @"item"];
	//NSLog(@"toolbarDidRemoveItem: %@", removedItem);
}

- (BOOL)validateToolbarItem:(NSToolbarItem *)toolbarItem
{
	// Optional method:  This message is sent to us since we are the target of some toolbar item actions
	// (for example:  of the save items action)

	if ([[toolbarItem itemIdentifier] isEqualToString:AddColToolbarItemIdentifier])
		return(editedColumnNameIndex < 0);
	else if ([[toolbarItem itemIdentifier] isEqualToString:RemoveColsToolbarItemIdentifier])
		return(editedColumnNameIndex < 0 && [[editorSource selectedColumnIndexes] count]);
	else if ([[toolbarItem itemIdentifier] isEqualToString:AddRowToolbarItemIdentifier])
		return(editedColumnNameIndex < 0);
	else if ([[toolbarItem itemIdentifier] isEqualToString:RemoveRowsToolbarItemIdentifier])
		return(editedColumnNameIndex < 0 && [[editorSource selectedRowIndexes] count]);
	else if ([[toolbarItem itemIdentifier] isEqualToString:CancelEditToolbarItemIdentifier])
		return(YES);

	return NO;

}

#pragma mark -
#pragma mark IBActions

/**
 * Adds a column to the data either at the end or after the last columns selected by the user.
 * sender's tag will choose column type
 *   0 = type of column left of it
 *   1 = CHARACTER
 *   2 = NUMERIC
 */
- (IBAction)addCol:(id)sender
{

	NSUInteger lastcol, i;
	BOOL isEmpty = NO;
	BOOL typeWasPassed = NO;
	NSInteger newColType = CHARACTER;

	// if sender's tag pre-set type of to be added columns
	switch([sender tag]) {
		case 1:
		newColType = NUMERIC;
		typeWasPassed = YES;
		break;
		case 2:
		newColType = CHARACTER;
		typeWasPassed = YES;
		break;
	}

	NSIndexSet *cols =  [editorSource selectedColumnIndexes];
	NSInteger nCols = [[editorSource tableColumns] count];
	lastcol = [cols lastIndex];
	if(lastcol == NSNotFound) {
		isEmpty = (nCols == 0);
		lastcol = !isEmpty ? (nCols - 1) : 0;
	}

	// add a column of type of last selected column or last
	if(!typeWasPassed && !isEmpty)
		newColType = [[objectColumnTypes objectAtIndex:lastcol] intValue];

	newvar++;

	if((nCols-1) == lastcol) {
		[objectColumnNames addObject:[NSString stringWithFormat:@"var %d", newvar]];
		[objectColumnTypes addObject:[NSNumber numberWithInteger:newColType]];
		[objectData addObject:[NSMutableArray array]];
	} else {
		[objectColumnNames insertObject:[NSString stringWithFormat:@"var %d", newvar] atIndex:lastcol+1];
		[objectColumnTypes insertObject:[NSNumber numberWithInteger:newColType] atIndex:lastcol+1];
		[objectData insertObject:[NSMutableArray array] atIndex:lastcol+1];
	}

	numberOfColumns++;

	if(!isEmpty) 
		for(i = 0; i < numberOfRows; i++)
			[NSArrayObjectAtIndex(objectData, (lastcol+1)) addObject:(newColType == NUMERIC) ? @"NA" : @""];

	[self setDataTable:NO];

}

/**
 * Adds a row to the data either at the end or after the last row selected by the user
 *
 *    FIXME: it actually crashes if a row is added in the middle of the data
 *           Bibiko: cannot reproduce anymore; still valid?
 *
 */
- (IBAction)addRow:(id)sender
{

	NSUInteger col, lastrow;
	BOOL isEmpty = NO;

	if(![[editorSource tableColumns] count]) return;

	NSIndexSet *rows =  [editorSource selectedRowIndexes];
	NSInteger nRows = ([objectData count]) ? [[objectData objectAtIndex:0] count] : 0;
	lastrow = [rows lastIndex]; // last row selected by the user

	if(lastrow == NSNotFound) {
		isEmpty = (nRows == 0);
		lastrow = isEmpty ? 0 : (nRows - 1);
	}

	if(lastrow == nRows)
		for(col = 0; col < [[editorSource tableColumns] count]; col++)
			[[objectData objectAtIndex:col] addObject:([[objectColumnTypes objectAtIndex:col] intValue] == NUMERIC) ? @"NA" : @""];
	else
		for(col = 0; col < [[editorSource tableColumns] count]; col++)
			[[objectData objectAtIndex:col] insertObject:([[objectColumnTypes objectAtIndex:col] intValue] == NUMERIC) ? @"NA" : @"" atIndex:lastrow+1];

	numberOfRows++;

	[editorSource reloadData];

	if([rows count] == 1)
		[editorSource selectRowIndexes:[NSIndexSet indexSetWithIndex:lastrow+1] byExtendingSelection:NO];

	return;

}

/**
 * Remove selected columns
 */
- (IBAction)remCols:(id)sender
{

	NSUInteger i;

	NSIndexSet *cols =  [editorSource selectedColumnIndexes];
	NSUInteger current_index = [cols firstIndex];
	if(current_index == NSNotFound)
		return;

	while (current_index != NSNotFound) {
		[editorSource removeTableColumn:[editorSource tableColumnWithIdentifier:[NSString stringWithFormat:@"%ld", current_index]]];
		current_index = [cols indexGreaterThanIndex:current_index];
	}

	[objectData removeObjectsAtIndexes:cols];
	[objectColumnTypes removeObjectsAtIndexes:cols];
	[objectColumnNames removeObjectsAtIndexes:cols];

	numberOfColumns -= [cols count];

	// if no column is given create a matrix 1 x 1 of value NA
	if(!numberOfColumns) {
		[objectData addObject:[NSMutableArray array]];
		[[objectData objectAtIndex:0] addObject:@"NA"];
		[objectColumnNames addObject:@"var1"];
		[objectColumnTypes addObject:[NSNumber numberWithInteger:NUMERIC]];
		numberOfRows = 1;
		numberOfColumns++;
		[self setDataTable:NO];
	} else {

		for(i = 0; i < numberOfColumns; i++)
			[[[editorSource tableColumns] objectAtIndex:i] setIdentifier:[NSString stringWithFormat:@"%ld", i]];

		[editorSource reloadData];

		[editorSource selectColumnIndexes:[NSIndexSet indexSetWithIndex:([cols lastIndex] < [[editorSource tableColumns] count]) ? [cols lastIndex] : [[editorSource tableColumns] count]-1] byExtendingSelection:NO];
	}

}

/**
 * Removes selected rows
 */
- (IBAction)remRows:(id)sender
{

	NSUInteger col, nrows;

	NSIndexSet *rows =  [editorSource selectedRowIndexes];
	nrows = [rows count];

	if (nrows < 1) return;

	numberOfRows -= nrows;

	for(col = 0; col < numberOfColumns; col++)
		[[objectData objectAtIndex:col] removeObjectsAtIndexes:rows];

	[editorSource reloadData];

	// Check last selected rows to reset selection if user deleted last row
	[editorSource selectRowIndexes:[NSIndexSet indexSetWithIndex:([rows firstIndex] < numberOfRows) ? [rows firstIndex] : numberOfRows-1] byExtendingSelection:NO];

}

- (IBAction)remSelection:(id)sender
{
	if([[editorSource selectedColumnIndexes] count])
		[self remCols:nil];
	else if([[editorSource selectedRowIndexes] count])
		[self remRows:nil];
}

- (IBAction)editColumnNames:(id)sender
{
	if([[editorSource tableColumns] count])
		[self editColumnNameOfTableColumn:[[editorSource tableColumns] objectAtIndex:0]];
	else
		NSBeep();
}

/**
 * Cancel editing without storing data and close the window
 */
- (IBAction)cancelEditing:(id)sender
{

	// sending abort signal to startDataEntry's runModalForWindow
	// to cancel the edit() by sending an error() message back to R
	[NSApp abortModal];

	[[[REditor getDEController] window] orderOut:self];
	[[[REditor getDEController] window] close];

}

#pragma mark -

- (BOOL)validateMenuItem:(NSMenuItem*)menuItem
{

	if ([menuItem action] == @selector(remSelection:)) {
		return ([[editorSource selectedColumnIndexes] count] || [[editorSource selectedRowIndexes] count]);
	}

	if ([menuItem action] == @selector(editColumnNames:)) {
		return ([[editorSource tableColumns] count] && editedColumnNameIndex < 0);
	}

	return YES;

}

@end
