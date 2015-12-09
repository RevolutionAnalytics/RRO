/*
 *  CCComp.h - Common Cocoa Compatibility
 *  R
 *
 *  Include in all files instead of Cocoa, it provides compatibility work-arounds.
 *
 *  Created by Simon Urbanek on 3/15/11.
 *  Copyright 20011 R Foundation for Statistical Computing. All rights reserved.
 *  License: GPL v2+
 *
 */

/* (technically, this is no-op since Cocoa is pre-compiled but it feels better ;)) */
#import <Cocoa/Cocoa.h>
#import <Availability.h>

/* define constants for SDKs that already exist may be newer than the base SDK so we can check for them */
/* use MAC_OS_X_VERSION_MAX_ALLOWED to test for base SDK at build time and
 *     MAC_OS_X_VERSION_MAX_REQUIRED to test for (possibly weak-linked) minimal functionality */
#ifndef MAC_OS_X_VERSION_10_5
#define MAC_OS_X_VERSION_10_5 1050
#endif
#ifndef MAC_OS_X_VERSION_10_6
#define MAC_OS_X_VERSION_10_6 1060
#endif
#ifndef MAC_OS_X_VERSION_10_7
#define MAC_OS_X_VERSION_10_7 1070
#endif
#ifndef MAC_OS_X_VERSION_10_8
#define MAC_OS_X_VERSION_10_8 1080
#endif
#ifndef MAC_OS_X_VERSION_10_9
#define MAC_OS_X_VERSION_10_9 1090
#endif

/* the following protocols are new in 10.6 (and useful) so for older OS X we have to define them */
#if MAC_OS_X_VERSION_MAX_ALLOWED < MAC_OS_X_VERSION_10_6
@protocol NSTextStorageDelegate <NSObject>
@optional
- (void)textStorageWillProcessEditing:(NSNotification *)notification;   /* Delegate can change the characters or attributes */
- (void)textStorageDidProcessEditing:(NSNotification *)notification;    /* Delegate can change the attributes */
@end
@protocol NSToolbarDelegate <NSObject>
@optional
- (NSToolbarItem *)toolbar:(NSToolbar *)toolbar itemForItemIdentifier:(NSString *)itemIdentifier willBeInsertedIntoToolbar:(BOOL)flag;
- (NSArray *)toolbarDefaultItemIdentifiers:(NSToolbar*)toolbar;
- (NSArray *)toolbarAllowedItemIdentifiers:(NSToolbar*)toolbar;
- (NSArray *)toolbarSelectableItemIdentifiers:(NSToolbar *)toolbar;
- (void)toolbarWillAddItem: (NSNotification *)notification;
- (void)toolbarDidRemoveItem: (NSNotification *)notification;
@end
#endif

/* NS integer types for pre-10.5 compatibility */
#ifndef NSINTEGER_DEFINED
#if __LP64__ || NS_BUILD_32_LIKE_64
typedef long NSInteger;
typedef unsigned long NSUInteger;
#else
typedef int NSInteger;
typedef unsigned int NSUInteger;
#endif
#define NSINTEGER_DEFINED 1
#endif
