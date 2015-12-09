//
//  AMPreferencePane.m
//  PrefPane
//
//  Created by Andreas on Tue Aug 12 2003.
//  Copyright (c) 2003 Andreas Mayer. All rights reserved.
//

#import "AMPreferencePane.h"


@interface AMPreferencePane (Private)
- (NSView *)loadMainView;
- (NSBundle *)pluginBundle;
- (void)setPluginBundle:(NSBundle *)newPluginBundle;
- (NSObject <AMPrefPaneProtocol>*)prefPane;
- (void)setIdentifier:(NSString *)newIdentifier;
- (void)setPrefPane:(NSObject <AMPrefPaneProtocol>*)newPrefPane;
- (void)setLabel:(NSString *)newLabel;
- (void)setMainView:(NSView *)newMainView;
- (void)setIcon:(NSImage *)newIcon;
- (void)setCategory:(NSString *)newCategory;
- (void)setVersion:(NSString *)newLabel;
@end


@implementation AMPreferencePane


- (id)initWithBundle:(NSBundle *)bundle
{
	//if (self = [super init]) {
		NSString* pluginPrincipalClass = [bundle objectForInfoDictionaryKey:NSPrincipalClassKey];
		[self setIdentifier:[bundle objectForInfoDictionaryKey:CFBundleIdentifierKey]];
		if (!pluginPrincipalClass) {
			NSLog(@"principal class name not found");
		} else {  // found principal class name
			Class pluginClass = NSClassFromString(pluginPrincipalClass);
			if ([pluginClass class]) {
				NSLog(@"class %@ already exists", pluginPrincipalClass);
			} else { // is unique
				[self setPluginBundle:bundle];
				// label
				NSString *s = [bundle objectForInfoDictionaryKey:NSPrefPaneIconLabelKey];
				if (s) {
					[self setLabel:s];
				} else {
					[self setLabel:identifier];
				}
				// icon
				NSImage *theImage = nil;
				NSString *imageName = [bundle objectForInfoDictionaryKey:NSPrefPaneIconFileKey];
				if (!imageName) {
					imageName = identifier;
				}
				theImage = [[[NSImage alloc] initWithContentsOfFile:[bundle pathForImageResource:imageName]] autorelease];
				[self setIcon:theImage];
				NSString *categoryName = [bundle objectForInfoDictionaryKey:AMPrefPaneCategoryKey];
				[self setCategory:categoryName];
				NSString *versionInfo = [bundle objectForInfoDictionaryKey:AMPrefPaneVersionKey];
				[self setVersion:versionInfo];
			}
		}
	//}
	return self;
}

- (NSBundle *)bundle
{
	return pluginBundle;
}

- (void)dealloc
{
	[label release];
	[icon release];
	[mainView release];
	[pluginBundle release];
	[prefPane release];
	[super dealloc];
}

- (NSView *)loadMainView
{
	NSView *result = mainView;
	if (pluginBundle) {
		if ([self prefPane]) {
			result = [prefPane loadMainView];
		}
	}
	return result;
}

- (NSView *)mainView
{
	NSView *result = mainView;
	if (pluginBundle) {
		if ([self prefPane]) {
			result = [prefPane mainView];
		}
	}
	return result;
}

- (NSString *)identifier
{
    return identifier;
}

- (void)setIdentifier:(NSString *)newIdentifier
{
    id old = nil;

    if (newIdentifier != identifier) {
        old = identifier;
        identifier = [newIdentifier copy];
        [old release];
    }
}

- (NSString *)label
{
	return label;
}

- (void)setLabel:(NSString *)newLabel
{
	id old = nil;

	if (newLabel != label) {
		old = label;
		label = [newLabel copy];
		[old release];
	}
}

- (void)setMainView:(NSView *)newMainView
{
	if (!pluginBundle) {
		id old = nil;

		if (newMainView != mainView) {
			old = mainView;
			mainView = [newMainView retain];
			[old release];
		}
	}
}

- (NSImage *)icon
{
	return icon;
}

- (void)setIcon:(NSImage *)newIcon
{
	id old = nil;

	if (newIcon != icon) {
		old = icon;
		icon = [newIcon retain];
		[old release];
	}
}

- (NSString *)category
{
    return category;
}

- (void)setCategory:(NSString *)newCategory
{
    id old = nil;

    if (newCategory != category) {
        old = category;
        category = [newCategory copy];
        [old release];
    }
}

- (NSString *)version
{
    return version;
}

- (void)setVersion:(NSString *)newVersion
{
    id old = nil;

    if (newVersion != version) {
        old = version;
        version = [newVersion copy];
        [old release];
    }
}

- (NSBundle *)pluginBundle
{
	return pluginBundle;
}

- (void)setPluginBundle:(NSBundle *)newPluginBundle
{
	id old = nil;

	if (newPluginBundle != pluginBundle) {
		old = pluginBundle;
		pluginBundle = [newPluginBundle retain];
		[old release];
	}
}


- (NSObject <AMPrefPaneProtocol>*)prefPane
{
	if (!prefPane && pluginBundle) {
		// load bundle nib file
		NSString* pluginPrincipalClass = [pluginBundle objectForInfoDictionaryKey:NSPrincipalClassKey];
		Class pluginClass = [pluginBundle classNamed:pluginPrincipalClass];
		NSObject <AMPrefPaneProtocol>* newPrefPane = nil;
		if ((newPrefPane = [[[pluginClass alloc] initWithBundle:pluginBundle] autorelease])) {
			[self setPrefPane:newPrefPane];
			if ([prefPane respondsToSelector:@selector(loadMainView)])
				[prefPane loadMainView];
		}
	}
	return prefPane;
}

- (void)setPrefPane:(NSObject <AMPrefPaneProtocol>*)newPrefPane
{
	id old = nil;

	if (newPrefPane != prefPane) {
		old = prefPane;
		prefPane = [newPrefPane retain];
		[old release];
	}
}

/* I suppose this is what NSProxy does? ... or maybe not ... */

- (BOOL)respondsToSelector:(SEL)aSelector
{
	BOOL result = [[self prefPane] respondsToSelector:aSelector];
	if (!result) {
		result = [super respondsToSelector:aSelector];
	}
	return result;
}

- (NSMethodSignature *)methodSignatureForSelector:(SEL)aSelector
{
	NSMethodSignature *signature = [prefPane methodSignatureForSelector:aSelector];
	return signature;
}

- (void)forwardInvocation:(NSInvocation *)anInvocation
{
	if ([[self prefPane] respondsToSelector:[anInvocation selector]]) {
		[anInvocation invokeWithTarget:prefPane];
	} else {
		[super forwardInvocation:anInvocation];
	}
}


@end
