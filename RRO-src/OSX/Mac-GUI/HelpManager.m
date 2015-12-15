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
#import "HelpManager.h"
#import "RController.h"
#import "REngine/REngine.h"
#import "RegexKitLite.h"

static id sharedHMController;

@implementation HelpManager

- (id)init
{
    self = [super init];
    if (self) {
		sharedHMController = self;
		home = nil;
		searchType = kExactMatch;
	}
	
    return self;
}

- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver: self];
	[super dealloc];
}

- (IBAction)runHelpSearch:(id)sender
{
	if([[sender stringValue] length]==0) 
		return;
	
	NSString *searchString;
	NSCharacterSet *charSet;
	charSet = [NSCharacterSet characterSetWithCharactersInString:@"'\""];
	searchString = [[sender stringValue] stringByTrimmingCharactersInSet:charSet];
	SLog(@"runHelpSearch: <%@>", searchString);
	
	//		[self sendInput:[NSString stringWithFormat:@"help(\"%@\")", searchString]];
	if(searchType == kFuzzyMatch){
		[[REngine mainEngine] executeString:[NSString stringWithFormat:@"print(help.search(\"%@\"))", searchString]];
			[sender setStringValue:@""];
	} else {
		[self showHelpFor: searchString];
	}
}

- (void)showHelpUsingFile: (NSString *)file topic: (NSString*) topic
{
	if (!file) return;
	if (!topic) topic=@"<unknown>";
	NSString *url = nil;
	if ([file hasPrefix:@"http://"]) 
		url = file;
	else {
		int port = [[RController sharedController] helpServerPort];
		if (port == 0) {
			NSRunInformationalAlertPanel(NLS(@"Cannot start HTML help server."), NLS(@"Help"), NLS(@"Ok"), nil, nil);
			return;
		}
		if (!home) home = [[RController sharedController] home];
		if ([file hasPrefix:home])
			file = [file substringFromIndex:[home length]];
		url = [NSString stringWithFormat:@"http://127.0.0.1:%d%@", port, file];
	}
	SLog(@"HelpManager.showHelpUsingFile:\"%@\", topic=%@, URL=%@", file, topic, url);
	if(url != nil) {
		if ([Preferences flagForKey:kExternalHelp withDefault:NO])
			[[REngine mainEngine] executeString:[NSString stringWithFormat:@"browseURL(\"%@\")", url]];
		else {
			[[HelpView mainFrame] loadRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:url]]];
			[helpWindow makeKeyAndOrderFront:self];
		}
	}
}

- (IBAction)executeSelection:(id)sender
{
	DOMRange *dr = [HelpView selectedDOMRange];
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

- (void)showHelpFor:(NSString *)topic
{
	NSString *searchString;
	NSCharacterSet *charSet;
	if (!topic) return; /* should we issue an error? This happens only if the encoding is wrong */
	charSet = [NSCharacterSet characterSetWithCharactersInString:@"'\""];
	searchString = [topic stringByTrimmingCharactersInSet:charSet];
	SLog(@"showHelpFor: <%@>", searchString);

	if(searchType == kFuzzyMatch) {
		[[REngine mainEngine] executeString:[NSString stringWithFormat:@"print(help.search(\"%@\"))", searchString]];
		return;
	}

	REngine *re = [REngine mainEngine];	
	RSEXP *x= [re evaluateString:[NSString stringWithFormat:@"as.character(help(\"%@\", help_type='html'))",searchString]];
	if ((x==nil) || ([x string]==NULL)) {
		NSString *topicString = [NSString stringWithFormat:@"Topic: %@", searchString];
		int res = NSRunInformationalAlertPanel(NLS(@"Can't find help for topic, would you like to expand the search?"), topicString, NLS(@"No"), NLS(@"Yes"), nil);
		if (!res)
			[[REngine mainEngine] executeString:[NSString stringWithFormat:@"print(help.search(\"%@\"))", searchString]];
		else {
			// if user dismiss alert panel set focus back to caller window
			NSArray *orderedWindows = [NSApp orderedWindows];
			int i;
			for(i=0; i<[orderedWindows count]; i++) {
				if([[orderedWindows objectAtIndex:i] isVisible]) {
					[[orderedWindows objectAtIndex:i] makeKeyAndOrderFront:nil];
					return;
				}
			}
		}
		return;
	}
	[x release];
	[re executeString:[NSString stringWithFormat:@"print(help(\"%@\", help_type='html'))",searchString]];
}

- (NSWindow*) window
{
	return helpWindow;
}

- (WebView*)webView
{
	return HelpView;
}

- (IBAction)showMainHelp:(id)sender
{
	 REngine *re = [REngine mainEngine];	
	 RSEXP *x = [re evaluateString:@"try(getOption(\"main.help.url\"))"];

	 if ((x==nil) | ([x string]==nil)){
		[re executeString:@"try(main.help.url())"];            
		[x release];
		x = [re evaluateString:@"try(getOption(\"main.help.url\"))"];
		if((x == nil) | ([x string]==nil)){
			[x release];	
			return;		
		}
	 }

	NSString *url = [x string];

	if(url != nil)
	 	[[HelpView mainFrame] loadRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:url]]];
	[helpWindow makeKeyAndOrderFront:self];
	[x release];

}

- (IBAction)showRFAQ:(id)sender
{
	NSString *url = [[NSBundle mainBundle] resourcePath];
	if (!url) {
		REngine *re = [REngine mainEngine];	
		RSEXP *x= [re evaluateString:@"file.path(R.home(),\"RMacOSX-FAQ.html\")"];
		if(x==nil)
			return;
		url = [x string];
		[x release];
		if (url) url = [NSString stringWithFormat:@"file://%@", url];
	} else
		url = [NSString stringWithFormat:@"file://%@/RMacOSX-FAQ.html", url];

	if(url != nil) {
	 	[[HelpView mainFrame] loadRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:url]]];
		[helpWindow makeKeyAndOrderFront:self];
	}
}

- (IBAction)whatsNew:(id)sender
{

	SLog(@"What's New");

	REngine *re = [REngine mainEngine];

	/* syntax-highlighting kills us, so we use TextEdit for now */
	// [re executeString:@"system(paste('open -a /Applications/TextEdit.app',file.path(R.home(),'NEWS')))"];
	// {
	// 	NSBundle* myBundle = [NSBundle mainBundle];
	// 	if (myBundle)
	// 		system([[NSString stringWithFormat:@"open -a /Applications/TextEdit.app \"%@/NEWS\"", [myBundle resourcePath]] UTF8String]);
	// }

	NSBundle *myBundle = [NSBundle mainBundle];
	if(myBundle) {
		SLog(@" - resource path: %@", [myBundle resourcePath]);
		RSEXP *xx = [re evaluateString:[NSString stringWithFormat:@"file.show('%@/NEWS')", [[myBundle resourcePath] stringByReplacingOccurrencesOfString:@"'" withString:@"\\'"]]];
		if(xx) [xx release];
	}

	RSEXP *x = [re evaluateString:@"file.show(file.path(R.home(),\"NEWS\"))"];
	if(!x) return;
	[x release]; 

}

+ (id) sharedController{
	return sharedHMController;
}

- (void)showHelpFileForURL:(NSURL*)url
{
	if(url != nil) {
		SLog(@"HelpManager:showHelpFileForURL %@", [url absoluteString]);
		[[HelpView mainFrame] loadRequest:[NSURLRequest requestWithURL:url]];
		[helpWindow makeKeyAndOrderFront:self];
		return;
	}
	NSBeep();
}

- (IBAction)printDocument:(id)sender
{

	//TODO: for now, if displayed doc is a PDF open it via "Preview" for printing
	NSString *currentURL = [[HelpView mainFrameURL] lowercaseString];
	if([currentURL hasSuffix:@".pdf"]) {
		REngine *re = [REngine mainEngine];
		if (![re beginProtected]) {
			SLog(@"HelpManager.printPDF bailed because protected REngine entry failed [***]");
			return;
		}
		[re executeString:[NSString stringWithFormat:@"system('open \"%@\"', intern=TRUE, wait=FALSE)", currentURL]];
		[re endProtected];
		return;
	}


	NSPrintInfo *printInfo;
	NSPrintOperation *printOp;

	printInfo = [NSPrintInfo sharedPrintInfo];
	[printInfo setHorizontalPagination: NSFitPagination];
	[printInfo setVerticalPagination: NSAutoPagination];
	[printInfo setVerticallyCentered:NO];

	printOp = [NSPrintOperation printOperationWithView:[[[HelpView mainFrame] frameView] documentView] 
											 printInfo:printInfo];
	[printOp setShowPanels:YES];
	[printOp runOperationModalForWindow:[self window] 
							   delegate:self 
						 didRunSelector:@selector(sheetDidEnd:returnCode:contextInfo:) 
						    contextInfo:@""];
}

- (void) setSearchTypeViaSender:(id)sender
{

	if(sender == nil) {
		[self setSearchType:kExactMatch];
		return;
	}

	int type = [sender tag];

	if (type==kFuzzyMatch || type==kExactMatch) {
		[self setSearchType:type];
		NSMenu *m = [(NSSearchFieldCell*)sender menu];
		if(!m) return;
		[[m itemWithTag:kFuzzyMatch] setState:(searchType==kFuzzyMatch)?NSOnState:NSOffState];
		[[m itemWithTag:kExactMatch] setState:(searchType==kExactMatch)?NSOnState:NSOffState];
	}
}

- (void) awakeFromNib
{
	[self setSearchTypeViaSender:nil];
}

- (IBAction)changeSearchType:(id)sender
{
	[self setSearchTypeViaSender:sender];
}

- (void)setSearchType:(int)type
{
	if(type == kExactMatch || type == kFuzzyMatch) {
		if(type != searchType) {
			SLog(@"HelpManger - searchType was changed from %d to %d", searchType, type);
			searchType = type;

			// Update searchField's searchMenuTemplate
			NSMenu *m = [[searchField cell] searchMenuTemplate];
			[[m itemWithTag:kExactMatch] setState:(type == kExactMatch) ? NSOnState : NSOffState];
			[[m itemWithTag:kFuzzyMatch] setState:(type == kExactMatch) ? NSOffState : NSOnState];
			[[searchField cell] setSearchMenuTemplate:m];

			// If searchType was changed notify all other help search fields
			[[NSNotificationCenter defaultCenter] postNotificationName:@"HelpSearchTypeChanged" object:nil];
		}
	}
}

- (int)searchType
{
	return searchType;
}

- (void)webView:(WebView *)sender didStartProvisionalLoadForFrame:(WebFrame *)frame {
}

- (void)webView:(WebView *)sender didFinishLoadForFrame:(WebFrame *)frame {
	[back setEnabled: [sender canGoBack]];
	[forward setEnabled: [sender canGoForward]];
}

- (BOOL)validateMenuItem:(NSMenuItem *)menuItem
{
	if ([menuItem action] == @selector(executeSelection:)) {
		return ([HelpView selectedDOMRange] == nil) ? NO : YES;
	}

	return YES;
}

- (void)supportsWebViewSwipingInHistory
{
	return;
}

- (void)supportsWebViewMagnifying
{
	return;
}

- (void)sheetDidEnd:(id)sheet returnCode:(int)returnCode contextInfo:(NSString *)contextInfo
{

	SLog(@"HelpManger: sheetDidEnd: returnCode: %d contextInfo: %@", returnCode, contextInfo);

	// Order out the sheet - could be a NSPanel or NSWindow
	if ([sheet respondsToSelector:@selector(orderOut:)]) {
		[sheet orderOut:nil];
	}
	else if ([sheet respondsToSelector:@selector(window)]) {
		[[sheet window] orderOut:nil];
	}

	[helpWindow makeKeyAndOrderFront:nil];

}

@end
