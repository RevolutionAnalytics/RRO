//
//  AMPrefPaneIcon.h
//  PrefPane
//
//  Created by Andreas on Mon Jun 09 2003.
//  Copyright (c) 2003 Andreas Mayer. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AppKit/NSImage.h>

#define AMPrefPaneIconImageWidth 32
#define AMPrefPaneIconImageHeight 32


@interface AMPrefPaneIcon : NSObject {
	NSString *itemIdentifier;
	NSImage *image;
	NSString *title;
	NSString *category;
	id target;
	SEL selector;
}

- (id)initWithIdentifier:(NSString *)identifier image:(NSImage *)image andTitle:(NSString *)title;

- (NSString *)itemIdentifier;
- (void)setItemIdentifier:(NSString *)newItemIdentifier;

- (NSImage *)image;
- (void)setImage:(NSImage *)newImage;

- (NSString *)title;
- (void)setTitle:(NSString *)newTitle;

- (NSString *)category;
- (void)setCategory:(NSString *)newCategory;

- (id)target;
- (void)setTarget:(id)newTarget;

- (SEL)selector;
- (void)setSelector:(SEL)newSelector;


@end
