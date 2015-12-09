/*
 *  R.app : a Cocoa front end to: "R A Computer Language for Statistical Data Analysis"
 *  
 *  R.app Copyright notes:
 *                     Copyright (C) 2004-11  The R Foundation
 *                     written by Stefano M. Iacus and Simon Urbanek
 *                     RDocumentController written by Rob Goedman
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

#import "RGUI.h"
#import "RDocumentController.h"
#import "RController.h"
#import "Preferences.h"
#import "PreferenceKeys.h"
#import "QuartzCocoaDocument.h"
#import "RChooseEncodingPopupAccessory.h"

// default autosave is 3 minutes
#define defaultAutosavingDelay (3 * 60.0)

// R defines "error" which is deadly as we use open ... with ... error: where error then gets replaced by Rf_error
#ifdef error
#undef error
#endif


@implementation OpenSaveAccessoryOwner
@end

@implementation RDocumentController

- (id)init {

	self = [super init];

	SLog(@"RDocumentController%@.init", self);

	if(self) {
		[[NSNotificationCenter defaultCenter] addObserver:self 
							 selector:@selector(windowWillCloseNotifications:) 
							     name:NSWindowWillCloseNotification 
							   object:nil];
		[self updatePreferences];
		[[Preferences sharedPreferences] addDependent:self];
		activeFileType = ftRSource;
	}

	return self;

}

- (void) dealloc {

	SLog(@"RDocumentController%@.dealloc", self);
	[[NSNotificationCenter defaultCenter] removeObserver:self];	
	[super dealloc];

}

- (void) updatePreferences
{
	BOOL autosaveEnabled = [Preferences flagForKey:kEditorAutosaveKey withDefault:YES];
	[self setAutosavingDelay: autosaveEnabled ? defaultAutosavingDelay : 0.0];
	SLog(@"%@ autosave %@", self, autosaveEnabled ? @"ENABLED" : @"DISABLED");
}

- (void)windowWillCloseNotifications:(NSNotification*) aNotification
{

	NSWindow *w = [aNotification object];

	if (w && (
			   [[(NSObject*)[w delegate] className] isEqualToString:@"RDocumentWinCtrl"] 
			|| [[(NSObject*)[w delegate] className] isEqualToString:@"QuartzCocoaView"])
			) {

		SLog(@"RDocumentController%@.windowWillCloseNotifications:%@", self, w);

		RDocument *d = [self documentForWindow:w];
		SLog(@" - document for window: %@", d);

		// if no document is associated wit this window, check whether this is a Quartz Cocoa window
		if (!d && [[(NSObject*)[w delegate] className] isEqualToString:@"QuartzCocoaView"]) {
			d = (RDocument*)[[QuartzCocoaDocument alloc] initWithWindow:w];
			[d makeWindowControllers];
			[[NSDocumentController sharedDocumentController] addDocument:d];
			[d release];
			SLog(@" - added dummy Quartz Cocoa window document");
		}
		
		d = [self documentForWindow:w];
		SLog(@" - document:%@ of type %@", d, [d fileType]);

		// make the next window of the same docType the key window and order it out;
		// if no window of the same docType is found make the RConsole the key window
		NSWindow *nextWindow = [self findNextWindowForDocType:[d fileType]];

		// if document hasREditFlag set focus back to RConsole AND if sanety check fails
		BOOL reditcheck = ([[self currentDocument] respondsToSelector:@selector(hasREditFlag)]);

		if((!reditcheck || (reditcheck && ![[self currentDocument] hasREditFlag])) 
				&& nextWindow && nextWindow != w) {
			SLog(@" - makeKeyWindow with title %@ and type %@", [nextWindow title], [d fileType]);
		} else {
			SLog(@" - makeKeyWindow RConsole");
			nextWindow = [[RController sharedController] window];
		}

		[NSApp removeWindowsItem: w];
		[nextWindow makeKeyAndOrderFront:nil];

	}
}

- (NSWindow*)findLastWindowForDocType:(NSString*)aType
{
	return [self findWindowForDocType:aType getLast:YES];
}

- (NSWindow*)findNextWindowForDocType:(NSString*)aType
{
	return [self findWindowForDocType:aType getLast:NO];
}

- (NSWindow*)findWindowForDocType:(NSString*)aType getLast:(BOOL)getLast;
{
	SLog(@"RDocumentController%@.findWindowForDocType: %@ getLast: %d", self, aType, getLast);

	BOOL getLastOrg = getLast;
	NSArray *appWindows = [NSApp orderedWindows]; // Get all windows
	int i;
	Class searchClass = nil;

	// set search class due to window's delegates
	if([aType isEqualToString:ftRSource])
		searchClass = NSClassFromString(@"RDocumentWinCtrl");
	else if([aType isEqualToString:ftQuartz])
		searchClass = NSClassFromString(@"QuartzCocoaView");

	// bail by returning main window if no search class defined
	if(!searchClass) {
		SLog(@" - passed docType unknown, return console window");
		return [[RController sharedController] window];
	}

	// loop through windows to find first/next window for desired docType
	for(i=0; i<[appWindows count]; i++) {
		id win = [appWindows objectAtIndex:i];
		if([win isVisible] && [[win delegate] isKindOfClass:searchClass]) {
			if(getLast) {
				SLog(@" - found window with title '%@'", [win title]);
				return win;
			}
			getLast = YES;
		}
	}

	// if no window was found for docType
	// try to get the last window
	getLast = getLastOrg;
	for(i=0; i<[appWindows count]; i++) {
		id win = [appWindows objectAtIndex:i];
		if([win isVisible]) {
			if(getLast) {
				SLog(@" - found window with title '%@'", [win title]);
				return win;
			}
			getLast = YES;
		}
	}

	// bail by returning main window
	SLog(@" - no window found for passed docType, return console window");
	return [[RController sharedController] window];

}

- (NSString *)defaultType
{
	return activeFileType;
}

- (IBAction)newRdDocument:(id)sender
{
	BOOL useInternalEditor = [Preferences flagForKey:internalOrExternalKey withDefault: YES];
	if (!useInternalEditor) {
		[self invokeExternalForFile: @""];
		return;
	}
	
	activeFileType = ftRdDoc;
	[super newDocument:sender];
}


- (IBAction)newDocument:(id)sender {
	BOOL useInternalEditor = [Preferences flagForKey:internalOrExternalKey withDefault: YES];
	if (!useInternalEditor) {
		[self invokeExternalForFile: @""];
		return;
	}
	activeFileType = ftRSource;
	[super newDocument:sender];
}

- (void)noteNewRecentDocument:(id)doc
{

	// suppress showing of doc in recent files if doc was called via REdit
	if([[RController sharedController] isREditMode]) return;

	[super noteNewRecentDocument:doc];

}

- (Class)documentClassForType:(NSString *)documentTypeName
{
	return [RDocument class];
}

- (id) openDocumentWithContentsOfURL:(NSURL *)absoluteURL display:(BOOL)displayDocument error:(NSError **)theError {
	if (absoluteURL == nil) {
		SLog(@"RDocumentController.openDocumentWithContentsOfURL with null URL. Nothing to do.");
		return nil;
	}
	NSString *aFile = [[absoluteURL path] stringByExpandingTildeInPath];
	SLog(@"RDocumentController.openDocumentWithContentsOfURL: %@", aFile);
	int res = [[RController sharedController] isImageData: aFile];
	if (res == 0 ) {
		SLog(@" - detected save image, invoking load instead of the editor");
		[[RController sharedController] sendInput: [NSString stringWithFormat:@"load(\"%@\")", aFile]];
		return nil;
	}

	BOOL useInternalEditor = [Preferences flagForKey:internalOrExternalKey withDefault: YES];
	if (!useInternalEditor) {
		SLog(@" - external editor is enabled, passing over to invokeExternalForFile");
		[self invokeExternalForFile:aFile];
		return nil;
	}			

	SLog(@" - call super -> openDocumentWithContentsOfURL: %@", aFile);
	RDocument *doc = [super openDocumentWithContentsOfURL:absoluteURL display:displayDocument error:theError];
	return doc;
}

- (void) invokeExternalForFile:(NSString*)aFile
{
	NSString *externalEditor = [NSString stringWithFormat:@"\"%@\"", [Preferences stringForKey:externalEditorNameKey withDefault: @"TextEdit"]];
	NSString *cmd;
	BOOL editorIsApp = [Preferences flagForKey:appOrCommandKey withDefault: YES];

	if (!aFile) aFile=@"";
	if (editorIsApp) {
		cmd = [@"open -a " stringByAppendingString:externalEditor];
		if (![aFile isEqualToString:@""])
			cmd = [cmd stringByAppendingString: [NSString stringWithFormat:@" \"%@\"", aFile]];
	} else {
		cmd = externalEditor; 
		if (![aFile isEqualToString:@""])
			cmd = [cmd stringByAppendingString: [NSString stringWithString: [NSString stringWithFormat:@" \"%@\"", aFile]]];
	}
	SLog(@" - call external: \"%@\"", cmd);
	system([cmd UTF8String]);	
}

/**
 * Loads the "encoding" accessory view used in save panels. 
 */
+ (NSView *)encodingAccessory:(NSStringEncoding)encoding includeDefaultEntry:(BOOL)includeDefaultItem encodingPopUp:(NSPopUpButton **)popup
{
	OpenSaveAccessoryOwner *owner = [[[OpenSaveAccessoryOwner alloc] init] autorelease];
	// Rather than caching, load the accessory view everytime, as it might appear in multiple panels simultaneously.
	if (![NSBundle loadNibNamed:@"EncodingPopupView" owner:owner])  {
		NSLog(@"Failed to load EncodingPopupView.xib");
		NSBeep();
		return nil;
	}
	if (popup) *popup = owner->encodingPopUp;
	[[RChooseEncodingPopupAccessory sharedInstance] setupPopUpCell:[owner->encodingPopUp cell] selectedEncoding:encoding withDefaultEntry:includeDefaultItem];
	[owner->label setStringValue:[NSString stringWithFormat:@"%@:", NLS(@"Encoding")]];
	return [owner->accessoryView autorelease];
}

@end
