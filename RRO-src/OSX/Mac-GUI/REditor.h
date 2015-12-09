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
 *  REditor.h
 *
 */


#import "CCComp.h"
#import "Tools/RDataEditorTableView.h"

#define DataEditorToolbarIdentifier      @"DataEditor Toolbar Identifier"
#define AddColToolbarItemIdentifier      @"Add Column"
#define RemoveColsToolbarItemIdentifier  @"Remove Columns"
#define AddRowToolbarItemIdentifier      @"Add Row"
#define RemoveRowsToolbarItemIdentifier  @"Remove Rows"
#define CancelEditToolbarItemIdentifier  @"Cancel Edit"

@interface REditor : NSObject <NSToolbarDelegate>
{
	IBOutlet RDataEditorTableView *editorSource;
	IBOutlet NSWindow *dataWindow;
	NSToolbar *toolbar;
	NSInteger editedColumnNameIndex;
	NSMutableArray *objectData;
	NSMutableArray *objectColumnNames;
	NSMutableArray *objectColumnTypes;
	NSInteger numberOfRows;
	NSInteger numberOfColumns;
}

+ (id) getDEController;
+ (void)startDataEntry;

- (id)window;

- (BOOL)initData;
- (BOOL)writeDataBackToObject;
- (NSArray*)objectData;
- (NSArray*)objectColumnTypes;
- (void)clearData;
- (void)setDataTable:(BOOL)removeAll;
- (void)editColumnNameOfTableColumn:(NSTableColumn *)aTableColumn;

- (void)setupToolbar;

- (IBAction)addCol:(id)sender;
- (IBAction)remCols:(id)sender;
- (IBAction)addRow:(id)sender;
- (IBAction)remRows:(id)sender;
- (IBAction)remSelection:(id)sender;
- (IBAction)editColumnNames:(id)sender;
- (IBAction)cancelEditing:(id)sender;

@end
