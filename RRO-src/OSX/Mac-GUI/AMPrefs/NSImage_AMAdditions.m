//
//  NSImageAMAdditions.m
//  TimeDiscSaver
//
//  Created by Andreas on Sat Jan 18 2003.
//  Copyright (c) 2003 Andreas Mayer. All rights reserved.
//

#import "NSImage_AMAdditions.h"


@implementation NSImage (AMAdditions)

// If a bitmap image, fix the size of the bitmap so that it is
// equal to the exact pixel dimensions.
// FROM: Dan Wood
// DATE: 2001-10-19 19:00

- (NSImage *) normalizeSize
{
	NSBitmapImageRep *theBitmap = nil;
	NSSize newSize;
	NSArray *reps = [self representations];
	int i;

	for (i = 0 ; i < [reps count] ; i++ )
	{
		NSImageRep *theRep = [reps objectAtIndex:i];
		if ([theRep isKindOfClass:[NSBitmapImageRep class]])
		{
			theBitmap = (NSBitmapImageRep *)theRep;
			break;
		}
	}
	if (nil != theBitmap)
	{
		newSize.width = [theBitmap pixelsWide];
		newSize.height = [theBitmap pixelsHigh];
		[theBitmap setSize:newSize];
		[self setSize:newSize];
	}
	return self;
}

- (NSImage *)darkenedImageWithColor:(NSColor *)tint
{
	NSSize size = [self size];
	
	NSBitmapImageRep *bitmapImageRep = [[NSBitmapImageRep alloc] initWithBitmapDataPlanes:nil pixelsWide:size.width pixelsHigh:size.height bitsPerSample:8 samplesPerPixel:4 hasAlpha:YES isPlanar:NO colorSpaceName:NSCalibratedRGBColorSpace bytesPerRow:0 bitsPerPixel:0];
	NSImage *result = [[[NSImage alloc] initWithSize:size] autorelease];
	[result addRepresentation:bitmapImageRep];
	
	// get RGB components from tint color
	NSColor *rgbTint = [tint colorUsingColorSpaceName:NSCalibratedRGBColorSpace];
	// get bitmap data
	NSImageRep *imageRep = [[self representations] objectAtIndex:0];
	if ([imageRep isKindOfClass:NSClassFromString(@"NSBitmapImageRep")]) {
		unsigned char *sourceData = [(NSBitmapImageRep *)imageRep bitmapData];
		unsigned char *destData = [bitmapImageRep bitmapData];
		int x, y, pos;
		int bytesPerRow = [(NSBitmapImageRep *)imageRep bytesPerRow];
		int bytesPerPixel = [(NSBitmapImageRep *)imageRep bitsPerPixel]/8;
		int value = 0;
		int redTint = (256 - [rgbTint redComponent]*255);
		int greenTint = (256 - [rgbTint greenComponent]*255);
		int blueTint = (256 - [rgbTint blueComponent]*255);
		// process pixels
        if (*destData== '\0') {
            //NSLog(@"No data in destData (darkenedImageWithColor.m)");
        } else {
            //NSLog(@"destData has data");
            for (x = 0; x < size.width; x++) {
                for (y = 0; y < size.height; y++) {
                    pos = (y * bytesPerRow) + (x * bytesPerPixel);
                    value = sourceData[pos] - redTint;
                    destData[pos] = ((value > 0) ? value : 0);
                    value = sourceData[pos+1] - greenTint;
                    destData[pos+1] = ((value > 0) ? value : 0);
                    value = sourceData[pos+2] - blueTint;
                    destData[pos+2] = ((value > 0) ? value : 0);
                    // copy alpha from source
                    destData[pos+3] = sourceData[pos+3];
                }
            }
        }
	} else {
		NSLog(@"not a bitmap image rep");
	}
	[bitmapImageRep release];
	return result;
}

@end
