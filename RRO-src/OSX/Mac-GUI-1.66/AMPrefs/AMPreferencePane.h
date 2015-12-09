//
//  AMPreferencePane.h
//  PrefPane
//
//  Created by Andreas on Tue Aug 12 2003.
//  Copyright (c) 2003 Andreas Mayer. All rights reserved.
//

#import <AppKit/AppKit.h>
#import "AMPrefPaneProtocol.h"


@interface AMPreferencePane : NSProxy <AMPrefPaneProtocol> {
	NSString *identifier;
	NSView *mainView;
	NSString *label;
	NSImage *icon;
	NSString *category;
	NSString *version;
	// private
	NSBundle *pluginBundle;
	NSObject <AMPrefPaneBundleProtocol> *prefPane;
}

- (id)initWithBundle:(NSBundle *)bundle;
- (NSBundle *)bundle;

// AMPrefPaneProtocol

- (NSString *)identifier;
- (NSView *)mainView;
- (NSString *)label;
- (NSImage *)icon;
- (NSString *)category;

// AMTiggerClientPrefPane informal protocol

- (NSString *)version;

@end
