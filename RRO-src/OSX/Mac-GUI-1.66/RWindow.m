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
 *  RWindow.m
 *
 *  Created by Hans-J. Bibiko on 18/02/2012.
 *
 */

#import "RWindow.h"
#import <WebKit/WebKit.h>
#import "RController.h"
#import "HelpManager.h"


#if MAC_OS_X_VERSION_MIN_REQUIRED <= MAC_OS_X_VERSION_10_5
// declare the following methods to avoid compiler warnings
@interface NSWindow (SuppressWarnings)
- (void)swipeWithEvent:(NSEvent *)event;
- (void)magnifyWithEvent:(NSEvent *)event;
@end
#endif

@implementation RWindow

/**
 * Dispatcher for trackpad three-finger swiping
 */
- (void)swipeWithEvent:(NSEvent *)event
{

	// Check for RConsole to toggle history
	if([[self delegate] respondsToSelector:@selector(toggleHistory:)]) {

		CGFloat x = [event deltaX];
		CGFloat y = [event deltaY];
		NSNumber *onEdge = nil;

		if(x == -1.0f && y == 0.0f)
			onEdge = [NSNumber numberWithInt:NSMaxXEdge];
		else if(x == 1.0f && y == 0.0f)
			onEdge = [NSNumber numberWithInt:NSMinXEdge];

		if(onEdge) {
			[(id)[self delegate] toggleHistory:onEdge];
			return;
		}

	}

	// Check for helper windows for navigating back and forward
	// - to use it the helper delegates have to be implemented the following methods:
	//     (void)supportsWebViewSwipingInHistory  [just an identifier]
	//     (WebView*)webView  [which returns the web view in question]
	if([[self delegate] respondsToSelector:@selector(supportsWebViewSwipingInHistory)]) {

		WebView* wv = [(id)[self delegate] webView];

		CGFloat x = [event deltaX];
		CGFloat y = [event deltaY];

		if(x == -1.0f && y == 0.0f && [wv canGoForward]) {
			[wv goForward];
			return;
		}
		else if(x == 1.0f && y == 0.0f && [wv canGoBack]) {
			[wv goBack];
			return;
		}
		
	}

	[super swipeWithEvent:event];

}

- (void)magnifyWithEvent:(NSEvent *)event
{
	if([[self delegate] respondsToSelector:@selector(supportsWebViewMagnifying)]) {
		[[RController sharedController] fontSizeChangedBy:([event deltaZ]/100) withSender:self];
		return;
	}

	[super magnifyWithEvent:event];

}


@end
