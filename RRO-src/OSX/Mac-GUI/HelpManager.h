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

/* HelpManager */

#import "CCComp.h"
#import <WebKit/WebKit.h>
#import <WebKit/WebFrame.h>

#define kExactMatch 10
#define kFuzzyMatch 11

@interface HelpManager : NSObject
{
	IBOutlet WebView *HelpView;
	IBOutlet NSSearchField *searchField;
	IBOutlet NSWindow *helpWindow;
	IBOutlet NSButton *forward;
	IBOutlet NSButton *back;

	int searchType;
	NSString *home;
}

- (IBAction)runHelpSearch:(id)sender;
- (IBAction)showMainHelp:(id)sender;
- (IBAction)showRFAQ:(id)sender;
- (IBAction)whatsNew:(id)sender;
- (IBAction)changeSearchType:(id)sender;
- (IBAction)executeSelection:(id)sender;
- (IBAction)printDocument:(id)sender;

- (void)showHelpUsingFile: (NSString *)file topic: (NSString*) topic; // displays results only, used by help() in 2.1 and later
- (void)showHelpFor:(NSString *)topic; // runs a search

+ (id)sharedController;
- (NSWindow*)window;
- (WebView*)webView;

- (void)setSearchType:(int)type;
- (int)searchType;

- (void)showHelpFileForURL:(NSURL*)url;
- (void)supportsWebViewSwipingInHistory;
- (void)supportsWebViewMagnifying;

- (void)webView:(WebView *)sender didStartProvisionalLoadForFrame:(WebFrame *)frame;

@end
