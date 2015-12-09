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
 *  RChooseMenuItemDialog.m
 *
 *  Created by Hans-J. Bibiko on 26/02/2012.
 *
 * Usage:
 *
 * #import "Tools/RChooseMenuItemDialog.h"
 *
 * [RChooseMenuItemDialog withItems:
 * 		[NSArray arrayWithObjects:@"item0", @"item1", nil] atPosition:[NSEvent mouseLocation]]
 *
 * It return the index of the chosen menu item or -1 if user pressed ESC
 *
 */

#import "RChooseMenuItemDialog.h"

@interface RChooseMenuItemDialogTextView : NSTextView
{
}

- (IBAction)menuItemHandler:(id)sender;

@end

@implementation RChooseMenuItemDialogTextView
{
}
- (id)init;
{
	if((self = [super initWithFrame:NSMakeRect(1,1,2,2)]))
	{
		;
	}
	return self;
}

- (IBAction)menuItemHandler:(id)sender
{
	[(id)[self delegate] setSelectedItemIndex:[sender tag]];
	[(id)[self delegate] setWaitForChoice:NO];
}

- (NSMenu *)menuForEvent:(NSEvent *)event 
{
	return [(id)[self delegate] contextMenu];
}

@end

@implementation RChooseMenuItemDialog

@synthesize contextMenu;
@synthesize selectedItemIndex;
@synthesize waitForChoice;

- (id)init;
{
	if((self = [super initWithContentRect:NSMakeRect(1,1,2,2) 
					styleMask:NSBorderlessWindowMask backing:NSBackingStoreBuffered defer:NO]))
	{
		waitForChoice = YES;
		selectedItemIndex = -1;
	}
	return self;
}

- (void)dealloc
{
	[dummyTextView release];
	[super dealloc];
}

- (void)initDialog
{
	[self setReleasedWhenClosed:YES];
	[self setLevel:NSNormalWindowLevel];
	[self setHidesOnDeactivate:YES];
	[self setHasShadow:YES];
	[self setAlphaValue:0.0f];

	dummyTextView = [[RChooseMenuItemDialogTextView alloc] init];
	[dummyTextView setDelegate:(id)self];

	[self setContentView:dummyTextView];

}

+ (NSInteger)withItems:(NSArray*)theList atPosition:(NSPoint)location
{

	if(!theList || ![theList count]) return -1;

	RChooseMenuItemDialog *dialog = [RChooseMenuItemDialog new];

	[dialog initDialog];
	
	NSMenu *theMenu = [[[NSMenu alloc] init] autorelease];
	NSInteger cnt = 0;
	for(id item in theList) {
		NSMenuItem *aMenuItem = nil;
		if([item isKindOfClass:[NSString class]])
			aMenuItem = [[NSMenuItem alloc] initWithTitle:item action:@selector(menuItemHandler:) keyEquivalent:@""];
		else if([item isKindOfClass:[NSDictionary class]]) {
			NSString *title = ([item objectForKey:@"title"]) ?: @"";
			SEL action = ([item objectForKey:@"action"]) ? NSSelectorFromString([item objectForKey:@"action"]) : @selector(menuItemHandler:);
			NSString *keyEquivalent = ([item objectForKey:@"key"]) ?: @"";
			aMenuItem = [[NSMenuItem alloc] initWithTitle:title action:action keyEquivalent:keyEquivalent];
			if([item objectForKey:@"tooltip"])
				[aMenuItem setToolTip:[item objectForKey:@"tooltip"]];
		}
		[aMenuItem setTag:cnt++];
		[theMenu addItem:aMenuItem];
		[aMenuItem release];
	}
	[dialog setContextMenu:theMenu];

	[dialog setFrameTopLeftPoint:location];

	[dialog makeKeyAndOrderFront:nil];

	// Send a right-click to order front the context menu
	NSEvent *theEvent = [NSEvent
	        mouseEventWithType:NSRightMouseDown
	        location:NSMakePoint(1,1)
	        modifierFlags:0
	        timestamp:1
	        windowNumber:[dialog windowNumber]
	        context:[NSGraphicsContext currentContext]
	        eventNumber:0
	        clickCount:1
	        pressure:0.0f];

	[[NSApplication sharedApplication] sendEvent:theEvent];

	while([dialog waitForChoice] && [[[NSApp keyWindow] firstResponder] isKindOfClass:[RChooseMenuItemDialogTextView class]]) {

		NSEvent* event = [NSApp nextEventMatchingMask:NSAnyEventMask
                                          untilDate:[NSDate distantFuture]
                                             inMode:NSDefaultRunLoopMode
                                            dequeue:YES];

		if(!event) continue;

		[NSApp sendEvent:event];

		usleep(1000);

	}

	[dialog performSelector:@selector(close) withObject:nil afterDelay:0.01];

	return [dialog selectedItemIndex];
}

@end
