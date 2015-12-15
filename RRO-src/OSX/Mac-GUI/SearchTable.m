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
 */

#import "RGUI.h"
#import "SearchTable.h"
#import "RController.h"
#import <WebKit/WebKit.h>
#import <WebKit/WebFrame.h>
#import "RegexKitLite.h"

static id sharedHSController;

@implementation SearchTable

- (id)init
{
    self = [super init];
    if (self) {
		sharedHSController = self;
		windowTitle = nil;
		dataSource = [[SortableDataSource alloc] init];
    }
	
    return self;
}

- (void) awakeFromNib
{
	[topicsDataSource setTarget: self];
	[topicsDataSource setDataSource: dataSource];
	[TopicHelpView setFrameLoadDelegate:self];
}

- (void)dealloc {
	[super dealloc];
}

- (void) updateHelpSearch: (int) count withTopics: (char**) topics packages: (char**) pkgs descriptions: (char**) descs urls: (char**) urls title: (char*) title
{
	[dataSource reset];
	[dataSource addColumnOfLength:count withUTF8Strings:topics name:@"topic"];
	[dataSource addColumnOfLength:count withUTF8Strings:pkgs name:@"package"];
	[dataSource addColumnOfLength:count withUTF8Strings:descs name:@"description"];
	[dataSource addColumnOfLength:count withUTF8Strings:urls name:@"URL"];
	if (windowTitle) [windowTitle release];
	windowTitle = [[NSString alloc] initWithUTF8String: title];
	[self show];
}

- (int) count
{
	return [dataSource count];
}

- (void) show
{
	[topicsDataSource reloadData];
	[searchTableWindow setTitle:(windowTitle)?windowTitle:NLS(@"<unknown>")];
	[searchTableWindow makeKeyAndOrderFront:self];
	[topicsDataSource deselectAll:nil];
}

#pragma mark -
#pragma mark TableView notifications

- (void)tableViewSelectionDidChange:(NSNotification *)aNotification
{
	// Check our notification object is our table
	if ([aNotification object] != topicsDataSource) return;

	// Update Info delayed
	[NSObject cancelPreviousPerformRequestsWithTarget:self 
							selector:@selector(showInfo:) 
							object:topicsDataSource];

	[self performSelector:@selector(showInfo:) withObject:topicsDataSource afterDelay:0.5];
	
}

#pragma mark -

- (IBAction) showInfo:(id)sender
{
	int row = [sender selectedRow];
	if(row < 0) return;
	NSString *urlText = [dataSource objectAtColumn:@"URL" row:row];
	SLog(@"showInfo: URL='%@'", urlText);
	if (![urlText hasPrefix:@"http://"]) {
		NSString *home = [[RController sharedController] home];
		int port = [[RController sharedController] helpServerPort];
		if (port == 0)
			urlText = [NSString stringWithFormat:@"file://%@", urlText];
		else {
			if ([urlText hasPrefix:home]) urlText = [urlText substringFromIndex:[home length]];
			urlText = [NSString stringWithFormat:@"http://127.0.0.1:%d%@", port, urlText];
		}
	}
	SLog(@" - invoking help sub-panel with %@", urlText);
	[[TopicHelpView mainFrame] loadRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:urlText]]];
}


- (id) window
{
	return searchTableWindow;
}

+ (id) sharedController{
	return sharedHSController;
}

- (void)sheetDidEnd:(id)sheet returnCode:(int)returnCode contextInfo:(NSString *)contextInfo
{
	[searchTableWindow makeKeyAndOrderFront:nil];
}

- (IBAction)executeSelection:(id)sender
{
	DOMRange *dr = [TopicHelpView selectedDOMRange];
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

- (IBAction)printDocument:(id)sender
{

	[NSObject cancelPreviousPerformRequestsWithTarget:self 
							selector:@selector(showInfo:) 
							object:topicsDataSource];

	NSPrintInfo *printInfo;
	NSPrintOperation *printOp;
	
	printInfo = [NSPrintInfo sharedPrintInfo];
	[printInfo setHorizontalPagination: NSFitPagination];
	[printInfo setVerticalPagination: NSAutoPagination];
	[printInfo setVerticallyCentered:NO];
	
	printOp = [NSPrintOperation printOperationWithView:[[[TopicHelpView mainFrame] frameView] documentView] 
											 printInfo:printInfo];
	[printOp setShowPanels:YES];
	[printOp runOperationModalForWindow:[self window] 
							   delegate:self 
						 didRunSelector:@selector(sheetDidEnd:returnCode:contextInfo:) 
						    contextInfo:@""];
}

- (void)supportsWebViewSwipingInHistory
{
	return;
}

- (void)supportsWebViewMagnifying
{
	return;
}

- (WebView*)webView
{
	return TopicHelpView;
}

- (BOOL)validateMenuItem:(NSMenuItem *)menuItem
{
	if ([menuItem action] == @selector(executeSelection:)) {
		return ([TopicHelpView selectedDOMRange] == nil) ? NO : YES;
	}

	return YES;
}

@end
