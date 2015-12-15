//
//  AMPreferenceWindowController.h
//  PrefPane
//
//  Created by Andreas on Sat May 31 2003.
//  Copyright (c) 2003 Andreas Mayer. All rights reserved.
//

// to do:
// - we need a way to define a certain order of the prefs displayed in the toolbar


#import <AppKit/AppKit.h>
#import "AMPreferencePane.h"


#define AMPPToolbarIdentifier @"AMPPToolbar"
#define AMPPToolbarShowAllItemIdentifier @"AMPPToolbarShowAll"

@interface AMPreferenceWindowController : NSWindowController {
	NSMutableDictionary *prefPanes;
	NSView *iconView;
	AMPreferencePane *activePane;
	NSRect _am_oldContentViewFrame;
	BOOL usesConfigurationPane;
	id delegate;
	NSString *autosaveName;
	NSString *title;
	BOOL _am_delegateRespondsToCategoryForPreferencePane;
	BOOL _am_delegateRespondsToDisplayNameForCategory;
}

- (AMPreferencePane *)activePane;

- (id)initWithAutosaveName:(NSString *)name;

- (id)delegate;
- (void)setDelegate:(id)newDelegate;

- (BOOL)usesConfigurationPane;
- (void)setUsesConfigurationPane:(BOOL)newUsesConfigurationPane;
// needs to be set before actually showing the prefs window

- (BOOL)sortByCategory;
- (void)setSortByCategory:(BOOL)newSortByCategory;

- (NSArray *)categorySortOrder;
- (void)setCategorySortOrder:(NSArray *)newCategorySortOrder;

- (NSString *)title;
- (void)setTitle:(NSString *)newTitle;


- (BOOL)addPane:(id<AMPrefPaneProtocol>)newPane withIdentifier:(NSString *)identifier;

- (void)addPluginFromPath:(NSString *)path;

- (void)addPluginsOfType:(NSString *)extension fromPath:(NSString *)path;
// if you do not require a special type, pass nil for pluginType
// (see NSBundle's pathForResource:ofType:)

- (BOOL)selectPaneWithIdentifier:(NSString *)identifier;

- (BOOL)selectIconViewPane;

- (void)replyToShouldUnselect:(BOOL)shouldUnselect;

- (NSDictionary *)prefPanes;

- (NSString *)categoryForIdentifier:(NSString *)identifier;

- (NSArray *)categories;

- (NSString *)categoryDisplayNameForIdentifier:(NSString *)identifier;

@end


@interface NSObject (AMPrefPaneDelegate)

- (NSString *)displayNameForCategory:(NSString *)category;

- (NSString *)categoryForPreferencePane:(NSString *)identifier defaultCategory:(NSString *)category;

- (BOOL)shouldLoadPreferencePane:(NSString *)identifier;
- (void)willSelectPreferencePane:(NSString *)identifier;
- (void)didUnselectPreferencePane:(NSString *)identifier;

@end

