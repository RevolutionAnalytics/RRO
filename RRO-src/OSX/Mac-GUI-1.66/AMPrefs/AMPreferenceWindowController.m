//
//  AMPreferenceWindowController.m
//  PrefPane
//
//  Created by Andreas on Sat May 31 2003.
//  Copyright (c) 2003 Andreas Mayer. All rights reserved.
//

#import "../RGUI.h" /* for NLS nacro */
#import "AMPreferenceWindowController.h"
#import "AMPrefPaneProtocol.h"
#import "AMPrefPaneIcon.h"
#import "AMPrefPaneIconView.h"
//#import "../RController.h"


@interface NSToolbar (AMPrivate)
- (void)_setCustomizesAlwaysOnClickAndDrag:(BOOL)flag;
- (void)_setFirstMoveableItemIndex:(int)index;
- (void)setCustomizationSheetWidth:(int)width;
@end


// ============================================================
#pragma mark -
#pragma mark ━ private interface ━
// ============================================================

@interface AMPreferenceWindowController (Private)
- (void)setPrefPanes:(NSDictionary *)newPrefPanes;
- (void)setActivePane:(AMPreferencePane *)newActivePane;
- (void)removeAllPanes;
- (NSString *)autosaveName;
- (void)setAutosaveName:(NSString *)newAutosaveName;
- (AMPrefPaneIcon *)iconForPrefPane:(id<AMPrefPaneProtocol>)prefPane;
- (void)changeContentView:(NSView *)contentView;
- (void)createIconViewPane;
- (void)toolbarShowAll;
- (NSArray *)validPrefPaneIdentifiers;
@end

// ============================================================
#pragma mark -
#pragma mark ━ implementation ━
// ============================================================

@implementation AMPreferenceWindowController

// ============================================================
#pragma mark -
#pragma mark ━ initialisation ━
// ============================================================

- (id)initWithAutosaveName:(NSString *)name
{
	NSWindow *panel = [[[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 200, 100) styleMask:(NSTitledWindowMask|NSClosableWindowMask|NSMiniaturizableWindowMask) backing:NSBackingStoreBuffered defer:YES] autorelease];
		// create a new window
	[panel setDelegate:self];
	[panel setOpaque:YES];
	[panel setContentView:[[[NSView alloc] initWithFrame:NSMakeRect(0, 0, 200, 100)] autorelease]];
	[self setPrefPanes:[NSMutableDictionary dictionary]];
	[self setAutosaveName:name];
	[self setTitle:NLS(@"Preferences")];
	[self createIconViewPane];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationWillTerminate:) name:NSApplicationWillTerminateNotification object:NSApp];
	_am_oldContentViewFrame = [[panel contentView] frame];
	return [super initWithWindow:panel];
}

- (void)dealloc
{
	[iconView release];
	[prefPanes release];
	[activePane release];
	[super dealloc];
}

// ============================================================
#pragma mark -
#pragma mark ━ setters / getters ━
// ============================================================

- (NSWindow *)window
{
	NSWindow *result = [super window];
	if (![result toolbar]) {
		NSToolbar *toolbar = [[NSToolbar alloc] initWithIdentifier:AMPPToolbarIdentifier];
		[toolbar setDelegate:self];
		[toolbar setVisible:YES];
		[toolbar setAllowsUserCustomization:usesConfigurationPane];
		[toolbar setAutosavesConfiguration:YES];
		if (usesConfigurationPane) {
			[toolbar _setCustomizesAlwaysOnClickAndDrag:YES];
			[toolbar _setFirstMoveableItemIndex:2];
		}
		[result setToolbar:toolbar];
		// select first panel
		NSString *selectedItemIdentifier = [[[toolbar items] objectAtIndex:0] itemIdentifier];
		[toolbar setSelectedItemIdentifier:selectedItemIdentifier];
		[self selectPaneWithIdentifier:selectedItemIdentifier];
		// set frame size
		// gnnn... we need to extract the saved frame ourselfes, since we want to set the origin only
		NSString *frameString = [[NSUserDefaults standardUserDefaults] stringForKey:[NSString stringWithFormat:@"NSWindow Frame %@", autosaveName]];
		NSRect frame;
		if (frameString) {
			NSArray *frameArray = [frameString componentsSeparatedByString:@" "];
			frame = NSMakeRect([[frameArray objectAtIndex:0] floatValue], [[frameArray objectAtIndex:1] floatValue], [[frameArray objectAtIndex:2] floatValue], [[frameArray objectAtIndex:3] floatValue]);
			NSRect oldFrame = [result frame];
			oldFrame.origin.x = frame.origin.x;
			oldFrame.origin.y = frame.origin.y+(frame.size.height-oldFrame.size.height);
			[result setFrame:oldFrame display:NO];
		} else {
			[result center];
		}
	}
	return result;
}

- (NSDictionary *)prefPanes
{
    return prefPanes;
}

- (id)delegate
{
    return delegate;
}

- (void)setDelegate:(id)newDelegate
{
	// do not retain delegate
	delegate = newDelegate;
	_am_delegateRespondsToCategoryForPreferencePane = [delegate respondsToSelector:@selector(categoryForPreferencePane:defaultCategory:)];
	_am_delegateRespondsToDisplayNameForCategory = [delegate respondsToSelector:@selector(displayNameForCategory:)];
}

- (BOOL)usesConfigurationPane
{
	return usesConfigurationPane;
}

- (void)setUsesConfigurationPane:(BOOL)newUsesConfigurationPane
{
	usesConfigurationPane = newUsesConfigurationPane;
}

- (BOOL)sortByCategory
{
	return [(AMPrefPaneIconView *)iconView sortByCategory];
}

- (void)setSortByCategory:(BOOL)newSortByCategory
{
	BOOL changed = ([(AMPrefPaneIconView *)iconView sortByCategory] != newSortByCategory);
	if (changed) {
		[(AMPrefPaneIconView *)iconView setSortByCategory:newSortByCategory];
		if (activePane == nil) {
			[self toolbarShowAll];
		}
	}
}

- (NSArray *)categorySortOrder
{
	return [(AMPrefPaneIconView *)iconView categorySortOrder];
}

- (void)setCategorySortOrder:(NSArray *)newCategorySortOrder
{
	[(AMPrefPaneIconView *)iconView setCategorySortOrder:newCategorySortOrder];
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


// ============================================================
#pragma mark -
#pragma mark ━ public methods ━
// ============================================================

- (void)addPluginsOfType:(NSString *)extension fromPath:(NSString *)path
{
	NSEnumerator* enumerator = [[NSBundle pathsForResourcesOfType:extension inDirectory:path] objectEnumerator];
	NSString* pluginPath;
	while ((pluginPath = [enumerator nextObject])) {
		[self addPluginFromPath:pluginPath];
	}
}

- (BOOL)addPane:(id<AMPrefPaneProtocol>)newPane withIdentifier:(NSString *)identifier
{
	BOOL result;
	if ((result = ([prefPanes objectForKey:identifier] == nil))) {
		if ([delegate respondsToSelector:@selector(shouldLoadPreferencePane:)]) {
			result = [delegate shouldLoadPreferencePane:identifier];
		}
		if (result) {
			[prefPanes setObject:newPane forKey:identifier];
			if ([(NSObject*)newPane respondsToSelector:@selector(mainView)] && [newPane mainView]) {
				[(AMPrefPaneIconView *)iconView addIcon:[self iconForPrefPane:newPane]];
			}
		}
	}
	return result;
}

- (void)addPluginFromPath:(NSString *)path
{
	NSBundle* pluginBundle = [NSBundle bundleWithPath:path];
	if (!pluginBundle) {
		NSLog(@"error loading bundle: %@", path);
	} else { // loaded successfully
		NSLog(@"loaded: %@", [pluginBundle bundlePath]);
		NSString* prefPaneIdentifier;
		if ((prefPaneIdentifier = [pluginBundle objectForInfoDictionaryKey:CFBundleIdentifierKey])) {
			if ([prefPanes objectForKey:prefPaneIdentifier]) {
				// pane with same identifier exists
				NSLog(@"pref pane already loaded %@", prefPaneIdentifier);
			} else {
				BOOL load = YES;
				if ([delegate respondsToSelector:@selector(shouldLoadPreferencePane:)]) {
					load = [delegate shouldLoadPreferencePane:prefPaneIdentifier];
				}
				if (load) {
					AMPreferencePane *newPane;
					if ((newPane = [[AMPreferencePane alloc] initWithBundle:pluginBundle])) {
						if (newPane)
							[self addPane:newPane withIdentifier:prefPaneIdentifier];
					}
				} else {
					NSLog(@"delegate did not approve plugin %@", prefPaneIdentifier);
				}
			}
		} else {
			// no identifier
		}
	}
}

- (BOOL)deselectActivePane
{
	BOOL result = YES;
	if (activePane) {
		if ([activePane respondsToSelector:@selector(willUnselect)]) {
			[(id)activePane willUnselect];
		}
		if ([delegate respondsToSelector:@selector(didUnselectPreferencePane:)]) {
			[delegate didUnselectPreferencePane:[activePane identifier]];
		}
		if ([activePane respondsToSelector:@selector(didUnselect)]) {
			[(id)activePane didUnselect];
		}
		[self setActivePane:nil];
	}
	[[NSColorPanel sharedColorPanel] close];
	return result;
}

- (BOOL)selectPaneWithIdentifier:(NSString *)identifier
{
	BOOL result = NO;
	AMPreferencePane *pane = [prefPanes objectForKey:identifier];
	if (pane) {
		if (pane == activePane) {
			// already active
			/*
			if ([delegate respondsToSelector:@selector(willSelectPreferencePane:)]) {
				[delegate willSelectPreferencePane:identifier];
			}
			 */
			result = YES;
		} else {
			NSView *paneView = [pane mainView];
			if (paneView) {
				if ([activePane respondsToSelector:@selector(willUnselect)])
					[(id)activePane willUnselect];
				if ([delegate respondsToSelector:@selector(willSelectPreferencePane:)]) {
					[delegate willSelectPreferencePane:identifier];
				}
				if ([pane respondsToSelector:@selector(willSelect)])
					[(id)pane willSelect];
				if ([pane respondsToSelector:@selector(loadMainView)])
					[(id)pane loadMainView];

				// For some reasons the NSColorPanel pops up while changing the pane;
				// thus close it explicitly
				[[NSColorPanel sharedColorPanel] close];

				// Synchronize selected toolbar item mainly if the
				// method was called by the app (like Rconsole colors)
				[[[self window] toolbar] setSelectedItemIdentifier:identifier];

				[[self window] setTitle:[[prefPanes objectForKey:identifier] label]];
				[self changeContentView:paneView];

				if (activePane) {
					if ([delegate respondsToSelector:@selector(didUnselectPreferencePane:)]) {
						[delegate didUnselectPreferencePane:[activePane identifier]];
					}
					if ([activePane respondsToSelector:@selector(didUnselect)])
						[(id)activePane didUnselect];
				}
				if ([pane respondsToSelector:@selector(didSelect)])
					[(id)pane didSelect];
				[self setActivePane:pane];
			} else { // no view?!
				NSLog(@"Preference Pane \"%@\" has no view", [pane identifier]);
			}
		}
	}
	return result;
}

- (BOOL)selectIconViewPane
{
	BOOL result = [self deselectActivePane];
	if (result)
		[self toolbarShowAll];
	return result;
}

- (void)replyToShouldUnselect:(BOOL)shouldUnselect;
{}

- (NSString *)categoryForIdentifier:(NSString *)identifier
{
	NSString *result;
	AMPreferencePane *prefPane = [prefPanes objectForKey:identifier];
	result = [prefPane category];
	if (_am_delegateRespondsToCategoryForPreferencePane) {
		result = [delegate performSelector:@selector(categoryForPreferencePane:defaultCategory:) withObject:identifier withObject:result];
	}
	return result;
}

- (NSArray *)categories
{
	NSArray *result = nil;
	NSMutableDictionary *categories = [NSMutableDictionary dictionary];
	NSEnumerator *enumerator = [[prefPanes allValues] objectEnumerator];
	AMPreferencePane *prefPane;
	while ((prefPane = [enumerator nextObject])) {
		NSString *category = [prefPane category];
		if (_am_delegateRespondsToCategoryForPreferencePane) {
			category = [delegate performSelector:@selector(categoryForPreferencePane:defaultCategory:) withObject:[prefPane identifier] withObject:category];
		}
		[categories setObject:category forKey:category];
	}
	result = [categories allKeys];
	return result;
}

- (NSString *)categoryDisplayNameForIdentifier:(NSString *)identifier
{
	NSString *result = nil;
	NSString *category = [self categoryForIdentifier:identifier];
	if (_am_delegateRespondsToDisplayNameForCategory) {
		result = [delegate displayNameForCategory:category];
	}
	if (result == nil) {
		AMPreferencePane *prefPane = [prefPanes objectForKey:identifier];
		if ([prefPane respondsToSelector:@selector(categoryDisplayName)]) {
			result = [(id)prefPane categoryDisplayName];
		}
	}
	if (result == nil) {
		result = category;
	}
	return result;
}


// ============================================================
#pragma mark -
#pragma mark ━ private methods ━
// ============================================================

- (void)setPrefPanes:(NSDictionary *)newPrefPanes
{
	id old = nil;
	
	if (newPrefPanes != prefPanes) {
		old = prefPanes;
		prefPanes = [newPrefPanes mutableCopy];
		[old release];
	}
}

- (AMPreferencePane *)activePane
{
	return activePane;
}

- (void)setActivePane:(AMPreferencePane *)newActivePane
{
	id old = nil;
	
	if (newActivePane != activePane) {
		old = activePane;
		activePane = [newActivePane retain];
		[old release];
	}
}

- (void)removeAllPanes
{
	NSLog(@"at this time (10.2.6) there's no way to unload bundles, sorry");
}

- (NSString *)autosaveName
{
	return autosaveName;
}

- (void)setAutosaveName:(NSString *)newAutosaveName
{
	id old = nil;
	
	if (newAutosaveName != autosaveName) {
		old = autosaveName;
		autosaveName = [newAutosaveName copy];
		[old release];
	}
}

- (AMPrefPaneIcon *)iconForPrefPane:(id<AMPrefPaneProtocol>)prefPane
{
	AMPrefPaneIcon *result = [[[AMPrefPaneIcon alloc] initWithIdentifier:[prefPane identifier] image:[prefPane icon] andTitle:[prefPane label]] autorelease];
	[result setCategory:[prefPane category]];
	[result setTarget:self];
	[result setSelector:@selector(toolbarShowPane:)];
	return result;
}

- (void)createIconViewPane
{
	if (!iconView) {
		NSMutableArray *icons = [NSMutableArray array];
		NSEnumerator *enumerator = [prefPanes objectEnumerator];
		AMPreferencePane *prefPane;
		while ((prefPane = [enumerator nextObject])) {
			if ([prefPane respondsToSelector:@selector(mainView)] && [prefPane mainView]) {
				[icons addObject:[self iconForPrefPane:prefPane]];
			}
		}
		iconView = [[AMPrefPaneIconView alloc] initWithController:self icons:icons columns:7];
	}
}

- (void)changeContentView:(NSView *)contentView
{
	NSRect windowFrame = [[self window] frame];
	NSRect newViewFrame = [contentView frame];
	float deltaX = (newViewFrame.size.width-_am_oldContentViewFrame.size.width);
	float deltaY = (newViewFrame.size.height-_am_oldContentViewFrame.size.height);
	windowFrame.size.width += deltaX;
	windowFrame.size.height += deltaY;
	windowFrame.origin.y -= deltaY;
	[[self window] setContentView:contentView];
	[[self window] setFrame:windowFrame display:YES animate:YES];
	_am_oldContentViewFrame = newViewFrame;
}

- (NSArray *)validPrefPaneIdentifiers
{
	NSMutableArray *result = [NSMutableArray array];
	NSEnumerator *enumerator = [prefPanes objectEnumerator];
	AMPreferencePane *pane;
	while ((pane = [enumerator nextObject])) {
		if ([pane respondsToSelector:@selector(mainView)] && [pane mainView]) {
			[result addObject:[pane identifier]];
		}
	}
	return result;
}


// ============================================================
#pragma mark -
#pragma mark ━ toolbar action methods ━
// ============================================================

- (void)toolbarShowAll
{
	[self deselectActivePane];
	[[self window] setTitle:[self title]];
	[self changeContentView:iconView];
}

- (void)toolbarShowPane:(id)sender
{
	NSString *identifier = [(NSToolbarItem *)sender itemIdentifier];
	[[[self window] toolbar] setSelectedItemIdentifier:[(NSToolbarItem *)sender itemIdentifier]];
	[self selectPaneWithIdentifier:identifier];
}

// ============================================================
#pragma mark -
#pragma mark ━ toolbar delegate methods ━
// ============================================================

- (NSToolbarItem *)toolbar:(NSToolbar *)toolbar itemForItemIdentifier:(NSString *)itemIdentifier willBeInsertedIntoToolbar:(BOOL)flag
{
	NSToolbarItem *result = nil;
	AMPreferencePane *pane = nil;
	if ([itemIdentifier isEqualToString:AMPPToolbarShowAllItemIdentifier]) {
		if ((result = [[NSToolbarItem alloc] initWithItemIdentifier:itemIdentifier])) {
			[result setTarget:self];
			[result setAction:@selector(toolbarShowAll)];
			[result setEnabled:YES];
			[result setImage:[NSImage imageNamed:@"Prefs"]];
			[result setLabel:NLS(@"Show All")];
		}
	} else if ((pane = [prefPanes objectForKey:itemIdentifier])) {
		if ((result = [[NSToolbarItem alloc] initWithItemIdentifier:itemIdentifier])) {
			[result setTarget:self];
			[result setAction:@selector(toolbarShowPane:)];
			[result setEnabled:YES];
			[result setImage:[pane icon]];
			[result setLabel:[pane label]];
		}
	}
        if (result) [result autorelease];
	return result;
}

- (NSArray *)toolbarDefaultItemIdentifiers:(NSToolbar*)toolbar
{
	NSMutableArray *result = [[[NSMutableArray alloc] init] autorelease];
	if (usesConfigurationPane) {
		[result addObject:AMPPToolbarShowAllItemIdentifier];
		[result addObject:NSToolbarSeparatorItemIdentifier];
	}
	NSMutableArray *prefPaneIdentifiers = [NSMutableArray arrayWithArray:[self validPrefPaneIdentifiers]];
	[prefPaneIdentifiers sortUsingSelector:@selector(caseInsensitiveCompare:)];
	[result addObjectsFromArray:prefPaneIdentifiers];
	return result;
}

- (NSArray *)toolbarAllowedItemIdentifiers:(NSToolbar*)toolbar
{
	NSMutableArray *result = [[[NSMutableArray alloc] init] autorelease];
	if (usesConfigurationPane) {
		[result addObject:AMPPToolbarShowAllItemIdentifier];
		[result addObject:NSToolbarSeparatorItemIdentifier];
	}
	[result addObjectsFromArray:[self validPrefPaneIdentifiers]];
	return result;
}

- (NSArray *)toolbarSelectableItemIdentifiers:(NSToolbar *)toolbar
{
	NSMutableArray *result = [[[NSMutableArray alloc] init] autorelease];
	if (usesConfigurationPane) {
		[result addObject:AMPPToolbarShowAllItemIdentifier];
	}
	[result addObjectsFromArray:[self validPrefPaneIdentifiers]];
	return result;
}

- (void)toolbarDidRemoveItem:(NSNotification *)notification
{}

- (void)toolbarWillAddItem:(NSNotification *)notification
{}

// ============================================================
#pragma mark -
#pragma mark ━ window delegate methods ━
// ============================================================

- (void)windowWillClose:(NSNotification *)aNotification
{
//	if (![[[RController sharedController] getRConsoleWindow] isKeyWindow]) {
//		[[[RController sharedController] getRConsoleWindow] makeKeyWindow];
//		SLog(@" RConsole set to key window");
//	}
	if ([activePane respondsToSelector:@selector(willUnselect)])
		[(id)activePane willUnselect];
	// Close opened NSColorPanel if Preferences window will be closed
	if([NSColorPanel sharedColorPanelExists])
		[[NSColorPanel sharedColorPanel] close];
}

- (void)windowDidClose:(NSNotification *)aNotification
{
	if ([activePane respondsToSelector:@selector(willUnselect)])
		[(id)activePane willUnselect];
	if ([activePane respondsToSelector:@selector(didUnselect)])
		[(id)activePane didUnselect];
}

- (void)windowDidMove:(NSNotification *)aNotification
{
	[[self window] saveFrameUsingName:autosaveName];
}


// ============================================================
#pragma mark -
#pragma mark ━ notification methods ━
// ============================================================

- (void)applicationWillTerminate:(NSNotification *)aNotification
{
	if ([activePane respondsToSelector:@selector(willUnselect)])
		[(id)activePane willUnselect];
	if ([activePane respondsToSelector:@selector(didUnselect)])
		[(id)activePane didUnselect];
}


@end
