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


#import <Foundation/Foundation.h>
#import "../AMPrefs/AMPrefPaneProtocol.h"
#import "Preferences.h"


@interface MiscPrefPane : NSObject <AMPrefPaneProtocol,  PreferencesDependent> {
	NSString *identifier;
	NSString *label;
	NSString *category;
	NSImage *icon;

	IBOutlet NSView *mainView;
	IBOutlet NSMatrix *editOrSource;
	IBOutlet NSButton *cbRAquaPath;
	IBOutlet NSButton *enforceInitialWorkingDirectory;
	IBOutlet NSTextField *workingDir;
	IBOutlet NSButton *importOnStartup;
	IBOutlet NSButton *setToDefault;
	IBOutlet NSTextField *historyFileNamePath;
	IBOutlet NSTextField *historyFileNamePathText;
	IBOutlet NSTextField *maxHistoryEntries;
	IBOutlet NSButton *removeDuplicateHistoryEntries;
	IBOutlet NSButton *cleanupHistoryEntries;
	IBOutlet NSButton *stripCommentsFromHistoryEntries;
	IBOutlet NSTextField *defaultMirror;
	IBOutlet NSMatrix *saveOnExit;
}

- (id)initWithIdentifier:(NSString *)identifier label:(NSString *)label category:(NSString *)category;

// AMPrefPaneProtocol
- (NSString *)identifier;
- (NSView *)mainView;
- (NSString *)label;
- (NSImage *)icon;
- (NSString *)category;

// AMPrefPaneInformalProtocol
- (int)shouldUnselect;

// Other methods

- (IBAction) changeEditOrSource:(id)sender;
- (IBAction) changeLibPaths:(id)sender;
- (IBAction) changeWorkingDir: (id)sender;
- (IBAction) chooseWorkingDir:(id)sender;
- (IBAction) changeImportOnStartup:(id)sender;
- (IBAction) changeEnforceInitialWorkingDirectory:(id)sender;
- (IBAction) changeHistoryFileNamePathToDefault: (id)sender;
- (IBAction) changeHistoryFileNamePath:(id)sender;
- (IBAction) changeMaxHistoryEntries:(id)sender;
- (IBAction) changeRemoveDuplicateHistoryEntries:(id)sender;
- (IBAction) changeCleanupHistoryEntries:(id)sender;
- (IBAction) changeStripCommentsFromHistoryEntries:(id)sender;
- (IBAction) saveOnExit:(id)sender;
- (IBAction) changeMirrorURL:(id)sender;
- (IBAction) selectMirror:(id)sender;

- (void) updatePreferences;

@end
