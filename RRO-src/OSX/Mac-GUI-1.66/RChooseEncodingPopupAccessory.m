/*
 *  R.app : a Cocoa front end to: "R A Computer Language for Statistical Data Analysis"
 *  
 *  R.app Copyright notes:
 *                     Copyright (C) 2004-5  The R Foundation
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
 *  RChooseEncodingPopupAccessory.m
 *
 *  Created by Hans-J. Bibiko on 16/03/2011.
 */

/*
  The core code was taken from Apple's TextEdit example:
    EncodingManager.m
    Copyright (c) 2002-2009 by Apple Computer, Inc., all rights reserved.
    Author: Ali Ozer

 IMPORTANT:  This Apple software is supplied to you by Apple Computer, Inc. ("Apple") in
 consideration of your agreement to the following terms, and your use, installation,
 modification or redistribution of this Apple software constitutes acceptance of these
 terms.  If you do not agree with these terms, please do not use, install, modify or
 redistribute this Apple software.

 In consideration of your agreement to abide by the following terms, and subject to these
 terms, Apple grants you a personal, non-exclusive license, under Apple's copyrights in
 this original Apple software (the "Apple Software"), to use, reproduce, modify and
 redistribute the Apple Software, with or without modifications, in source and/or binary
 forms; provided that if you redistribute the Apple Software in its entirety and without
 modifications, you must retain this notice and the following text and disclaimers in all
 such redistributions of the Apple Software.  Neither the name, trademarks, service marks
 or logos of Apple Computer, Inc. may be used to endorse or promote products derived from
 the Apple Software without specific prior written permission from Apple. Except as expressly
 stated in this notice, no other rights or licenses, express or implied, are granted by Apple
 herein, including but not limited to any patent rights that may be infringed by your
 derivative works or by other works in which the Apple Software may be incorporated.

 The Apple Software is provided by Apple on an "AS IS" basis.  APPLE MAKES NO WARRANTIES,
 EXPRESS OR IMPLIED, INCLUDING WITHOUT LIMITATION THE IMPLIED WARRANTIES OF NON-INFRINGEMENT,
 MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE, REGARDING THE APPLE SOFTWARE OR ITS
 USE AND OPERATION ALONE OR IN COMBINATION WITH YOUR PRODUCTS.

 IN NO EVENT SHALL APPLE BE LIABLE FOR ANY SPECIAL, INDIRECT, INCIDENTAL OR CONSEQUENTIAL
 DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS
 OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) ARISING IN ANY WAY OUT OF THE USE,
 REPRODUCTION, MODIFICATION AND/OR DISTRIBUTION OF THE APPLE SOFTWARE, HOWEVER CAUSED AND
 WHETHER UNDER THEORY OF CONTRACT, TORT (INCLUDING NEGLIGENCE), STRICT LIABILITY OR
 OTHERWISE, EVEN IF APPLE HAS BEEN ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*/
#import "RChooseEncodingPopupAccessory.h"
#import "RGUI.h"
#import "PreferenceKeys.h"
#import "RController.h"

// quasi sorted list of all supported and relevant encodings (NSStringEncoding)
static const NSInteger stringEncodingsSupported[] = {
	4,10,2348810496,2415919360,2483028224,2550137088,2617245952,
	30,5,12,2147484163,2147484175,1,2147486212,2,2147486721,2147486722,
	2147484672,2147484688,2147483677,9,2147484690,15,2147484164,3,8,
	2147486209,2147485224,21,2147485730,2147485729,2147483649,2147486001,
	2147486211,2147486214,2147486217,2147483650,2147484707,2147485233,
	2147485234,2147485744,2147486000,2147486213,2147483673,2147484705,2147486016,
	2147485760,2147483651,2147484706,2147483652,2147484166,2147484697,2147484934,
	2147483653,2147484168,2147484933,2147484695,2147486210,2147483655,2147484165,
	11,2147484691,2147484699,2147483800,2147486216,2147483654,2147484167,2147484677,
	2147484689,2147484700,13,2147483657,2147483658,2147483659,2147483669,2147484171,
	2147484701,2147483674,2147483788,2147483683,2147484169,2147484692,14,2147484170,
	2147484698,2147484173,2147484678,2147484935,2147484936,2147483684,2147483685,2147484694,
	2147483686,2147484176,2147483687,2147484174,2147483688,2147484693,2147484696,2147483884,7,
	-1
};


/*
    EncodingPopUpButtonCell is a subclass of NSPopUpButtonCell which provides the ability to automatically recompute its contents on changes 
    to the encodings list. This allows sprinkling these around the app any have them automatically update themselves. 
    Because we really only want to know when the cell's selectedItem is changed, we want to prevent the last item ("Customize...") 
    from being selected.
    In a nib file, to indicate that a default entry is wanted, the first menu item is given a tag of -1.
*/
@implementation EncodingPopUpButtonCell

- (id)initTextCell:(NSString *)stringValue pullsDown:(BOOL)pullDown
{
	if ((self = [super initTextCell:stringValue pullsDown:pullDown])) {
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(encodingsListChanged:) name:@"EncodingsListChanged" object:nil];
		[[RChooseEncodingPopupAccessory sharedInstance] setupPopUpCell:self selectedEncoding:kNoStringEncoding withDefaultEntry:NO];
	}
	return self;
}

- (id)initWithCoder:(NSCoder *)coder
{
	if ((self = [super initWithCoder:coder])) {
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(encodingsListChanged:) name:@"EncodingsListChanged" object:nil];
		[[RChooseEncodingPopupAccessory sharedInstance] setupPopUpCell:self 
													  selectedEncoding:kNoStringEncoding 
													  withDefaultEntry:([self numberOfItems] > 0 && [[self itemAtIndex:0] tag] == kWantsAutomaticTag)];
	}
	return self;
}

- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[super dealloc];
}

/** Do not allow selecting the "Customize" item and the separator before it. 
 * (Note that the customize item can be chosen and an action will be sent, but the selection doesn't change to it.)
 */
- (void)selectItemAtIndex:(NSInteger)index
{
	if (index + 2 <= [self numberOfItems]) [super selectItemAtIndex:index];
}

/* Update contents based on encodings list customization
*/
- (void)encodingsListChanged:(NSNotification *)notification
{
	[[RChooseEncodingPopupAccessory sharedInstance] setupPopUpCell:self 
									selectedEncoding:[[[self selectedItem] representedObject] unsignedIntegerValue] 
									withDefaultEntry:([self numberOfItems] > 0 && [[self itemAtIndex:0] tag] == kWantsAutomaticTag)];
}

@end

@implementation RChooseEncodingPopupAccessory

static RChooseEncodingPopupAccessory *sharedInstance = nil;

+ (RChooseEncodingPopupAccessory *)sharedInstance
{
	return sharedInstance ? sharedInstance : [[self alloc] init];
}

- (id)init
{
	if (sharedInstance) {
		[self release];
	}
	else if ((self = [super init]))
	{
		sharedInstance = self;
	}
	return sharedInstance;
}

- (void)dealloc
{
	if (self != sharedInstance) [super dealloc];
}

+ (NSArray *)allAvailableEncodings
{

    static NSMutableArray *allEncodings = nil;

	if (!allEncodings) {
		NSInteger cnt = 0;
		allEncodings = [[NSMutableArray alloc] init];
		while(stringEncodingsSupported[cnt] != -1) {
			[allEncodings addObject:[NSNumber numberWithUnsignedInteger:stringEncodingsSupported[cnt]]];
			cnt++;
		}
	}

	return allEncodings;

}

/**
 * Called once (when the UI is first brought up) to properly setup the encodings list in the "Customize Encodings List" panel.
 */
- (void)setupEncodingsList
{
	NSArray *allEncodings = [[self class] allAvailableEncodings];
	NSInteger cnt, numEncodings = [allEncodings count];

	for (cnt = 0; cnt < numEncodings; cnt++) {
		NSNumber *encodingNumber = [allEncodings objectAtIndex:cnt];
		NSStringEncoding encoding = [encodingNumber unsignedIntegerValue];
		NSString *encodingName = [NSString localizedNameOfStringEncoding:encoding];
		NSCell *cell;
		if (cnt >= [encodingMatrix numberOfRows]) [encodingMatrix addRow];
		cell = [encodingMatrix cellAtRow:cnt column:0];
		[cell setTitle:encodingName];
		[cell setRepresentedObject:encodingNumber];
	}
	[encodingMatrix sizeToCells];
	[self noteEncodingListChange:NO updateList:YES postNotification:NO];
}

/**
 * This method initializes the provided popup with list of encodings;
 * it also sets up the selected encoding as indicated and if includeDefaultItem is YES, 
 * includes an initial item for selecting "Automatic" choice. 
 * All encoding items have an NSNumber with the encoding (or kNoStringEncoding) as their representedObject.
 */
- (void)setupPopUpCell:(EncodingPopUpButtonCell *)popup selectedEncoding:(NSStringEncoding)selectedEncoding withDefaultEntry:(BOOL)includeDefaultItem
{
	NSArray *encs = [self enabledEncodings];
	NSUInteger cnt, numEncodings, itemToSelect = 0;

	// Put the encodings in the popup
	[popup removeAllItems];

	// Put the initial "Automatic" item, if desired
	if (includeDefaultItem) {
		[popup addItemWithTitle:NSLocalizedString(@"Automatic", @"Encoding popup entry indicating automatic choice of encoding")];
		[[popup itemAtIndex:0] setRepresentedObject:[NSNumber numberWithUnsignedInteger:kNoStringEncoding]];
		[[popup itemAtIndex:0] setTag:kWantsAutomaticTag]; // so that the default entry is included again next time
	}

	// Make sure the initial selected encoding appears in the list
	if (!includeDefaultItem && (selectedEncoding != kNoStringEncoding) && ![encs containsObject:[NSNumber numberWithUnsignedInteger:selectedEncoding]])
		encs = [encs arrayByAddingObject:[NSNumber numberWithUnsignedInteger:selectedEncoding]];

	numEncodings = [encs count];

	// Fill with encodings
	for (cnt = 0; cnt < numEncodings; cnt++) {
		NSNumber *encodingNumber = [encs objectAtIndex:cnt];
		NSStringEncoding encoding = [encodingNumber unsignedIntegerValue];
		[popup addItemWithTitle:[NSString localizedNameOfStringEncoding:encoding]];
		[[popup lastItem] setRepresentedObject:encodingNumber];
		[[popup lastItem] setEnabled:YES];
		if (encoding == selectedEncoding) itemToSelect = [popup numberOfItems] - 1;
		// UTF-8 is our default and is listed at the first position.
		// To emphasize it separate it by a separator
		if(encoding == NSUTF8StringEncoding && numEncodings > 1)
			[[popup menu] addItem:[NSMenuItem separatorItem]];
	}

	// Add an optional separator and "customize" item at end
	if ([popup numberOfItems] > 0) {
		[[popup menu] addItem:[NSMenuItem separatorItem]];
	}
	[popup addItemWithTitle:NLS(@"Customize List…")];
	[[popup lastItem] setAction:@selector(showPanel:)];
	[[popup lastItem] setTarget:self];

	[popup selectItemAtIndex:itemToSelect];
}

/**
 * Returns the actual enabled list of encodings for open/save files.
 */
- (NSArray *)enabledEncodings
{
	static const NSInteger stringEncodingsSupported[] = {
		kCFStringEncodingUTF8, kCFStringEncodingUnicode, kCFStringEncodingMacRoman, kCFStringEncodingISOLatin1, kCFStringEncodingWindowsLatin1, kCFStringEncodingISOLatin2, 
		kCFStringEncodingWindowsLatin2, kCFStringEncodingEUC_JP, kCFStringEncodingShiftJIS, kCFStringEncodingISO_2022_JP, kCFStringEncodingWindowsCyrillic, 
		kCFStringEncodingWindowsGreek, kCFStringEncodingWindowsLatin5, -1
		};
	if (encodings == nil) {
		NSMutableArray *encs = [[[NSUserDefaults standardUserDefaults] arrayForKey:usedFileEncodings] mutableCopy];
		if (encs == nil) {
			NSStringEncoding defaultEncoding = [NSString defaultCStringEncoding];
			NSStringEncoding encoding;
			BOOL hasDefault = NO;
			NSInteger cnt = 0;
			encs = [[NSMutableArray alloc] init];
			while (stringEncodingsSupported[cnt] != -1) {
				if ((encoding = CFStringConvertEncodingToNSStringEncoding(stringEncodingsSupported[cnt++])) != kCFStringEncodingInvalidId) {
					[encs addObject:[NSNumber numberWithUnsignedInteger:encoding]];
					if (encoding == defaultEncoding) hasDefault = YES;
				}
			}
			if (!hasDefault) [encs addObject:[NSNumber numberWithUnsignedInteger:defaultEncoding]];
		}
		encodings = encs;
	}
	return encodings;
}



/**
 * Should be called after any customization to the encodings list. Writes the new list out to defaults; 
 * updates the UI; also posts notification to get all encoding popups to update.
 */
- (void)noteEncodingListChange:(BOOL)writeDefault updateList:(BOOL)updateList postNotification:(BOOL)post
{

	if (writeDefault) [[NSUserDefaults standardUserDefaults] setObject:encodings forKey:usedFileEncodings];

	if (updateList) {
		NSInteger cnt, numEncodings = [encodingMatrix numberOfRows];
		for (cnt = 0; cnt < numEncodings; cnt++) {
			NSCell *cell = [encodingMatrix cellAtRow:cnt column:0];
			[cell setState:[encodings containsObject:[cell representedObject]] ? NSOnState : NSOffState];
		}
	}

	if (post) [[NSNotificationCenter defaultCenter] postNotificationName:@"EncodingsListChanged" object:nil];

	[[RController sharedController] updateReInterpretEncodingMenu];
}

/**
 * Because we want the encoding list to be modifiable even when a modal panel (such as the open panel) is up, 
 * we indicate that both the encodings list panel and the target work when modal. (See showPanel: below for the former...)
 */
- (BOOL)worksWhenModal
{
	return YES;
}


- (IBAction)showPanel:(id)sender
{
	if (!encodingMatrix) {
		if (![NSBundle loadNibNamed:@"SelectEncodingsPanel" owner:self])  {
			NSLog(@"Failed to load SelectEncodingsPanel.nib");
			return;
		}
		[(NSPanel *)[encodingMatrix window] setWorksWhenModal:YES];	// This should work when open panel is up
		[[encodingMatrix window] setLevel:NSModalPanelWindowLevel];	// Again, for the same reason
		[self setupEncodingsList];									// Initialize the list (only need to do this once)
	}
	[[encodingMatrix window] makeKeyAndOrderFront:nil];
}

- (IBAction)encodingListChanged:(id)sender
{
	NSInteger cnt, numRows = [encodingMatrix numberOfRows];
	NSMutableArray *encs = [[NSMutableArray alloc] init];

	for (cnt = 0; cnt < numRows; cnt++) {
		NSCell *cell = [encodingMatrix cellAtRow:cnt column:0];
		NSNumber *encodingNumber = [cell representedObject];
		// Add first item (our default) and all selected ones
		if (cnt == 0 || (([encodingNumber unsignedIntegerValue] != kNoStringEncoding) && ([cell state] == NSOnState)))
			[encs addObject:encodingNumber];
	}

	[encodings autorelease];
	encodings = encs;

	[self noteEncodingListChange:YES updateList:NO postNotification:YES];
}

- (IBAction)clearAll:(id)sender
{
	[encodings autorelease];
	// Empty encodings list, but not the default
	encodings = [[NSArray arrayWithObject:[NSNumber numberWithUnsignedInteger:NSUTF8StringEncoding]] retain];
	[self noteEncodingListChange:YES updateList:YES postNotification:YES];
}

- (IBAction)selectAll:(id)sender {
	[encodings autorelease];
	encodings = [[[self class] allAvailableEncodings] retain];	// All encodings
	[self noteEncodingListChange:YES updateList:YES postNotification:YES];
}

- (IBAction)revertToDefault:(id)sender {
	[encodings autorelease];
	encodings = nil;
	[[NSUserDefaults standardUserDefaults] removeObjectForKey:usedFileEncodings];
	(void)[self enabledEncodings];					// Regenerate default list
	[self noteEncodingListChange:NO updateList:YES postNotification:YES];
}


@end
