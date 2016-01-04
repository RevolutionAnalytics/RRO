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
 *  REditorToolbar.h
 *  Toolbar for the integrated document editor
 *
 *  Created by Hans-J. Bibiko on 1/6/12.
 */

#import "CCComp.h"
#import "RDocumentWinCtrl.h"

#define	RDETI_Save       @"RDETI Save Document"
#define	RDETI_RdTools    @"RDETI RdToolbox"
#define	RDETI_HelpSearch @"RDETI Help Search"
#define RDETI_SecList    @"RDETI SecList"

#define RDET_ListAll RDETI_Save, RDETI_HelpSearch, RDETI_SecList, RDETI_RdTools, \
NSToolbarPrintItemIdentifier, NSToolbarSeparatorItemIdentifier, NSToolbarFlexibleSpaceItemIdentifier
#define RDET_ListDefault RDETI_Save, NSToolbarPrintItemIdentifier, RDETI_RdTools, NSToolbarFlexibleSpaceItemIdentifier, RDETI_SecList, RETI_HelpSearch

@interface RdEditorToolbar : NSObject <NSToolbarDelegate> {

	RDocumentWinCtrl *winCtrl;
	NSToolbar *toolbar;
	NSToolbarItem *tiSave, *tiHelpSearch, *tiSecList, *tiRdTools;

}

- initWithEditor: (RDocumentWinCtrl *)dwCtrl;

// toolbar delegate interface
- (NSToolbarItem *) toolbar: (NSToolbar *)toolbar itemForItemIdentifier: (NSString *) itemIdent willBeInsertedIntoToolbar:(BOOL) willBeInserted;
- (NSArray *) toolbarDefaultItemIdentifiers: (NSToolbar *) toolbar;
- (NSArray *) toolbarAllowedItemIdentifiers: (NSToolbar *) toolbar;
- (void) toolbarWillAddItem: (NSNotification *) notif;
- (void) toolbarDidRemoveItem: (NSNotification *) notif;

@end
