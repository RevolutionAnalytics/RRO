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
 *                     Copyright (C) 1998-2012   The R Development Core Team
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
 */

#import "DataManager.h"
#import "RController.h"
#import "REngine/REngine.h"
#import "RegexKitLite.h"

#import <WebKit/WebKit.h>
#import <WebKit/WebFrame.h>

#define kDataManagerData          @"data"
#define kDataManagerPackage       @"package"
#define kDataManagerDescription   @"description"
#define kDataManagerURL           @"URL"

#define kSortModeNone 0
#define kSortModeAsc  1
#define kSortModeDesc 2

static DataManager* sharedController;

@implementation DataManager

+ (DataManager*) sharedController{
	return sharedController;
}

- (void)awakeFromNib
{
	[RDataSource setDoubleAction:@selector(loadRData:)];
	[dataInfoView setFrameLoadDelegate:self];
	[self enableGUIActions:NO];
}

- (id)init
{
	self = [super init];
	if (self) {
		sharedController = self;
		datasets = [[NSMutableArray alloc] initWithCapacity:500];
		filteredDatasets = [[NSMutableArray alloc] initWithCapacity:500];
		sortMode = kSortModeNone;
		sortedColumn = nil;
	}

	return self;
}

- (void)dealloc {
	if(datasets) [datasets release], datasets = nil;
	if(filteredDatasets) [filteredDatasets release], filteredDatasets = nil;
	[super dealloc];
}

#pragma mark -

- (NSWindow*)window
{
	return DataManagerWindow;
}

- (void)show
{
	[RDataSource reloadData];
	[DataManagerWindow makeKeyAndOrderFront:self];
}

#pragma mark -

- (void)updateDatasets:(int)count withNames:(char**)name descriptions:(char**)desc packages:(char**)pkg URLs:(char**)url
{

	[self enableGUIActions:NO];
	[[self window] display];
	[self show];
	[self resetDatasets];

	NSInteger i = 0;

	for(i = 0; i < count; i++) {
		NSDictionary *entry = [NSDictionary dictionaryWithObjectsAndKeys:
			[NSString stringWithUTF8String: name[i]], kDataManagerData,
			[NSString stringWithUTF8String: desc[i]], kDataManagerDescription,
			[NSString stringWithUTF8String: pkg[i]],  kDataManagerPackage,
			[NSString stringWithUTF8String: url[i]],  kDataManagerURL,
			nil
		];
		[datasets addObject:entry];
		[filteredDatasets addObject:entry];
	}

	[self filterTable:nil];
	[RDataSource reloadData];
	[self enableGUIActions:YES];

}

- (void)resetDatasets
{
	[datasets removeAllObjects];
	[filteredDatasets removeAllObjects];
}

- (NSInteger)count
{
	return [datasets count];
}

- (void)enableGUIActions:(BOOL)enabled
{
	[loadButton setEnabled:enabled];
	[refreshButton setEnabled:enabled];
	[searchField setEnabled:enabled];
	[RDataSource setEnabled:enabled];
}

#pragma mark -

- (IBAction)loadRData:(id)sender
{

	NSIndexSet *selectedRows = [RDataSource selectedRowIndexes];

	if(![selectedRows count]) return;

	NSInteger anIndex = [selectedRows firstIndex];
	NSMutableArray *data = [[NSMutableArray alloc] initWithCapacity:[selectedRows count]];
	NSMutableArray *pkgs = [[NSMutableArray alloc] initWithCapacity:[selectedRows count]];
	while(anIndex != NSNotFound) {
		[data addObject:[[filteredDatasets objectAtIndex:anIndex] objectForKey:kDataManagerData]];
		[pkgs addObject:[[filteredDatasets objectAtIndex:anIndex] objectForKey:kDataManagerPackage]];
		anIndex = [selectedRows indexGreaterThanIndex:anIndex];
	}
	[[REngine mainEngine] evaluateString:[NSString stringWithFormat:@"data(%@,package=c(\"%@\"))",
		[data componentsJoinedByString:@","], 
		[pkgs componentsJoinedByString:@"\",\""]]];
}

- (IBAction)filterTable:(id)sender
{

	NSString *searchPattern = [searchField stringValue];

	if(![searchPattern length]) {
		[filteredDatasets setArray:datasets];
		[RDataSource deselectAll:nil];
	} else {
		NSPredicate *predicate = [NSPredicate predicateWithFormat:@"data CONTAINS[cd] %@ OR package CONTAINS[cd] %@ OR description CONTAINS[cd] %@", 
			searchPattern, searchPattern, searchPattern];
		[filteredDatasets setArray:[datasets filteredArrayUsingPredicate:predicate]];
	}

	if(sortedColumn) {
		[RDataSource setIndicatorImage:(sortMode == kSortModeAsc) ? [NSImage imageNamed:@"NSAscendingSortIndicator"] : [NSImage imageNamed:@"NSDescendingSortIndicator"] inTableColumn:[RDataSource tableColumnWithIdentifier:sortedColumn]];
		[RDataSource setHighlightedTableColumn:[RDataSource tableColumnWithIdentifier:sortedColumn]];
		NSSortDescriptor *sortDescriptor = [[NSSortDescriptor alloc] initWithKey:sortedColumn ascending:(sortMode == kSortModeAsc) 
			selector:@selector(localizedCaseInsensitiveCompare:)];
		[filteredDatasets sortUsingDescriptors:
			[NSArray arrayWithObjects:sortDescriptor, nil]];
		[sortDescriptor release];
	}


	[RDataSource reloadData];
}

- (IBAction)reloadDatasets:(id)sender
{
	[self enableGUIActions:NO];
	[[self window] display];
	[[REngine mainEngine] executeString:@"data.manager()"];
}

- (IBAction)showHelp:(id)sender
{

	if([RDataSource numberOfSelectedRows] != 1) return;

	NSInteger row = [RDataSource selectedRow];

	NSDictionary *selectedItem = [filteredDatasets objectAtIndex:row];

	SLog(@"DataManager showHelp: %@", selectedItem);

	NSString *urlText = nil;
	int port = [[RController sharedController] helpServerPort];
	if (port == 0) {
		NSRunInformationalAlertPanel(NLS(@"Cannot start HTML help server."), NLS(@"Help"), NLS(@"Ok"), nil, nil);
		return;
	}

	NSString *topic = [selectedItem objectForKey:kDataManagerData];
	NSRange r = [topic rangeOfString:@" ("];
	if (r.length > 0 && [topic length] - r.length > 3) // some datasets have the topic in parents
		topic = [topic substringWithRange: NSMakeRange(r.location + 2, [topic length] - r.location - 3)];

	urlText = [NSString stringWithFormat:@"http://127.0.0.1:%d/library/%@/html/%@.html", port, [selectedItem objectForKey:kDataManagerPackage], topic];

	[[dataInfoView mainFrame] loadRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:urlText]]];

}

- (IBAction)printDocument:(id)sender
{

	[NSObject cancelPreviousPerformRequestsWithTarget:self 
							selector:@selector(showHelp:) 
							object:RDataSource];

	NSPrintInfo *printInfo;
	NSPrintOperation *printOp;
	
	printInfo = [NSPrintInfo sharedPrintInfo];
	[printInfo setHorizontalPagination: NSFitPagination];
	[printInfo setVerticalPagination: NSAutoPagination];
	[printInfo setVerticallyCentered:NO];
	
	printOp = [NSPrintOperation printOperationWithView:[[[dataInfoView mainFrame] frameView] documentView] 
											 printInfo:printInfo];
	[printOp setShowPanels:YES];
	[printOp runOperationModalForWindow:[self window] 
							   delegate:self 
						 didRunSelector:@selector(sheetDidEnd:returnCode:contextInfo:) 
						    contextInfo:@""];
}

- (IBAction)executeSelection:(id)sender
{
	DOMRange *dr = [dataInfoView selectedDOMRange];
	if (dr) { /* we don't do line-exec since we don't get the text outside the selection */
		NSString *stx = [dr markupString];
		// Ok, some simple processing here - it may not work in all cases
		stx = [stx stringByReplacingOccurrencesOfRegex:@"(?i)<br[^>]*?>" withString:@"\n"];
		stx = [stx stringByReplacingOccurrencesOfRegex:@"<[^>]*?>" withString:@""];
		stx = [stx stringByReplacingOccurrencesOfString:@"&lt;" withString:@"<"];
		stx = [stx stringByReplacingOccurrencesOfString:@"&gt;" withString:@">"];
		stx = [stx stringByReplacingOccurrencesOfString:@"&amp;" withString:@"&"];
		[[RController sharedController] sendInput:stx];
	}
}

#pragma mark -
#pragma mark tableView delegates

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView
{
	return [filteredDatasets count];
}

- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)rowIndex
{
	if([[tableColumn identifier] isEqualToString:kDataManagerPackage])
		return [[filteredDatasets objectAtIndex:rowIndex] objectForKey:kDataManagerPackage];
	else if([[tableColumn identifier] isEqualToString:kDataManagerData])
		return [[filteredDatasets objectAtIndex:rowIndex] objectForKey:kDataManagerData];
	else if([[tableColumn identifier] isEqualToString:kDataManagerDescription])
		return [[filteredDatasets objectAtIndex:rowIndex] objectForKey:kDataManagerDescription];
	return @"...";
}

- (BOOL)tableView:(NSTableView *)aTableView shouldEditTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex
{
	return NO;
}

- (void)tableViewSelectionDidChange:(NSNotification *)aNotification
{
	// Check our notification object is our table
	if ([aNotification object] != RDataSource) return;

	// Update Info delayed
	[NSObject cancelPreviousPerformRequestsWithTarget:self 
							selector:@selector(showHelp:) 
							object:RDataSource];

	[self performSelector:@selector(showHelp:) withObject:RDataSource afterDelay:0.5];
	
}

- (void)tableView:(NSTableView*)tableView didClickTableColumn:(NSTableColumn *)tableColumn
{

	[tableView deselectAll:nil];

	// Tri-state sorting none -> asc -> desc -> none -> ...
	if(!sortedColumn || (sortedColumn && [sortedColumn isEqualToString:[tableColumn identifier]])) {
		sortMode++;
		if (sortMode > kSortModeDesc) sortMode = kSortModeNone;
	} else {
		sortMode = kSortModeAsc;
	}

	// remove sort indicator of old column
	if(sortedColumn) {
		[self filterTable:nil];
		[tableView setIndicatorImage:nil inTableColumn:[tableView tableColumnWithIdentifier:sortedColumn]];
	}

	// remember last to be sorted column
	sortedColumn = [tableColumn identifier];

	NSSortDescriptor* sortDescriptor;

	switch(sortMode) {
		case kSortModeNone:
		[tableView setIndicatorImage:nil inTableColumn:tableColumn];
		[tableView setHighlightedTableColumn:nil];
		[filteredDatasets removeAllObjects];
		[filteredDatasets setArray:datasets];
		sortedColumn = nil;
		break;
		case kSortModeAsc:
		[tableView setIndicatorImage:[NSImage imageNamed:@"NSAscendingSortIndicator"] inTableColumn:tableColumn];
		[tableView setHighlightedTableColumn:tableColumn];
		sortDescriptor = [[NSSortDescriptor alloc] initWithKey:sortedColumn ascending:YES 
			selector:@selector(localizedCaseInsensitiveCompare:)];
		[filteredDatasets sortUsingDescriptors:
			[NSArray arrayWithObjects:sortDescriptor, nil]];
		[sortDescriptor release];
		break;
		case kSortModeDesc:
		[tableView setIndicatorImage:[NSImage imageNamed:@"NSDescendingSortIndicator"] inTableColumn:tableColumn];
		[tableView setHighlightedTableColumn:tableColumn];
		sortDescriptor = [[NSSortDescriptor alloc] initWithKey:sortedColumn ascending:NO 
			selector:@selector(localizedCaseInsensitiveCompare:)];
		[filteredDatasets sortUsingDescriptors:
			[NSArray arrayWithObjects:sortDescriptor, nil]];
		[sortDescriptor release];
		break;
	}

	[RDataSource reloadData];

}

#pragma mark -

- (void)sheetDidEnd:(id)sheet returnCode:(int)returnCode contextInfo:(NSString *)contextInfo
{

	SLog(@"DataManager: sheetDidEnd: returnCode: %d contextInfo: %@", returnCode, contextInfo);

	// Order out the sheet - could be a NSPanel or NSWindow
	if ([sheet respondsToSelector:@selector(orderOut:)]) {
		[sheet orderOut:nil];
	}
	else if ([sheet respondsToSelector:@selector(window)]) {
		[[sheet window] orderOut:nil];
	}

	[DataManagerWindow makeKeyAndOrderFront:nil];

}

- (BOOL)validateMenuItem:(NSMenuItem *)menuItem
{
	if ([menuItem action] == @selector(executeSelection:)) {
		return ([dataInfoView selectedDOMRange] == nil) ? NO : YES;
	}

	return YES;
}

@end
