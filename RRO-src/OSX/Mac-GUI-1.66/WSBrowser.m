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
 */

#import "WSBrowser.h"
#import "RController.h"
#import "REngine/REngine.h"

#include <R.h>
#include <R_ext/Boolean.h>
#include <R_ext/Rdynload.h>

extern int		*ws_IDNum;              /* id          */
extern Rboolean *ws_IsRoot;        /* isroot      */
extern Rboolean *ws_IsContainer;   /* iscontainer */
extern UInt32	*ws_numOfItems;      /* numofit     */
extern int		*ws_parID;           /* parid       */
extern char		**ws_name;            /* name        */
extern char		**ws_type;            /* type        */
extern char		**ws_size;            /* objsize     */
extern int		NumOfWSObjects;         /* length of the vectors    */
extern BOOL WeHaveWorkspace;

static id sharedWSBController;
#define ROOT_KEY @"root"
#define NAME_KEY @"name"
#define TYPE_KEY @"type"
#define PROP_KEY @"property"
#define CHILD_KEY @"children"

@implementation WSBrowser



- (id)init
{

    self = [super init];

    if (self) {
		sharedWSBController = self;
		// Add your subclass-specific initialization here.
        // If an error occurs here, send a [self release] message and return nil.
		    [WSBDataSource setTarget: self];
			[WSBWindow orderFront:self];
			toolbar = nil;
    }
	
    return self;
}

- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self 
													name:NSWindowDidBecomeKeyNotification 
												  object:WSBWindow];
	[super dealloc];
}

#define GET_CHILDREN 	NSArray *children; \
if (!item) { \
    children = dataStore; \
} else { \
    children = [item objectForKey:CHILD_KEY]; \
}

// required
- (id)outlineView:(NSOutlineView *)ov child:(NSInteger)index ofItem:(id)item
{
    // item is an NSDictionary...
    GET_CHILDREN;
    if ((!children) || ([children count] <= index)) return nil;
    return [children objectAtIndex:index];
}

- (BOOL)outlineView:(NSOutlineView *)ov isItemExpandable:(id)item
{
    GET_CHILDREN;
    if ((!children) || ([children count] < 1)) return NO;
    return YES;
}

- (NSInteger)outlineView:(NSOutlineView *)ov numberOfChildrenOfItem:(id)item
{
    GET_CHILDREN;
    return [children count];
}

- (id)outlineView:(NSOutlineView *)ov objectValueForTableColumn:(NSTableColumn *)tableColumn byItem:(id)item
{
   return [item objectForKey:[tableColumn identifier]];
}


// Delegate methods

- (BOOL)outlineView:(NSOutlineView *)outlineView shouldEditTableColumn:(NSTableColumn *)tableColumn item:(id)item {
    return NO;
}

- (id) window
{
	return WSBWindow;
}

+ (WSBrowser*)getWSBController
{
	return sharedWSBController;
}



- (NSMutableDictionary *)itemWithName:(NSString *)itemName type:(NSString *)itemType  property:(NSString *)itemProperty andChildren:(NSMutableArray *)childList
{
    NSMutableDictionary *item = [[NSMutableDictionary alloc] init];
    [item setObject:itemName forKey:NAME_KEY];
    [item setObject:itemType forKey:TYPE_KEY];
    [item setObject:itemProperty forKey:PROP_KEY];
    if (childList) [item setObject:childList forKey:CHILD_KEY];
        [item autorelease];
    return item;
}

- (void)_indentBy:(int)indent withString:(NSString *)str
{
    int i = indent;
    while (i>0) {
        fprintf(stderr, "%s", [str UTF8String]);
        i--;
    }
}

- (void)_dumpBranch:(NSArray *)items level:(int)level
{
    int count = [items count];
    int i;
    if (count < 1) return;
    for (i=0; i<count; i++) {
        [self _indentBy:level withString:@" |  "];
        fprintf(stderr, " +  %s (%s) - %s\n", [[[items objectAtIndex:i] objectForKey:NAME_KEY] cString], 
		[[[items objectAtIndex:i] objectForKey:TYPE_KEY] cString], 
		[[[items objectAtIndex:i] objectForKey:PROP_KEY] cString]);
        [self _dumpBranch:[[items objectAtIndex:i] objectForKey:CHILD_KEY] level:(level+1)];
    }
}

- (void)dumpDataStore
{
    [self _dumpBranch:dataStore level:0];
}



- (void)initWSData
{
	int i, j;
		
	if (dataStore) {
		[dataStore release];
		 dataStore = nil;
	}
	if(WeHaveWorkspace==NO)
		return;
		
		
	dataStore = [[NSMutableArray alloc] init];
	
	for (i = 0; i < NumOfWSObjects; i++){
		NSMutableDictionary *item;
		if(ws_IsRoot[i]){
		if(ws_IsContainer[i]==0){
			item = [self itemWithName:[NSString stringWithUTF8String:ws_name[i]] 
					type:[NSString stringWithUTF8String:ws_type[i]]
					property: [NSString stringWithUTF8String:ws_size[i]] 
					andChildren:nil];
		} else {
			NSMutableArray *group = [[NSMutableArray alloc] init];
			for(j=i+1;j<NumOfWSObjects;j++){
				if(ws_parID[j] == ws_IDNum[i]){
					NSMutableDictionary *subitem;			
					subitem = [self itemWithName:[NSString stringWithUTF8String:ws_name[j]] 
						type:[NSString stringWithUTF8String:ws_type[j]]
						property: [NSString stringWithUTF8String:ws_size[j]] 
						andChildren:nil];
					[group addObject:subitem];
				}
			}
			item = [self itemWithName:[NSString stringWithUTF8String:ws_name[i]] 
								type:[NSString stringWithUTF8String:ws_type[i]]
								property: [NSString stringWithUTF8String:ws_size[i]] 
								andChildren:group];
			[group release];					
		}
		[dataStore addObject:item];
	}
	}
}

- (void) doInitWSData
{
	[self initWSData];
	// [self dumpDataStore]; /* This intended for debug purposes only */
	[WSBDataSource reloadData];
}

- (void) awakeFromNib
{

	// if WSBWindow became first responder refresh data
	[[NSNotificationCenter defaultCenter] addObserver:self 
											 selector:@selector(reloadWSBData:) 
												 name:NSWindowDidBecomeKeyNotification 
											   object:WSBWindow];

	[self setupToolbar];

}

- (void) setupToolbar {
	
    // Create a new toolbar instance, and attach it to our document window 
	toolbar = [[[NSToolbar alloc] initWithIdentifier: WorkSpaceBrowserToolbarIdentifier] autorelease];
    
    // Set up toolbar properties: Allow customization, give a default display mode, and remember state in user defaults 
    [toolbar setAllowsUserCustomization: YES];
    [toolbar setAutosavesConfiguration: YES];
    [toolbar setDisplayMode: NSToolbarDisplayModeIconOnly];
    
    // We are the delegate
    [toolbar setDelegate: self];
    
    // Attach the toolbar to the document window 
    [WSBWindow setToolbar: toolbar];
}

- (NSToolbarItem *) toolbar: (NSToolbar *)toolbar itemForItemIdentifier: (NSString *) itemIdent willBeInsertedIntoToolbar:(BOOL) willBeInserted {
    // Required delegate method:  Given an item identifier, this method returns an item 
    // The toolbar will use this method to obtain toolbar items that can be displayed in the customization sheet, or in the toolbar itself 
    NSToolbarItem *toolbarItem = [[[NSToolbarItem alloc] initWithItemIdentifier: itemIdent] autorelease];
    
    if ([itemIdent isEqual: EditObjectToolbarItemIdentifier]) {
		// Set the text label to be displayed in the toolbar and customization palette 
		[toolbarItem setLabel: NLS(@"Edit")];
		[toolbarItem setPaletteLabel: NLS(@"Edit Object")];
		
		// Set up a reasonable tooltip, and image   Note, these aren't localized, but you will likely want to localize many of the item's properties 
		[toolbarItem setToolTip: NLS(@"Edit the selected object")];
		[toolbarItem setImage: [NSImage imageNamed: @"objEdit"]];
		
		// Tell the item what message to send when it is clicked 
		[toolbarItem setTarget: self];
		[toolbarItem setAction: @selector(editObject:)];
    } else  if ([itemIdent isEqual: RemoveObjectToolbarItemIdentifier]) {
		// Set the text label to be displayed in the toolbar and customization palette 
		[toolbarItem setLabel: NLS(@"Remove")];
		[toolbarItem setPaletteLabel: NLS(@"Remove Object")];
		
		// Set up a reasonable tooltip, and image   Note, these aren't localized, but you will likely want to localize many of the item's properties 
		[toolbarItem setToolTip: NLS(@"Remove Selected Object")];
		[toolbarItem setImage: [NSImage imageNamed: @"objRem"]];
		
		// Tell the item what message to send when it is clicked 
		[toolbarItem setTarget: self];
		[toolbarItem setAction: @selector(remObject:)];
    }  else  if ([itemIdent isEqual: RefreshObjectsListToolbarItemIdentifier]) {
		// Set the text label to be displayed in the toolbar and customization palette 
		[toolbarItem setLabel: NLS(@"Refresh")];
		[toolbarItem setPaletteLabel: NLS(@"Refresh Objects List")];
		
		// Set up a reasonable tooltip, and image   Note, these aren't localized, but you will likely want to localize many of the item's properties 
		[toolbarItem setToolTip: NLS(@"Refresh Objects List")];
		[toolbarItem setImage: [NSImage imageNamed: @"refresh"]];
		
		// Tell the item what message to send when it is clicked 
		[toolbarItem setTarget: self];
		[toolbarItem setAction: @selector(reloadWSBData:)];
    } else {
		// itemIdent refered to a toolbar item that is not provide or supported by us or cocoa 
		// Returning nil will inform the toolbar this kind of item is not supported 
		toolbarItem = nil;
    }
    return toolbarItem;
}

- (NSArray *) toolbarDefaultItemIdentifiers: (NSToolbar *) toolbar {
    // Required delegate method:  Returns the ordered list of items to be shown in the toolbar by default    
    // If during the toolbar's initialization, no overriding values are found in the user defaults, or if the
    // user chooses to revert to the default items this set will be used 
    return [NSArray arrayWithObjects:	EditObjectToolbarItemIdentifier,  RemoveObjectToolbarItemIdentifier,
		RefreshObjectsListToolbarItemIdentifier, nil];
}


- (NSArray *) toolbarAllowedItemIdentifiers: (NSToolbar *) toolbar {
    // Required delegate method:  Returns the list of all allowed items by identifier.  By default, the toolbar 
    // does not assume any items are allowed, even the separator.  So, every allowed item must be explicitly listed   
    // The set of allowed items is used to construct the customization palette 
    return [NSArray arrayWithObjects: 	EditObjectToolbarItemIdentifier,  RemoveObjectToolbarItemIdentifier, 
		RefreshObjectsListToolbarItemIdentifier, nil];
}



- (BOOL) validateToolbarItem: (NSToolbarItem *) toolbarItem {
    // Optional method:  This message is sent to us since we are the target of some toolbar item actions 
    // (for example:  of the save items action) 
    BOOL enable = NO;
	int nsel = [WSBDataSource numberOfSelectedRows];

	if( ([[toolbarItem itemIdentifier] isEqual: EditObjectToolbarItemIdentifier]) && (nsel>0) ) {
		enable = YES;
    } else if( ([[toolbarItem itemIdentifier] isEqual: RemoveObjectToolbarItemIdentifier]) && (nsel>0)) {
		enable = YES;
    } else if ([[toolbarItem itemIdentifier] isEqual: RefreshObjectsListToolbarItemIdentifier]) {
		enable = YES;
    }		
    return enable;
}

- (BOOL)validateMenuItem:(NSMenuItem *)menuItem
{

	if ([menuItem action] == @selector(editObject:)) {
		return ([WSBDataSource numberOfSelectedRows] == 1);
	}

	return YES;

}

- (IBAction) reloadWSBData:(id)sender
{

	// Avoid refreshing if not visible
	if(![[[WSBrowser getWSBController] window] isVisible]) return;

	SLog(@"Workspace Browser data will be updated");

	NumOfWSObjects = 0;
	[[REngine mainEngine] executeString:@"capture.output(browseEnv(html=F))"];
	[self  doInitWSData];

}


-(NSString *)getObjectName{
	NSUInteger row, sel_row;
	id item;
	if( (sel_row = [WSBDataSource selectedRow]) == NSNotFound)
		return @"";
	
	for(row = sel_row; row>=0; row--){
		if([WSBDataSource levelForRow:row]==0){
			item = [WSBDataSource itemAtRow:row]; 			
			return [item objectForKey:NAME_KEY];
			break;
		}
	}
	return @"";
}

-(IBAction) editObject:(id)sender{

	NSString *objName = [[WSBrowser getWSBController] getObjectName];
	if([objName isEqual:@""])
		return;

	[[REngine mainEngine] executeString: [NSString stringWithFormat:@"%@ <- edit(%@)", objName, objName]];
	[[WSBrowser getWSBController] reloadWSBData:self];

	// Remain key window status
	[[self window] makeKeyAndOrderFront:nil];

}

-(IBAction) remObject:(id)sender{
	NSString *objName = [[WSBrowser getWSBController] getObjectName];
	if([objName isEqual:@""])
		return;

	NSBeginAlertSheet(NLS(@"Remove Object from Workspace"), NLS(@"Yes"), NLS(@"No"), nil, WSBWindow, self, @selector(shouldRemoveObj:returnCode:contextInfo:), NULL, objName,
				  [NSString stringWithFormat:NLS(@"Are you sure you want to remove object '%@' from the workspace? You cannot undo this action!"), objName]);    
}

/**
 * this gets called by the "wanna remove object?" sheet 
 */
- (void) shouldRemoveObj:(id)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo
{

	// Order out the sheet - could be a NSPanel or NSWindow
	if ([sheet respondsToSelector:@selector(orderOut:)]) {
		[sheet orderOut:nil];
	}
	else if ([sheet respondsToSelector:@selector(window)]) {
		[[sheet window] orderOut:nil];
	}

	if( (returnCode==NSAlertDefaultReturn) && contextInfo != nil ) {
		[[REngine mainEngine] executeString: [NSString stringWithFormat:@"rm(%@)",contextInfo]];
		[[WSBrowser getWSBController] reloadWSBData:self];
	}

	[[self window] makeKeyAndOrderFront:nil];

}

+ (void) initData
{
	[[WSBrowser getWSBController] doInitWSData];
	
}

+ (void)toggleWorkspaceBrowser
{
	[WSBrowser initData];
	[[[WSBrowser getWSBController] window] makeKeyAndOrderFront:self];
}

@end
