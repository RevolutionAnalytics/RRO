//
//  NSImageAMAdditions.h
//  TimeDiscSaver
//
//  Created by Andreas on Sat Jan 18 2003.
//  Copyright (c) 2003 Andreas Mayer. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface NSImage (AMAdditions)

// If a bitmap image, fix the size of the bitmap so that it is
// equal to the exact pixel dimensions.
// FROM: Dan Wood
// DATE: 2001-10-19 19:00

- (NSImage *)normalizeSize;

- (NSImage *)darkenedImageWithColor:(NSColor *)tint;


@end
