//
//  AMPrefPaneIcon.m
//  PrefPane
//
//  Created by Andreas on Mon Jun 09 2003.
//  Copyright (c) 2003 Andreas Mayer. All rights reserved.
//

#import "AMPrefPaneIcon.h"


@implementation AMPrefPaneIcon

- (id)initWithIdentifier:(NSString *)theIdentifier image:(NSImage *)theImage andTitle:(NSString *)theTitle;
{
	self = [super init];
	[self setItemIdentifier:theIdentifier];
	[self setImage:theImage];
	[self setTitle:theTitle];
	[self setCategory:@""];
	return self;
}

- (id)init
{
	return [self initWithIdentifier:@"" image:nil andTitle:@""];
}

- (void)dealloc
{
	[image release];
	[title release];
	[category release];
	[super dealloc];
}

- (NSString *)itemIdentifier
{
    return itemIdentifier;
}

- (void)setItemIdentifier:(NSString *)newItemIdentifier
{
    id old = nil;

    if (newItemIdentifier != itemIdentifier) {
        old = itemIdentifier;
        itemIdentifier = [newItemIdentifier copy];
        [old release];
    }
}

- (NSImage *)image
{
    return image;
}

- (void)setImage:(NSImage *)newImage
{
	id old =  image;
	// scale image to icon size
	NSRect imageRect = NSZeroRect;
	imageRect.size = NSMakeSize(AMPrefPaneIconImageWidth, AMPrefPaneIconImageHeight);
	NSImage *tempImage = [[[NSImage alloc] initWithSize:imageRect.size] autorelease];
	[tempImage setFlipped:YES];
	[tempImage setCachedSeparately:YES];
	[tempImage lockFocus];
	NSRect sourceRect = NSZeroRect;
	sourceRect.size = [newImage size];
	[newImage drawInRect:imageRect fromRect:sourceRect operation:NSCompositeCopy fraction:1.0];
	[tempImage unlockFocus];
	// we want an NSBitmapImageRep ...
	image = [[NSImage alloc] initWithData:[tempImage TIFFRepresentationUsingCompression:NSTIFFCompressionNone factor:0.0]];
	// remove old representation
	[old release];
}

- (NSString *)title
{
    return title;
}

- (void)setTitle:(NSString *)newTitle
{
    id old = nil;

    if (newTitle != title) {
        old = title;
        title = [newTitle copy];
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

- (id)target
{
    return target;
}

- (void)setTarget:(id)newTarget
{
	target = newTarget;
}

- (SEL)selector
{
    return selector;
}

- (void)setSelector:(SEL)newSelector
{
    selector = newSelector;
}

- (NSComparisonResult)compare:(AMPrefPaneIcon *)anIcon
{
	return [[self title] compare:[anIcon title]];
}

- (NSComparisonResult)caseInsensitiveCompare:(AMPrefPaneIcon *)anIcon
{
	return [[self title] caseInsensitiveCompare:[anIcon title]];
}


@end
