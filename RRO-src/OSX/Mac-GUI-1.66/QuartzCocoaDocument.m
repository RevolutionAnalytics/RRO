//
//  QuartzCocoaDocument.m
//  R
//
//  Created by Simon Urbanek on 4/22/08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import "RGUI.h"
#import "QuartzCocoaDocument.h"
#import "RDocumentController.h"

@implementation QuartzCocoaDocument

- (id) initWithWindow: (NSWindow*) aWindow
{
	self = [super init];
	if (self) {
		window = aWindow;
		[self setFileType:ftQuartz];
		[window retain];
		SLog(@"QuartzCocoaDocument.initWithWindow:%@", window);
	}
	return self;
}

- (void) dealloc
{
	SLog(@"QuartzCocoaDocument.dealloc");
	if (window) [window release];
	[super dealloc];
}

- (void) close
{
	SLog(@"QuartzCocoaDocument.close");
	[super close];
}

- (void)makeWindowControllers
{
	NSWindowController *wc = [[NSWindowController alloc] initWithWindow:window];
	SLog(@" - new Quartz window %@ - creating corresponding document %@ and wctrl %@", window, self, wc);
	[wc setShouldCloseDocument:YES];
	[self addWindowController:wc];
	[wc release];
}


- (NSData *)dataOfType:(NSString *)typeName error:(NSError **)outError
{
	return nil;
}

- (BOOL)readFromData:(NSData *)data ofType:(NSString *)typeName error:(NSError **)outError
{
	return YES;
}

- (NSWindow*) window
{
	return window;
}

// this should never be reached
- (NSTextView *)textView
{
	return nil;
}
@end
