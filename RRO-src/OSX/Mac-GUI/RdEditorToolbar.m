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
 *                     Copyright (C) 2002-2012   The R Foundation
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
 *  RdEditorToolbar.h
 *  Toolbar for the integrated document editor
 *
 *  Created by Hans-J. Bibiko on 1/6/12.
 */

#import "RGUI.h"
#import "RdEditorToolbar.h"
#import "RDocumentWinCtrl.h"

@implementation RdEditorToolbar

- initWithEditor: (RDocumentWinCtrl *)dwCtrl
{
	self = [super init];
	if (self) {

		winCtrl = [dwCtrl retain];

		// Items
		tiSave = [[NSToolbarItem alloc] initWithItemIdentifier: RDETI_Save];
		[tiSave setLabel: NLS(@"Save")];
		[tiSave setPaletteLabel: NLS(@"Save")];
		[tiSave setToolTip: NLS(@"Save current document")];
		[tiSave setImage: [NSImage imageNamed: @"SaveDocumentItemImage"]];
		[tiSave setTarget: [winCtrl document]];
		[tiSave setAction: @selector(saveDocument:)];

		tiHelpSearch = [[NSToolbarItem alloc] initWithItemIdentifier: RDETI_HelpSearch];
		NSView *myView = [winCtrl searchToolbarView];
		// Set up the standard properties 
		[tiHelpSearch setLabel:NLS(@"Search")];
		[tiHelpSearch setPaletteLabel:NLS(@"Search")];
		[tiHelpSearch setToolTip:NLS(@"Search Help")];
		// Use a custom view, a rounded text field, attached to searchFieldOutlet in InterfaceBuilder as the custom view 
		SLog(@" - tiHelpSearch=%@, view=%@", tiHelpSearch, myView);
		[tiHelpSearch setView:myView];
		[tiHelpSearch setMinSize:NSMakeSize(100,NSHeight([myView frame]))];
		[tiHelpSearch setMaxSize:NSMakeSize(300,NSHeight([myView frame]))];
		// Create the custom menu (alternative if icons are disabled)
		NSMenu *submenu=[[NSMenu alloc] init];
		NSMenuItem *submenuItem=[[NSMenuItem alloc] initWithTitle: NLS(@"Search Panel")
														   action: @selector(searchUsingSearchPanel:)
													keyEquivalent: @""];
		NSMenuItem *menuFormRep=[[NSMenuItem alloc] init];
		[submenu addItem: submenuItem];
		[submenuItem setTarget:self];
		[menuFormRep setSubmenu:submenu];
		[menuFormRep setTitle:[tiHelpSearch label]];
		[tiHelpSearch setMenuFormRepresentation:menuFormRep];
		[menuFormRep release];
		[submenuItem release];
		[submenu release];

		myView = [winCtrl fnListView];
		tiSecList = [[NSToolbarItem alloc] initWithItemIdentifier: RDETI_SecList];
		[tiSecList setLabel:NLS(@"Sections")];
		[tiSecList setPaletteLabel:NLS(@"Sections")];
		[tiSecList setToolTip:NLS(@"List of Sections")];
		SLog(@" - tiSecList=%@, view=%@", tiSecList, myView);
		[tiSecList setView:myView];
		[tiSecList setMinSize:NSMakeSize(100,NSHeight([myView frame]))];
		[tiSecList setMaxSize:NSMakeSize(200,NSHeight([myView frame]))];

		myView = [winCtrl rdToolboxView];
		tiRdTools = [[NSToolbarItem alloc] initWithItemIdentifier: RDETI_RdTools];
		[tiRdTools setLabel:NLS(@"Rd Toolbox")];
		[tiRdTools setPaletteLabel:NLS(@"Rd Toolbox")];
		[tiRdTools setToolTip:NLS(@"Rd Toolbox")];
		SLog(@" - tiRdTools=%@, view=%@", tiRdTools, myView);
		[tiRdTools setView:myView];
		[tiRdTools setMinSize:NSMakeSize(60,NSHeight([myView frame]))];
		[tiRdTools setMaxSize:NSMakeSize(60,NSHeight([myView frame]))];

		toolbar = [[NSToolbar alloc] initWithIdentifier: @"RdEditorToolbar"];

		[toolbar setAllowsUserCustomization: YES];
		[toolbar setAutosavesConfiguration: YES];
		[toolbar setDisplayMode: NSToolbarDisplayModeIconOnly];

		// We are the delegate
		[toolbar setDelegate: self];

		// Attach the toolbar to the document window 
		[[winCtrl window] setToolbar: toolbar];
	}

	return self;

}

- (void) dealloc
{

	[toolbar release];
	[tiSecList release];
	[tiHelpSearch release];
	[tiSave release];
	[tiRdTools release];
	[winCtrl release];

	[super dealloc];

}

- (NSToolbarItem *) toolbar: (NSToolbar *)aToolbar itemForItemIdentifier: (NSString *) itemIdent willBeInsertedIntoToolbar:(BOOL) willBeInserted
{

	NSToolbarItem *toolbarItem = nil;

	SLog(@"toolbar:%@ itemForItemIdentifier:%@", aToolbar, itemIdent);

	if ([itemIdent isEqual: RDETI_Save])
		return tiSave;
	else if ([itemIdent isEqual: RDETI_HelpSearch])
		return tiHelpSearch;
	else if ([itemIdent isEqual: RDETI_SecList]) 
		return tiSecList;
	else if ([itemIdent isEqual: RDETI_RdTools]) 
		return tiRdTools;

	return toolbarItem;

}

- (NSArray *) toolbarDefaultItemIdentifiers: (NSToolbar *) aToolbar
{
	return [NSArray arrayWithObjects: RDET_ListDefault, nil];
}

- (NSArray *) toolbarAllowedItemIdentifiers: (NSToolbar *) aToolbar
{
	return [NSArray arrayWithObjects: RDET_ListAll, nil];
}

- (void) toolbarWillAddItem: (NSNotification *) notification
{
	// Optional delegate method:  Before an new item is added to the toolbar, this notification is posted.
	// This is the best place to notice a new item is going into the toolbar.  For instance, if you need to 
	// cache a reference to the toolbar item or need to set up some initial state, this is the best place 
	// to do it.  The notification object is the toolbar to which the item is being added.  The item being 
	// added is found by referencing the @"item" key in the userInfo 
	// NSToolbarItem *addedItem = [[notification userInfo] objectForKey: @"item"];
	//if ([[addedItem itemIdentifier] isEqual: ...]) {
}  

- (void) toolbarDidRemoveItem: (NSNotification *) notification
{
	// Optional delegate method:  After an item is removed from a toolbar, this notification is sent.   This allows 
	// the chance to tear down information related to the item that may have been cached.   The notification object
	// is the toolbar from which the item is being removed.  The item being added is found by referencing the @"item"
	// key in the userInfo 
	// NSToolbarItem *removedItem = [[notification userInfo] objectForKey: @"item"];
}

@end
