//
//  AMPrefPaneIconView.h
//  PrefPane
//
//  Created by Andreas on Mon Jun 09 2003.
//  Copyright (c) 2003 Andreas Mayer. All rights reserved.
//

#import <AppKit/AppKit.h>
#import "AMPrefPaneIcon.h"
#import "AMPreferenceWindowController.h"


@interface AMPrefPaneIconView : NSView {
	AMPreferenceWindowController *prefsController;
	// icons array holds objects of class AMPrefPaneIcon
	NSMutableArray *icons;
	BOOL sortByCategory;
	NSArray *categorySortOrder;
	NSMutableArray *iconListList; // array of arrays (one for each category) of icons
	int columns;
	float iconSpacing;
	float iconHeight; // including subtitle
	float horizontalPadding;
	float captionHeight;
	int iconsPerRow;
	BOOL dataChanged; // need to rebuild lists
	NSDictionary *_am_iconLabelAttributes;
	NSDictionary *_am_captionAttributes;
	AMPrefPaneIcon *_am_selectedIcon;
	int _am_selectedIconCategory;
	int _am_selectedIconIndex;
	NSPoint _am_mouseDownPoint;
}

- (id)initWithController:(AMPreferenceWindowController *)theController icons:(NSArray *)theIcons columns:(int)numColumns;

- (AMPreferenceWindowController *)prefsController;
- (void)setPrefsController:(AMPreferenceWindowController *)newPrefsController;

- (NSArray *)icons;
- (void)setIcons:(NSArray *)newIcons;

- (int)columns;
- (void)setColumns:(int)newColumns;

- (BOOL)sortByCategory;
- (void)setSortByCategory:(BOOL)newSortByCategory;

- (NSArray *)categorySortOrder;
- (void)setCategorySortOrder:(NSArray *)newCategorySortOrder;

- (void)removeAllIcons;

- (void)addIcon:(AMPrefPaneIcon *)icon;


@end
