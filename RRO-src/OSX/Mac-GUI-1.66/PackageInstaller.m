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

#import "PackageInstaller.h"
#import "RController.h"
#import "REngine/Rcallbacks.h"
#import "REngine/REngine.h"
#import "Tools/Authorization.h"
#import "Preferences.h"
#include <unistd.h>

static id sharedController;

#define defaultCustomURL @"http://R.research.att.com/"

NSString *location[4] = {
	@"\"/Library/Frameworks/R.framework/Resources/library/\"",
	@"\"~/Library/R/library\"", /* this is changed by awakeFromNIB to Library/R/x.y/library */
	nil, /* other location - choose directory */
	@".libPaths()[1]"
};

@interface PackageEntry (PrivateMethods)
- (NSString*) name;
- (NSString*) iver;
- (NSString*) rver;
- (BOOL) status;

// this one allows us to run sortUsingSelector: on the enclosing array - the actual reason why I replaced the C structure
- (NSComparisonResult)caseInsensitiveCompare:(PackageEntry *)anEntry;
@end

@implementation PackageEntry

- (id) initWithName: (const char*) cName iVer: (const char*) iV rVer: (const char*) rV status: (BOOL) st
{
	self = [super init];
	if (self) {
		name=[[NSString alloc] initWithUTF8String: cName];
		iver=[[NSString alloc] initWithUTF8String: iV];
		rver=[[NSString alloc] initWithUTF8String: rV];
		status=st;
	}
	return self;
}

- (void) dealloc {
	[name release];
	[iver release];
	[rver release];
	[super dealloc];
}

- (NSString*) name { return name; };
- (NSString*) iver { return iver; };
- (NSString*) rver { return rver; };
- (BOOL) status { return status; };

- (NSComparisonResult)caseInsensitiveCompare:(PackageEntry *)anEntry
{
	return [name caseInsensitiveCompare:[anEntry name]];
}
@end

@implementation PackageInstaller

- (void) busy: (BOOL) really
{
	if (really) {
		SLog(@"PackageInstaller: I'm getting busy");
		[busyIndicator startAnimation:self];
		[updateAllButton setEnabled:NO];
		[installButton setEnabled:NO];
		[getListButton setEnabled:NO];
	} else {
		SLog(@"PackageInstaller: Stopped being busy");
		[busyIndicator stopAnimation:self];
		[updateAllButton setEnabled:!(pkgUrl==kLocalBin || pkgUrl==kLocalSrc || pkgUrl==kLocalDir)];
		[installButton setEnabled:YES];
		[getListButton setEnabled:!(pkgUrl==kLocalBin || pkgUrl==kLocalSrc || pkgUrl==kLocalDir)];
	}
}

- (IBAction)installSelected:(id)sender
{
	NSString *targetLocation = location[pkgInst];

	BOOL success = YES;
	
	if(!targetLocation){ /* custom location */
		NSOpenPanel *op;
		int answer;
		
		op = [NSOpenPanel openPanel];
		[op setCanChooseDirectories:YES];
		[op setCanChooseFiles:NO];
		[op setTitle:NLS(@"Select Installation Directory")];
		
		answer = [op runModalForDirectory:nil file:nil types:[NSArray arrayWithObject:@""]];
		[op setCanChooseDirectories:NO];
		[op setCanChooseFiles:YES];
		if(answer == NSOKButton)
			targetLocation = [NSString stringWithFormat:@"\"%@\"", [op directory]];
		else
			return;
	} else
		[self busy:YES];

	{
		NSString *testFile, *realLoc=nil;
		RSEXP *lx = [[REngine mainEngine] evaluateString: targetLocation];
		if (lx) realLoc = [lx string];
		if (realLoc) realLoc = [realLoc stringByExpandingTildeInPath];
		if (lx) [lx release];
		SLog(@"PackageInstaller.installSelected: real location=%@", realLoc);
		if (!realLoc || ![[NSFileManager defaultManager] fileExistsAtPath:realLoc]) {
			if (realLoc && pkgInst==kUserLevel) { // create user-level path if it doesn't exist
				system([[NSString stringWithFormat:@"mkdir -p %@", realLoc] UTF8String]);
			} else {
				[self busy: NO];
				NSRunAlertPanel(NLS(@"Package Installer"),NLS(@"The installation location doesn't exist."),NLS(@"OK"),nil,nil);				
				return;
			}
		}
		testFile = [realLoc stringByAppendingString:@"/.aqua.test"];
		if ([[NSFileManager defaultManager] createFileAtPath:testFile contents:[NSData dataWithBytes:"foo" length:4] attributes:nil])
			[[NSFileManager defaultManager] removeFileAtPath:testFile handler:nil];
		else {
			if (requestRootAuthorization(0)) {
				[self busy: NO];
				NSRunAlertPanel(NLS(@"Package Installer"),NLS(@"The package has not been installed."),NLS(@"OK"),nil,nil);	
				return;
			} else {
				[[RController sharedController] setRootFlag:YES];
				// we need to make sure that the tempdir is root-writable
				SLog(@" - installing as root, we need to make sure tempdir() is writable");
				RSEXP *x = [[REngine mainEngine] evaluateString:@"tempdir()"];
				if (x) {
					NSString *td = [x string];
					if (td) {
						NSDictionary *fa = [NSDictionary dictionaryWithObjectsAndKeys: @"wheel", NSFileGroupOwnerAccountName, [NSNumber numberWithInt: 0770], NSFilePosixPermissions, nil];
						if (fa) {
							BOOL succ = [[NSFileManager defaultManager] changeFileAttributes:fa atPath:td];
							SLog(@" - changed group to wheel and permissions to 0770 (%s)", succ?"success":"FAILED!");
						} else SLog(@" * cannot create file attributes dictionary!");
					} else SLog(@" * cannot retrieve tempdir! (got NULL string) Installation is likely to fail ...");
					[x release];					
				} else SLog(@" * cannot retrieve tempdir! (RSEXP is nil) Installation is likely to fail ...");
			}
		}
	}
	
	switch(pkgUrl) {
		case kLocalBin:
			[[REngine mainEngine] executeString: [NSString stringWithFormat:@"install.packages(file.choose(),%@,NULL,type='%@')", targetLocation, pkgType]];
			break;
			
		case kLocalSrc:
			 [[REngine mainEngine] executeString: [NSString stringWithFormat:@"install.packages(file.choose(),%@,NULL,type='source')", targetLocation]];
			break;
			
		case kLocalDir:
			 {
				NSOpenPanel *op;
				int answer;
				
				op = [NSOpenPanel openPanel];
				[op setCanChooseDirectories:YES];
				[op setCanChooseFiles:NO];
				[op setTitle:NLS(@"Select Package Directory")];
				
				answer = [op runModalForDirectory:nil file:nil types:[NSArray arrayWithObject:@""]];
				[op setCanChooseDirectories:NO];
				[op setCanChooseFiles:YES];		
				
				if(answer == NSOKButton) 
					if([op directory] != nil)
						[[REngine mainEngine] executeString: [NSString stringWithFormat:@"install.packages(\"%@\",%@,NULL,type='source')",[op directory], targetLocation]];
			}				
			break;
			
		default:
		{
			NSMutableString *packagesToInstall = nil;
			NSIndexSet *rows =  [pkgDataSource selectedRowIndexes];
			NSString *repos = @"getOption(\"repos\")";
			NSString *type  = pkgType;
			NSUInteger current_index = [rows firstIndex];
			
			if(current_index == NSNotFound) {
				[self busy: NO];
				NSBeginAlertSheet(NLS(@"Package installer"), NLS(@"OK"), nil, nil, [self window], self, @selector(sheetDidEnd:returnCode:contextInfo:), @selector(sheetDidEnd:returnCode:contextInfo:), NULL, NLS(@"No packages selected, nothing to do."));
				break;
			}
			
			packagesToInstall = [[NSMutableString alloc] initWithString: @"c("];
			
			while (current_index != NSNotFound) {
				NSUInteger cix = current_index;
				if (filter) cix = filter[cix];
				[packagesToInstall appendFormat:@"\"%@\"",[[packages objectAtIndex:cix] name]];
				current_index = [rows indexGreaterThanIndex: current_index];
				if(current_index != NSNotFound)
					[packagesToInstall appendString:@","];
			}
			
			[packagesToInstall appendString:@")"];
			
			switch(pkgUrl) {
				
				case kCRANBin:
					if([[RController sharedController] getRootFlag]) {
						NSBeginAlertSheet(NLS(@"Package installer"), NLS(@"OK"), nil, nil, [self window], self, @selector(sheetDidEnd:returnCode:contextInfo:), @selector(sheetDidEnd:returnCode:contextInfo:), NULL, NLS(@"Currently it is not possible to install binary packages from a remote repository as root.\nPlease use the CRAN binary of R to allow admin users to install system-wide packages without becoming root. Alternatively you can either use command-line version of R as root or install the packages from local files."));
						break;
					}
					
					break;
					
				case kCRANSrc:
					type = @"source";
					break;
					
				case kBIOCBin:
					repos=@"c(getOption(\"BioC.Repos\"),getOption(\"repos\"))";
					break;
					
				case kBIOCSrc:
					repos=@"c(getOption(\"BioC.Repos\"),getOption(\"repos\"))";
					type=@"source";
					break;
					
				case kOTHER:
				case kOtherFlat:
					if (pkgFormat == kSource) type=@"source";
					repos = [NSString stringWithFormat:@"\"%@\"", [urlTextField stringValue]];
					break;
			}
			
			if (repos && type) {
				if (pkgUrl == kOtherFlat)
					success = [[REngine mainEngine] executeString: 
						[NSString stringWithFormat:@"install.packages(%@,lib=%@,contriburl=%@),type='%@',dependencies=%@)",
							packagesToInstall, targetLocation, repos, type, ([depsCheckBox state]==NSOnState)?@"TRUE":@"FALSE"]
						];
				else
					success = [[REngine mainEngine] executeString: 
						[NSString stringWithFormat:@"install.packages(%@,lib=%@,contriburl=contrib.url(%@,'%@'),type='%@',dependencies=%@)",
							packagesToInstall, targetLocation, repos, type, type, ([depsCheckBox state]==NSOnState)?@"TRUE":@"FALSE"]
						];
			}
			
			[packagesToInstall release];
		}
	}
			
	if (!success) NSBeginAlertSheet(NLS(@"Package installation failed"), NLS(@"OK"), nil, nil, [self window], self, @selector(sheetDidEnd:returnCode:contextInfo:), @selector(sheetDidEnd:returnCode:contextInfo:), NULL, NLS(@"Package installation was not successful. Please see the R Console for details."));
	
	[self busy:NO];
	
	if (!(pkgUrl==kLocalBin || pkgUrl==kLocalSrc || pkgUrl==kLocalDir)) [self reloadURL:self];
}

- (void) checkOptions
{
	// in 2.1.0 release the proxy functions were not updated to accomodate for changes in
	// package installation - so we need to set options for backward compati-
	// bility
	if (!optionsChecked) {
		RSEXP *x;
		BOOL hadToChoose=NO;
			x = [[REngine mainEngine] evaluateString:@"getOption('repos')['CRAN']"];
			if (!x || ![x string] || [[x string] isEqualToString:@"@CRAN@"]) { // repos is not set
				if (x) [x release];
				SLog(@" - ['repos']['CRAN'] is not set, either. Launching mirror selector.");
				[[REngine mainEngine] executeString:@"chooseCRANmirror()"];
				hadToChoose=YES;
				x = [[REngine mainEngine] evaluateString:@"getOption('repos')['CRAN']"];
			}
			if (x && [x string] && ![[x string] isEqualToString:@"@CRAN@"]) { // repos is set now - push it to CRAN
				if (hadToChoose && ![Preferences flagForKey:stopAskingAboutDefaultMirrorSavingKey withDefault:NO])
					NSBeginAlertSheet(NLS(@"Set as default?"), NLS(@"Yes"), NLS(@"Never"), NLS(@"No"), [self window], self, @selector(mirrorSaveAskSheetDidEnd:returnCode:contextInfo:), NULL, NULL, NLS(@"Do you want me to remember the mirror you selected for future sessions?"));
			} else {
				if (x) [x release]; // set x to nil - we need that in case x is @CRAN@
				x=nil;
			}
		if (!x || ![x string]) { // CRAN is still not set - bail out with an error
			[self busy:NO];
			NSRunAlertPanel(NLS(@"No CRAN Mirror Found"),NLS(@"No valid CRAN mirror was selected.\nYou won't be able to install any CRAN packages unless you set the CRAN option to a valid mirror URL."),NLS(@"OK"),nil,nil);
			return;
		}
		if (x) [x release];
		optionsChecked = YES;
	}
}

- (IBAction)reloadURL:(id)sender
{
	BOOL success = NO;
	//	NSLog(@"pkgUrl=%d, pkgInst=%d, pkgFormat:%d",pkgUrl, pkgInst, pkgFormat);
	
	[self busy: YES];
	
	[self checkOptions];
	
	switch(pkgUrl){
		
		case kCRANBin:
			success = [[REngine mainEngine] executeString: 
				   [NSString stringWithFormat:@"browse.pkgs(type=\"%@\")", pkgType]];
			break;
			
		case kCRANSrc:
			success = [[REngine mainEngine] executeString: 
				   @"browse.pkgs(type=\"source\")"];
			break;
			
		case kBIOCBin:
			success = [[REngine mainEngine] executeString: 
				   [NSString stringWithFormat:@"browse.pkgs(contriburl=contrib.url(setBioCversion(),\"%@\"), type=\"%@\")", pkgType, pkgType]];
			break;
			
		case kBIOCSrc:
			success = [[REngine mainEngine] executeString: 
				   @"browse.pkgs(contriburl=contrib.url(setBioCversion(),\"source\"), type=\"source\")"];
			break;
			
		case kOTHER:
		case kOtherFlat:
			if( [[urlTextField stringValue] isEqual:@""]){
				[self busy:NO];
				NSBeginAlertSheet(NLS(@"Invalid Repository URL"), NLS(@"OK"), nil, nil, [self window], self, NULL, NULL, NULL, NLS(@"Please specify a valid URL first."));
				return;
			}
			
			[Preferences setKey:@"pkgInstaller.customURL" withObject:[urlTextField stringValue]];
			success = [[REngine mainEngine] executeString: 
				   [NSString stringWithFormat:@"browse.pkgs(%@=\"%@\",type=\"%@\")",
				    (pkgUrl == kOtherFlat)?@"contriburl":@"repos",
				    [urlTextField stringValue], (pkgFormat == kSource)?@"source":pkgType]];
			break;
			
	}
	loadedPkgUrl=pkgUrl; // whether successful or not doesn't mattter - but the load was attempted

	[self reRunFilter];
	
	if (!success) NSBeginAlertSheet(NLS(@"Fetching Package List Failed"), NLS(@"OK"), nil, nil, [self window], self, NULL, NULL, NULL, NLS(@"Please consult  R Console output for details."));
	
	[self busy:NO];

	[installButton setEnabled:([[pkgDataSource selectedRowIndexes] count])];

}

- (void) mirrorSaveAskSheetDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
	switch(returnCode) {
		case NSAlertDefaultReturn: // Yes
			SLog(@"mirrorSaveAskSheetDidEnd: YES, Save");
			{
				RSEXP *x = [[REngine mainEngine] evaluateString:@"getOption('repos')['CRAN']"];
				if (x) {
					NSString *url = [x string];
					[x release];
					if (url && ![url isEqualToString:@"@CRAN@"])
						[Preferences setKey:defaultCRANmirrorURLKey withObject:url];
				}
				break;
			}
			case NSAlertAlternateReturn: // Never
				SLog(@"mirrorSaveAskSheetDidEnd: NEVER!");
				[Preferences setKey:stopAskingAboutDefaultMirrorSavingKey withFlag:YES];
				break;
			default:
				SLog(@"mirrorSaveAskSheetDidEnd: NO, Don't Save");
	}

	[[self window] makeKeyAndOrderFront:nil];

}

- (IBAction)setURL:(id)sender
{
	pkgUrl = [[ sender selectedCell] tag];
	[pkgDataSource setHidden:(loadedPkgUrl!=pkgUrl)]; // hide if it's not the loaded one 
	[installButton setEnabled:(loadedPkgUrl==pkgUrl || pkgUrl==kLocalBin || pkgUrl==kLocalSrc || pkgUrl==kLocalDir)];
	
	if (pkgUrl==kLocalBin || pkgUrl==kLocalSrc || pkgUrl==kLocalDir)
		[installButton setTitle:NLS(@"Install…")];
	else
		[installButton setTitle:NLS(@"Install Selected")];
			
	
	switch(pkgUrl){
		
		
		case kCRANBin:
		case kBIOCBin:
			pkgFormat = kBinary;
			[formatCheckBox setState:pkgFormat];
			[formatCheckBox setEnabled:NO];
			[urlTextField setHidden:YES];
			[getListButton setEnabled:YES];
			[updateAllButton setEnabled:YES];
			[depsCheckBox setHidden:NO];
			break;
			
		case kCRANSrc:
		case kBIOCSrc:
			pkgFormat = kSource;
			[formatCheckBox setState:pkgFormat];
			[formatCheckBox setEnabled:NO];
			[urlTextField setHidden:YES];
			[getListButton setEnabled:YES];
			[updateAllButton setEnabled:YES];
			[depsCheckBox setHidden:NO];
			break;
			
		case kOTHER:
			pkgFormat = hasBinaries ? kBinary : kSource;
			[formatCheckBox setState:pkgFormat];
			[formatCheckBox setEnabled:hasBinaries];
			[urlTextField setHidden:NO];
			[getListButton setEnabled:YES];
			[updateAllButton setEnabled:YES];
			[depsCheckBox setHidden:NO];
			break;

		case kOtherFlat:
			pkgFormat = kBinary;
			[formatCheckBox setState:pkgFormat];
			[formatCheckBox setEnabled:YES];
			[urlTextField setHidden:NO];
			[getListButton setEnabled:YES];
			[updateAllButton setEnabled:YES];
			[depsCheckBox setHidden:NO];
			break;
			
		case kLocalBin:
			pkgFormat = kBinary;
			[formatCheckBox setState:pkgFormat];
			[formatCheckBox setEnabled:NO];
			[urlTextField setHidden:YES];
			[getListButton setEnabled:NO];
			[updateAllButton setEnabled:NO];
			[depsCheckBox setHidden:YES];
			break;
			
		case kLocalSrc:
			pkgFormat = kSource;
			[formatCheckBox setState:pkgFormat];
			[formatCheckBox setEnabled:NO];
			[urlTextField setHidden:YES];
			[getListButton setEnabled:NO];
			[updateAllButton setEnabled:NO];
			[depsCheckBox setHidden:YES];
			break;
			
		case kLocalDir:
			pkgFormat = kSource;
			[formatCheckBox setState:pkgFormat];
			[formatCheckBox setEnabled:NO];
			[urlTextField setHidden:YES];
			[getListButton setEnabled:NO];
			[updateAllButton setEnabled:NO];
			[depsCheckBox setHidden:YES];
			break;
			
		default:
			break;
	}
}

- (IBAction)setLocation:(id)sender
{
	pkgInst = [[ sender selectedCell] tag];
}

- (IBAction)setFormat:(id)sender
{
	pkgFormat = [[ sender selectedCell] state];
}

- (void)setPkgType: (NSString*) type
{
	hasBinaries = YES;
	if (type && [type isEqualToString:@"source"]) {
		NSInteger i;
		pkgUrl = kCRANSrc;
		pkgFormat = kSource;
		[formatCheckBox setState:pkgFormat];
		[repositoryButton selectItemWithTag:pkgUrl];
		/* disable binary choices */
		[repositoryButton setAutoenablesItems:NO];
		i = [repositoryButton indexOfItemWithTag:kCRANBin]; if (i >= 0) [[repositoryButton itemAtIndex:i] setEnabled:NO];
		SLog(@"Item: %@", [repositoryButton itemAtIndex:i]);
		i = [repositoryButton indexOfItemWithTag:kBIOCBin]; if (i >= 0) [[repositoryButton itemAtIndex:i] setEnabled:NO];
		hasBinaries = NO;
		type = @"mac.binary"; /* not used for repositories but for local packages */
	}
	if (type) {
		[pkgType release];
		pkgType = [type copy];
	}
}

- (void)awakeFromNib
{
	SLog(@"PackageInstaller: awakeFromNib");
	NSString *cURL = [Preferences stringForKey:@"pkgInstaller.customURL" withDefault:defaultCustomURL];
	{
		// add version number to local installation 
		location[1] = [[NSString alloc] initWithString: [NSString stringWithFormat:@"\"%@\"", [[NSString stringWithFormat:@"~/Library/R/%@/library", Rapp_R_version_short] stringByExpandingTildeInPath]]];
	}
	pkgType=[@"mac.binary" copy];
	hasBinaries = YES;
	[formatCheckBox setEnabled:NO];
	if (cURL) [urlTextField setStringValue:cURL];
	[urlTextField setHidden:YES];
	[installButton setEnabled:NO];
	pkgInst = isAdmin()?kSystemLevel:kUserLevel;
	pkgUrl = kCRANBin;
	pkgFormat = kBinary;
	[formatCheckBox setState:pkgFormat];
	[repositoryButton setTag:pkgUrl];
	[locationMatrix setTag:pkgInst];
	[locationMatrix selectCellWithTag:pkgInst];
	[busyIndicator setUsesThreadedAnimation:YES];
	
	{
		NSString *curRV = [NSString stringWithUTF8String:R_MAJOR "." R_MINOR];
		NSRange cr = [curRV rangeOfString:@"." options:NSBackwardsSearch];
		if (cr.location != NSNotFound)
			curRV = [curRV substringToIndex:cr.location];
		NSArray *a = [[NSFileManager defaultManager] directoryContentsAtPath:@"/Library/Frameworks/R.framework/Versions"];
		int i;

		oldRPath = nil;
		[[pkgSearchMenu itemWithTag:2] setEnabled:NO];
		if (a && [a count]>1) {
			a = [a sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)];
			i = [a count]-1;
			while (i>=0) {
				if ([(NSString*)[a objectAtIndex:i] compare:curRV]<0) break;
				i--;
			}
			if (i>=0) {
				oldRPath=[[NSString stringWithFormat:@"/Library/Frameworks/R.framework/Versions/%@/Resources", [a objectAtIndex:i]] retain];
				SLog(@"PackageInstaller.awakeFromNib: found previous R at %@", oldRPath);
				[[pkgSearchMenu itemWithTag:2] setTitle:[NSString stringWithFormat:NLS(@"Select packages from R %@"), [a objectAtIndex:i]]];
			}
		}
	}
	if (!oldRPath) {
		SLog(@"PackageInstaller.awakeFromNib: no previous R version found.");
		[pkgSearchMenu removeItem:[pkgSearchMenu itemWithTag:2]];
	}
}

- (id)init
{
    self = [super init];
    if (self) {
		sharedController = self;
		[pkgDataSource setTarget: self];
		optionsChecked = NO;
		loadedPkgUrl = -1;
		packages = [[NSMutableArray alloc] init];
		filter = 0;
		filterlen = 0;
		filterString = nil;
		installedOnly = NO;
		oldRPath = nil;
    }
	
    return self;
}

- (void)dealloc {
	[self resetPackages];
	if(packages) [packages release];
	[super dealloc];
}

- (void) resetPackages
{
	[packages removeAllObjects];
	if (filter) {
		free(filter);
		filter=0;
	}
	filterlen=0;
}

- (NSInteger)numberOfRowsInTableView: (NSTableView *)tableView
{
	return (filter)?filterlen:[packages count];
}

- (id)tableView: (NSTableView *)tableView objectValueForTableColumn: (NSTableColumn *)tableColumn row: (NSInteger)row
{
	int lrow = row;
	if (!packages) return nil;
	if (filter) {
		if (row>=filterlen) return nil;
		lrow = filter[row];
	}
	if (lrow>=[packages count]) return nil;
	if([[tableColumn identifier] isEqualToString:@"package"])
		return [[packages objectAtIndex:lrow] name];
	else if([[tableColumn identifier] isEqualToString:@"instVer"])
		return [[packages objectAtIndex:lrow] iver];
	else if([[tableColumn identifier] isEqualToString:@"repVer"])
		return [[packages objectAtIndex:lrow] rver];
	return nil;				
}

- (id) window
{
	return pkgWindow;
}

+ (id) sharedController {
	return sharedController;
}

- (IBAction) reloadPIData:(id)sender
{
	//	[[RController sharedController] sendInput:@"package.manager()"];
	[pkgDataSource reloadData];
}

- (void) reloadData
{
	[pkgDataSource setHidden:NO];
	[pkgDataSource reloadData];
	[installButton setEnabled:([[pkgDataSource selectedRowIndexes] count])];
}

- (void) show
{
	[self reloadData];
	[[self window] makeKeyAndOrderFront:self];
}

- (void) updateInstalledPackages: (int) count withNames: (char**) name installedVersions: (char**) iver repositoryVersions: (char**) rver update: (BOOL*) stat label: (char*) label
{
	int i=0;
	
	if ([packages count]>0) [self resetPackages];
	if (count<1) {
		[self show];
		return;
	}
	
	if (label) repositoryLabel = [NSString stringWithUTF8String: label];

	while (i<count) {
		PackageEntry *pe = [[PackageEntry alloc] initWithName:name[i] iVer:iver[i] rVer:rver[i] status:stat[i]];
		[packages addObject:pe];
		[pe release]; // the array retained it
		i++;
	}
	[packages sortUsingSelector:@selector(caseInsensitiveCompare:)];
	
	[self show];
	[installButton setEnabled:([[pkgDataSource selectedRowIndexes] count])];

}

- (IBAction)updateAll:(id)sender
{
	NSString *targetLocation = nil;
	NSString *repos = nil;
	NSString *type = pkgType;
	BOOL success = NO;

	if(pkgUrl == kOTHER && [[urlTextField stringValue] isEqual:@""]) {
		NSBeginAlertSheet(NLS(@"Invalid Repository URL"), NLS(@"OK"), nil, nil, [self window], self, NULL, NULL, NULL, NLS(@"Please specify a valid URL first."));
		return;
	}

	if(pkgInst == kOtherLocation){
		NSOpenPanel *op;
		int answer;
		
		op = [NSOpenPanel openPanel];
		[op setCanChooseDirectories:YES];
		[op setCanChooseFiles:NO];
		[op setTitle:NLS(@"Select Installation Directory")];
		
		answer = [op runModalForDirectory:nil file:nil types:[NSArray arrayWithObject:@""]];
		[op setCanChooseDirectories:NO];
		[op setCanChooseFiles:YES];
		if(answer == NSOKButton)
			targetLocation = [op directory];
		else
			return;
	} else
		targetLocation = location[pkgInst];
	
	[self busy:YES];
	
	[self checkOptions];
	
	switch(pkgUrl){
		case kCRANBin:
			if([[RController sharedController] getRootFlag]) {
				NSBeginAlertSheet(NLS(@"Package installer"), NLS(@"OK"), nil, nil, [self window], self, NULL, NULL, NULL, NLS(@"Currently it is not possible to install binary packages from a remote repository as root.\nPlease use the CRAN binary of R to allow admin users to install system-wide packages without becoming root. Alternatively you can either use command-line version of R as root or install the packages from local files."));
				break;
			}
			repos=@"getOption(\"repos\")";
			break;
			
		case kCRANSrc:
			repos=@"getOption(\"repos\")";
			type =@"source";
			break;
			
		case kBIOCBin:
			repos=@"getOption(\"BioC.Repos\")";
			break;
			
		case kBIOCSrc:
			repos=@"getOption(\"BioC.Repos\")";
			type =@"source";
			break;
			
		case kOTHER:
			repos=[NSString stringWithFormat:@"\"%@\"", [urlTextField stringValue]];
			if(pkgFormat == kSource) type =@"source";
	}
	if (pkgUrl != kOtherFlat)
		success = [[REngine mainEngine] executeString: 
			[NSString stringWithFormat:@"update.packages(lib=%@,ask='graphics',contriburl=contrib.url(%@,'%@'),type='%@')",
				targetLocation, repos, type, type]
			];
	else
		success = [[REngine mainEngine] executeString: 
			[NSString stringWithFormat:@"update.packages(lib=%@,ask='graphics',contriburl='%@',type='%@')",
				targetLocation, [urlTextField stringValue], type]
			];
	
	if (!success) NSBeginAlertSheet(NLS(@"Package update failed"), NLS(@"OK"), nil, nil, [self window], self, NULL, NULL, NULL, NLS(@"Package update was not successful. Please see the R Console for details."));
	
	[self reloadURL:self];
	[self busy:NO];
}

- (void) reRunFilter
{
	SLog(@"PackageInstaller.reRunFilter (search string is %@)",filterString?filterString:@"<none>");
	
	NSIndexSet *preIx = [pkgDataSource selectedRowIndexes];
	NSMutableIndexSet *postIx = [[NSMutableIndexSet alloc] init];
	NSMutableIndexSet *absSelIx = [[NSMutableIndexSet alloc] init];
	NSUInteger i=0;
	
	if ([preIx count]>0) { // save selection in absolute index positions
		i = [preIx firstIndex];
		do {
			if (!filter || i<filterlen)
				[absSelIx addIndex:filter?filter[i]:i];
			i = [preIx indexGreaterThanIndex:i];
		} while (i != NSNotFound);
		i = 0;
	}
	
	if (filter) {
		filterlen=0;
		if (filter) free(filter);
		filter=0;
	}
	
	if (installedOnly || (filterString && [filterString length]>0)) {
		filterlen=0;
		while (i<[packages count]) {
			BOOL isCand = !installedOnly || [[[packages objectAtIndex:i] iver] length]>0;
			if (isCand && (!filterString || [[[packages objectAtIndex:i] name] rangeOfString:filterString options:NSCaseInsensitiveSearch].location!=NSNotFound)) filterlen++;
			i++;
		}
		SLog(@" - found %d matches", filterlen);
		filter=(int*)malloc(sizeof(int)*(filterlen+1));
		i=0; filterlen=0;
		while (i<[packages count]) {
			BOOL isCand = !installedOnly || [[[packages objectAtIndex:i] iver] length]>0;
			if (isCand && (!filterString || [[[packages objectAtIndex:i] name] rangeOfString:filterString options:NSCaseInsensitiveSearch].location!=NSNotFound)) {
				if ([absSelIx containsIndex:i])
					[postIx addIndex:filterlen];
				filter[filterlen++]=i;
			}
			i++;
		}
	} else [postIx addIndexes:absSelIx];
	
	[pkgDataSource reloadData];
	[pkgDataSource selectRowIndexes:postIx byExtendingSelection:NO];
	[absSelIx release];
	[postIx release];

	[installButton setEnabled:([[pkgDataSource selectedRowIndexes] count])];
}

- (IBAction)runPkgSearch:(id)sender
{
	NSString *ss = [sender stringValue];
	if (filterString) [filterString release];
	if (!ss || [ss length]==0)
		filterString=nil;
	else {
		filterString = ss;
		[filterString retain];
	}
	[self reRunFilter];
}

- (IBAction)toggleShowInstalled:(id)sender
{
	installedOnly = !installedOnly;
	[(NSMenuItem*) sender setTitle:installedOnly?NLS(@"Show All"):NLS(@"Show Installed Only")];
	[self reRunFilter];
}

- (IBAction)selectOldPackages:(id)sender
{
	if (!oldRPath) return;
	NSArray *a = [[NSFileManager defaultManager] directoryContentsAtPath:[NSString stringWithFormat:@"%@/library", oldRPath]];
	if (!a || [a count]<1) return;
	NSMutableIndexSet *postIx = [[NSMutableIndexSet alloc] init];
	if (filter) {
		int i = 0;
		while (i<filterlen) {
			if ([a containsObject:[[packages objectAtIndex:filter[i]] name]])
				[postIx addIndex:i];
			i++;
		}
	} else {
		int i = 0, n = [packages count];
		while (i<n) {
			if ([a containsObject:[[packages objectAtIndex:i] name]])
				[postIx addIndex:i];
			i++;
		}
	}
	[pkgDataSource selectRowIndexes:postIx byExtendingSelection:NO];
	[postIx release];	
}

- (void)tableViewSelectionDidChange:(NSNotification *)aNotification
{
	// Check our notification object is our table
	if ([aNotification object] != pkgDataSource) return;

	[installButton setEnabled:([[pkgDataSource selectedRowIndexes] count])?YES:NO];
}

- (void)sheetDidEnd:(id)sheet returnCode:(int)returnCode contextInfo:(NSString*)contextInfo
{

	// Order out the sheet - could be a NSPanel or NSWindow
	if ([sheet respondsToSelector:@selector(orderOut:)]) {
		[sheet orderOut:nil];
	}
	else if ([sheet respondsToSelector:@selector(window)]) {
		[[sheet window] orderOut:nil];
	}

	[[self window] makeKeyAndOrderFront:nil];

}

@end
