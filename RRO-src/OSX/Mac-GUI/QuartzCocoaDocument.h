//
//  QuartzCocoaDocument.h
//  R
//
//  Created by Simon Urbanek on 4/22/08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface QuartzCocoaDocument : NSDocument {
	NSWindow *window;
}

- (id) initWithWindow: (NSWindow*) aWindow;
- (NSWindow*) window;

@end
