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

/* PackageManager */

#import "CCComp.h"

// structure holding all available data about a package
typedef struct pkgManagerEntry {
	NSString *name;
	NSString *desc;
	NSString *url;
	BOOL status;
} s_pkgManagerEntry;

@interface PackageManager : NSObject
{
	IBOutlet NSTableView *packageDataSource;	/* TableView for the history */ 
	IBOutlet id PackageInfoView;
	
	IBOutlet NSButton *backButton, *forwardButton;
	
	id  PackageManagerWindow;
	
	int packages;
	s_pkgManagerEntry *package;
}

+ (PackageManager*) sharedController;

- (id) window;
- (IBAction) showInfo:(id)sender;
- (IBAction) reloadPMData:(id)sender;
- (IBAction)executeSelection:(id)sender;

- (void) show;

- (void) resetPackages; // removes all package data
- (void) updatePackages: (int) count withNames: (char**) name descriptions: (char**) desc URLs: (char**) url status: (BOOL*) stat;
- (int) count;

@end
