//
//  AMPrefPaneIconView.m
//  PrefPane
//
//  Created by Andreas on Mon Jun 09 2003.
//  Copyright (c) 2003 Andreas Mayer. All rights reserved.
//

#import "AMPrefPaneIconView.h"
#import "NSImage_AMAdditions.h"

#define AMPrefPaneIconViewVerticalPadding 10
#define AMPrefPaneIconViewHorizontalPadding 40
#define AMPrefPaneIconViewTopGroupPadding 3
#define AMPrefPaneIconViewTopPadding 2
#define AMPrefPaneIconViewBottomGroupPadding 6
#define AMPrefPaneIconViewBottomPadding 10
#define AMPrefPaneIconViewTopIconPadding 8
#define AMPrefPaneIconViewVerticalLabelSpacing 3
#define AMPrefPaneIconViewHorizontalIconSpacing 20



@interface AMPrefPaneIconView (Private)
- (NSMutableArray *)iconListList;
- (void)setIconListList:(NSMutableArray *)newIconListList;
- (AMPrefPaneIcon *)_am_selectedIcon;
- (void)_am_setSelectedIcon:(AMPrefPaneIcon *)newSelectedIcon;
- (void)rebuild;
- (NSPoint)positionForIconInCategoryWithIndex:(int)categoryIndex atIndex:(int)iconIndex;
- (NSRect)frameForCategoryWithIndex:(int)index;
- (NSRect)imageFrameForIconInCategoryWithIndex:(int)categoryIndex atIndex:(int)iconIndex;
- (NSRect)labelFrameForIconInCategoryWithIndex:(int)categoryIndex atIndex:(int)iconIndex;
- (void)drawBackgroundForCategoryWithIndex:(int)index;
- (void)drawIcon:(AMPrefPaneIcon *)icon atPosition:(NSPoint)pos highlighted:(BOOL)highlighted;
@end


@implementation AMPrefPaneIconView

// ============================================================
#pragma mark -
#pragma mark ━ initialization ━
// ============================================================

- (id)initWithController:(AMPreferenceWindowController *)theController icons:(NSArray *)theIcons columns:(int)numColumns
{
	self = [super initWithFrame:NSZeroRect];
	if (self) {
		[self setIconListList:[NSMutableArray array]];
		[self setPrefsController:theController];
		[self setIcons:theIcons];
		[self setColumns:numColumns];
		//[self setSortByCategory:YES];
		NSFont *labelFont = [NSFont systemFontOfSize:[NSFont systemFontSizeForControlSize:NSSmallControlSize]];
		NSMutableParagraphStyle *mutParaStyle=[[NSMutableParagraphStyle alloc] init];
		[mutParaStyle setAlignment:NSCenterTextAlignment];
		// [attrStr addAttributes:[NSDictionary dictionaryWithObject:mutParaStyle forKey:NSParagraphStyleAttributeName] range:NSMakeRange(0,[attrStr length])];
		_am_iconLabelAttributes = [[NSDictionary dictionaryWithObjectsAndKeys:
			labelFont, NSFontAttributeName,
			mutParaStyle, NSParagraphStyleAttributeName,
			nil] retain];
		NSFont *captionFont = [NSFont boldSystemFontOfSize:[NSFont systemFontSize]];
		_am_captionAttributes = [[NSDictionary dictionaryWithObject:captionFont forKey:NSFontAttributeName] retain];
		[mutParaStyle release];

	}
	return self;
}

- (id)initWithFrame:(NSRect)frame
{
	return [self initWithController:nil icons:[[NSArray array] autorelease] columns:7];
}

- (void)dealloc
{
	[_am_iconLabelAttributes release];
	[icons release];
	[super dealloc];
}

// ============================================================
#pragma mark -
#pragma mark ━ accessors ━
// ============================================================

- (AMPreferenceWindowController *)prefsController
{
    return prefsController;
}

- (void)setPrefsController:(AMPreferenceWindowController *)newPrefsController
{
    id old = nil;

    if (newPrefsController != prefsController) {
        old = prefsController;
        prefsController = [newPrefsController retain];
        [old release];
    }
}

- (NSArray *)icons
{
    return icons;
}

- (void)setIcons:(NSArray *)newIcons
{
	id old = icons;
	icons = [newIcons mutableCopy];
	[old release];
	dataChanged = YES;
}

- (int)columns
{
	return columns;
}

- (void)setColumns:(int)newColumns
{
	dataChanged = (columns != newColumns);
	columns = newColumns;
}

- (BOOL)sortByCategory
{
    return sortByCategory;
}

- (void)setSortByCategory:(BOOL)newSortByCategory
{
	dataChanged = dataChanged || (sortByCategory != newSortByCategory);
	sortByCategory = newSortByCategory;
}

- (NSArray *)categorySortOrder
{
	return categorySortOrder;
}

- (void)setCategorySortOrder:(NSArray *)newCategorySortOrder
{
	id old = categorySortOrder;
	categorySortOrder = [newCategorySortOrder copy];
	[old release];
	dataChanged = YES;
}

- (AMPrefPaneIcon *)_am_selectedIcon
{
    return _am_selectedIcon;
}

- (void)_am_setSelectedIcon:(AMPrefPaneIcon *)newSelectedIcon
{
    id old = nil;

    if (newSelectedIcon != _am_selectedIcon) {
        old = _am_selectedIcon;
        _am_selectedIcon = [newSelectedIcon retain];
        [old release];
    }
}

- (NSMutableArray *)iconListList
{
    return iconListList;
}

- (void)setIconListList:(NSMutableArray *)newIconListList
{
    id old = nil;

    if (newIconListList != iconListList) {
        old = iconListList;
        iconListList = [newIconListList retain];
        [old release];
    }
}

// ============================================================
#pragma mark -
#pragma mark ━ public methods ━
// ============================================================

- (void)removeAllIcons
{
	[icons removeAllObjects];
	dataChanged = YES;
}

- (void)addIcon:(AMPrefPaneIcon *)icon
{
	[icons addObject:icon];
	dataChanged = YES;
}

// ============================================================
#pragma mark -
#pragma mark ━ private methods ━
// ============================================================

- (void)calculateGeometry
{
	// calculate icon sizes and positions
	horizontalPadding = AMPrefPaneIconViewHorizontalPadding;
	iconSpacing = AMPrefPaneIconImageWidth;
	AMPrefPaneIcon *previousIcon = nil;
	NSSize previousIconSize = NSZeroSize;
	int rows = 0;

	NSEnumerator *listEnumerator = [iconListList objectEnumerator];
	NSMutableArray *iconList;
	while ((iconList = [listEnumerator nextObject])) { // loop over categories
		int column = 0;

		NSEnumerator *iconEnumerator = [iconList objectEnumerator];
		AMPrefPaneIcon *icon;
		while ((icon = [iconEnumerator nextObject])) { // loop over icons
			column++;
			if (column > columns) {
				column = 1;
				rows++;
			}
			//NSSize imageSize = [[icon image] size];
			NSSize imageSize = NSMakeSize(AMPrefPaneIconImageWidth, AMPrefPaneIconImageHeight); // 32 x 32 fixed
			NSSize titleSize = [[icon title] sizeWithAttributes:_am_iconLabelAttributes];
			NSSize iconSize = NSMakeSize(ceilf(MAX(imageSize.width, titleSize.width)), imageSize.height+titleSize.height);
			iconHeight = MAX(iconHeight, iconSize.height+AMPrefPaneIconViewVerticalPadding);
			if (column > 1) {
				iconSpacing = MAX(iconSpacing, (iconSize.width+previousIconSize.width)/2);
			}
			if (((column-1) % columns) == 0) {
				horizontalPadding = MAX(horizontalPadding, (titleSize.width-iconSpacing)/2 +AMPrefPaneIconViewHorizontalPadding);
			}				
			previousIcon = icon;
			previousIconSize = iconSize;
		} // while icon
		rows++;
	} // while iconList
	NSRect newFrame = NSZeroRect;
	iconSpacing += AMPrefPaneIconViewHorizontalIconSpacing;
	newFrame.size.width = ceilf((columns * iconSpacing)+horizontalPadding);
	newFrame.size.height = (rows * iconHeight) +AMPrefPaneIconViewTopPadding +AMPrefPaneIconViewTopGroupPadding +AMPrefPaneIconViewBottomPadding;
	if (sortByCategory) {
		// add headers
		NSFont *boldSystemFont = [[NSFont boldSystemFontOfSize:[NSFont systemFontSize]] autorelease];
		NSLayoutManager *layoutManager = [[NSLayoutManager alloc] init];
		captionHeight = ceilf((float) [layoutManager defaultLineHeightForFont: boldSystemFont]);
		[layoutManager release];
	} else {
		captionHeight = 0.0;
	}
	newFrame.size.height += ([iconListList count] *(AMPrefPaneIconViewBottomGroupPadding+captionHeight));
	[self setFrame:newFrame];
}

/* OS X <10.5 don't have NSInteger, so we need to defined it */
#ifndef NSINTEGER_DEFINED
#if __LP64__ || NS_BUILD_32_LIKE_64
typedef long NSInteger;
typedef unsigned long NSUInteger;
#else
typedef int NSInteger;
typedef unsigned int NSUInteger;
#endif
#endif

NSInteger _am_compareByCategory(id array1, id array2, void *prefsController)
{
	NSString *identifier1 = [(AMPrefPaneIcon *)[array1 objectAtIndex:0] itemIdentifier];
	NSString *identifier2 = [(AMPrefPaneIcon *)[array2 objectAtIndex:0] itemIdentifier];
	return [[(id)prefsController categoryDisplayNameForIdentifier:identifier1] caseInsensitiveCompare:[(id)prefsController categoryDisplayNameForIdentifier:identifier2]];
}

- (void)sortCategories
{
	NSMutableArray *newIconListList = [NSMutableArray array];
	if (categorySortOrder) {
		NSEnumerator *sortOrderEnumerator = [categorySortOrder objectEnumerator];
		NSString *category;
		while ((category = [sortOrderEnumerator nextObject])) {
			NSEnumerator *enumerator = [iconListList objectEnumerator];
			NSArray *iconList;
			while ((iconList = [enumerator nextObject])) {
				if ([[(AMPrefPaneIcon *)[iconList objectAtIndex:0] category] isEqualToString:category]) {
					[newIconListList addObject:iconList];
					break;
				}
			}
		}
		NSEnumerator *enumerator = [iconListList objectEnumerator];
		NSArray *iconList;
		while ((iconList = [enumerator nextObject])) {
			if ((![newIconListList containsObject:iconList])) {
				[newIconListList addObject:iconList];
			}
		}
		[self setIconListList:newIconListList];
	} else {
		[iconListList sortUsingFunction:&_am_compareByCategory context:prefsController];
	}
}

- (void)rebuild
{
	dataChanged = NO;
	// sort icons
	if (sortByCategory) {
		[iconListList removeAllObjects];
		NSMutableDictionary *categoryIndex = [[[NSMutableDictionary alloc] init] autorelease];
		NSEnumerator *enumerator = [icons objectEnumerator];
		AMPrefPaneIcon *icon;
		while ((icon = [enumerator nextObject])) {
			id key = [icon category];
			if (key == nil) {
				key = [NSNull null];
			}
			//NSLog(@"category: %@", key);
			NSMutableArray *category = [categoryIndex objectForKey:key];
			if (category == nil) {
				category = [[[NSMutableArray alloc] init] autorelease];
				[categoryIndex setObject:category forKey:key];
				[iconListList addObject:category];
			}
			[category addObject:icon];
		}
		enumerator = [iconListList objectEnumerator];
		NSMutableArray *iconList;
		while ((iconList = [enumerator nextObject])) {
			[iconList sortUsingSelector:@selector(caseInsensitiveCompare:)];
		}
		[self sortCategories];
	} else {
		[iconListList removeAllObjects];
		NSMutableArray *allIcons = [[icons mutableCopy] autorelease];
		[iconListList addObject:allIcons];
		[allIcons sortUsingSelector:@selector(caseInsensitiveCompare:)];
	}
	[self calculateGeometry];
}

- (NSRect)frameForCategoryWithIndex:(int)index
{
	NSRect result = NSZeroRect;
	// category header height
	// category offset
	int i;
	for (i = 0; i < index; i++) {
		result.origin.y += ((ceilf(([[iconListList objectAtIndex:i] count]-1) / columns)+1) *iconHeight);
	}
	result.size.height = ((ceilf(([[iconListList objectAtIndex:index] count]-1) / columns)+1) *iconHeight) +AMPrefPaneIconViewBottomGroupPadding +captionHeight +AMPrefPaneIconViewTopGroupPadding;
	result.origin.y += i*(AMPrefPaneIconViewBottomGroupPadding +captionHeight +AMPrefPaneIconViewTopGroupPadding);
	if (index == 0) {
		result.size.height += AMPrefPaneIconViewTopPadding;
	} else {
		result.origin.y += AMPrefPaneIconViewTopPadding;
	}
	if (index == ([iconListList count]-1)) {
		result.size.height += AMPrefPaneIconViewBottomPadding;
	}
	result.size.width = ([self frame].size.width);
	return result;
}

- (NSPoint)positionForIconInCategoryWithIndex:(int)categoryIndex atIndex:(int)iconIndex
{
	NSPoint result = [self frameForCategoryWithIndex:categoryIndex].origin;
	result.x += (horizontalPadding+iconSpacing)/2.0;
	result.x += (iconIndex % columns)*iconSpacing;
	int row = (iconIndex/columns);
	result.y += AMPrefPaneIconViewTopPadding +AMPrefPaneIconViewTopGroupPadding +AMPrefPaneIconViewTopIconPadding +captionHeight;
	result.y += iconHeight*row;
	return result;
}

- (NSRect)imageFrameForIconInCategoryWithIndex:(int)categoryIndex atIndex:(int)iconIndex 
{
	NSRect result;
	int row = (iconIndex/columns);
	result.origin = [self frameForCategoryWithIndex:categoryIndex].origin;
	result.origin.x += (horizontalPadding +iconSpacing -AMPrefPaneIconImageWidth)/2.0;
	result.origin.x += (iconIndex % columns)*iconSpacing;
	result.origin.y += AMPrefPaneIconViewTopPadding +AMPrefPaneIconViewTopGroupPadding +captionHeight +AMPrefPaneIconViewTopIconPadding +(AMPrefPaneIconViewTopIconPadding+iconHeight)*row;
	result.size = NSMakeSize(AMPrefPaneIconImageWidth, AMPrefPaneIconImageHeight);
	return result;
}

- (NSRect)labelFrameForIconInCategoryWithIndex:(int)categoryIndex atIndex:(int)iconIndex 
{
	NSRect result;
	int row = (iconIndex/columns);
	AMPrefPaneIcon *icon = [[iconListList objectAtIndex:categoryIndex] objectAtIndex:iconIndex];
	result.origin = [self frameForCategoryWithIndex:categoryIndex].origin;
	result.size = [[icon title] sizeWithAttributes:_am_iconLabelAttributes];
	result.origin.x += (horizontalPadding+iconSpacing)/2.0;
	result.origin.x += (iconIndex % columns)*iconSpacing-result.size.width/2.0;
	result.origin.y += AMPrefPaneIconViewTopPadding +AMPrefPaneIconViewTopGroupPadding +captionHeight +AMPrefPaneIconViewTopIconPadding +(AMPrefPaneIconViewTopIconPadding+iconHeight)*row;
	result.origin.y += AMPrefPaneIconImageHeight +AMPrefPaneIconViewVerticalLabelSpacing;
	return result;
}

- (void)drawBackgroundForCategoryWithIndex:(int)index
{
	NSRect frame = [self frameForCategoryWithIndex:index];
	if ((index % 2) == 1) {
		[[NSColor colorWithCalibratedWhite:0.97 alpha:0.99] set];
		NSRectFillUsingOperation(frame, NSCompositePlusDarker);
	}
	if (sortByCategory) {
		NSPoint captionOffset = NSMakePoint(AMPrefPaneIconViewHorizontalPadding, frame.origin.y +AMPrefPaneIconViewTopGroupPadding);
		captionOffset.x -= 10;
		if (index > 0) {
			// divider line
			[[NSColor colorWithCalibratedWhite:0.84 alpha:1.0] set];
			NSRectFill(NSMakeRect(frame.origin.x, frame.origin.y, frame.size.width, 1));
		} else {
			captionOffset.y += AMPrefPaneIconViewTopPadding;
		}
		// caption
		NSString *identifier = [[[iconListList objectAtIndex:index] objectAtIndex:0] itemIdentifier];
		NSString *categoryName = [prefsController categoryDisplayNameForIdentifier:identifier];
		[categoryName drawAtPoint:captionOffset withAttributes:_am_captionAttributes];
	}
}

- (void)drawIcon:(AMPrefPaneIcon *)icon atPosition:(NSPoint)pos highlighted:(BOOL)highlighted
{
	NSRect iconRect = NSMakeRect(pos.x-AMPrefPaneIconImageWidth/2, pos.y+AMPrefPaneIconViewTopIconPadding +captionHeight, AMPrefPaneIconImageWidth, AMPrefPaneIconImageHeight);
	NSRect sourceRect = NSZeroRect;
	sourceRect.size = [[icon image] size];
	NSImage *theImage;
	if (highlighted) {
		theImage = [[icon image] darkenedImageWithColor:[NSColor colorWithCalibratedWhite:0.7 alpha:1.0]];
	} else {
		theImage = [icon image];
	}
	[theImage setFlipped:NO];
	[theImage drawInRect:iconRect fromRect:sourceRect operation:NSCompositeSourceAtop fraction:1.0];
	NSRect labelRect = NSZeroRect;
	labelRect.size = [[icon title] sizeWithAttributes:_am_iconLabelAttributes];
	labelRect.origin.x = pos.x-labelRect.size.width/2.0;
	labelRect.origin.y = pos.y +AMPrefPaneIconImageHeight +AMPrefPaneIconViewTopIconPadding +AMPrefPaneIconViewVerticalLabelSpacing +captionHeight;
	[[icon title] drawInRect:labelRect withAttributes:_am_iconLabelAttributes];
}

- (AMPrefPaneIcon *)iconAt:(NSPoint)point categoryIndex:(int *)categoryIndex iconIndex:(int *)iconIndex
{
	AMPrefPaneIcon *result = nil;
	// find category first
	int cIndex = 0;
	NSEnumerator *enumerator = [iconListList objectEnumerator];
	NSArray *iconList;
	while ((iconList = [enumerator nextObject])) {
		NSRect frame = [self frameForCategoryWithIndex:cIndex];
		if (NSPointInRect(point, frame)) {
			// hit - find icon
			// we ignore the category caption for now ...
			int iIndex = 0;
			NSEnumerator *iconEnumerator = [iconList objectEnumerator];
			AMPrefPaneIcon *icon;
			while ((icon = [iconEnumerator nextObject])) {
				NSRect imageFrame = [self imageFrameForIconInCategoryWithIndex:cIndex atIndex:iIndex];
				NSRect labelFrame = [self labelFrameForIconInCategoryWithIndex:cIndex atIndex:iIndex];
				if (NSPointInRect(point, imageFrame) || NSPointInRect(point, labelFrame)) {
					result = [iconList objectAtIndex:iIndex];
					if (categoryIndex)
						*categoryIndex = cIndex;
					if (iconIndex)
						*iconIndex = iIndex;
					break;
				} else {
				}
				iIndex++;
			}
			break;
		}
		cIndex++;
	}			
	return result;
}

// ============================================================
#pragma mark -
#pragma mark ━ NSView methods ━
// ============================================================

- (NSRect)frame
{
	if (dataChanged) {
		[self rebuild];
	}
	return [super frame];
}

- (NSRect)bounds
{
	if (dataChanged) {
		[self rebuild];
	}
	return [super bounds];
}

- (BOOL)isFlipped
{
	return YES;
}

- (void)drawRect:(NSRect)rect
{
	if (dataChanged) {
		[self rebuild];
	}
	int i = 0;
	NSPoint offset = NSZeroPoint;
	offset.y += AMPrefPaneIconViewTopGroupPadding+AMPrefPaneIconViewTopPadding;
	NSEnumerator *enumerator = [iconListList objectEnumerator];
	NSArray *iconList;
	while ((iconList = [enumerator nextObject])) {
		[self drawBackgroundForCategoryWithIndex:i++];
		int row = 0;
		int column = 0;
		offset.x = (horizontalPadding+iconSpacing)/2.0;
		NSEnumerator *iconEnumerator = [iconList objectEnumerator];
		AMPrefPaneIcon *icon;
		while ((icon = [iconEnumerator nextObject])) {
			if (column == columns) {
				row++;
				column = 0;
				offset.x = (horizontalPadding+iconSpacing)/2.0;
				offset.y += iconHeight;
			}
			[self drawIcon:icon atPosition:offset highlighted:(icon == _am_selectedIcon)];
			column++;
			offset.x += iconSpacing;
		}
		offset.y += iconHeight +AMPrefPaneIconViewBottomGroupPadding +AMPrefPaneIconViewTopGroupPadding +captionHeight;
	}
}

- (void)mouseDown:(NSEvent *)theEvent
{
	_am_mouseDownPoint = [self convertPoint:[theEvent locationInWindow] fromView:nil];
	AMPrefPaneIcon *icon = [self iconAt:_am_mouseDownPoint categoryIndex:&_am_selectedIconCategory iconIndex:&_am_selectedIconIndex];
	if (icon) {
		[self _am_setSelectedIcon:icon];
		[self setNeedsDisplay:YES];
	} 
}

- (void)mouseUp:(NSEvent *)theEvent
{
	NSPoint localPoint = [self convertPoint:[theEvent locationInWindow] fromView:nil];
	AMPrefPaneIcon *icon = [self iconAt:localPoint categoryIndex:&_am_selectedIconCategory iconIndex:&_am_selectedIconIndex];
	if (icon == _am_selectedIcon) {
		[[icon target] performSelector:[icon selector] withObject:icon];
	} 
	[self setNeedsDisplay:YES];
	[self _am_setSelectedIcon:nil];
}

- (void)mouseDragged:(NSEvent *)theEvent
{
	NSImage *image;
	NSPoint imageOrigin;
	NSSize dragOffset;
	NSPasteboard *pasteboard;
	if (_am_selectedIcon) {
		// calculate position and offset
		NSRect imageFrame = [self imageFrameForIconInCategoryWithIndex:_am_selectedIconCategory atIndex:_am_selectedIconIndex];
		NSRect labelFrame = [self labelFrameForIconInCategoryWithIndex:_am_selectedIconCategory atIndex:_am_selectedIconIndex];
		NSSize imageSize = NSMakeSize(MAX(imageFrame.size.width, labelFrame.size.width), imageFrame.size.height +labelFrame.size.height +AMPrefPaneIconViewVerticalLabelSpacing);
		NSRect cFrame = [self frameForCategoryWithIndex:_am_selectedIconCategory];
		imageOrigin.x = cFrame.origin.x+labelFrame.origin.x;
		imageOrigin.y = cFrame.origin.y +(_am_selectedIconIndex/columns)*iconHeight +imageSize.height +AMPrefPaneIconViewTopIconPadding +AMPrefPaneIconViewTopGroupPadding +captionHeight;
		if (_am_selectedIconCategory == 0) {
			imageOrigin.y += AMPrefPaneIconViewTopPadding;
		}
		NSPoint localPoint = [self convertPoint:[theEvent locationInWindow] fromView:nil];
		dragOffset = NSMakeSize(localPoint.x - _am_mouseDownPoint.x, localPoint.y -_am_mouseDownPoint.y);
		// create drag image
		NSImage *tempImage;
		tempImage = [[[NSImage alloc] initWithSize:labelFrame.size] autorelease];
		
		[tempImage lockFocus];
		NSRect labelRect = NSZeroRect;
		labelRect.size = labelFrame.size;
		[[_am_selectedIcon title] drawInRect:labelRect withAttributes:_am_iconLabelAttributes];
		[tempImage unlockFocus];

		image = [[[NSImage alloc] initWithSize:imageSize] autorelease];
		[image lockFocus];
		[image setFlipped:NO];
		labelRect.origin.y = 0;
		NSRect sourceRect = NSZeroRect;
		sourceRect = NSZeroRect;
		sourceRect.size = labelRect.size;
		[tempImage drawInRect:labelRect fromRect:sourceRect operation:NSCompositeSourceOver fraction:0.7];
		
		NSRect iconRect = NSMakeRect((imageSize.width-AMPrefPaneIconImageWidth)/2.0, labelRect.size.height +AMPrefPaneIconViewVerticalLabelSpacing, AMPrefPaneIconImageWidth, AMPrefPaneIconImageHeight);
		sourceRect.size = [[_am_selectedIcon image] size];
		tempImage = [_am_selectedIcon image];
		[tempImage setFlipped:YES];
		[tempImage drawInRect:iconRect fromRect:sourceRect operation:NSCompositeSourceOver fraction:0.7];
		
		[image unlockFocus];
		
		// create pasteboard data
		pasteboard = [NSPasteboard pasteboardWithName:NSDragPboard];
		[pasteboard declareTypes:[NSArray arrayWithObject:@"NSToolbarIndividualItemDragType"] owner:nil];
		[pasteboard setString:[_am_selectedIcon itemIdentifier] forType:@"NSToolbarItemIdentifierPboardType"];
		// deselect icon
		[self setNeedsDisplay:YES];

		// still over the same icon from which the mouseDown event came?
		// if so - do not clear _am_selectedIcon since for Lion _am_selectedIcon will be set to nil
		// [due to the fact that mouseDragged is also called for mouseDown]
		// and mouseUp event will never invoke clicked icon in category overview
		// <TODO> the entire Pref Pane stuff should be re-written since the code is VERY old!
		localPoint = [self convertPoint:[theEvent locationInWindow] fromView:nil];
		AMPrefPaneIcon *icon_cur = [self iconAt:localPoint categoryIndex:&_am_selectedIconCategory iconIndex:&_am_selectedIconIndex];
		if (icon_cur != _am_selectedIcon)
			[self _am_setSelectedIcon:nil];

		[self displayIfNeeded];
		// initiate drag
		[self dragImage:image at:imageOrigin offset:dragOffset event:theEvent pasteboard:pasteboard source:self slideBack:YES];
	}
}


// ============================================================
#pragma mark -
#pragma mark ━ drag & drop handling ━
// ============================================================

- (NSDragOperation) draggingSourceOperationMaskForLocal:(BOOL)isLocal
{
	NSDragOperation result = NSDragOperationNone;
	if (isLocal) {
		result = NSDragOperationEvery; // NSDragOperationCopy sufficient?
	}
	return result;
}

- (BOOL)ignoreModifierKeysWhileDragging
{
	return YES;
}


@end
