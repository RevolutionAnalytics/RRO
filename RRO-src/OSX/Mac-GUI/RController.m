/*
 *  R.app : a Cocoa front end to: "R A Computer Language for Statistical Data Analysis"
 *  
 *  R.app Copyright notes:
 *                     Copyright (C) 2004-14  The R Foundation
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
 *
 *  $Id: RController.m 7107 2016-01-18 17:31:28Z urbaneks $
 */


#import "RGUI.h"
#include <R.h>
#include <Rinternals.h>
#include <R_ext/Parse.h>
//#include <Fileio.h>
#include <Rinterface.h>
#include <langinfo.h>
#include <locale.h>
#include <R_ext/QuartzDevice.h>

#import <sys/fcntl.h>
#import <sys/select.h>
#import <sys/types.h>
#import <sys/time.h>
#import <sys/wait.h>
#import <signal.h>
#import <unistd.h>
#import "RController.h"
#import "REngine/Rcallbacks.h"
#import "REngine/REngine.h"
#import "RDocumentWinCtrl.h"
#import "Tools/Authorization.h"
#import "RChooseEncodingPopupAccessory.h"
#import "NSTextView_RAdditions.h"
#import "RWindow.h"

#import "Preferences.h"
#import "SearchTable.h"

// R defines "error" which is deadly as we use open ... with ... error: where error then gets replaced by Rf_error
#ifdef error
#undef error
#endif

// size of the console output cache buffer
#define DEFAULT_WRITE_BUFFER_SIZE 32768
// high water-mark of the buffer - it's [length - x] where x is the smallest possible size to be flushed before a new string will be split.
#define writeBufferHighWaterMark  (DEFAULT_WRITE_BUFFER_SIZE-4096)
// low water-mark of the buffer - if less than the water mark is available then the buffer will be flushed
#define writeBufferLowWaterMark   2048

#define kR_WebViewSearchWindowHeight 27

/*  RController.m: main GUI code originally based on Simon Urbanek's work of embedding R in Cocoa app (RGui?)
The Code and File Completion is due to Simon U.
History handler is due to Simon U.
*/

typedef struct {
	ParseStatus    status;
	int            prompt_type;
	int            browselevel;
	unsigned char  buf[1025];
	unsigned char *bufp;
} R_ReplState;

extern R_ReplState state;

void run_Rmainloop(void); // from Rinit.c
extern void RGUI_ReplConsole(SEXP rho, int savestack, int browselevel); // from Rinit.c
extern int RGUI_ReplIteration(SEXP rho, int savestack, int browselevel, R_ReplState *state);

// from Defn.h

int R_SetOptionWidth(int);

#import "RController.h"
#import "Tools/CodeCompletion.h"
#import "Tools/FileCompletion.h"
#import "HelpManager.h"
#import "RDocument.h"
#import "PackageManager.h"
#import "DataManager.h"
#import "PackageInstaller.h"
#import "WSBrowser.h"
#import "HelpManager.h"
#import "RDocumentController.h"
#import "SelectList.h"
#import "VignettesController.h"

#import <unistd.h>
#import <sys/fcntl.h>

static RController* sharedRController;

static SEL _nextEventSel;
static SEL _sendEventSel;
static SEL _doProcessSel;

static inline const char* NSStringUTF8String(NSString* self) 
{
	typedef const char* (*SPUTF8StringMethodPtr)(NSString*, SEL);
	static SPUTF8StringMethodPtr SPNSStringGetUTF8String;
	if (!SPNSStringGetUTF8String) SPNSStringGetUTF8String = (SPUTF8StringMethodPtr)[NSString instanceMethodForSelector:@selector(UTF8String)];
	const char* to_return = SPNSStringGetUTF8String(self, @selector(UTF8String));
	return to_return;
}

#if MAC_OS_X_VERSION_MIN_REQUIRED < MAC_OS_X_VERSION_10_7
// declare the following methods to avoid compiler warnings
@interface NSWindow (SuppressWarnings)
- (void)toggleFullScreen:(id)sender;
@end
#endif


@interface R_WebViewSearchWindow : NSWindow
@end

@interface NSDocumentControllerWithAutosave : NSDocumentController
- (void)_autoreopenDocuments;
@end

@implementation R_WebViewSearchWindow
- (BOOL)canBecomeKeyWindow { return YES; }
- (BOOL)acceptsMouseMovedEvents { return YES; }
@end

@interface NSApplication (ScriptingSupport)
- (id)handleDCMDCommand:(NSScriptCommand*)command;
@end

@implementation NSApplication (ScriptingSupport)
- (id)handleDCMDCommand:(NSScriptCommand*)command
{
//	if (![[[RController sharedController] getRConsoleWindow] isKeyWindow]) {
//		[[[RController sharedController] getRConsoleWindow] makeKeyWindow];
//		SLog(@" RConsole set to key window");
//	}
    NSDictionary *args = [command evaluatedArguments];
    NSString *cmd = [args objectForKey:@""];
    if (!cmd || [cmd isEqualToString:@""])
        return [NSNumber numberWithBool:NO];
	[[RController sharedController] sendInput: cmd];
	/* post an event to wake the event loop in order to process the command */
	int wn = [[[RController sharedController] getRConsoleWindow] windowNumber];
//	SLog(@"Key window number %d", wn);
	[NSApp postEvent:[NSEvent otherEventWithType: NSApplicationDefined 
										location: (NSPoint){0,0} modifierFlags: 0 timestamp: 0
									windowNumber: wn context: NULL subtype: 0 data1: 0 data2: 0
		] atStart: YES];
	return [NSNumber numberWithBool:YES];
}
@end

@implementation RController

- (id) init {
	self = [super init];

	runSystemAsRoot = NO;
	toolbar = nil;
	toolbarStopItem = nil;
	rootFD = -1;
	childPID = 0;
	RLtimer = nil;
	lastShownWD = nil;
	busyRFlag = YES;
	appLaunched = NO;
	terminating = NO;
	processingEvents = NO;
	breakPending = NO;
	isREditMode = NO;
	ignoreMagnifyingEvent = NO;
	outputPosition = promptPosition = committedLength = lastCommittedLength = 0;
	consoleInputQueue = [[NSMutableArray alloc] initWithCapacity:8];
	currentConsoleInput = nil;
	forceStdFlush = NO;
	writeBufferLen = DEFAULT_WRITE_BUFFER_SIZE;
	writeBufferPos = writeBuffer = (char*) malloc(writeBufferLen);
    writeBufferType = 0;
	readConsTransBufferSize = 1024; // initial size - will grow as needed
	readConsTransBuffer = (char*) malloc(readConsTransBufferSize);
	textViewSync = [[NSString alloc] initWithString:@"consoleTextViewSemahphore"];
	searchInWebViewWindow = nil;
	
	consoleColorsKeys = [[NSArray alloc] initWithObjects:
		backgColorKey, inputColorKey, outputColorKey, promptColorKey,
		stderrColorKey, stdoutColorKey, rootColorKey, selectionColorKey, nil];
	defaultConsoleColors = [[NSArray alloc] initWithObjects: // default colors
		[NSColor whiteColor], [NSColor blueColor], [NSColor blackColor], [NSColor purpleColor],
		[NSColor redColor], [NSColor grayColor], [NSColor purpleColor], [NSColor colorWithCalibratedRed:0.71f green:0.835f blue:1.0f alpha:1.0f], nil];
	consoleColors = [defaultConsoleColors mutableCopy];

	filteredHistory = nil;
	
	_nextEventSel = @selector(nextEventMatchingMask:untilDate:inMode:dequeue:);
	_sendEventSel = @selector(sendEvent:);
	_doProcessSel = @selector(doProcessEvents:);

	_nextEventImp = [NSApp methodForSelector:_nextEventSel];
	_sendEventImp = [NSApp methodForSelector:_sendEventSel];
	_doProcessImp = [self methodForSelector:_doProcessSel];

	specialCharacters = [[NSCharacterSet characterSetWithCharactersInString:@"\r\b\a"] retain];

	[[NSNotificationCenter defaultCenter] addObserver:self 
											 selector:@selector(windowWillCloseNotifications:) 
												 name:NSWindowWillCloseNotification 
											   object:nil];

	[[NSNotificationCenter defaultCenter] addObserver:self 
						 selector:@selector(helpSearchTypeChanged) 
						     name:@"HelpSearchTypeChanged" 
						   object:nil];

	lastFunctionForHint = [[NSString stringWithString:@""] retain];
	lastFunctionHintText = nil;
	appSupportPath = nil;

	return self;

}

- (void) setRootFlag: (BOOL) flag
{
	if (!flag) removeRootAuthorization();
	runSystemAsRoot=flag;
	
	{
		NSArray * ia = [toolbar items];
		int l = [ia count], i=0;
		while (i<l) {
			NSToolbarItem *ti = [ia objectAtIndex:i];
			if ([[ti itemIdentifier] isEqual:AuthenticationToolbarItemIdentifier]) {
				[ti setImage: [NSImage imageNamed: flag?@"lock-unlocked":@"lock-locked"]];
				break;
			}
			i++;
		}
	}
}

- (BOOL) getRootFlag { return runSystemAsRoot; }

- (void) setRootFD: (int) fd {
	rootFD=fd;
}

- (NSFont*) currentFont
{
	return ([consoleTextView font]) ? [consoleTextView font] : [Preferences unarchivedObjectForKey:RConsoleDefaultFont withDefault:[NSFont fontWithName:@"Monaco" size:11]];
}

/**
 * AppleScript handler for kAEOpenDocuments
 * before NSApplication is ready, we need to catch any odoc events that arrive, otherwise we loose them
 */ 
- (void)handleAppleEventAEOpenDocuments:(NSAppleEventDescriptor *)event withReplyEvent:(NSAppleEventDescriptor *)replyEvent
{

	SLog(@"RController.handleAppleEvent is called");

	NSAppleEventDescriptor *openEvents = [event paramDescriptorForKeyword:keyDirectObject];

	if(!openEvents) {
		NSLog(@" - no open events found");
		return;
	}

	int docs = [openEvents numberOfItems];
	int i = 0;
	SLog(@" - %d files to open", docs);
	while (i <= docs) {
		NSAppleEventDescriptor *d = [openEvents descriptorAtIndex:i];
		if (d) {
			CFURLRef url;
			d = [d coerceToDescriptorType:typeFSRef];
			url = CFURLCreateFromFSRef(kCFAllocatorDefault, [[d data] bytes]);
			if (url) {
				NSString *pathName = (NSString *)CFURLCopyFileSystemPath(url, kCFURLPOSIXPathStyle);
				[pathName autorelease];
				if (!appLaunched) {
					[pendingDocsToOpen addObject:pathName];
					SLog(@"    appending %@ to open after launching", pathName);
				} else {
					SLog(@"    openFile %@", pathName);
					[self application:NSApp openFile:pathName];
				}
				CFRelease(url);
			}
		}
		i++;
	}
}


- (void) awakeFromNib {

	SLog(@"RController.awakeFromNib");

	// Add full screen support for MacOSX Lion or higher
	[RConsoleWindow setCollectionBehavior:[RConsoleWindow collectionBehavior] | NSWindowCollectionBehaviorFullScreenPrimary];

	char *args[5]={ "R", "--no-save", "--no-restore-data", "--gui=aqua", 0 };

	requestSaveAction = nil;
	sharedRController = self;
	currentConsoleWidth = -1;
	pendingDocsToOpen = [[NSMutableArray alloc] init];

	NSFileManager *fm = [NSFileManager defaultManager];

	// Register AppleScript handler for kAEOpenDocuments eventID
	[[NSAppleEventManager sharedAppleEventManager] setEventHandler:self 
													   andSelector:@selector(handleAppleEventAEOpenDocuments:withReplyEvent:) 
													 forEventClass:kCoreEventClass 
														andEventID:kAEOpenDocuments];

	[WDirView setToolTip:[NSString stringWithFormat:@"%@ (⌘D)", [WDirView stringValue]]];

	[consoleTextView setConsoleMode: YES];
	[consoleTextView setEditable:YES];
	[consoleTextView setFont:[Preferences unarchivedObjectForKey:RConsoleDefaultFont withDefault:[NSFont fontWithName:@"Monaco" size:11]]];
	[consoleTextView setDrawsBackground:NO];
	[[consoleTextView enclosingScrollView] setDrawsBackground:NO];
	NSMutableDictionary *attr = [NSMutableDictionary dictionary];
	[attr setDictionary:[consoleTextView selectedTextAttributes]];
	[attr setObject:[Preferences unarchivedObjectForKey:selectionColorKey withDefault:[NSColor colorWithCalibratedRed:0.71f green:0.835f blue:1.0f alpha:1.0f]] forKey:NSBackgroundColorAttributeName];
	[consoleTextView setSelectedTextAttributes:attr];
	[consoleTextView setNeedsDisplayInRect:[consoleTextView visibleRect]];

	NSLayoutManager *lm = [[consoleTextView layoutManager] retain];
#if MAC_OS_X_VERSION_MIN_REQUIRED >= MAC_OS_X_VERSION_10_5
	[lm setAllowsNonContiguousLayout:YES];
#endif
	NSTextStorage *origTS = [[consoleTextView textStorage] retain];
	textStorage = [[RConsoleTextStorage alloc] init];
	[origTS removeLayoutManager:lm];
	[textStorage addLayoutManager:lm];
	[lm release];
	[origTS release];

	[consoleTextView setTextColor:[consoleColors objectAtIndex:iInputColor]];
	[consoleTextView setContinuousSpellCheckingEnabled:NO]; // force 'no spell checker'
	[[consoleTextView textStorage] setDelegate:self];


	RTextView_autoCloseBrackets = [Preferences flagForKey:kAutoCloseBrackets withDefault:YES];

	[self setupToolbar];
	[RConsoleWindow setOpaque:NO]; // Needed so we can see through it when we have clear stuff on top
	[RConsoleWindow setBackgroundColor:[defaultConsoleColors objectAtIndex:iBackgroundColor]]; // we need this, because "update" doesn't touch the color if it's equal - and by default the window has *no* background - not even the default one, so we bring it in sync
	[RConsoleWindow setDocumentEdited:YES];

	SLog(@" - working directory setup timer");
	WDirtimer = [NSTimer scheduledTimerWithTimeInterval:0.5
												 target:self
											   selector:@selector(showWorkingDir:)
											   userInfo:0
												repeats:YES];


	SLog(@" - load preferences");
	[self updatePreferences]; // first update, then add self
	[[Preferences sharedPreferences] addDependent: self];

	SLog(@" - init R_LIBS");	
	{ // first initialize R_LIBS if necessary
		NSString *prefStr = [Preferences stringForKey:miscRAquaLibPathKey withDefault:nil];
		BOOL flag = !isAdmin(); // the default is YES for users and NO for admins
		if (prefStr)
			flag=[prefStr isEqualToString: @"YES"];
		if (flag) {
			char *cRLIBS = getenv("R_LIBS");
			NSString *addPath = [[NSString stringWithFormat:@"~/Library/R/%@/library", Rapp_R_version_short] stringByExpandingTildeInPath];
			if (![fm fileExistsAtPath:addPath]) { // make sure the directory exists

//				[fm createDirectoryAtPath:[@"~/Library/R" stringByExpandingTildeInPath] attributes:nil];
//				[fm createDirectoryAtPath:[[NSString stringWithFormat:@"~/Library/R/%@", Rapp_R_version_short] stringByExpandingTildeInPath] attributes:nil];
//              [fm createDirectoryAtPath:addPath attributes:nil];

                NSError *err = nil;
                [fm createDirectoryAtPath:addPath withIntermediateDirectories:YES attributes:nil error:&err];
                if(err != nil) {
                    NSBeep();
                    NSLog(@"The directory '%@' couldn't be created!", addPath);
                }
            }
			if (cRLIBS && *cRLIBS)
				addPath = [NSString stringWithFormat: @"%s:%@", cRLIBS, addPath];
			setenv("R_LIBS", [addPath UTF8String], 1);
			SLog(@" - setting R_LIBS=%s", [addPath UTF8String]);
		}
	}
	SLog(@" - set APP VERSION (%s) and REVISION (%@)", R_GUI_VERSION_STR,
		 [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleVersion"]);
	setenv("R_GUI_APP_VERSION", R_GUI_VERSION_STR, 1);
	setenv("R_GUI_APP_REVISION", [(NSString*)[[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleVersion"] UTF8String], 1);
	
	SLog(@" - set R home");
	if (!getenv("R_HOME")) {
		NSBundle *rfb = [NSBundle bundleWithIdentifier:@"org.r-project.R-framework"];
		if (!rfb) {
			SLog(@" * problem: R_HOME is not set and I can't find the framework bundle");
			if ([fm fileExistsAtPath:@"/Library/Frameworks/R.framework/Resources/bin/R"]) {
				SLog(@" * I'm being desperate and I found R at /Library/Frameworks/R.framework - so I'll use it, wish me luck");
				setenv("R_HOME", "/Library/Frameworks/R.framework/Resources", 1);
			} else
				SLog(@" * I didn't even find R framework in the default location, I'm giving up - you're on your own");
		} else {
			SLog(@"   %s", [[rfb resourcePath] UTF8String]);
			setenv("R_HOME", [[rfb resourcePath] UTF8String], 1);
		}
	}
	if (getenv("R_HOME"))
		home = [[NSString alloc] initWithUTF8String:getenv("R_HOME")];
	else
		home = [[NSString alloc] initWithString:@""];

	{
		char tp[1024];
		/* since 2.2.0 those are set in the R shell script, so we need to set them as well */
		/* FIXME: possible buffer-overflow attack by over-long R_HOME */
		if (!getenv("R_INCLUDE_DIR")) {
			strcpy(tp, getenv("R_HOME")); strcat(tp, "/include"); setenv("R_INCLUDE_DIR", tp, 1);
		}
		if (!getenv("R_SHARE_DIR")) {
			strcpy(tp, getenv("R_HOME")); strcat(tp, "/share"); setenv("R_SHARE_DIR", tp, 1);
		}
		if (!getenv("R_DOC_DIR")) {
			strcpy(tp, getenv("R_HOME")); strcat(tp, "/doc"); setenv("R_DOC_DIR", tp, 1);
		}
	}

#if defined __i386__
#define arch_lib_nss @"/lib/i386"
#define arch_str "/i386"
#elif defined __x86_64__
#define arch_lib_nss @"/lib/x86_64"
#define arch_str "/x86_64"
/* not used in R >= 2.15.2, so remove eventually */
#elif defined __ppc__
#define arch_lib_nss @"/lib/ppc"
#define arch_str "/ppc"
#elif defined __ppc64__
#define arch_lib_nss @"/lib/ppc64"
#define arch_str "/ppc64"
#endif

#ifdef arch_lib_nss
	if (!getenv("R_ARCH")) {
		if ([fm fileExistsAtPath:[[NSString stringWithUTF8String:getenv("R_HOME")] stringByAppendingString: arch_lib_nss]])
			setenv("R_ARCH", arch_str, 1);
	}
#else
#warning "Unknown architecture, R_ARCH won't be set automatically."
#endif
	
	/* setup LANG variable to match the system locale based on user's CFLocale */
	SLog(@" - set locale");
	if ([Preferences stringForKey:@"force.LANG"]) {
		const char *ls = [[Preferences stringForKey:@"force.LANG"] UTF8String];
		if (*ls) {
			setenv("LANG", ls, 1);
			SLog(@" - force.LANG present, setting LANG to \"%s\"", ls);
		} else
			SLog(@" - force.LANG present, but empty. LANG won't be set at all.");
	} else if ([Preferences flagForKey:@"ignore.system.locale"]==YES) {
		setenv("LANG", "en_US.UTF-8", 1);
		SLog(@" - ignore.system.locale is set to YES, using en_US.UTF-8");
	} else {
		char cloc[64];
		char *c = getenv("LANG");
		cloc[63]=0;
		if (c)
			strcpy(cloc, c);
		else {
			CFLocaleRef lr = CFLocaleCopyCurrent();
			CFStringRef ls = CFLocaleGetIdentifier(lr);
			*cloc=0;
			if (ls) {
				NSString *lss = (NSString*)ls;
				NSRange atr = [lss rangeOfString:@"@"];
				SLog(@"   CFLocaleGetIdentifier=\"%@\"", ls);
				if (atr.location != NSNotFound) {
					lss = [lss substringToIndex:atr.location];
					SLog(@"   - it contains @, stripped to \"%@\"", lss);
				}
				strncpy(cloc, [lss UTF8String], 63);
			}
			if (! *cloc) {
				SLog(@"   CFLocaleGetIdentifier is empty, falling back to en_US.UTF-8");
				strcpy(cloc,"en_US.UTF-8");
			}
			if (lr) CFRelease(lr);
		}
			
		if (!strchr(cloc,'.'))
			strcat(cloc,".UTF-8");
		setenv("LANG", cloc, 1);
		SLog(@" - setting LANG=%s", getenv("LANG"));
	}

	BOOL noReenter = [Preferences flagForKey:@"REngine prevent reentrance"];
	if (noReenter == YES) preventReentrance = YES;

	SLog(@" - init R");
	[[[REngine alloc] initWithHandler:self arguments:args] setCocoaHandler:self];

	/* set save action */
	[[REngine mainEngine] setSaveAction:[Preferences stringForKey:saveOnExitKey withDefault:@"ask"]];
	[[REngine mainEngine] disableRSignalHandlers:[Preferences flagForKey:@"Disable R signal handlers" withDefault:
#ifdef DEBUG_RGUI
		YES
#else
		NO
#endif
		]];

	SLog(@" - other widgets");

	hist=[[History alloc] init];

    BOOL WantThread = ([Preferences flagForKey:@"Redirect stdout/err"] != NO);
	SLog(@" - setup stdout/err grabber");
	if (WantThread){ // re-route the stdout to our own file descriptor and use ConnectionCache on it
		int pfd[2];
		pipe(pfd);
		dup2(pfd[1], STDOUT_FILENO);
		close(pfd[1]);
        
		stdoutFD=pfd[0];

		pipe(pfd);
#ifndef PLAIN_STDERR
		if ([Preferences flagForKey:@"Ignore stderr"] != YES) {
			dup2(pfd[1], STDERR_FILENO);
			close(pfd[1]);
		}
#endif

		stderrFD=pfd[0];

		[self addConnectionLog];
	}
	
	SLog(@" - set cwd and load history");
	[historyView setDoubleAction: @selector(historyDoubleClick:)];

	[fm changeCurrentDirectoryPath: [[Preferences stringForKey:initialWorkingDirectoryKey withDefault:@"~"] stringByExpandingTildeInPath]];
	if ([Preferences flagForKey:importOnStartupKey withDefault:YES]) {
		[self doLoadHistory:nil];
	}

	SLog(@" - awake is done");

}

- (NSString*) home
{
	return home;
}

- (NSString*) currentWorkingDirectory
{
	return [[WDirView stringValue] stringByExpandingTildeInPath];
}

-(void) applicationDidFinishLaunching: (NSNotification *)aNotification
{

	NSString *fname = nil;
	SLog(@"RController:applicationDidFinishLaunching");
	SLog(@" - clean up and flush console");
	[self flushROutput];
	
	RSEXP *xPT = [[REngine mainEngine] evaluateString:@".Platform$pkgType"];
	if (xPT) {
		NSString *pkgType = [xPT string];
		SLog(@" - pkgType in this R: \"%@\"", pkgType);
		if (pkgType) [[PackageInstaller sharedController] setPkgType:pkgType];
		[xPT release];
	}
		
	SLog(@" - setup notification and timers");
	[[NSNotificationCenter defaultCenter] 
		addObserver:self
		   selector:@selector(RConsoleDidResize:)
			   name:NSWindowDidResizeNotification
			 object: RConsoleWindow];

	timer = [NSTimer scheduledTimerWithTimeInterval:0.05
											 target:self
										   selector:@selector(otherEventLoops:)
										   userInfo:0
											repeats:YES];
	Flushtimer = [NSTimer scheduledTimerWithTimeInterval:0.5
												  target:self
												selector:@selector(flushTimerHook:)
												userInfo:0
												 repeats:YES];
	
	// once we're ready with the doc transition, the following will actually fire up the cconsole window
	//[[NSDocumentController sharedDocumentController] openUntitledDocumentOfType:@"Rcommand" display:YES];
	
	fname = [[[[NSFileManager defaultManager] currentDirectoryPath] stringByAppendingString: @"/.RData"] stringByExpandingTildeInPath];
	if (([pendingDocsToOpen count] == 0) && 
		([[NSFileManager defaultManager] fileExistsAtPath: fname])) {
		[[REngine mainEngine] executeString: [NSString stringWithFormat:@"load(\"%@\")", fname]];
		[self handleWriteConsole: [NSString stringWithFormat:@"%@%@]\n", NLS(@"[Workspace restored from "), fname]];
		SLog(@"RController.applicationDidFinishLaunching - load workspace %@", fname);
	}
	fname = [[Preferences stringForKey:historyFileNamePathKey withDefault: @".Rapp.history"] stringByExpandingTildeInPath];
	if ([Preferences flagForKey:importOnStartupKey withDefault:YES] && ([[NSFileManager defaultManager] fileExistsAtPath: fname])) {
		NSString *fullfname = [NSString stringWithString:fname];
		if ([fname characterAtIndex:0] != '/') {
			fullfname = [[[[[NSFileManager defaultManager] currentDirectoryPath] 
				stringByAppendingString:@"/"] stringByAppendingString: fname]
				stringByExpandingTildeInPath];
		}
		[self handleWriteConsole: [NSString stringWithFormat:@"%@%@]\n\n", NLS(@"[History restored from "), fullfname]];
		SLog(@"RController.applicationDidFinishLaunching - load history file %@", fname);
	}
    
	SLog(@"RController.openDocumentsPending: process pending 'odoc' events");
	if ([pendingDocsToOpen count] > 0) {
		NSEnumerator *enumerator = [pendingDocsToOpen objectEnumerator];
		NSString *fileName;
		SLog(@" - %d documents to open", [pendingDocsToOpen count]);
		while ((fileName = (NSString*) [enumerator nextObject]))
			[self application:NSApp openFile:fileName];
		[pendingDocsToOpen removeAllObjects];
	}
	
	[[REngine mainEngine] executeString:@"if (exists('.First') && is.function(.First) && !identical(.First, .__RGUI__..First)) .First()"];

	SLog(@" - set Quartz preferences (if necessary)");
	BOOL flag=[Preferences flagForKey:useQuartzPrefPaneSettingsKey withDefault: NO];
	if (flag) {
		NSString *qWidth = [Preferences stringForKey:quartzPrefPaneWidthKey withDefault: @"5"];
		NSString *qHeight = [Preferences stringForKey:quartzPrefPaneHeightKey withDefault: @"5"];
		NSString *qDPI = [Preferences stringForKey:quartzPrefPaneDPIKey withDefault: @""];
		[[REngine mainEngine] executeString:[NSString stringWithFormat:@"quartz.options(width=%@,height=%@,dpi=%@)", qWidth, qHeight, ([qDPI length] == 0) ? @"NA_real_" : qDPI]];
	}
	
	appLaunched = YES;
	[self setStatusLineText:@""];

	{
		// check locale
		RSEXP * x = [[REngine mainEngine] evaluateString:@"Sys.getlocale()"];
		if (x) {
			NSString *s = [x string];
			if (s) {
				NSRange r = [s rangeOfString:@"utf" options:NSCaseInsensitiveSearch];
				if (r.location == NSNotFound) {
					[self writeConsoleDirectly:NLS(@"WARNING: You're using a non-UTF8 locale, therefore only ASCII characters will work.\nPlease read R for Mac OS X FAQ (see Help) section 9 and adjust your system preferences accordingly.\n") withColor:[NSColor redColor]];
				}
			}
			[x release];
		}
	}

	[self updateReInterpretEncodingMenu];

	// for some reason Cocoa never calls this so we have to do it by hand even though it's internal
	// FIXME: check with OS X version to make sure this doesn't go away
	if ([[NSDocumentController sharedDocumentController] respondsToSelector:@selector(_autoreopenDocuments)]) {
		SLog(@" - re-open autosaved documents (if any)");
		[(NSDocumentControllerWithAutosave*)[NSDocumentController sharedDocumentController] _autoreopenDocuments];
	} else {
		SLog(@"WARNING: _autoreopenDocuments is not supported, cannot re-open autosaved documents");
	}

	[self performSelector:@selector(setOptionWidth:) withObject:nil afterDelay:0.0];

	SLog(@" - done, ready to go");

	// Register us as service provider
	[NSApp setServicesProvider:self];


	if (floor(NSAppKitVersionNumber) > NSAppKitVersionNumber10_6) {
		NSString *label = nil;
		if(([[self window] styleMask] & NSFullScreenWindowMask) == NSFullScreenWindowMask)
			label = NLS(@"Exit Full Screen");
		else
			label = NLS(@"Enter Full Screen");
		toggleFullScreenMenuItem = [[NSMenuItem alloc] initWithTitle:label action:@selector(toggleFullScreenMode:) keyEquivalent:@"f"];
		[toggleFullScreenMenuItem setKeyEquivalentModifierMask:(NSControlKeyMask | NSCommandKeyMask)];
		NSInteger m = [[NSApp mainMenu] numberOfItems]-2; // Window submenu
		[[[[NSApp mainMenu] itemAtIndex:m] submenu] insertItem:[NSMenuItem separatorItem] atIndex:0];
		[[[[NSApp mainMenu] itemAtIndex:m] submenu] insertItem:toggleFullScreenMenuItem atIndex:0];
	} else {
		// <TODO> folding only for >=10.7 - why?
		[[[[[NSApp mainMenu] itemAtIndex:3] submenu] itemAtIndex:9] setHidden:YES];
		[[[[[NSApp mainMenu] itemAtIndex:3] submenu] itemAtIndex:10] setHidden:YES];
	}

	SLog(@"RController.applicationDidFinishLaunching - show main window");

}

- (void)windowDidEnterFullScreen:(NSNotification *)notification
{
	if(toggleFullScreenMenuItem)
		[toggleFullScreenMenuItem setTitle:NLS(@"Exit Full Screen")];
}

- (void)windowDidExitFullScreen:(NSNotification *)notification
{
	if(toggleFullScreenMenuItem)
		[toggleFullScreenMenuItem setTitle:NLS(@"Enter Full Screen")];
}

-(IBAction)toggleFullScreenMode:(id)sender
{
#if !defined(MAC_OS_X_VERSION_10_7) || MAC_OS_X_VERSION_MAX_ALLOWED < MAC_OS_X_VERSION_10_7
	[[self window] toggleFullScreen:nil];
#endif
}

- (void)updateReInterpretEncodingMenu
{
	// Update Re-Open with Encoding submenu
	while ([reinterpretEncodingMenu numberOfItems]) [reinterpretEncodingMenu removeItemAtIndex:0];
	NSArray *enabledEncodings = [[RChooseEncodingPopupAccessory sharedInstance] enabledEncodings];
	NSInteger i;
	NSMenuItem *encItem;
	for(i=0; i<[enabledEncodings count]; i++) {
		encItem = [[NSMenuItem alloc] initWithTitle:[NSString localizedNameOfStringEncoding:[[enabledEncodings objectAtIndex:i] unsignedIntValue]] action:@selector(reInterpretDocument:) keyEquivalent:@""];
		[encItem setRepresentedObject:[enabledEncodings objectAtIndex:i]];
		[reinterpretEncodingMenu addItem:encItem];
		[encItem release];
	}
	[reinterpretEncodingMenu addItem:[NSMenuItem separatorItem]];
	encItem = [[NSMenuItem alloc] initWithTitle:NLS(@"Customize List…") action:@selector(customizeEncodingList:) keyEquivalent:@""];
	[reinterpretEncodingMenu addItem:encItem];
	[encItem release];
}

- (BOOL)appLaunched {
	return appLaunched;
}

-(void) addConnectionLog
{
	NSPort *port1;
	NSPort *port2;
	NSArray *portArray;
	NSConnection *connectionToTransferServer;
				
	port1 = [NSPort port];
	port2 = [NSPort port];
	connectionToTransferServer = [[NSConnection alloc] initWithReceivePort:port1 sendPort:port2];
	[connectionToTransferServer setRootObject:self];
	
	portArray = [NSArray arrayWithObjects:port2, port1, nil];
	[NSThread detachNewThreadSelector:@selector(readThread:)
							 toTarget:self
						   withObject:portArray];
}

- (void) readThread: (NSArray *)portArray
{
    NSAutoreleasePool *pool=[[NSAutoreleasePool alloc] init];
    NSConnection *connectionToController;
	RController *rc = nil;
	unsigned int bufSize=2048;
    char *buf=(char*) malloc(bufSize+16);
    int n=0, pib=0, flushMark=bufSize-(bufSize>>2);
	int bufFD=0;
    fd_set readfds;
	struct timeval timv;
	BOOL truncated = NO;
	
	timv.tv_sec=0; timv.tv_usec=300000; /* timeout */
	
	connectionToController = [NSConnection connectionWithReceivePort:[portArray objectAtIndex:0]
															sendPort:[portArray objectAtIndex:1]];
	
	rc = ((RController *)[connectionToController rootProxy]);

	// set timeouts only *after* the connection was established
	[connectionToController setRequestTimeout:2.0];
	[connectionToController setReplyTimeout:2.0];

    fcntl(stdoutFD, F_SETFL, O_NONBLOCK);
    fcntl(stderrFD, F_SETFL, O_NONBLOCK);
    while (1) {
		int selr=0, maxfd=stdoutFD;
		int validRootFD=-1;
        FD_ZERO(&readfds);
        FD_SET(stdoutFD,&readfds);
        FD_SET(stderrFD,&readfds); if(stderrFD>maxfd) maxfd=stderrFD;
		if (rootFD!=-1) {
			validRootFD = rootFD; // we copy it as to not run into threading problems when it is changed while we're in the middle of processing
			FD_SET(rootFD,&readfds);
			if(rootFD>maxfd) maxfd=rootFD;
		}
        selr=select(maxfd+1, &readfds, 0, 0, &timv);
        if (FD_ISSET(stdoutFD, &readfds)) {
			if (bufFD!=0 && pib>0) {
				@try{
					[rc writeLogsWithBytes:buf length:pib type:bufFD];
					if (truncated) { [rc writeLogsWithBytes:"\n(WARNING: partial output only, ask package author to use Rprintf instead!)\n" length:-1 type:1]; truncated=NO; }
				} @catch(NSException *ex) {
					truncated = YES;
				}
				pib=0;
			}
			bufFD=0;
            while (pib<bufSize && (n=read(stdoutFD,buf+pib,bufSize-pib))>0)
				pib+=n;
			if (pib>flushMark) { // if we reach the flush mark, dump it
				@try{
					[rc writeLogsWithBytes:buf length:pib type:bufFD];
					if (truncated) { [rc writeLogsWithBytes:"\n(WARNING: partial output only, ask package author to use Rprintf instead!)\n" length:-1 type:1]; truncated=NO; }
				} @catch(NSException *ex) {
					truncated = YES;
				}
				pib=0;
            }
        } 
		if (FD_ISSET(stderrFD, &readfds)) {
			if (bufFD!=1 && pib>0) {
				@try {
					[rc writeLogsWithBytes:buf length:pib type:bufFD];
				} @catch(NSException *ex) {
				}				
				pib=0;
			}
			bufFD=1;
			while (pib<bufSize && (n=read(stderrFD,buf+pib,bufSize-pib))>0)
				pib+=n;
			if (pib>flushMark) { // if we reach the flush mark, dump it
				@try{
					[rc writeLogsWithBytes:buf length:pib type:bufFD];
				} @catch(NSException *ex) {
				}
				pib=0;
			}
		}
		if (validRootFD!=-1 && FD_ISSET(validRootFD, &readfds)) {
			if (bufFD!=2 && pib>0) {
				@try{
					[rc writeLogsWithBytes:buf length:pib type:bufFD];
				} @catch(NSException *ex) {
					truncated = YES;
				}
				pib=0;
			}
			bufFD=2;
			while (pib<bufSize && (n=read(validRootFD,buf+pib,bufSize-pib))>0)
				pib+=n;
			if (n==0 || pib>flushMark) { // if we reach the flush mark, dump it
				@try{
					[rc writeLogsWithBytes:buf length:pib type:bufFD];
				} @catch(NSException *ex) {
					truncated = YES;
				}
				pib=0;
			}
			if (n==0) rootFD=-1; // we indicate EOF on the rootFD by setting it to -1
		}
		if ((forceStdFlush || selr==0) && pib>0) { // dump also if we got a timeout
			@try{
				[rc writeLogsWithBytes:buf length:pib type:bufFD];
			} @catch(NSException *ex) {
				truncated = YES;
			}
			pib=0;
		}
    }
    free(buf);
	
    [pool release];
}

- (void) flushStdConsole
{
	fflush(stderr);
	fflush(stdout);
	forceStdFlush=YES;
}

- (void) addChildProcess: (pid_t) pid
{
	childPID=pid;
	if (pid>0 && toolbarStopItem) [toolbarStopItem setEnabled:YES];
}

- (void) rmChildProcess: (pid_t) pid
{
	childPID=0;
	if (!busyRFlag && toolbarStopItem) [toolbarStopItem setEnabled:NO];
	[self flushStdConsole];
}

- (void)ignoreMagnifyingEventTimer
{
	ignoreMagnifyingEvent = NO;
}

- (void) fontSizeChangedBy:(float)delta withSender:(id)sender
{

	SLog(@"RController - fontSizeChangedBy:%f", delta);

	NSFont *font;

	id firstResponder = [[NSApp keyWindow] firstResponder];

	// Check if first responder is a WebView
	if([[[firstResponder class] description] isEqualToString:@"WebHTMLView"]) {
		// Try to get the corresponding WebView
		id aWebFrameView = [[[firstResponder superview] superview] superview];
		if(aWebFrameView && [aWebFrameView respondsToSelector:@selector(webFrame)]) {
			WebView *aWebView = [[(WebFrameView*)aWebFrameView webFrame] webView];
			if(aWebView) {
				if(!ignoreMagnifyingEvent) {

					// delay font size changing for 200msecs
					ignoreMagnifyingEvent = YES;
					[self performSelector:@selector(ignoreMagnifyingEventTimer) withObject:nil afterDelay:0.2f];

					if(delta > 0)
						[aWebView makeTextLarger:sender];
					else if(delta < 0)
						[aWebView makeTextSmaller:sender];
				}
			}
		}
	}
	// Change size for RConsole
	else if ([RConsoleWindow isKeyWindow]) {
		font = [[NSFontPanel sharedFontPanel] panelConvertFont:[NSUnarchiver unarchiveObjectWithData:[[NSUserDefaults standardUserDefaults] dataForKey:RConsoleDefaultFont]]];
		float s = [font pointSize];
		s = s + delta;
		font = [NSFont fontWithName:[font fontName] size:s];
		if(font) {
			[[NSUserDefaults standardUserDefaults] setObject:[NSArchiver archivedDataWithRootObject:font] forKey:RConsoleDefaultFont];
			[consoleTextView setFont:font];
			// Force to scroll view to cursor
			[consoleTextView scrollRangeToVisible:[consoleTextView selectedRange]];
		}
		[[consoleTextView textStorage] setFont:font];
		[self setOptionWidth:YES];
	}
	// Change size in R script windows
	else if ([firstResponder isKindOfClass:[RScriptEditorTextView class]]) {

		font = [[NSFontPanel sharedFontPanel] panelConvertFont:[NSUnarchiver unarchiveObjectWithData:[[NSUserDefaults standardUserDefaults] dataForKey:RScriptEditorDefaultFont]]];
		float s = [font pointSize];
		s = s + delta;
		font = [NSFont fontWithName:[font fontName] size:s];

		if(!font) return;

		if([firstResponder selectedRange].length ||[[[NSDocumentController sharedDocumentController] currentDocument] isRTF]) {
			// register font change for undo
			NSRange r = [firstResponder selectedRange];
			[firstResponder shouldChangeTextInRange:r replacementString:[[firstResponder string] substringWithRange:r]];
			[[firstResponder textStorage] addAttribute:NSFontAttributeName value:font range:r];
			if([firstResponder lineNumberingEnabled]) {
				[[[firstResponder enclosingScrollView] verticalRulerView] performSelector:@selector(refresh) withObject:nil afterDelay:0.0f];
			}
		} else {
			[[NSUserDefaults standardUserDefaults] setObject:[NSArchiver archivedDataWithRootObject:font] forKey:RScriptEditorDefaultFont];
			if([firstResponder lineNumberingEnabled]) {
				[[[firstResponder enclosingScrollView] verticalRulerView] performSelector:@selector(refresh) withObject:nil afterDelay:0.0f];
			}
		}
	}

}

-(IBAction) fontSizeBigger:(id)sender
{
	[self fontSizeChangedBy:1.0f withSender:sender];
}

-(IBAction) fontSizeSmaller:(id)sender
{
	[self fontSizeChangedBy:-1.0f withSender:sender];
}

-(IBAction) changeFontSize:(id)sender
{
	
}

-(IBAction) clearConsole:(id)sender {
	if (promptPosition > 0) {
		committedLength -= promptPosition;
		lastCommittedLength = committedLength;
		outputPosition = 0;
		[consoleTextView replaceCharactersInRange: NSMakeRange(0,promptPosition) withString:@""];
		promptPosition = 0;
	}
}

-(IBAction) activateSearchInHistory:(id)sender
{

	[HistoryDrawer open];
	// if currently nothing is selected jump to last row
	if(![[historyView selectedRowIndexes] count]) {
		NSInteger lastRowIndex = [self numberOfRowsInTableView:historyView]-1;
		[historyView reloadData];
		[historyView selectRowIndexes:[NSIndexSet indexSetWithIndex:lastRowIndex] byExtendingSelection:NO];
		[historyView scrollRowToVisible:lastRowIndex];
	}
	[[NSApp keyWindow] makeFirstResponder:historySearchField];

}

-(IBAction) searchInHistory:(id)sender
{

	if(filteredHistory) [filteredHistory release], filteredHistory = nil;

	NSString *pattern = [historySearchField stringValue];

	if(![pattern length]) {
		[historyView reloadData];
		return;
	}

	@try{
		NSPredicate *predicate = [NSPredicate predicateWithFormat:@"SELF MATCHES[c] %@", [NSString stringWithFormat:@".*%@.*", pattern]];
		filteredHistory = [[[hist entries] filteredArrayUsingPredicate:predicate] retain];
	}
	@catch(id ae) {
		filteredHistory = [[NSArray arrayWithObject:NLS(@"…invalid regular expression")] retain];
	}
	[historyView reloadData];

}

extern BOOL isTimeToFinish;

- (NSApplicationTerminateReply)applicationShouldTerminate:(NSApplication *)app {
	terminating = YES;

	if (![self windowShouldClose:self]) {
		terminating = NO;
		return NSTerminateCancel;
	}
	
	if(timer){
		[timer invalidate];
		timer = nil;
	}
	
	if(RLtimer){
		[RLtimer invalidate];
		RLtimer = nil;
	}
	
	if(Flushtimer){
		[Flushtimer invalidate];
		Flushtimer = nil;
	}
	
	if(WDirtimer){
		[WDirtimer invalidate];
		WDirtimer = nil;
	}
	
	return NSTerminateNow;
}


- (void) dealloc
{
	if(toggleFullScreenMenuItem) [toggleFullScreenMenuItem release];
	if(toolbarStopItem) [toolbarStopItem release];
	if(lastFunctionForHint) [lastFunctionForHint release];
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[[Preferences sharedPreferences] removeDependent:self];
	if(home) [home release];
	if(appSupportPath) [appSupportPath release];
	if(filteredHistory) [filteredHistory release], filteredHistory = nil;
	if(currentWebViewForFindAction) [currentWebViewForFindAction release];
	if(searchInWebViewWindow) [searchInWebViewWindow release], searchInWebViewWindow = nil;
	[defaultConsoleColors release];
	[consoleColors release];
	[consoleColorsKeys release];
	[textStorage release];
	[consoleInputQueue release];
	[pendingDocsToOpen release];
	[super dealloc];
}

- (void) flushTimerHook: (NSTimer*) source
{
	[self flushROutput];
}

- (void) flushROutput {
	if (writeBuffer != writeBufferPos) {
		[self writeConsoleDirectly:[NSString stringWithUTF8String:writeBuffer]
                         withColor:[consoleColors objectAtIndex:writeBufferType ? iErrorColor : iOutputColor]];
		writeBufferPos = writeBuffer;
	}
}

- (void) handleFlushConsole {
	[self flushROutput];
	[self flushStdConsole];
}

/* this writes R output to the Console window, but indirectly by using a buffer */
- (void) handleWriteConsole: (NSString*) txt withType: (int) oType {

	if (!txt) return;

	const char *s = NSStringUTF8String(txt);
    // NSLog(@"handleWriteConsole[%d(%d,%d)] %@", oType, writeBufferType, writeBufferPos - writeBuffer, txt);
	int sl = strlen(s);
	int fits = writeBufferLen - (writeBufferPos - writeBuffer) - 1;
	
	// let's flush the buffer if the new string is large and it would, but the buffer should be occupied
    // also flush if the type doesn't match the type
	if (writeBuffer != writeBufferPos && (writeBufferType != oType || (fits < sl && fits > writeBufferHighWaterMark))) {
		// for efficiency we're not using handleFlushConsole, because that would trigger stdxx flush, too
		[self writeConsoleDirectly:[NSString stringWithUTF8String:writeBuffer]
                         withColor:(NSColor*)CFArrayGetValueAtIndex((CFArrayRef)consoleColors, writeBufferType ? iErrorColor : iOutputColor)];
		writeBufferPos = writeBuffer;
		fits = writeBufferLen - 1;
	}

	writeBufferType = oType;
	NSColor *writingColor = (NSColor*)CFArrayGetValueAtIndex((CFArrayRef)consoleColors, writeBufferType ? iErrorColor : iOutputColor);

    // this seems a bit insane given that we could just pass the string as a whole, but it should be exteremely rare
    // since we are dealing with small strings most of the time
	while (fits < sl) {	// ok, we're in a situation where we must split the string
		memcpy(writeBufferPos, s, fits);
		writeBufferPos[writeBufferLen - 1] = 0;
		[self writeConsoleDirectly:[NSString stringWithUTF8String:writeBuffer] withColor:writingColor];
		sl -= fits; s += fits;
		writeBufferPos = writeBuffer;
		fits = writeBufferLen - 1;
	}
	
	strcpy(writeBufferPos, s);
	writeBufferPos += sl;

	// flush the buffer if the low watermark is reached
	if (fits - sl < writeBufferLowWaterMark) {
		[self writeConsoleDirectly:[NSString stringWithUTF8String:writeBuffer] withColor:writingColor];
		writeBufferPos = writeBuffer;
	}
}

// compatibility wrapper for older code
- (void) handleWriteConsole: (NSString*) txt {
    [self handleWriteConsole:txt withType:0];
}

/* this writes R output to the Console window directly, i.e. without using a buffer. Use handleWriteConsole: for the regular way. */
- (void) writeConsoleDirectly: (NSString*) txt withColor: (NSColor*) color{

	if (!txt || 
		(writeBufferType && [txt isEqualToString:@"\n"]) // suppress the output of an error message containing only a new line
		) return;

	NSRange scr = [txt rangeOfCharacterFromSet:specialCharacters];
	if (scr.location != NSNotFound) { /* at least one special character */
		int tl = [txt length], cl = scr.location;
		unichar sc = [txt characterAtIndex: cl];
		SLog(@"writeConsoleDirectly special char 0x%x (@%d of %d, full string:'%@')", (int) sc, cl, tl, txt);
		if (sc == '\r') { /* CR */
			if (tl < cl + 1 && [txt characterAtIndex: cl + 1] == '\n') { /* CR+LF -> can use as-is */
				if (tl > cl + 2) {
					NSString *head = [txt substringToIndex: cl + 2];
					NSString *tail = [txt substringFromIndex: cl + 2];
					[self writeConsoleDirectly:head withColor:color];
					[self writeConsoleDirectly:tail withColor:color];
					return;
				}
			} else if (cl > 0 && [txt characterAtIndex:cl - 1] == '\n') { /* LF+CR -> ignore */
				NSString *head = [txt substringToIndex: cl];
				cl++; while (cl < tl && [txt characterAtIndex:cl] == '\r') cl++; /* skip all subsequent CRs */
				if (cl < tl) { /* is there more behind those CRs? Then we need to split-process it */
					NSString *tail = [txt substringFromIndex: cl];
					[self writeConsoleDirectly:tail withColor:color];
					return;
				} else txt = head; /* just proceed with trailing CRs removed */
			} else { /* ok, a "true" CR without any of its LF friends */
				NSString *head = [txt substringToIndex: cl];
				cl++; while (cl < tl && [txt characterAtIndex:cl] == '\r') cl++; /* skip all subsequent CRs */
				NSString *tail = nil;
				if (cl < tl) tail = [txt substringFromIndex: cl];
				[self writeConsoleDirectly:head withColor:color];
				if (outputPosition < 0) outputPosition = [[consoleTextView textStorage] length];
				NSRange lr = [[[consoleTextView textStorage] string] lineRangeForRange:NSMakeRange(outputPosition, 0)];
				/* do whatever we need to do to mark CR */
				outputPosition = lr.location;
				outputOverwrite = lr.length;
				//[consoleTextView setSelectedRange:lr];
				if (tail) [self writeConsoleDirectly:tail withColor:color];
				return;
			}
		} else {
			if (cl > 0) {
				NSString *head = [txt substringToIndex: cl];
				SLog(@"write head '%@'", head);
				[self writeConsoleDirectly:head withColor:color];
			}
			NSRange csr = [consoleTextView selectedRange];
			if (outputPosition < 0) outputPosition = [[consoleTextView textStorage] length];
			[consoleTextView setSelectedRange:NSMakeRange(outputPosition, 0)];
			while (cl < tl) {
				unichar tsc = [txt characterAtIndex:cl];
				SLog(@" @%d: %d", cl, tsc);
				if (tsc == '\a')
					NSBeep();
				else if (tsc == '\b' && outputPosition > 0) {
					lastCommittedLength = committedLength;
					int ocl = committedLength;
					committedLength = 0;
					[consoleTextView deleteBackward:self];
					committedLength = ocl;
					if (outputPosition <= committedLength) committedLength--;
					if (outputPosition <= promptPosition) promptPosition--;
					if (outputPosition <= csr.location) csr.location--;
					outputPosition--;
					lastCommittedLength = committedLength;
				}
				else break;
				cl++;
			}
			[consoleTextView setSelectedRange:csr];
			if (cl < tl) {
				NSString *tail = [txt substringFromIndex: cl];
				SLog(@"process tail '%@'", tail);
				[self writeConsoleDirectly:tail withColor:color];
			}
			return;
		}
	}
	BOOL inEditing = NO;
	@try {
		@synchronized(textViewSync) {
			NSRange origSel = [consoleTextView selectedRange];
			unsigned tl = [txt length];
			int delta = 0;
			if (tl>0) {
				unsigned oldCL=committedLength;
				SLog(@"original: %d:%d, insertion: %d, length: %d, prompt: %d, commit: %d, overwrite:%d", origSel.location,
					 origSel.length, outputPosition, tl, promptPosition, committedLength, outputOverwrite);
				if (outputPosition > [textStorage length]) outputPosition = [textStorage length];
				SLog(@"RController writeConsoleDirectly, beginEditing");
				[textStorage beginEditing];
				inEditing = YES;
				lastCommittedLength = committedLength;
				committedLength=0;
				if (outputOverwrite) {
					int otl = [txt length];
					NSRange nlr = [txt rangeOfString:@"\n"]; /* if it has any newlines, we replace only up to the newline */
					if (nlr.location != NSNotFound) {
						int nlpos = nlr.location;
						nlr.length = (nlpos < outputOverwrite) ? nlpos : outputOverwrite;
						nlr.location = outputPosition;
						[textStorage replaceCharactersInRange:nlr withString:@""];
						[textStorage insertText:[txt substringToIndex:nlpos] atIndex:outputPosition withColor:color];
						delta = nlpos - outputOverwrite;
						txt = [txt substringFromIndex:nlr.length];
						tl = [txt length];
						outputPosition += outputOverwrite;
						outputOverwrite = 0;
					} else {
						if (otl > outputOverwrite) otl = outputOverwrite;
						nlr.location = outputPosition;
						nlr.length = otl;
						[textStorage replaceCharactersInRange:nlr withString:@""];
						outputOverwrite -= otl;
						delta = -nlr.length;
					}
				}
				[textStorage insertText:txt atIndex:outputPosition withColor:color];
				if (outputPosition <= promptPosition) promptPosition += tl + delta;
				committedLength=oldCL;
				if (outputPosition <= committedLength) committedLength += tl + delta;
				if (outputPosition <= origSel.location) origSel.location += tl + delta;
				outputPosition += tl;
				[textStorage endEditing];
				lastCommittedLength = committedLength;
				inEditing = NO;
				SLog(@"RController writeConsoleDirectly, endEditing");
				[consoleTextView setSelectedRange:origSel];
				[consoleTextView scrollRangeToVisible:origSel];
			}
		}
	}
	@catch (NSException *e) {
		SLog(@"** EXCEPTION while editing console: %@", e);
		if (inEditing) [[consoleTextView textStorage] endEditing];
	}
}

/* Just writes the prompt in a different color */
- (void)handleWritePrompt: (NSString*) prompt {
    [self handleFlushConsole];
	outputOverwrite=0; // disable any overwrites
	@synchronized(textViewSync) {
		unsigned textLength = [textStorage length];
		int promptLength=[prompt length];
//		NSLog(@"Prompt: %@", prompt);
		NSRange lr = [[textStorage string] lineRangeForRange:NSMakeRange(textLength,0)];
		SLog(@"RController handleWritePrompt: '%@', beginEditing", prompt);
		[textStorage beginEditing];
		promptPosition=textLength;
		if (lr.location!=textLength) { // the prompt must be on the beginning of the line
			[textStorage insertText: @"\n" atIndex: textLength withColor:[consoleColors objectAtIndex:iPromptColor]];
			textLength = [textStorage length];
			promptLength++;
		}
		
		if (promptLength>0) {
			[textStorage insertText:prompt atIndex: textLength withColor:[consoleColors objectAtIndex:iPromptColor]];
			if (promptLength>1) // this is a trick to make sure that the insertion color doesn't change at the prompt
				[textStorage insertText:@"" atIndex:promptPosition+promptLength withColor:[consoleColors objectAtIndex:iInputColor]];
			committedLength=promptPosition+promptLength;
			
		}
		committedLength=promptPosition+promptLength;
		lastCommittedLength = committedLength;
		[textStorage endEditing];
		SLog(@"RController handleWritePrompt: '%@', endEditing", prompt);

		NSRange targetRange = NSMakeRange(committedLength,0);
		[consoleTextView setSelectedRange:targetRange];
		[consoleTextView scrollRangeToVisible:targetRange];

	}
}

- (void)  handleProcessingInput: (char*) cmd
{
	NSString *s = [[NSString alloc] initWithUTF8String:cmd];

	@synchronized(textViewSync) {
		unsigned textLength = [[consoleTextView textStorage] length];
		
		[consoleTextView setSelectedRange:NSMakeRange(committedLength, textLength-committedLength)];
		[consoleTextView insertText:s];
		textLength = [[consoleTextView textStorage] length];
		[consoleTextView setTextColor:[consoleColors objectAtIndex:iInputColor] range:NSMakeRange(committedLength, textLength-committedLength)];
		outputPosition=committedLength=textLength;
		lastCommittedLength = committedLength;
		// remove undo actions to prevent undo across prompts
		[[consoleTextView undoManager] removeAllActions];
	}
	
	[s release];
}

- (char*) handleReadConsole: (int) addtohist
{
#ifdef USE_POOLS
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
#endif
	
	if (currentConsoleInput) {
		[currentConsoleInput release];
		currentConsoleInput=nil;
	}
	
	while ([consoleInputQueue count]==0) {
		processingEvents = NO; // we should be at the top level, so for sanity reasons make sure we always process events
		(_doProcessImp)(self, _doProcessSel, YES);
	}
	
	currentConsoleInput = [consoleInputQueue objectAtIndex:0];
	[consoleInputQueue removeObjectAtIndex:0];
	
	if (addtohist) {
//		Figure out how to get hold of ParseStatus here!
		[hist commit:currentConsoleInput];
		// Update filtered list if active
		if([[historySearchField stringValue] length])
			[self searchInHistory:nil];
		else
			[historyView reloadData];
	}
	
	{
		const char *c = [currentConsoleInput UTF8String];
#ifdef USE_POOLS

		if (!c) { [pool release]; return 0; }
#endif
		if (strlen(c)>readConsTransBufferSize-1) { // grow as necessary
			free(readConsTransBuffer);
			readConsTransBufferSize = (strlen(c)+2048)&0xfffffc00;
			readConsTransBuffer = (char*) malloc(readConsTransBufferSize);
		} // we don't shrink the buffer if gets too large - we may want to think about that ...
		
		strcpy(readConsTransBuffer, c);
	}
#ifdef USE_POOLS
	[pool release];
#endif
	return readConsTransBuffer;
}

- (int) handleEdit: (char*) file
{
#ifdef USE_POOLS
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
#endif
	NSString *fn = [NSString stringWithUTF8String:file];
	if (fn) fn = [fn stringByExpandingTildeInPath];
	if (!fn) {
#ifdef USE_POOLS
		[pool release];
#endif
		Rf_error("Invalid file name.");
	}

	SLog(@"RController.handleEdit: %s", file);
	
	if (![[NSFileManager defaultManager] isReadableFileAtPath:fn]) {
#ifdef USE_POOLS
		[pool release];
#endif
		return 0;
	}

	// If user called "... edit (...)" from WSBrowser or Console 
	// append the extension .R to the temp file
	// in order to open the to be edited file syntax highlighted
	NSString *fn_temp = [NSString stringWithString:fn];
	BOOL renamed = NO;
	if([[[NSApp keyWindow] delegate] isKindOfClass:[WSBrowser class]] 
			||[currentConsoleInput rangeOfString:@"edit"].length) {
		NSFileManager *fm = [[NSFileManager alloc] init];
		renamed = [fm moveItemAtPath:fn toPath:[NSString stringWithFormat:@"%@.R", fn] error:nil];
		if(renamed)
		    fn_temp = [NSString stringWithFormat:@"%@.R", fn];
		[fm release];
	}
	NSURL *url = [NSURL fileURLWithPath:fn_temp];
	NSError *theError;
	isREditMode = YES;

	RDocument *document = [[RDocumentController sharedDocumentController] openDocumentWithContentsOfURL:url display:YES error:&theError];

	[document setREditFlag: YES];
	NSArray *wcs = [document windowControllers];
	if (![wcs count]) {
		[document makeWindowControllers];
		wcs = [document windowControllers];
		SLog(@" - created windowController");
	}

	NSWindow *win = [[wcs objectAtIndex:0] window];
	if (win) {

		// run win as modal session but allow RDocumentWinCtrl to
		// manage win like initial syntax highlighting, edit status controlling,
		// undo behaviour etc.
		NSModalSession session = [NSApp beginModalSessionForWindow:win];
		for (;;) {

			// Break the run loop if win was closed
			if ([NSApp runModalSession:session] != NSRunContinuesResponse 
				|| ![win isVisible]) 
				break;

			// Allow the execution of code on DefaultRunLoop
			[[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode 
									 beforeDate:[NSDate distantFuture]];

		}
		// If temp file name was changed to *.R rename it to its original
		if(renamed) {
			NSFileManager *fm = [[NSFileManager alloc] init];
			renamed = [fm moveItemAtPath:fn_temp toPath:fn error:nil];
			if(!renamed) {
				NSBeep();
				NSLog(@"Couldn't rename temporay edit file to its original file name.");
			}
			[fm release];
		}
		[NSApp endModalSession:session];

	} else {
		SLog(@"handleEdit: WARNING, window is null!");
	}
	if ([wcs count]>1) {
		SLog(@"handleEdit: WARNING, there is more than one window controller, ignoring all but the first one.");
	}

	isREditMode = NO;

#ifdef USE_POOLS
	[pool release];
#endif

	return(0);
}

/* FIXME: the filename is not set for newly created files */
- (int) handleEditFiles: (int) nfile withNames: (char**) file titles: (char**) wtitle pager: (char*) pager
{
	int    	i;
    
	SLog(@"RController.handleEditFiles (%d of them, pager %s)", nfile, pager);
	if (nfile <=0) return 1;
	isREditMode = YES;
	for (i = 0; i < nfile; i++) {
		NSString *fn = [NSString stringWithUTF8String:file[i]];
		if (fn) fn = [fn stringByExpandingTildeInPath];
		SLog(@"file #%d: %@", i + 1, fn);
		if (fn) {
			if([[NSFileManager defaultManager] fileExistsAtPath:fn]) {
				NSURL *url = [NSURL fileURLWithPath:fn];
				NSError *theError;
				[[NSDocumentController sharedDocumentController] openDocumentWithContentsOfURL:url display:YES error:&theError];
			} else
				[[NSDocumentController sharedDocumentController] newDocument: [RController sharedController]];
			
			NSDocument *document = [[NSDocumentController sharedDocumentController] currentDocument];
			if(wtitle[i]!=nil)
				[RDocument changeDocumentTitle: document Title: [NSString stringWithUTF8String:wtitle[i]]];
		}
	}
	isREditMode = NO;
	return 1;
}

- (int) handleShowFiles: (int) nfile withNames: (char**) file headers: (char**) headers windowTitle: (char*) wtitle pager: (char*) pages andDelete: (BOOL) del
{
	int    	i;

	if (nfile <=0) return 1;
	SLog(@"RController.handleShowFiles (%d of them, title %s, pager %s)", nfile, wtitle, pages);

	isREditMode = YES;
	for (i = 0; i < nfile; i++){
		NSString *fn = [NSString stringWithUTF8String:file[i]];
		if (fn) fn = [fn stringByExpandingTildeInPath];
		if (fn) {
			NSURL *url = [NSURL fileURLWithPath:fn];
			NSError *theError;
			RDocument *document = [[RDocumentController sharedDocumentController] openDocumentWithContentsOfURL:url display:YES error:&theError];
			// don't display - we need to prevent the window controller from using highlighting
			if (document) {
				NSArray *wcs = [document windowControllers];
				if (![wcs count]) {
					[document makeWindowControllers];
					wcs = [document windowControllers];
					SLog(@" - created windowController");
				}
				if (wcs && [wcs count]>0) {
					SLog(@" - Disabling syntax highlighting for this document");
					[(RDocumentWinCtrl*) [wcs objectAtIndex:0] setPlain:YES];
				}
				if (wtitle)
					[RDocument changeDocumentTitle: document Title: [NSString stringWithFormat:@"%@ (%@)", [NSString stringWithUTF8String:wtitle], [document displayName]]];
				[document setEditable: NO];
				SLog(@" - finally show the document window");
				[document showWindows];
			}
		}
	}
	isREditMode = NO;
	return 1;
}

//======== Cocoa Handler ======

- (int) handlePackages: (int) count withNames: (char**) name descriptions: (char**) desc URLs: (char**) url status: (BOOL*) stat
{
	[[PackageManager sharedController] updatePackages:count withNames:name descriptions:desc URLs:url status:stat];
	return 0;
}

- (int) handleListItems: (int) count withNames: (char**) name status: (BOOL*) stat multiple: (BOOL) multiple title: (NSString*) title;
{
	return [[SelectList sharedController] selectList:count withNames:name status:stat multiple: multiple title:title];
}

- (int) handleHelpSearch: (int) count withTopics: (char**) topics packages: (char**) pkgs descriptions: (char**) descs urls: (char**) urls title: (char*) title
{
	[[SearchTable sharedController] updateHelpSearch:count withTopics:topics packages:pkgs descriptions:descs urls:urls title:title];
	return 0;
}

- (BOOL*) handleDatasets: (int) count withNames: (char**) name descriptions: (char**) desc packages: (char**) pkg URLs: (char**) url
{
	[[DataManager sharedController] updateDatasets:count withNames:name descriptions:desc packages:pkg URLs:url];
	return 0; // we don't load the DS this way, we use REngine instead
}

- (int) handleInstalledPackages: (int) count withNames: (char**) name installedVersions: (char**) iver repositoryVersions: (char**) rver update: (BOOL*) stat label: (char*) label
{
	[[PackageInstaller sharedController] updateInstalledPackages:count withNames:name installedVersions:iver repositoryVersions:rver update:stat label:label];
	return 0;
}

- (int) handleSystemCommand: (char*) cmd
{	
	int cstat=-1;
	pid_t pid;
	
	if ([self getRootFlag]) {
		FILE *f;
		char *argv[3] = { "-c", cmd, 0 };
		int res;
 		NSBundle *b = [NSBundle mainBundle];
		char *sushPath = 0;
		if (b) {
			NSString *sush = [[b resourcePath] stringByAppendingString:@"/sush"];
			sushPath = strdup([sush UTF8String]);
		}
		
		res = runRootScript(sushPath?sushPath:"/bin/sh",argv,&f,1);
		if (!res && f) {		
			int fd = fileno(f);
			if (fd != -1) {
				struct timespec peSleep = { 0, 50000000 }; // 50ms sleep
				[self setRootFD:fileno(f)];
			
				while (rootFD!=-1) { // readThread will reset rootFD to -1 when reaching EOF
					nanosleep(&peSleep, 0); // sleep at least 50ms between PE calls (they're expensive)
					Re_ProcessEvents();
				}
			}
		}
		if (sushPath) free(sushPath);
		return res;
	}
	
	pid=fork();
	if (pid==0) {
		// int sr;
		// reset signal handlers
		signal(SIGINT, SIG_DFL);
		signal(SIGTERM, SIG_DFL);
		signal(SIGQUIT, SIG_DFL);
		signal(SIGALRM, SIG_DFL);
		signal(SIGCHLD, SIG_DFL);
		execl("/bin/sh", "/bin/sh", "-c", cmd, NULL);
		exit(-1);
		//sr=system(cmd);
		//exit(WEXITSTATUS(sr));
	}
	if (pid==-1) return -1;
		
	{
		while (1) {
			pid_t w = waitpid(pid, &cstat, WNOHANG);
			if (w!=0 || breakPending) break;

			// NOTE: this deliberately circumvents doProcessEvents: since we need events
			// to be processed in all cases, even if system was called from within
			// the event handler and as such can run recursively
			NSEvent *event;
			if((event = (_nextEventImp)(NSApp, _nextEventSel, NSAnyEventMask, [NSDate dateWithTimeIntervalSinceNow:0.05], NSDefaultRunLoopMode, YES)))
				(_sendEventImp)(NSApp, _sendEventSel, event);

		}
		if(breakPending) {
			kill(pid, SIGINT);
			breakPending = NO;
		}
	}
	[[RController sharedController] rmChildProcess: pid];
	return cstat;
}	

- (int) handleCustomPrint: (char*) type withObject: (RSEXP*) obj
{
	if (!obj) return -2;
	if (!strcmp(type, "help-files")) {
		RSEXP *x = [obj attr:@"topic"];
		NSString *topic = @"<unknown>";
		if (x && [x string]) topic = [x string];
		[x release];
		if ([obj type]==STRSXP && [obj length]>0)
			[[HelpManager sharedController] showHelpUsingFile: [obj string] topic: topic];
		else {
			NSBeginAlertSheet(
				NLS(@"Help topic not found"),
				NLS(@"OK"),
				nil,
				nil,
				[consoleTextView window],
				self,
				@selector(sheetDidEnd:returnCode:contextInfo:),
				@selector(sheetDidEnd:returnCode:contextInfo:),
				NULL,
				[NSString stringWithFormat: NLS(@"Help for the topic \"%@\" was not found."), topic]);
		}
	}
	return 0;
}

- (void)sheetDidEnd:(id)sheet returnCode:(int)returnCode contextInfo:(NSString*)contextInfo
{

	SLog(@"RController: sheetDidEnd: returnCode: %d contextInfo: %@", returnCode, contextInfo);

	// Order out the sheet - could be a NSPanel or NSWindow
	if ([sheet respondsToSelector:@selector(orderOut:)]) {
		[sheet orderOut:nil];
	}
	else if ([sheet respondsToSelector:@selector(window)]) {
		[[sheet window] orderOut:nil];
	}

	if([contextInfo isEqualToString:@"saveAsRConsole"]) {
		if(returnCode == NSOKButton) {
			NSError *writeError = nil;
			[[consoleTextView string] writeToFile:[sheet filename] atomically:YES encoding:NSUTF8StringEncoding error:&writeError];
			if(writeError != nil) {
				NSBeginCriticalAlertSheet(NLS(@"Error"), NLS(@"OK"), nil, nil, RConsoleWindow, self, nil, nil, nil, [writeError localizedDescription]);
			}
		}
	}

	[RConsoleWindow makeKeyWindow];

}

//==========

- (void)didCloseAll:(id)sender {
	[Preferences commit];
	[self doSaveHistory:nil];
	NSString *sa = [Preferences stringForKey:@"saveOnExit" withDefault:@"ask"];
	if ([sa isEqualToString: @"ask"]) {

		NSAlert *alert = [[NSAlert alloc] init];

		[alert addButtonWithTitle:NLS(@"Save")];
		[alert addButtonWithTitle:NLS(@"Cancel")];
		[alert addButtonWithTitle:NLS(@"Don't Save")];
		[alert setInformativeText:NLS(@"Save workspace image?")];
		[alert setMessageText:NLS(@"Closing R session")];

		// Set standard key equivalent ⌘D to "Don't Save" for localization as well
		NSButton *dontSaveButton = [[alert buttons] objectAtIndex:2];
		[dontSaveButton setKeyEquivalent:@"d"];
		[dontSaveButton setKeyEquivalentModifierMask:NSCommandKeyMask];

		[alert beginSheetModalForWindow:[consoleTextView window] 
				modalDelegate:self 
			   didEndSelector:@selector(shouldCloseDidEnd:returnCode:contextInfo:) 
				  contextInfo:nil];
		[alert release];

	} else {
		terminating = YES;
		[self windowShouldClose:self];
	}
}

- (BOOL)windowShouldClose:(id)sender
{
	if (!terminating) {
		SLog(@"RController.windowShouldClose: initiating app termination");
		[[NSApplication sharedApplication] terminate:self];
		SLog(@"RController.windowShouldClose: app termination finished.");
		return NO;
	}
//	NSString *sa = [[REngine mainEngine] saveAction];
	NSString *sa = requestSaveAction ? requestSaveAction : [Preferences stringForKey:saveOnExitKey withDefault:@"ask"];
	SLog(@"RController.windowShouldClose: save action is %@.", sa);
	if ([sa isEqual:@"yes"] || [sa isEqual:@"no"]) {
		[Preferences commit];
		[self doSaveHistory:nil];
		[[REngine mainEngine] executeString:[NSString stringWithFormat:@"base::quit('%@')", sa]];
		return YES;
	}
	//[[RDocumentController sharedDocumentController] closeAllDocumentsWithDelegate:self didCloseAllSelector:@selector(didCloseAll:) contextInfo:nil];	
	//return NO;
	[self didCloseAll:self];
	SLog(@"RController.windowShouldClose: running modal");

	// since [self didCloseAll:] has already ordered out "Closing R session" alert sheet
	// try to run R.app modal for that sheet 
	BOOL canClose = (BOOL)[[NSApplication sharedApplication] runModalForWindow:([RConsoleWindow attachedSheet])?[RConsoleWindow attachedSheet]:RConsoleWindow];
	SLog(@"RController.windowShouldClose: returning %@", canClose?@"YES":@"NO");
	// FWIW: canClose is never YES, because didCloseAll: executes quit(..)

	// If user cancelled termination remain input focus to RConsoleWindow for convenience
	if(!canClose)
		[RConsoleWindow makeKeyWindow];

	return canClose;
}	
	
/* this gets called by the "wanna save?" sheet on window close */
- (void) shouldCloseDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo {

	[Preferences commit];
	// the code specifies whether it's ok for the application to close in response to windowShouldClose:
	[[NSApplication sharedApplication] stopModalWithCode: 
		(returnCode==NSAlertFirstButtonReturn || returnCode==NSAlertThirdButtonReturn)?YES:NO];
    if (returnCode==NSAlertFirstButtonReturn)
		[[REngine mainEngine] executeString:@"base::quit(\"yes\")"];
    if (returnCode==NSAlertThirdButtonReturn)
		[[REngine mainEngine] executeString:@"base::quit(\"no\")"];

}


/**
 * Closing a window will set the focus to the next window
 * according ordered window list
 */
- (void)windowWillCloseNotifications:(NSNotification*) aNotification
{

	NSWindow *w = [aNotification object];

	SLog(@"RController%@.windowWillCloseNotifications:%@", self, w);

	if (w && (
			   [[(NSObject*)[w delegate] className] isEqualToString:@"RDocumentWinCtrl"] 
			|| [[(NSObject*)[w delegate] className] isEqualToString:@"QuartzCocoaView"])
			)
		{
			SLog(@" - R source or Quartz windows will be handled by RDocumentController.windowWillCloseNotifications");
			return;
		}


	// Get all windows
	NSArray *appWindows = [NSApp orderedWindows];
	int i;

	// for NSPanels set focus to the first window; otherwise the first window is the to be
	// closed window thus set focus to the next window
	BOOL closingWindowFound = ([w isKindOfClass:[NSPanel class]]);

	// loop through windows to find next window
	// and make it the key window
	for(i=0; i<[appWindows count]; i++) {
		id win = [appWindows objectAtIndex:i];
		if([win isVisible]) {
			if(closingWindowFound) {
				SLog(@" - next key window title: %@", [win title]);
				[win makeKeyAndOrderFront:nil];
				return;
			}
			closingWindowFound = YES;
		}
	}
	SLog(@" - no window found; make RConsole key window");
	[RConsoleWindow makeKeyAndOrderFront:nil];
}

/*  This is used to send commands through the GUI, i.e. from menus 
The input replaces what the user is currently typing.
*/
- (void) sendInput: (NSString*) text {
	[self consoleInput:text interactive:YES];
}

/* These two routines are needed to update the History TableView */
- (int)numberOfRowsInTableView: (NSTableView *)tableView
{
	return (filteredHistory) ? [filteredHistory count] : [[hist entries] count];
}

- (id)tableView: (NSTableView *)tableView
		objectValueForTableColumn: (NSTableColumn *)tableColumn
			row: (int)row
{
	if(filteredHistory)
		return [filteredHistory objectAtIndex:row];
	else
		return (NSString*) [[hist entries] objectAtIndex:row];
}

- (BOOL)tableView:(NSTableView *)aTableView shouldEditTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex
{
	return NO;
}

- (BOOL)tableView:(NSTableView *)tableView shouldShowCellExpansionForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{
	return NO;
}

- (NSString *)tableView:(NSTableView *)aTableView toolTipForCell:(NSCell *)aCell rect:(NSRectPointer)rect tableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)row mouseLocation:(NSPoint)mouseLocation
{
	if(filteredHistory)
		return [filteredHistory objectAtIndex:row];
	else
		return (NSString*) [[hist entries] objectAtIndex:row];
}

/*  Clears the history  and updates the TableView */

- (IBAction)doClearHistory:(id)sender
{
	SLog(@"RController.doClearHistory");
	[hist resetAll];
	[historyView reloadData];
}

- (IBAction)doLoadHistory:(id)sender
{
	NSString *fname=nil;
	SLog(@"RController.doLoadHistory");
	if (sender) {
		NSOpenPanel *op = [NSOpenPanel openPanel];
		[op setDirectory:[[[NSFileManager defaultManager] currentDirectoryPath] stringByExpandingTildeInPath]];
		[op setTitle:NLS(@"Choose history File")];
		if([op runModalForTypes: [NSArray arrayWithObject:@"history"]] == NSOKButton)
			fname = [op filename];
	} else
		fname = [[Preferences stringForKey:historyFileNamePathKey
							   withDefault: kDefaultHistoryFile] stringByExpandingTildeInPath];
	SLog(@" - history file to load: %@", fname);
	if(fname != nil){
//		fname = [[[[NSFileManager defaultManager] currentDirectoryPath] stringByExpandingTildeInPath] stringByAppendingString:[NSString stringWithFormat:@"/%@", fname]];
		[self doClearHistory:nil];
		
		SLog(@" - cleared history, reload with: %@", fname);
		if ([[NSFileManager defaultManager] fileExistsAtPath: fname]) {
			FILE *rhist = fopen([fname UTF8String], "r");
			if (!rhist) {
				NSLog(NLS(@"Can't open history file %@"), fname);
			} else {
				NSString *entry = nil;
				char c[1024];
				
				c[1023]=0;
				while(fgets(c, 1023, rhist) && *c) {
					int i = strlen(c);
					BOOL multiline = NO;
					NSString *sEntry;

					while (i>0 && (c[i-1]=='\n' || c[i-1]=='\r')) c[--i]=0; // just in case someone has PC history we strip \r too
					if (!*c) continue; // skip blank lines (is that intended? what about "foo#\n\nbla\n"?)
					if ((multiline = (c[i - 1] == '#'))) c[i - 1] = '\n';
					sEntry=[NSString stringWithUTF8String:c];
					if (sEntry) {
						if (entry)
							entry = [entry stringByAppendingString:sEntry];
						else
							entry = sEntry;
						if (!multiline) {
							[hist commit:entry];
							entry=nil;
						}
					}
				}
				if (entry) [hist commit:entry]; // just being paranoid if someone edited the file manually
				fclose(rhist);
			}
		}		
		[historyView scrollRowToVisible:[historyView numberOfRows]];
		[historyView reloadData];
	}
}

- (void)doSaveHistory:(id)sender {
	NSString *fname = nil;
	FILE *rhist;
	
	if (sender) {
		NSSavePanel *sp = [NSSavePanel savePanel];
		[sp setDirectory:[[[NSFileManager defaultManager] currentDirectoryPath] stringByExpandingTildeInPath]];
		[sp setRequiredFileType:@"history"];
		[sp setTitle:NLS(@"Save history File")];
		if([sp runModal] == NSOKButton) fname = [sp filename];
	} else 
		fname = [[Preferences stringForKey:historyFileNamePathKey
							   withDefault: kDefaultHistoryFile] stringByExpandingTildeInPath];

	SLog(@"RController.doSaveHistory (file %@)", fname);
	rhist = fopen([fname UTF8String], "w");
	if (!rhist) {
		SLog(@"* Can't create history file %@", fname);
	} else {
		NSEnumerator *enumerator = [[hist entries] objectEnumerator];
		NSString *entry;
        
		while ((entry = [enumerator nextObject])) {
			if ([entry rangeOfString:@"\n" options:NSLiteralSearch].location!=NSNotFound) { // add # before \n for multi-line strings
				entry = [entry mutableCopy];
				[(NSMutableString*)entry replaceOccurrencesOfString:@"\n" withString:@"#\n" options:NSLiteralSearch range:NSMakeRange(0,[entry length])];
				fputs([entry UTF8String], rhist); // not 100% safe
				[entry release];
			} else {
				fputs([entry UTF8String], rhist); // not 100% safe
			}
			fputc('\n', rhist); // trailing \n
		}

		fclose(rhist);
	}
}

/*  On double-click on items of the History TableView, the item is pasted into the console
at current cursor position
*/
- (IBAction)historyDoubleClick:(id)sender {

	NSString *cmd;
	int index = [historyView selectedRow];
	if(index == -1) return;
	
	if(filteredHistory)
		cmd = [filteredHistory objectAtIndex:index];
	else
		cmd = [[hist entries] objectAtIndex:index];
	[self consoleInput:cmd interactive:NO];
	[RConsoleWindow makeFirstResponder:consoleTextView];
}

- (IBAction)historyDeleteEntry:(id)sender {

	int index = [historyView selectedRow];

	if(filteredHistory) {
		index = [[hist entries] indexOfObject:[filteredHistory objectAtIndex:index]];
		if((index >= 0) && (index < [[hist entries] count])) {
			[hist deleteEntry:index];
			[self searchInHistory:nil];
			return;
		}
	} else {
		if((index >= 0) && (index < [[hist entries] count]))
			[hist deleteEntry:index];
	}

	[historyView reloadData];

}

/*  This routine is intended to "cat" some text to the R Console without
issuing the newline.
- (void) consolePaste: (NSString*) text {
	unsigned textLength = [[consoleTextView textStorage] length];
	[consoleTextView setSelectedRange:NSMakeRange(textLength, 0)];
	[consoleTextView insertText:text];
}
*/
/* This function is used by two threads to write  stderr and/or stdout to the console
length: -1 = the string is null-terminated
outputType: 0 = stdout, 1 = stderr, 2 = stdout/err as root
*/
- (void) writeLogsWithBytes: (char*) buf length: (int) len type: (int) outputType
{
	NSColor *color=(outputType==0)?[consoleColors objectAtIndex:iStdoutColor]:((outputType==1)?[consoleColors objectAtIndex:iStderrColor]:[consoleColors objectAtIndex:iRootColor]);
	if (len>=0 && buf[len]!=0) buf[len]=0; /* this MAY be dangerous ... */
	NSString *s = [[NSString alloc] initWithUTF8String:buf];
	[self flushROutput];
	[self writeConsoleDirectly:s withColor:color];
	[s release];
}

+ (RController*) sharedController{
	return sharedRController;
}

/* console input - the string passed here is handled as if it was typed on the console */
- (void) consoleInput: (NSString*) cmd interactive: (BOOL) inter
{
	@synchronized(textViewSync) {
		if (!inter) {
			int textLength = [[consoleTextView textStorage] length];
			if (textLength>committedLength)
				[consoleTextView replaceCharactersInRange:NSMakeRange(committedLength,textLength-committedLength) withString:@""];
			[consoleTextView setSelectedRange:NSMakeRange(committedLength,0)];
			[consoleTextView insertText: cmd];
			textLength = [[consoleTextView textStorage] length];
			[consoleTextView setTextColor:[consoleColors objectAtIndex:iInputColor] range:NSMakeRange(committedLength,textLength-committedLength)];
		} else {
			// Create a dummy key event (SHIFT keyUp) to let cmd be processed
			// since the interaction between R and consoleTextView is key event based.
			// This is needed for cmd sent by mouse events only like "Show Workspace" etc.
			if([[NSApp currentEvent] type] != NSKeyDown) {
				CGEventRef e1 = CGEventCreateKeyboardEvent(NULL, (CGKeyCode)56, false);
				CGEventPost(kCGSessionEventTap, e1);
				CFRelease(e1);
			}
			if ([cmd characterAtIndex:[cmd length]-1]!='\n') cmd=[cmd stringByAppendingString: @"\n"];
			[consoleInputQueue addObject:[cmd copy]];
			[self setStatusLineText:@""];
		}
	}
}

- (BOOL)textView:(NSTextView *)textView doCommandBySelector:(SEL)commandSelector {

	SLog(@"RController.textView doCommandBySelector: %@\n", NSStringFromSelector(commandSelector));

	if(textView != consoleTextView) return NO;

	if (@selector(insertNewline:) == commandSelector) {
		unsigned textLength = [[textView textStorage] length];
		if(lastFunctionHintText) [lastFunctionHintText release], lastFunctionHintText=nil;
		[textView setSelectedRange:NSMakeRange(textLength,0)];
        if (textLength >= committedLength) {
			[textView insertText:@"\n"];
			textLength = [[textView textStorage] length];
			[self consoleInput: [[textView attributedSubstringFromRange:NSMakeRange(committedLength, textLength - committedLength)] string] interactive: YES];
		}
		return(YES);
    }

	// ---- history browsing ----
	if (@selector(moveUp:) == commandSelector) {
        unsigned textLength = [[textView textStorage] length];        
        NSRange sr=[textView selectedRange];
        if (sr.location==committedLength || sr.location==textLength) {
            NSRange rr=NSMakeRange(committedLength, textLength-committedLength);
            NSString *text = [[textView attributedSubstringFromRange:rr] string];
            if ([hist isDirty]) {
                [hist updateDirty: text];
            }
            NSString *news = [hist prev];
            if (news!=nil) {
                [news retain];
                sr.length=0; sr.location=committedLength;
                [textView setSelectedRange:sr];
                [textView replaceCharactersInRange:rr withString:news];
                [textView insertText:@""];
                [news release];
            }
			return(YES);
        }
    }
    if (@selector(moveDown:) == commandSelector) {
        unsigned textLength = [[textView textStorage] length];        
        NSRange sr=[textView selectedRange];
        if ((sr.location==committedLength || sr.location==textLength) && ![hist isDirty]) {
            NSRange rr=NSMakeRange(committedLength, textLength-committedLength);
            NSString *news = [hist next];
            if (news==nil) news=@""; else [news retain];
            sr.length=0; sr.location=committedLength;
            [textView setSelectedRange:sr];
            [textView replaceCharactersInRange:rr withString:news];
            [textView insertText:@""];
            [news release];
			return(YES);
        }
    }
    
	// ---- make sure the user won't accidentally get out of the input line ----
	// FIXME: essentially everything here behaves the same for a paragraph and line, but we should be making a distinction because of multi-line commands
	if ([textView selectedRange].location >= committedLength && (@selector(moveToBeginningOfParagraph:) == commandSelector 
			|| @selector(moveToBeginningOfLine:) == commandSelector
			|| @selector(moveToLeftEndOfLine:) == commandSelector)) {

        [textView setSelectedRange: NSMakeRange(committedLength,0)];
		return(YES);
    }
	
	if (@selector(deleteToBeginningOfLine:) == commandSelector || @selector(deleteToBeginningOfParagraph:) == commandSelector) {
		NSRange r = [textView selectedRange];
		if (r.length) /* if anything is selected, only the selected portion gets killed */
			[textView insertText:@""];
		else { /* otherwise delete all up to the beginning of the line or commit point */
			r.length = r.location - committedLength;
			r.location = committedLength;
			if (r.length > 0) {
				[textView setSelectedRange:r];
				[textView insertText:@""];
			}
		}
		return(YES);
	}
    
	if ([textView selectedRange].location >= committedLength && (@selector(moveToBeginningOfParagraphAndModifySelection:) == commandSelector 
			|| @selector(moveToLeftEndOfLineAndModifySelection:) == commandSelector
			|| @selector(moveToBeginningOfLineAndModifySelection:) == commandSelector)) {
		NSRange r = [textView selectedRange];
		r.length = r.location + r.length - committedLength;
		r.location = committedLength;
		if (r.length < 0) r.length = 0;
        [textView setSelectedRange: r];
		return(YES);
    }
	
	if (@selector(moveWordLeft:) == commandSelector || @selector(moveLeft:) == commandSelector) {
		NSRange sr = [textView selectedRange];
		if (sr.location == committedLength) {
			// if there is a selection, we have to remove it
			if (sr.length) [textView setSelectedRange:NSMakeRange(sr.location, 0)];
			return YES;
		}
	}
	if (@selector(moveWordLeftAndModifySelection:) == commandSelector || @selector(moveLeftAndModifySelection:) == commandSelector) {
		NSRange sr = [textView selectedRange];
		if (sr.location == committedLength) return YES;
	}
	
	// ---- code/file completion ----
	
	if (@selector(insertTab:) == commandSelector) {
		[textView complete:self];
		return(YES);
	}
	
	// ---- cancel ---
	
	if (@selector(cancel:) == commandSelector || @selector(cancelOperation:) == commandSelector) {
		[self breakR:self];
		return(YES);
	}
    
	return NO;
}

- (void)textStorageDidProcessEditing:(NSNotification *)notification
{

	// Make sure that the notification is from the correct textStorage object
	if ([consoleTextView textStorage] != [notification object]) return;

	NSInteger editedMask = [[consoleTextView textStorage] editedMask];

	SLog(@"RController: textStorageDidProcessEditing <%@> with mask %d", self, editedMask);

	// if the user really changed the text
	if(editedMask != 1) {

		[consoleTextView checkSnippets];

		// Cancel setting undo break point
		[NSObject cancelPreviousPerformRequestsWithTarget:consoleTextView 
								selector:@selector(breakUndoCoalescing) 
								object:nil];

		// Improve undo behaviour, i.e. it depends how fast the user types
		[consoleTextView performSelector:@selector(breakUndoCoalescing) withObject:nil afterDelay:0.8];

	}
}

- (void)textViewDidChangeSelection:(NSNotification *)aNotification
{

	// show functions hints in RConsole due to current caret position or selection

	SLog(@"RController: textViewDidChangeSelection");
	RTextView *tv = [aNotification object];

	// Cancel pending currentFunctionHint calls
	[NSObject cancelPreviousPerformRequestsWithTarget:tv 
							selector:@selector(currentFunctionHint) 
							object:nil];

	if([tv selectedRange].location >= committedLength && !busyRFlag && [[[tv textStorage] string] lineRangeForRange:[tv selectedRange]].length > 2) {
		SLog(@"RController: textViewDidChangeSelection called textView's currentFunctionHint");
		[tv performSelector:@selector(currentFunctionHint) withObject:nil afterDelay:0.1];
	}

}

- (BOOL)isREditMode
{
	return isREditMode;
}

- (BOOL)hintForFunction: (NSString*) fn
{
	if ([fn isEqualToString:lastFunctionForHint]) {
		if (lastFunctionHintText)
			[self setStatusLineText:lastFunctionHintText];
		return lastFunctionHintText ? YES : NO;
	}
	if(lastFunctionForHint) [lastFunctionForHint release];
	lastFunctionForHint = [fn retain];

	BOOL success = NO;
	if (insideR>0) {
		[self setStatusLineText:NLS(@"(arguments lookup is disabled while R is busy)")];
		return NO;
	}
	if (![[REngine mainEngine] beginProtected]) {
		[self setStatusLineText:NLS(@"(arguments lookup is disabled while R is busy)")];
		return NO;
	}
	RSEXP *x = [[REngine mainEngine] evaluateString:[NSString stringWithFormat:@"try(gsub('\\\\s+',' ',paste(capture.output(print(args(%@))),collapse='')),silent=TRUE)", fn]];
	if (x) {
		NSString *res = [x string];
		if (res && [res length]>10 && [res hasPrefix:@"function"]) {
			NSRange lastClosingParenthesis = [res rangeOfString:@")" options:NSBackwardsSearch];
			if(lastClosingParenthesis.length) {
				res = [res substringToIndex:NSMaxRange(lastClosingParenthesis)];
				res = [fn stringByAppendingString:[res substringFromIndex:9]];
				success = YES;
				[self setStatusLineText:res];
				if (lastFunctionHintText) [lastFunctionHintText release];
				lastFunctionHintText = [res retain];
			}
		}
		[x release];
	}
	[[REngine mainEngine] endProtected];
	return success;
}

/* Allow changes only for uncommitted text */
- (BOOL)textView:(NSTextView *)textView shouldChangeTextInRange:(NSRange)affectedCharRange replacementString:(NSString *)replacementString {
	if (replacementString && /* on font change we get nil replacementString which is ok to pass through */
		affectedCharRange.location < committedLength) { /* if the insertion is outside editable scope, append at the end */
		[textView setSelectedRange:NSMakeRange([[textView textStorage] length],0)];
		[textView insertText:replacementString];
		return NO;
	}
	return YES;
}

- (NSArray *)textView:(NSTextView *)textView completions:(NSArray *)words forPartialWordRange:(NSRange)charRange indexOfSelectedItem:(NSInteger *)index 
{

	NSRange sr = [textView selectedRange];

	SLog(@"completion attempt in RConsole; cursor at %d, complRange: %d-%d, commit: %d", sr.location, charRange.location, charRange.location+charRange.length, committedLength);

	int bow = NSMaxRange(sr);

	if (bow <= committedLength) return nil;

	while (bow>committedLength) bow--;

	NSRange er = NSMakeRange(bow, NSMaxRange(sr)-bow);

	*index=0;

	// avoid selecting of token if nothing was found
	// FIXME: do we need it?
	if (os_version < 11.0)
		[textView setSelectedRange:NSMakeRange(NSMaxRange(sr), 0)];

	return [CodeCompletion retrieveSuggestionsForScopeRange:er inTextView:textView];

}

- (void) handleBusy: (BOOL) isBusy {
	if (isBusy) {
		[progressWheel startAnimation:self];
#ifdef USE_APPNAP_API
		self.activity = [[NSProcessInfo processInfo] beginActivityWithOptions:NSActivityUserInitiated reason:@"R busy message"];
#endif
	} else {
		[progressWheel stopAnimation:self];
#ifdef USE_APPNAP_API
		if (self.activity) {
			[[NSProcessInfo processInfo] endActivity:self.activity];
			self.activity = NULL;
		}
#endif
	}
	
	busyRFlag = isBusy;
	if (toolbarStopItem) {
		if (isBusy || childPID>0)
			[toolbarStopItem setEnabled:YES];
		else
			[toolbarStopItem setEnabled:NO];
	}
}

- (void)  handleShowMessage: (char*) msg
{
	NSRunAlertPanel(NLS(@"R Message"),[NSString stringWithUTF8String:msg],NLS(@"OK"),nil,nil);
}

- (IBAction)flushconsole:(id)sender {
	[self handleFlushConsole];
}

- (IBAction)otherEventLoops:(id)sender {
	R_runHandlers(R_InputHandlers, R_checkActivity(0, 1));
}


- (IBAction)newQuartzDevice:(id)sender {

	NSWindow *currentKeyWindow = [NSApp keyWindow];

	NSString *cmd;
	BOOL flag=[Preferences flagForKey:useQuartzPrefPaneSettingsKey withDefault: NO];
	if (flag) {
		NSString *width = [Preferences stringForKey:quartzPrefPaneWidthKey withDefault: @"4.5"];
		NSString *height = [Preferences stringForKey:quartzPrefPaneHeightKey withDefault: @"4.5"];
		cmd = [NSString stringWithFormat:@"quartz(width=%@,height=%@)", width, height];
	}
	else
		cmd = @"quartz()";
	
	[[REngine mainEngine] executeString:cmd];

	// set focus back to last key window
	[currentKeyWindow makeKeyWindow];
}

- (IBAction)breakR:(id)sender{
	if (childPID)
		kill(childPID, SIGINT);
	else
		breakPending = YES;
	// we cannot break immediately in case we're in the middle of an inner event loop processing.
	// therefore we delay the break until the event loop is back (see doProcessEvents:)
}

- (IBAction)quitR:(id)sender{
	[self windowShouldClose:RConsoleWindow];
}

- (IBAction)makeConsoleKey:(id)sender
{
	[RConsoleWindow makeKeyAndOrderFront:sender];
	// due to the existance of a drawer set the first responder explicitly
	[RConsoleWindow makeFirstResponder:consoleTextView];
}

- (IBAction)makeLastQuartzKey:(id)sender
{
	NSWindow *w = [(RDocumentController*)[NSDocumentController sharedDocumentController] findLastWindowForDocType:ftQuartz];
	NSDocument *d = [[NSDocumentController sharedDocumentController] documentForWindow:w];
	if (!d || ![d fileType] || ![[d fileType] isEqualToString:ftQuartz]) {
		/* could not find Quartz window - either there is none or it has never
		been key. That can happen, because new Quartz windows are not made
		key upon creation to not disturb the workflow (you can't do anything
													   with them anyway) */
		d = nil;
		NSArray *a = [[NSDocumentController sharedDocumentController] documents];
		int i = 0, ct = [a count];
		while (i < ct) {
			NSString *ft = [(NSDocument*)[a objectAtIndex:i] fileType];
			if (ft && [ft isEqualToString:ftQuartz]) d = (NSDocument*)[a objectAtIndex:i];
			i++;
		}
		if (d) {
			a = [d windowControllers];
			if (a && [a count]>0)
				w = [(NSWindowController*)[a objectAtIndex:0] window];
		}
	}
	[w makeKeyAndOrderFront:self];
}

- (IBAction)makeLastEditorKey:(id)sender
{
	[[(RDocumentController*)[NSDocumentController sharedDocumentController] findLastWindowForDocType:ftRSource] makeKeyAndOrderFront:sender];
}

- (IBAction)toggleHistory:(id)sender
{
	NSDrawerState state = [HistoryDrawer state];
	if (NSDrawerOpeningState == state || NSDrawerOpenState == state) {
		[HistoryDrawer close];
	} else {
		if(sender && [sender isKindOfClass:[NSNumber class]]) {
			[HistoryDrawer openOnEdge:[sender intValue]];
		} else {
			[HistoryDrawer open];
		}
		NSInteger lastRowIndex = [self numberOfRowsInTableView:historyView]-1;
		[historyView selectRowIndexes:[NSIndexSet indexSetWithIndex:lastRowIndex] byExtendingSelection:NO];
		[historyView scrollRowToVisible:lastRowIndex];
		[[NSApp keyWindow] makeFirstResponder:historyView];
	}
}

-(IBAction) showVignettes:(id)sender {
	if ([VignettesController sharedController])
		[[VignettesController sharedController] showVigenttes];
}

- (IBAction)toggleAuthentication:(id)sender{
	BOOL isOn = [self getRootFlag];
	
	if (isOn) {
		removeRootAuthorization();
		[self setRootFlag:NO];
	} else {
		if (requestRootAuthorization(1)) return;
		[self setRootFlag:YES];
	}
}

- (IBAction)performFindPanelFindInWebViewAction:(id)sender
{
	if(currentWebViewForFindAction) {
		NSPasteboard *pasteBoard = [NSPasteboard pasteboardWithName:NSFindPboard];
		NSString *searchString = [searchInWebViewSearchField stringValue];
		if(![searchString length]) return;
		[pasteBoard declareTypes:[NSArray arrayWithObjects:NSStringPboardType, nil] owner:nil];
		[pasteBoard setString:searchString forType:NSStringPboardType];
		if(![currentWebViewForFindAction searchFor:searchString direction:YES caseSensitive:NO wrap:YES]) NSBeep();
	}
}

- (IBAction)performFindPanelAction:(id)sender
{

	// Handle each performFindPanelAction: - needed due to the fact that a WebView doesn't listen
	// as first responder to performFindPanelAction:
	id firstResponder = [[NSApp keyWindow] firstResponder];

	// Check if first responder is a WebView; if so call [[WebView frameLoadDelegate] performFindPanelAction:]
	// if implemented
	if([[[firstResponder class] description] isEqualToString:@"WebHTMLView"]) {
		// Try to get the corresponding WebView
		id aWebFrameView = [[[firstResponder superview] superview] superview];
		if(aWebFrameView && [aWebFrameView respondsToSelector:@selector(webFrame)]) {
			WebView *aWebView = [[(WebFrameView*)aWebFrameView webFrame] webView];
			if(aWebView) {
				// Handle all non-GUI actions here for each WebView
				if([sender tag] != 1) {
					NSPasteboard *pasteBoard = [NSPasteboard pasteboardWithName:NSFindPboard];
					switch([sender tag]) {
						case 2: // Find Next
						if(![aWebView searchFor:[pasteBoard stringForType:NSStringPboardType] direction:YES caseSensitive:NO wrap:YES]) NSBeep();
						break;
						case 3: // Find Previous
						if(![aWebView searchFor:[pasteBoard stringForType:NSStringPboardType] direction:NO caseSensitive:NO wrap:YES]) NSBeep();
						break;
						case 7: // Use selection for Find
						[pasteBoard declareTypes:[NSArray arrayWithObjects:NSStringPboardType, nil] owner:nil];
						[pasteBoard setString:[[aWebView selectedDOMRange] toString] forType:NSStringPboardType];
						break;
						default:
						NSBeep();
					}
				}
				else if([sender tag] == 1) {
					// Show Find in WebView Find Panel

					// Get webView's enclosing window
					NSWindow *webViewsEnclosingWindow = [NSApp keyWindow];
					NSRect winRect = [webViewsEnclosingWindow frame];

					// If the Find Panel is already open close it since it's application-shared
					if(searchInWebViewWindow)
						[self closeFindInWebViewSheet:self];

					// Remember the active webView for searching
					if(currentWebViewForFindAction) [currentWebViewForFindAction release];
					currentWebViewForFindAction = [aWebView retain];
					// Increase webView's content bottom margin
					[[currentWebViewForFindAction windowScriptObject] evaluateWebScript:@"document.body.style.marginBottom='30px';"];

					// Create Find Panel window and place it at the bottom of the enclosing window
					searchInWebViewWindow = [[[R_WebViewSearchWindow alloc] initWithContentRect:
						NSMakeRect(
							winRect.origin.x, 
							winRect.origin.y, 
							[[[[currentWebViewForFindAction mainFrame] frameView] documentView] visibleRect].size.width, 
							kR_WebViewSearchWindowHeight) 
						styleMask:NSBorderlessWindowMask 
						backing:NSBackingStoreBuffered 
						defer:NO] retain];

					// Add observer for resizing if parent window will be resized
					[[NSNotificationCenter defaultCenter] addObserver:self
						selector:@selector(resizeSearchInWebViewWindow:)
						name:NSWindowDidResizeNotification
						object:[NSApp keyWindow]];

					[searchInWebViewWindow setParentWindow:webViewsEnclosingWindow];
					[searchInWebViewWindow setContentView:[searchInWebViewSheet contentView]];

					// Preset search field by the current FindPboard's search pattern
					NSString *currentFindPattern = [[NSPasteboard pasteboardWithName:NSFindPboard] stringForType:NSStringPboardType];
					if(currentFindPattern)
						[searchInWebViewSearchField setStringValue:currentFindPattern];
					[searchInWebViewWindow setInitialFirstResponder:searchInWebViewSearchField];

					[webViewsEnclosingWindow addChildWindow:searchInWebViewWindow ordered:NSWindowAbove];

					[searchInWebViewWindow makeKeyAndOrderFront:nil];

				}
			}
			else
				NSBeep();
		} else {
			NSBeep();
		}
	}
	// Find request came from searchInWebViewSearchField 
	else if(firstResponder == [searchInWebViewSearchField currentEditor] && currentWebViewForFindAction) {
		NSPasteboard *pasteBoard = [NSPasteboard pasteboardWithName:NSFindPboard];
		int tag = [sender tag];
		// if user pressed Find Next/Prev buttons?
		if([sender isKindOfClass:[NSSegmentedControl class]])
			tag = ([sender selectedSegment]==0) ? 3 : 2;
		switch(tag) {
			case 2: // Find Next
			if(![currentWebViewForFindAction searchFor:[pasteBoard stringForType:NSStringPboardType] direction:YES caseSensitive:NO wrap:YES]) NSBeep();
			break;
			case 3: // Find Previous
			if(![currentWebViewForFindAction searchFor:[pasteBoard stringForType:NSStringPboardType] direction:NO caseSensitive:NO wrap:YES]) NSBeep();
			break;
			default:
			NSBeep();
		}
	}
	else if([firstResponder respondsToSelector:@selector(performFindPanelAction:)])
		[firstResponder performFindPanelAction:sender];
	else
		NSBeep();

}

- (void)resizeSearchInWebViewWindow:(NSNotification*)aNotification
{

	if(!searchInWebViewWindow) return;

	// Resize searchInWebViewWindow if parent window will be resized
	if([aNotification object] == [searchInWebViewWindow parentWindow]) {
		NSRect winRect = [[searchInWebViewWindow parentWindow] frame];
		winRect.size.width = [[[[currentWebViewForFindAction mainFrame] frameView] documentView] visibleRect].size.width;
		winRect.size.height = kR_WebViewSearchWindowHeight;
		[searchInWebViewWindow setFrame:winRect display:YES];
	}

}

- (IBAction)closeFindInWebViewSheet:(id)sender
{
	NSWindow *parentWin = [searchInWebViewWindow parentWindow];
	[parentWin removeChildWindow:searchInWebViewWindow];
	[[currentWebViewForFindAction windowScriptObject] evaluateWebScript:@"document.body.style.marginBottom='5px';"];
	[searchInWebViewWindow orderOut:nil];
	[[NSNotificationCenter defaultCenter] removeObserver:self 
			name:NSWindowDidResizeNotification 
			object:[searchInWebViewWindow parentWindow]];
	if(searchInWebViewWindow) [searchInWebViewWindow release], searchInWebViewWindow = nil;
	if(currentWebViewForFindAction) [currentWebViewForFindAction release], currentWebViewForFindAction = nil;
	[parentWin makeKeyAndOrderFront:nil];
}

- (BOOL)validateMenuItem:(NSMenuItem *)menuItem
{


	if ([menuItem action] == @selector(reInterpretDocument:)) {
		return NO;
	}

	if ([menuItem action] == @selector(printDocument:)) {

		id firstResponder = [[NSApp keyWindow] firstResponder];

		// Check if first responder is a WebView
		// if so call [[WebView frameLoadDelegate] printDocument:] if implemented
		if([[[firstResponder class] description] isEqualToString:@"WebHTMLView"]) {
			id aWebFrameView = [[[firstResponder superview] superview] superview];
			if(aWebFrameView && [aWebFrameView respondsToSelector:@selector(webFrame)]) {
				WebView *aWebView = [[(WebFrameView*)aWebFrameView webFrame] webView];
				if(aWebView && [[aWebView frameLoadDelegate] respondsToSelector:@selector(printDocument:)]) {
					return YES;
				} else {
					return NO;
				}
			}
			return NO;
		}

		return ([firstResponder delegate] && [[firstResponder delegate] respondsToSelector:@selector(printDocument:)]) ? YES : NO;

	}
	if ([menuItem action] == @selector(performFindPanelAction:)) {

		id firstResponder = [[NSApp keyWindow] firstResponder];

		// Validate "Use Selection for Find", i.e. is something selected
		if([menuItem tag] == 7) {
			if([[[firstResponder class] description] isEqualToString:@"WebHTMLView"]) {
				// Try to get the corresponding WebView and check if something is selected
				id aWebFrameView = [[[firstResponder superview] superview] superview];
				if(aWebFrameView && [aWebFrameView respondsToSelector:@selector(webFrame)]) {
					return ([[[[[(WebFrameView*)aWebFrameView webFrame] webView] selectedDOMRange] toString] length]) ? YES : NO;
				} else {
					return NO;
				}
			}
			if([firstResponder respondsToSelector:@selector(selectedRange)])
				return ([firstResponder selectedRange].length > 0) ? YES : NO;
			else
				return NO;
		}

		// Check if first responder is a WebView
		if([[[firstResponder class] description] isEqualToString:@"WebHTMLView"]) {
			// Try to get the corresponding WebView
			id aWebFrameView = [[[firstResponder superview] superview] superview];
			if(aWebFrameView && [aWebFrameView respondsToSelector:@selector(webFrame)]) {
				WebView *aWebView = [[(WebFrameView*)aWebFrameView webFrame] webView];
				if(aWebView)
					return YES;
				else
					return NO;
			} else {
				return NO;
			}
		}
		else if([firstResponder respondsToSelector:@selector(performFindPanelAction:)])
			return YES;
		else
			return NO;

	}

	if ([menuItem action] == @selector(editObject:)) {
		id fr = [[NSApp keyWindow] firstResponder];
		if([fr respondsToSelector:@selector(getRangeForCurrentWord)]) {

			NSString *objName = nil;

			// if user selected something allow it since s/he is responsible
			// otherwise take the current word due to cursor position and 
			// check if it is a valid object name in the workspace “ls()”
			if([(NSTextView*)fr selectedRange].length)
				return YES;
			else if([(NSTextView*)fr getRangeForCurrentWord].length)
				objName = [[(NSTextView*)fr string] substringWithRange:[(RTextView*)fr getRangeForCurrentWord]];
			else
				return NO;

			if(!objName) return NO;

			// check if found object name is defined in workspace “ls()”
			RSEXP *check = [[REngine mainEngine] evaluateString:[NSString stringWithFormat:@"ifelse(\"%@\" %%in%% ls(), '1', '')", objName]];
			if(check && [check string].length) {
				[check release];
				return YES;
			}
			return NO;
		}
		return NO;
	}

	return YES;

}

- (BOOL)application:(NSApplication *)theApplication openFile:(NSString *)filename {
	SLog(@" - application:openFile:%@ called", (NSString *)filename);
	NSString *dirname = @"";
	NSString *fname = nil;
	BOOL isDir = NO;
	BOOL flag = [Preferences flagForKey:enforceInitialWorkingDirectoryKey withDefault:NO];
	filename = [filename stringByExpandingTildeInPath];
	NSFileManager *manager = [NSFileManager defaultManager];
	if ([manager fileExistsAtPath:filename isDirectory:&isDir] && isDir){
		SLog(@"   is a directory, cwd to %@", filename);
		[manager changeCurrentDirectoryPath:[filename stringByExpandingTildeInPath]];
		if (!flag && !appLaunched) {
//			[manager changeCurrentDirectoryPath:[filename stringByExpandingTildeInPath]];
//			[[REngine mainEngine] executeString:@"sys.load.image('.RData', FALSE)"];
			if ([manager fileExistsAtPath:@".Rprofile"] && ![[manager currentDirectoryPath] isEqualToString:[@"~" stringByExpandingTildeInPath]])
				[[REngine mainEngine] executeString:@"source(\".Rprofile\")"];
			if ([manager fileExistsAtPath:[filename stringByAppendingString:@"/.RData"]]) {
				fname = [[[[NSFileManager defaultManager] currentDirectoryPath] stringByAppendingString: @"/.RData"] stringByExpandingTildeInPath];
				[[REngine mainEngine] executeString:[NSString stringWithFormat:@"load(\"%@\")", fname]];
				[self handleWriteConsole: [NSString stringWithFormat:@"%@%@]\n\n", NLS(@"[Workspace restored from "), fname]];
			}
			[self showWorkingDir:nil];
			[self doClearHistory:nil];
			[self doLoadHistory:nil];
		} else {
			[self sendInput:[NSString stringWithFormat:@"setwd(\"%@\")",[filename stringByExpandingTildeInPath]]];
			if ([manager fileExistsAtPath:[filename stringByAppendingString:@"/.RData"]]) {
				fname = [[[[NSFileManager defaultManager] currentDirectoryPath] stringByAppendingString: @"/.RData"] stringByExpandingTildeInPath];
				[[REngine mainEngine] executeString:[NSString stringWithFormat:@"load(\"%@\")", fname]];
				[self handleWriteConsole: [NSString stringWithFormat:@"%@%@]\n\n", NLS(@"[Workspace restored from "), fname]];
			}
		}
	} else {
		if (!flag && !appLaunched) {
			int i, j=-1;
			for (i=[filename length]-1 ; i>=0 ; i--) {
				if ([filename characterAtIndex:i] == '/') {
					j = i; i = -1;
				};
			}
			dirname = [filename substringWithRange: NSMakeRange(0, j+1)];
			SLog(@" - intial start, changing wd to pathname whic is %@", dirname);
			[manager changeCurrentDirectoryPath:[dirname stringByExpandingTildeInPath]];
			[self showWorkingDir:nil];
			[self doClearHistory:nil];
			[self doLoadHistory:nil];
		}
		BOOL openInEditor = [Preferences flagForKey:editOrSourceKey withDefault: YES];
		SLog(@"   appLaunched = %@, openInEditor = %@", appLaunched ? @"YES" : @"NO", openInEditor ? @"YES" : @"NO");
		if (openInEditor || appLaunched) {
			NSURL *url = [NSURL fileURLWithPath:filename];
			NSError *theError = nil;
			SLog(@" - application:openFile path of URL: <%@>", [url absoluteString]);
			[[NSDocumentController sharedDocumentController] openDocumentWithContentsOfURL:url display:YES error:&theError];
			if (theError) {
				SLog(@"*** openDocumentWithContentsOfURL: failed with %@", theError);
				return NO;
			}
		} else {
			int res = [[RController sharedController] isImageData: filename];
			SLog(@"RDocumentController.openDocumentWithContentsOfFile: %@", filename);
			if (res == 0 ) {
				SLog(@" - detected save image, invoking load instead of the editor");
				[[RController sharedController] sendInput: [NSString stringWithFormat:@"load(\"%@\")", filename]];
			} else 
				[self sendInput:[NSString stringWithFormat:@"source(\"%@\")",[filename stringByExpandingTildeInPath]]];
		}
	}
	SLog(@" - application:openFile:%@ with wd: <%@> done", (NSString *)filename, dirname);

	return YES;
}

- (IBAction)openDocument:(id)sender
{

	SLog(@"RController: openDocument");

	NSOpenPanel *op = [NSOpenPanel openPanel];
	[op setTitle:NLS(@"Choose File")];
	[op setAllowsMultipleSelection:YES];
	[op setCanSelectHiddenExtension:YES];
	[op setCanChooseDirectories:NO];
	[op setResolvesAliases:YES];

	NSInteger answer = [op runModalForDirectory:nil file:nil];
	
	if(answer == NSOKButton) {
		if([op filenames] != nil) {
			NSInteger i;
			for(i=0; i<[[op filenames] count]; i++) {
				NSString *pathName = [[op filenames] objectAtIndex:i];
				SLog(@" - will open %@", pathName);
				[self application:NSApp openFile:pathName];
			}
		}
	}

}

- (IBAction)customizeEncodingList:(id)sender;
{
	[[RChooseEncodingPopupAccessory sharedInstance] showPanel:nil];
}

- (IBAction)saveDocumentAs:(id)sender{
	NSDocument *cd = [[NSDocumentController sharedDocumentController] currentDocument];
	
	if (cd)
		[cd saveDocumentAs:sender];
	else {

		NSSavePanel *panel = [NSSavePanel savePanel];

		[panel setRequiredFileType:@"txt"];
		[panel setMessage:NLS(@"Save R Console To File")];

		[panel setExtensionHidden:NO];
		[panel setAllowsOtherFileTypes:YES];
		[panel setCanSelectHiddenExtension:YES];

		[panel beginSheetForDirectory:nil 
								 file:@"R Console.txt" 
					   modalForWindow:[self window] 
					    modalDelegate:self 
					   didEndSelector:@selector(sheetDidEnd:returnCode:contextInfo:) 
						  contextInfo:@"saveAsRConsole"];

	}
}

- (IBAction)saveDocument:(id)sender{
	NSDocument *cd = [[NSDocumentController sharedDocumentController] currentDocument];
	
	if (cd)
		[cd saveDocument:sender];
	else // for the console this is the same as Save As ..
		[self saveDocumentAs:sender];
	[RConsoleWindow makeKeyWindow];
}

- (IBAction)runPageLayout:(id)sender {
	[NSApp runPageLayout:sender];
}

- (int) handleChooseFile:(char *)buf len:(int)len isNew:(int)isNew
{
	const char *fn;
	int answer;
	NSSavePanel *sp;
	NSOpenPanel *op;
	
	*buf = 0;
	if(isNew==1){
		sp = [NSSavePanel savePanel];
		[sp setTitle:NLS(@"Choose New File Name")];
		answer = [sp runModalForDirectory:nil file:nil];
		
		if(answer == NSOKButton) {
			if([sp filename] != nil){
				fn = [[sp filename] UTF8String];
				if (strlen(fn)>=len) {
					SLog(@"** handleChooseFile: bufer too small, truncating");
					memcpy(buf, fn, len-1);
					buf[len-1]=0;
				} else
					strcpy(buf, fn);
			}
		}
	} else {
		op = [NSOpenPanel openPanel];
		[op setTitle:NLS(@"Choose File")];
		answer = [op runModalForDirectory:nil file:nil];
		
		if(answer == NSOKButton) {
			if([op filename] != nil){
				fn = [[op filename] UTF8String];
				if (strlen(fn)>=len) {
					SLog(@"** handleChooseFile: bufer too small, truncating");
					memcpy(buf, fn, len-1);
					buf[len-1]=0;
				} else
					strcpy(buf, fn);
			}
		}
	}
	[RConsoleWindow makeKeyWindow];
	return strlen(buf); // is is used? it's potentially incorrect...
}

- (void) handlePromptRdFileAtPath:(NSString*)filepath isTempFile:(BOOL)isTempFile
{
	if(filepath && [filepath length] 
			&& [[NSFileManager defaultManager] fileExistsAtPath:[filepath stringByExpandingTildeInPath]]) {
		if(!isTempFile) {
			NSURL *url = [NSURL fileURLWithPath:[filepath stringByExpandingTildeInPath]];
			NSError *theError = nil;
			SLog(@"RController:handlePromptRdFileAtPath opens prompt's Rd file '%@>'", [url absoluteString]);
			[[NSDocumentController sharedDocumentController] openDocumentWithContentsOfURL:url display:YES error:&theError];
			if(theError != nil) {
				NSBeep();
				NSLog(@"RController.handlePromptRdFileAtPath %@ couldn't be opened.\n%@", theError);
			}
		} else {
			NSError *err = nil;
			SLog(@"RController:handlePromptRdFileAtPath opens untitled Rd file for '%@>'", filepath);
			RDocumentController *ctrl = [RDocumentController sharedDocumentController];
			RDocument *doc = [ctrl makeUntitledDocumentOfType:ftRdDoc error:&err];
			if(err != nil) {
				NSBeep();
				NSLog(@"RController.handlePromptRdFileAtPath couln't create an untitled Rd document.\n%@", err);
			} else {
				[ctrl addDocument:doc];
				[doc makeWindowControllers];
				if([doc windowControllers] && [[doc windowControllers] count]) {
					NSWindow *win = [[[doc windowControllers] objectAtIndex:0] window];
					[doc showWindows];
					NSString *content = [NSString stringWithContentsOfFile:filepath encoding:NSUTF8StringEncoding error:&err];
					if(win && err == nil && content && [content length]) {
						[[win firstResponder] insertText:content];
					} else {
						NSBeep();
						NSLog(@"RController.handlePromptRdFileAtPath couldn't insert the Rd template.\n%@", err);
					}
				} else {
					NSBeep();
					NSLog(@"RController.handlePromptRdFileAtPath couln't find a window for the untitled Rd document.");
					return;
				}
			}
			[[NSFileManager defaultManager] removeItemAtPath:filepath error:nil]; 
		}
	} else {
		SLog(@"RController.handlePromptRdFileAtPath - no valid file path passed.");
	}
}

- (void) loadFile:(NSString *)fname
{
	int res = [[RController sharedController] isImageData:fname];
	
	switch(res){
		case -1:
			NSLog(@"cannot open file");
			break;
			
		case 0:
			[self sendInput: [NSString stringWithFormat:@"load(\"%@\")",fname]];
			break;
			
		case 1:
			[self sendInput: [NSString stringWithFormat:@"source(\"%@\")",fname]];
			break;	
		default:
			break; 
	}
}

// FIXME: is this really sufficient? what about compressed files?
/*  isImageData:	returns -1 on error, 0 if the file is RDX2 or RDX1, 
1 otherwise.
*/	
- (int)isImageData:(NSString *)fname
{
	NSFileHandle *fh = [NSFileHandle fileHandleForReadingAtPath:fname];
	NSData *header;
	unsigned char buf[5];

	if (!fh)
		return -1;

	header = [fh readDataOfLength:4];
	[fh closeFile];
	
	if (!header || [header length]<4)
		return 1; /* if it's less that 4 bytes then it can't be RData */

	memcpy((char*)buf, [header bytes], 4);
	
	buf[4]=0;
	if( (strcmp((char*)buf,"RDX2")==0) || ((strcmp((char*)buf,"RDX1")==0)) ||
		(buf[0]==0x1f && buf[1]==0x8b)) /* or gzip signature - packed RData */
		return(0);
	return(1);
}

- (void) doProcessEvents: (BOOL) blocking
{

	NSEvent *event;
	
	// avoid re-entrant event processing
	if (processingEvents) return;
	
	processingEvents = YES;
	@try {
#ifdef USE_POOLS
		NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
#endif
		if (blocking){
			(_sendEventImp)(NSApp, _sendEventSel, (_nextEventImp)(NSApp, _nextEventSel, NSAnyEventMask, [NSDate distantFuture], NSDefaultRunLoopMode, YES));
		} else {
			while((event = (_nextEventImp)(NSApp, _nextEventSel, NSAnyEventMask, [NSDate dateWithTimeIntervalSinceNow:0.0001], NSDefaultRunLoopMode, YES)))
				(_sendEventImp)(NSApp, _sendEventSel, event);
		}
#ifdef USE_POOLS
		[pool release];
#endif
	}
	@catch (NSException *foo) {
        // annoyingly, R_SVN_REVISION has changed from string to int in R 3.0.0 - perfect for causing segfaults ...
#if R_VERSION < R_Version(3, 0, 0)
#define R_REV_FMT "%s"
#else
#define R_REV_FMT "%d"
#endif
        const char *arch = getenv("R_ARCH");
        if (!arch) arch = "";
		NSBeep();
		NSLog(@"*** RController: caught ObjC exception while processing system events. Update to the latest GUI version and consider reporting this properly (see FAQ) if it persists and is not known. \n*** reason: %@\n*** name: %@, info: %@\n*** Version: R %s.%s (" R_REV_FMT ") R.app %@%s\nConsider saving your work soon in case this develops into a problem.", [foo reason], [foo name], [foo userInfo], R_MAJOR, R_MINOR, R_SVN_REVISION, [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"], arch);
	}
	processingEvents = NO;
	if (breakPending) {
		breakPending = NO;
		onintr();
	}
	return;
}

- (void) handleProcessEvents
{
	(_doProcessImp)(self, _doProcessSel, NO);
}


/* 
This method calls the showHelpFor method of the Help Manager which opens
 the internal html browser/help system of R.app
 This method is called from ReadConsole.
 
 The input C string 'topic' is parsed and the behaviour is the following:
 
 topic = ?something  => showHelpFor:@"something"
 topic = help(something) => showHelpFor:@"something"
 topic = help(something); print(anotherthing);   =>  showHelpFor:@"something"
 
 which means that all the rest of the input is discarded.
 No error message or warning are raised.
 */

- (void) openHelpFor: (char *) topic 
{
	char tmp[300];
	int i;
	
//	NSLog(@"openHelpFor: <%@>", [NSString stringWithCString:topic]);
	if(topic[0] == '?' && (strlen(topic)>2)) {
		int oldSearchType = [[HelpManager sharedController] searchType];
		[[HelpManager sharedController] setSearchType:kExactMatch];
		[[HelpManager sharedController] showHelpFor:[NSString stringWithUTF8String:topic+1]];
		[[HelpManager sharedController] setSearchType:oldSearchType];
	}
	if(strncmp("help(",topic,5)==0){
		for(i=5;i<strlen(topic); i++){
			if(topic[i]==')')
				break;
			tmp[i-5] = topic[i];
		}
		tmp[i-5] = '\0';
		int oldSearchType = [[HelpManager sharedController] searchType];
		[[HelpManager sharedController] setSearchType:kExactMatch];
		[[HelpManager sharedController] showHelpFor: [NSString stringWithUTF8String:tmp]];
		[[HelpManager sharedController] setSearchType:oldSearchType];
	}
}

- (void) setupToolbar {
	
    // Create a new toolbar instance, and attach it to our document window 
	toolbar = [[[NSToolbar alloc] initWithIdentifier: RToolbarIdentifier] autorelease];
    
    // Set up toolbar properties: Allow customization, give a default display mode, and remember state in user defaults 
    [toolbar setAllowsUserCustomization: YES];
    [toolbar setAutosavesConfiguration: YES];
    [toolbar setDisplayMode: NSToolbarDisplayModeIconOnly];
    
    // We are the delegate
    [toolbar setDelegate: self];
    
    // Attach the toolbar to the document window 
    [RConsoleWindow setToolbar: toolbar];
}

- (NSToolbarItem *) toolbar: (NSToolbar *)toolbar itemForItemIdentifier: (NSString *) itemIdent willBeInsertedIntoToolbar:(BOOL) willBeInserted {
    // Required delegate method:  Given an item identifier, this method returns an item 
    // The toolbar will use this method to obtain toolbar items that can be displayed in the customization sheet, or in the toolbar itself 
    NSToolbarItem *toolbarItem = [[[NSToolbarItem alloc] initWithItemIdentifier: itemIdent] autorelease];
    
    if ([itemIdent isEqual: SaveDocToolbarItemIdentifier]) {
		// Set the text label to be displayed in the toolbar and customization palette 
		[toolbarItem setLabel: NLS(@"Save")];
		[toolbarItem setPaletteLabel: NLS(@"Save Console Window")];
		[toolbarItem setToolTip: NLS(@"Save R console window")];
		[toolbarItem setImage: [NSImage imageNamed: @"SaveDocumentItemImage"]];
		[toolbarItem setTarget: self];
		[toolbarItem setAction: @selector(saveDocument:)];
    } else if ([itemIdent isEqual: NewEditWinToolbarItemIdentifier]) {
		// Set the text label to be displayed in the toolbar and customization palette 
		[toolbarItem setLabel: NLS(@"New Document")];
		[toolbarItem setPaletteLabel: NLS(@"New Document")];
		[toolbarItem setToolTip: NLS(@"Create a new, empty document in the editor")];
		[toolbarItem setImage: [NSImage imageNamed: @"emptyDoc"]];
		[toolbarItem setTarget: [RDocumentController sharedDocumentController]];
		[toolbarItem setAction: @selector(newDocument:)];
				
    }  else  if ([itemIdent isEqual: SetColorsToolbarItemIdentifier]) {
		[toolbarItem setLabel: NLS(@"Set Colors")];
		[toolbarItem setPaletteLabel: NLS(@"Set R Colors")];
		[toolbarItem setToolTip: NLS(@"Set R console colors")];
		[toolbarItem setImage: [NSImage imageNamed: @"colors"]];
		[toolbarItem setTarget: self];
		[toolbarItem setAction: @selector(openColors:)];
		
    } else  if ([itemIdent isEqual: LoadFileInEditorToolbarItemIdentifier]) {
		[toolbarItem setLabel: NLS(@"Open In Editor")];
		[toolbarItem setPaletteLabel: NLS(@"Open In Editor")];
		[toolbarItem setToolTip: NLS(@"Open document in editor")];
		[toolbarItem setImage: [NSImage imageNamed: @"Rdoc"]];
		[toolbarItem setTarget: self];
		[toolbarItem setAction: @selector(openDocument:)];
		
    } else  if ([itemIdent isEqual: SourceRCodeToolbarIdentifier]) {
		[toolbarItem setLabel: NLS(@"Source/Load")];
		[toolbarItem setPaletteLabel: NLS(@"Source or Load in R")];
		[toolbarItem setToolTip: NLS(@"Source script or load data in R")];
		[toolbarItem setImage: [NSImage imageNamed: @"sourceR"]];
		[toolbarItem setTarget: self];
		[toolbarItem setAction: @selector(sourceOrLoadFile:)];
		
    } else if([itemIdent isEqual: NewQuartzToolbarItemIdentifier]) {
		[toolbarItem setLabel: NLS(@"Quartz")];
		[toolbarItem setPaletteLabel: NLS(@"Quartz")];
		[toolbarItem setToolTip: NLS(@"Open a new Quartz device window")];
		[toolbarItem setImage: [NSImage imageNamed: @"quartz"]];
		[toolbarItem setTarget: self];
		[toolbarItem setAction: @selector(newQuartzDevice:) ];
		
	} else if([itemIdent isEqual: InterruptToolbarItemIdentifier]) {
		[toolbarItem setLabel: NLS(@"Stop")];
		[toolbarItem setPaletteLabel: NLS(@"Stop")];
		if(!toolbarStopItem) toolbarStopItem = [toolbarItem retain];
		[toolbarItem setToolTip: NLS(@"Interrupt current R computation")];
		[toolbarItem setImage: [NSImage imageNamed: @"stop"]];
		[toolbarItem setTarget: self];
		[toolbarItem setAction: @selector(breakR:) ];
		
	}  else if([itemIdent isEqual: FontSizeToolbarItemIdentifier]) {
		[toolbarItem setLabel: NLS(@"Font Size")];
		[toolbarItem setPaletteLabel: NLS(@"Font Size")];
		[toolbarItem setToolTip: NLS(@"Change the size of R console font")];
		[toolbarItem setTarget: self];
		[toolbarItem performSelector:@selector(setView:) withObject:fontSizeView];
		[toolbarItem setAction:NULL];
		[toolbarItem setView:fontSizeView];
		if ([toolbarItem view]!=NULL)
		{
			[toolbarItem setMinSize:[[toolbarItem view] bounds].size];
			[toolbarItem setMaxSize:[[toolbarItem view] bounds].size];
		}
		
	}  else if([itemIdent isEqual: NewQuartzToolbarItemIdentifier]) {
		[toolbarItem setLabel: NLS(@"Quartz")];
		[toolbarItem setPaletteLabel: NLS(@"Quartz")];
		[toolbarItem setToolTip: NLS(@"Open a new Quartz device window")];
		[toolbarItem setImage: [NSImage imageNamed: @"quartz"]];
		[toolbarItem setTarget: self];
		[toolbarItem setAction: @selector(newQuartzDevice:) ];
		
	} else if([itemIdent isEqual: ShowHistoryToolbarItemIdentifier]) {
		[toolbarItem setLabel: NLS(@"History")];
		[toolbarItem setPaletteLabel: NLS(@"History")];
		[toolbarItem setToolTip: NLS(@"Show/Hide R command history")];
		[toolbarItem setImage: [NSImage imageNamed: @"history"]];
		[toolbarItem setTarget: self];
		[toolbarItem setAction: @selector(toggleHistory:) ];			
	} else if([itemIdent isEqual: AuthenticationToolbarItemIdentifier]) {
		[toolbarItem setLabel: NLS(@"Authentication")];
		[toolbarItem setPaletteLabel: NLS(@"Authentication")];
		[toolbarItem setToolTip: NLS(@"Authorize R to run system commands as root")];
		[toolbarItem setImage: [NSImage imageNamed: @"lock-locked"]];
		[toolbarItem setTarget: self];
		[toolbarItem setAction: @selector(toggleAuthentication:) ];
		
	} else if([itemIdent isEqual: QuitRToolbarItemIdentifier]) {
		[toolbarItem setLabel: NLS(@"Quit")];
		[toolbarItem setPaletteLabel: NLS(@"Quit")];
		[toolbarItem setToolTip: NLS(@"Quit R")];
		[toolbarItem setImage: [NSImage imageNamed: @"quit"]];
		[toolbarItem setTarget: self];
		[toolbarItem setAction: @selector(quitR:) ];
		
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
    return [NSArray arrayWithObjects:	InterruptToolbarItemIdentifier, SourceRCodeToolbarIdentifier,
		NewQuartzToolbarItemIdentifier,
		NSToolbarSeparatorItemIdentifier,
		AuthenticationToolbarItemIdentifier, ShowHistoryToolbarItemIdentifier,
		SetColorsToolbarItemIdentifier,
		NSToolbarSeparatorItemIdentifier, /* SaveDocToolbarItemIdentifier, */
		LoadFileInEditorToolbarItemIdentifier,
		NewEditWinToolbarItemIdentifier, NSToolbarPrintItemIdentifier, 
		NSToolbarSeparatorItemIdentifier, NSToolbarFlexibleSpaceItemIdentifier,
		QuitRToolbarItemIdentifier, nil];
}

- (NSArray *) toolbarAllowedItemIdentifiers: (NSToolbar *) toolbar {
    // Required delegate method:  Returns the list of all allowed items by identifier.  By default, the toolbar 
    // does not assume any items are allowed, even the separator.  So, every allowed item must be explicitly listed   
    // The set of allowed items is used to construct the customization palette 
    return [NSArray arrayWithObjects: 	QuitRToolbarItemIdentifier, AuthenticationToolbarItemIdentifier, ShowHistoryToolbarItemIdentifier, 
		InterruptToolbarItemIdentifier, NewQuartzToolbarItemIdentifier, /* SaveDocToolbarItemIdentifier, */
		NewEditWinToolbarItemIdentifier, LoadFileInEditorToolbarItemIdentifier,
		NSToolbarPrintItemIdentifier, NSToolbarCustomizeToolbarItemIdentifier,
		NSToolbarFlexibleSpaceItemIdentifier, NSToolbarSpaceItemIdentifier, 
		NSToolbarSeparatorItemIdentifier,
		SetColorsToolbarItemIdentifier,
		/*FontSizeToolbarItemIdentifier,*/ SourceRCodeToolbarIdentifier, nil];
}

- (void) toolbarWillAddItem: (NSNotification *) notif {
    // Optional delegate method:  Before an new item is added to the toolbar, this notification is posted.
    // This is the best place to notice a new item is going into the toolbar.  For instance, if you need to 
    // cache a reference to the toolbar item or need to set up some initial state, this is the best place 
    // to do it.  The notification object is the toolbar to which the item is being added.  The item being 
    // added is found by referencing the @"item" key in the userInfo 
    NSToolbarItem *addedItem = [[notif userInfo] objectForKey: @"item"];
    if ([[addedItem itemIdentifier] isEqual: NSToolbarPrintItemIdentifier]) {
		[addedItem setToolTip: NLS(@"Print this document")];
		[addedItem setTarget: self];
    }
}  

- (void) toolbarDidRemoveItem: (NSNotification *) notif {
    // Optional delegate method:  After an item is removed from a toolbar, this notification is sent.   This allows 
    // the chance to tear down information related to the item that may have been cached.   The notification object
    // is the toolbar from which the item is being removed.  The item being added is found by referencing the @"item"
    // key in the userInfo 
	// NSToolbarItem *removedItem = [[notif userInfo] objectForKey: @"item"];
}

- (BOOL) validateToolbarItem: (NSToolbarItem *) toolbarItem {
    // Optional method:  This message is sent to us since we are the target of some toolbar item actions 
    // (for example:  of the save items action) 
    BOOL enable = NO;
    if ([[toolbarItem itemIdentifier] isEqual: SaveDocToolbarItemIdentifier]) {
		enable = [RConsoleWindow isDocumentEdited];
    } else if ([[toolbarItem itemIdentifier] isEqual: SourceRCodeToolbarIdentifier]) {
		enable = YES;
} else if ([[toolbarItem itemIdentifier] isEqual: SetColorsToolbarItemIdentifier]) {
		enable = YES;
    } else if ([[toolbarItem itemIdentifier] isEqual: LoadFileInEditorToolbarItemIdentifier]) {
		enable = YES;
    } else if ([[toolbarItem itemIdentifier] isEqual: NewEditWinToolbarItemIdentifier]) {
		enable = YES;
    } else if ([[toolbarItem itemIdentifier] isEqual: NSToolbarPrintItemIdentifier]) {
		enable = YES;
    } else if ([[toolbarItem itemIdentifier] isEqual: NewQuartzToolbarItemIdentifier]) {
		enable = YES;
    } else if ([[toolbarItem itemIdentifier] isEqual: InterruptToolbarItemIdentifier]) {
		enable = (busyRFlag || (childPID>0));
	} else if ([[toolbarItem itemIdentifier] isEqual: ShowHistoryToolbarItemIdentifier]) {
		enable = YES;
	} else if ([[toolbarItem itemIdentifier] isEqual: AuthenticationToolbarItemIdentifier]) {
		enable = YES;
	} else if ([[toolbarItem itemIdentifier] isEqual: QuitRToolbarItemIdentifier]) {
		enable = YES;
    }		

    return enable;
}

/**
* This is needed to resize RConsole's content of the status bar and
* to set options()'s width
*/
- (void) RConsoleDidResize: (NSNotification *)notification
{

	[self setStatusLineText:[self statusLineText]];
	// perform setOptionWidth: delayed to allow the textContainer to be rendered
	// and set withObject:nil because we do not force setOptionWidth:
	[self performSelector:@selector(setOptionWidth:) withObject:nil afterDelay:0.1];

}

- (void) setOptionWidth:(BOOL)force
{

	SLog(@"RController - setOptionWidth was called with force:%d", force);

	// We assume that a 'W' is the widest character and get its width
	NSAttributedString *s = [[NSAttributedString alloc] initWithString:@"W" attributes:
		[NSDictionary dictionaryWithObject:[consoleTextView font] forKey:NSFontAttributeName]];
	float char_maxWidth = [s size].width;
	[s release];

	// Get the max container size and keep a margin
	int newSize = (int)[[consoleTextView textContainer] containerSize].width-(int)(2*char_maxWidth);

	// Check if vertical scrollbar is visible, if no we assume that it will be
	// displayed thus decrease newSize by 15
	id scrollView = (NSScrollView *)consoleTextView.superview.superview;
	if ([scrollView isKindOfClass:[NSScrollView class]]) {
		if([consoleTextView frame].size.width+10 > [scrollView frame].size.width) {
			SLog(@" - vertical scrollbar not yet visible");
			newSize -= 15;
		}
	}

	// How many chars can be displayed without line breaking?
	int newConsoleWidth = (int)(newSize/char_maxWidth);

	SLog(@" - container:%f - char:%f - width old:%d new:%d",
		[[consoleTextView textContainer] containerSize].width, char_maxWidth, currentConsoleWidth, newConsoleWidth);

	// Set the options' width if forced or a new one was calculated
	if(force | (currentConsoleWidth != newConsoleWidth)) {
		currentConsoleWidth = newConsoleWidth;
		R_SetOptionWidth(newConsoleWidth);
	}

}

-(IBAction) checkForUpdates:(id)sender{
	[[REngine mainEngine] executeString: @"Rapp.updates()"];
}

-(IBAction) getWorkingDir:(id)sender
{
	[self sendInput:@"getwd()"];
}

-(IBAction) resetWorkingDir:(id)sender
{
	[[NSFileManager defaultManager] changeCurrentDirectoryPath: [[Preferences stringForKey:@"initialWorkingDirectoryKey" withDefault:@"~"] stringByExpandingTildeInPath]];
	[self showWorkingDir:sender];
}

-(IBAction) setWorkingDir:(id)sender
{
	NSOpenPanel *op;
	int answer;

	op = [NSOpenPanel openPanel];
	[op setCanChooseDirectories:YES];
	[op setCanChooseFiles:NO];
	[op setTitle:NLS(@"Choose New Working Directory")];
	[op setDirectory:[[NSFileManager defaultManager] currentDirectoryPath]];
	
	answer = [op runModal];
	if(answer == NSOKButton && [op filename] != nil)
		[[NSFileManager defaultManager] changeCurrentDirectoryPath:[[op filename] stringByExpandingTildeInPath]];
	[self showWorkingDir:sender];
}

- (IBAction) showWorkingDir:(id)sender
{
	NSString *wd = [[NSFileManager defaultManager] currentDirectoryPath];
	if (!wd) wd = NLS(@"<deleted>");
	if (!lastShownWD || ![wd isEqual:lastShownWD]) {
		if (lastShownWD) [lastShownWD release];
		lastShownWD = [wd retain];
		[WDirView setEditable:YES];
		[WDirView setStringValue: [wd stringByAbbreviatingWithTildeInPath]];
		[WDirView setEditable:NO];
	}
}


/**** NOTE: the following install...: methods are no longer used by the PakcageInstaller because they are wrong!
 ****       (Incorrect target directory and packages type) Correct implementations are inside the PI.
 ****       Remove as soon as it is clear that no NIB code uses it either! */
- (IBAction)installFromDir:(id)sender
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
			[[REngine mainEngine] executeString: [NSString stringWithFormat:@"install.packages(\"%@\",,NULL,type='source')",[op directory]] ];
}

- (IBAction)installFromBinary:(id)sender
{
	[[REngine mainEngine] executeString: @"install.packages(file.choose(),,NULL,type='mac.binary')" ];
}

- (IBAction)installFromSource:(id)sender
{
	[[REngine mainEngine] executeString: @"install.packages(file.choose(),,NULL,type='source')" ];
}
/**** end of obsolete API ****/

- (IBAction)togglePackageInstaller:(id)sender
{
	[[PackageInstaller sharedController] show];
}

- (IBAction)toggleWSBrowser:(id)sender
{
	[WSBrowser toggleWorkspaceBrowser];
	[[REngine mainEngine] executeString:@"browseEnv(html=F)"];
}

- (IBAction)loadWorkSpace:(id)sender
{
	[self sendInput:@"load(\".RData\")"];
	//	[[REngine mainEngine] evaluateString:@"load(\".RData\")" ];	
	[RConsoleWindow makeKeyWindow];
}

- (IBAction)saveWorkSpace:(id)sender
{
	[self sendInput:@"save.image()"];
	//	[[REngine mainEngine] evaluateString:@"save.image()"];
	[RConsoleWindow makeKeyWindow];
}

- (IBAction)loadWorkSpaceFile:(id)sender
{
	[[REngine mainEngine] executeString:@"load(file.choose())"];
	[RConsoleWindow makeKeyWindow];
}					

- (IBAction)saveWorkSpaceFile:(id)sender
{
	[[REngine mainEngine] executeString: @"save.image(file=file.choose(TRUE))"];
	[RConsoleWindow makeKeyWindow];
}

- (IBAction)showWorkSpace:(id)sender{
	[self sendInput:@"ls()"];
	[RConsoleWindow makeKeyWindow];
}

- (IBAction)clearWorkSpace:(id)sender
{
	NSBeginAlertSheet(NLS(@"Clear Workspace"), NLS(@"Yes"), NLS(@"No") , nil, RConsoleWindow, self, @selector(shouldClearWS:returnCode:contextInfo:), NULL, NULL,
					  NLS(@"All objects in the workspace will be removed. Are you sure you want to proceed?"));
}

/* this gets called by the "wanna save?" sheet on window close */
- (void) shouldClearWS:(id)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo
{

	// Order out the sheet - could be a NSPanel or NSWindow
	if ([sheet respondsToSelector:@selector(orderOut:)]) {
		[sheet orderOut:nil];
	}
	else if ([sheet respondsToSelector:@selector(window)]) {
		[[sheet window] orderOut:nil];
	}

	if (returnCode==NSAlertDefaultReturn)
		[[REngine mainEngine] executeString: @"rm(list=ls(all=TRUE))"];

	[[WSBrowser getWSBController] reloadWSBData:nil];

	[RConsoleWindow makeKeyWindow];

}

- (IBAction)togglePackageManager:(id)sender
{
	if ([[PackageManager sharedController] count]==0)
		[[REngine mainEngine] executeString:@"package.manager()"];
	else
		[[PackageManager sharedController] show];
}

- (IBAction)toggleDataManager:(id)sender
{
	if ([[DataManager sharedController] count]==0) {
		[[DataManager sharedController] show];
		[[REngine mainEngine] executeString: @"data.manager()"];
	} else
		[[DataManager sharedController] show];
}


-(IBAction) runX11:(id)sender{
	system("open -a X11.app");
}

-(IBAction) openColors:(id)sender{
	[prefsCtrl selectPaneWithIdentifier:@"Colors"];
	[prefsCtrl showWindow:self];
	[[prefsCtrl window] makeKeyAndOrderFront:self];
}

- (IBAction)performHelpSearch:(id)sender {
	if ([[sender stringValue] length]>0) {
		[[HelpManager sharedController] showHelpFor:[sender stringValue]];
		// [helpSearch setStringValue:@""];
	}
	[RConsoleWindow makeKeyWindow];
}

- (IBAction)sourceOrLoadFile:(id)sender
{
	int answer;
	NSOpenPanel *op;
	op = [NSOpenPanel openPanel];
	[op setTitle:NLS(@"R File to Source/Load")];
	answer = [op runModalForTypes:nil];
	
	if (answer==NSOKButton)
		[self loadFile:[op filename]];

}

- (IBAction)sourceFile:(id)sender
{
	int answer;
	NSOpenPanel *op;
	op = [NSOpenPanel openPanel];
	[op setTitle:NLS(@"R File to Source")];
	answer = [op runModalForTypes:nil];
	
	if (answer==NSOKButton)
		[self sendInput:[NSString stringWithFormat:@"source(\"%@\")",[op filename]]];

}

- (IBAction)editObject:(id)sender
{
	id fr = [[NSApp keyWindow] firstResponder];

	if([fr respondsToSelector:@selector(getRangeForCurrentWord)]) {

		NSString *objName = nil;

		// take the selected word if any otherwise the current word due to cursor position
		if([(NSTextView*)fr selectedRange].length)
			objName = [[(NSTextView*)fr string] substringWithRange:[(RTextView*)fr selectedRange]];
		else if([(NSTextView*)fr getRangeForCurrentWord].length)
			objName = [[(NSTextView*)fr string] substringWithRange:[(RTextView*)fr getRangeForCurrentWord]];

		if(!objName) {
			NSBeep();
			return;
		}

		[[REngine mainEngine] executeString:[NSString stringWithFormat:@"%@ <- edit(%@)", objName, objName]];

	}

}

- (IBAction)printDocument:(id)sender
{

	id firstResponder = [[NSApp keyWindow] firstResponder];

	// Check if first responder is a WebView
	// if so call [[WebView frameLoadDelegate] printDocument:] if implemented
	if([[[firstResponder class] description] isEqualToString:@"WebHTMLView"]) {
		id aWebFrameView = [[[firstResponder superview] superview] superview];
		if(aWebFrameView && [aWebFrameView respondsToSelector:@selector(webFrame)]) {
			WebView *aWebView = [[(WebFrameView*)aWebFrameView webFrame] webView];
			if(aWebView && [[aWebView frameLoadDelegate] respondsToSelector:@selector(printDocument:)]) {
				[[aWebView frameLoadDelegate] printDocument:sender];
				return;
			}
		}
	}

	// Check if call didn't come from RConsole and if delegate responds
	// to printDocument: - if so call it
	if(![[firstResponder delegate] isKindOfClass:[RController class]] && [firstResponder delegate]
		&& [[firstResponder delegate] respondsToSelector:@selector(printDocument:)]) {
		[[firstResponder delegate] printDocument:sender];
		return;
	}

	// Print RConsole
	NSPrintInfo *printInfo;
	NSPrintOperation *printOp;
	
	printInfo = [NSPrintInfo sharedPrintInfo];
	[printInfo setHorizontalPagination: NSFitPagination];
	[printInfo setVerticalPagination: NSAutoPagination];
	[printInfo setVerticallyCentered:NO];
	
	printOp = [NSPrintOperation printOperationWithView:consoleTextView 
											 printInfo:printInfo];
	[printOp setShowPanels:YES];

	[printOp runOperationModalForWindow:[self window] 
							   delegate:self 
						 didRunSelector:@selector(sheetDidEnd:returnCode:contextInfo:) 
						    contextInfo:@""];

}

- (IBAction) setDefaultColors:(id)sender {
	int i = 0, ccs = [consoleColorsKeys count];
	[[Preferences sharedPreferences] beginBatch];
	while (i<ccs) {
		[Preferences setKey:[consoleColorsKeys objectAtIndex:i] withArchivedObject:[defaultConsoleColors objectAtIndex: i]];
		i++;
	}
	[[Preferences sharedPreferences] endBatch];
}

- (void) updatePreferences {
	SLog(@"RController.updatePreferences");

	argsHints=[Preferences flagForKey:prefShowArgsHints withDefault:YES];
	RTextView_autoCloseBrackets = [Preferences flagForKey:kAutoCloseBrackets withDefault:YES];
	{
		int i = 0, ccs = [consoleColorsKeys count];
		while (i<ccs) {
			NSColor *c = [Preferences unarchivedObjectForKey: [consoleColorsKeys objectAtIndex:i] withDefault: [consoleColors objectAtIndex:i]];
			if (c != [consoleColors objectAtIndex:i]) {
				[consoleColors replaceObjectAtIndex:i withObject:c];
				if (i == iBackgroundColor) {
					[RConsoleWindow setBackgroundColor:c];
					[RConsoleWindow display];
				}
			}
			i++;
		}
		[consoleTextView setInsertionPointColor:[consoleColors objectAtIndex:iInputColor]];
		NSMutableDictionary *attr = [NSMutableDictionary dictionary];
		[attr setDictionary:[consoleTextView typingAttributes]];
		[attr setObject:[consoleColors objectAtIndex:iInputColor] forKey:NSForegroundColorAttributeName];
		[consoleTextView setTypingAttributes:attr];
		[attr setDictionary:[consoleTextView selectedTextAttributes]];
		[attr setObject:[consoleColors objectAtIndex:iSelectionColor] forKey:NSBackgroundColorAttributeName];
		[consoleTextView setSelectedTextAttributes:attr];
	}
	[consoleTextView setNeedsDisplay:YES];
	SLog(@" - done, preferences updated");
}

- (NSWindow*) window {
	return RConsoleWindow;
}

- (NSTextView *)getRTextView{
	return consoleTextView;
}

- (NSWindow *)getRConsoleWindow{
	return RConsoleWindow;
}

- (NSString*)getAppSupportPath
{

	BOOL isDir;

	if(!appSupportPath) {

		NSString *tpath;
		NSArray* paths = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES);

		if (![paths count]) {
			SLog(@"RController.getAppSupportPath bailed due to no search paths found");
			return nil;
		}

		// Use only the first path returned
		tpath = [paths objectAtIndex:0];

		// Append the application name
		tpath = [tpath stringByAppendingPathComponent:
			[[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleExecutable"]];

		// Check if user created the app support path already
		[[NSFileManager defaultManager] fileExistsAtPath:tpath isDirectory:&isDir];

		if(isDir) appSupportPath = [tpath retain];

	}

	// Check if app support path still exists
	[[NSFileManager defaultManager] fileExistsAtPath:appSupportPath isDirectory:&isDir];
	if(!isDir) {
		if(appSupportPath) [appSupportPath release];
		appSupportPath = nil;
	}

	return appSupportPath;

}

- (void)setStatusLineText:(NSString*)text
{

	SLog(@"RController.setStatusLine: \"%@\"", [text description]);

	if(text == nil) text = @"";

	if(![[self statusLineText] isEqualToString:text]) {
		if(lastFunctionForHint) [lastFunctionForHint release];
		lastFunctionForHint = nil;
	}

	// Adjust status line to show a single line in the middle of the status bar
	// otherwise to come up with at least two visible lines
	float w = NSSizeToCGSize([text sizeWithAttributes:[NSDictionary dictionaryWithObject:[statusLine font] forKey:NSFontAttributeName]]).width + 2.0f;
	NSSize p = [statusLine frame].size;
	p.height = (w > p.width) ? 22 : 17;
	[statusLine setFrameSize:p];
	[statusLine setNeedsDisplay:YES];
	[statusLine setToolTip:text];
	[statusLine setStringValue:text];

}

- (NSString*) statusLineText {
	return [statusLine stringValue];
}

- (int) quitRequest: (int) saveFlag withCode: (int) code last: (int) runLast
{
	if (saveFlag == 0)
		requestSaveAction = @"no";
	if (saveFlag == 1)
		requestSaveAction = @"yes";
	[[NSApplication sharedApplication] terminate:self];
	return 1;
}

- (int) helpServerPort {
	REngine *re = [REngine mainEngine];	
	int port = 0;
#if R_VERSION < R_Version(3, 2, 0)
	RSEXP *x = [re evaluateString:@"tools:::httpdPort"];
	if (x) {
		port = [x integer];
		[x release];
	}
	if (port != 0) return port;
	[re executeString:@"tools::startDynamicHelp()"];
	x = [re evaluateString:@"tools:::httpdPort"];
	if (x) {
		port = [x integer];
		[x release];
	}
#else
	// Since R 3.2.0 there is actually an official API to get the port and start it if needed
	RSEXP *x = [re evaluateString:@"tools::startDynamicHelp(NA)"];
	if (x) {
		port = [x integer];
		[x release];
	}
#endif
	return port;
}

- (void) helpSearchTypeChanged
{
	int type = [[HelpManager sharedController] searchType];
	NSMenu *m = [[helpSearch cell] searchMenuTemplate];
	SLog(@"RController - received notification about search type change to %d", type);
	[[m itemWithTag:kExactMatch] setState:(type == kExactMatch) ? NSOnState : NSOffState];
	[[m itemWithTag:kFuzzyMatch] setState:(type == kExactMatch) ? NSOffState : NSOnState];
	[[helpSearch cell] setSearchMenuTemplate:m];
}

- (NSView*) searchToolbarView
{
	return helpSearch;
}

- (NSUInteger)lastCommittedLength
{
	return lastCommittedLength;
}

#pragma mark -
#pragma mark Services menu methods

/**
 * Run selection in R Console
 **/
- (void)doPerformServiceRunInConsole:(NSPasteboard *)pboard userData:(NSString *)data error:(NSString **)error
{

	SLog(@"Service: 'Run in console' was called.");

	NSString *pboardString;

	NSArray *types = [pboard types];
	
	// if file urls were passed source('...') them one by one
	if([types containsObject:NSURLPboardType] && (pboardString = [pboard stringForType:NSURLPboardType])) {

		NSArray *fileArray = [pboard propertyListForType:NSURLPboardType];
		
		if([fileArray count]) {

			SLog(@" - source %d files", [fileArray count]);

			NSInteger i =0;
			for(i=0; i<[fileArray count]; i++) {
				NSString *fn = [fileArray objectAtIndex:i];
				if([fn length]) {
					NSURL *url = [[NSURL alloc] initWithString:fn];
					[self loadFile:[url path]];
					[url release];
				}
				[RConsoleWindow makeKeyWindow];
			}
		}

		return;

	}
	// if text selection was passed run the text in R Console
	else if([types containsObject:NSStringPboardType] && (pboardString = [pboard stringForType:NSStringPboardType])) {

		SLog(@" - execute:%@", pboardString);

		[self sendInput:pboardString];
		[RConsoleWindow makeKeyWindow];
		return;

	}

	NSLog(@"R Service: Pasteboard couldn't give string or URL for service 'Run in console'");
	NSBeep();

}

/**
 * Open selection in a new R script doc
 **/
- (void)doPerformServiceOpenRScript:(NSPasteboard *)pboard userData:(NSString *)data error:(NSString **)error
{

	SLog(@"Service: 'Open as R script' was called.");

	NSString *pboardString;

	NSArray *types = [pboard types];
	
	if([types containsObject:NSStringPboardType] && (pboardString = [pboard stringForType:NSStringPboardType])) {

		SLog(@" - open:%@", pboardString);
		RDocument *doc = (RDocument*)[[NSDocumentController sharedDocumentController] openUntitledDocumentAndDisplay:YES error:nil];
		if(doc) {
			[[doc textView] insertText:pboardString];
		} else {
			NSLog(@"R Service: service 'Open as R script' couldn't open a new R script document");
			NSBeep();
		}
		return;
	}

	NSLog(@"R Service: Pasteboard couldn't give string for service 'Open as R script'");
	NSBeep();

}

- (NSMenu *)textView:(NSTextView *)view menu:(NSMenu *)menu forEvent:(NSEvent *)event atIndex:(NSUInteger)charIndex
{

	if(view != consoleTextView) return menu;

	NSArray* items = [menu itemArray];
	NSInteger insertionIndex;

	// Check if context menu additions were added already
	for(insertionIndex = 0; insertionIndex < [items count]; insertionIndex++) {
		if([[items objectAtIndex:insertionIndex] tag] == kShowHelpContextMenuItemTag)
			return menu;
	}

	// Add additional menu items at the end

	SLog(@"RTextView: add additional menu items at the end of the context menu");

	[menu addItem:[NSMenuItem separatorItem]];
	
	NSMenuItem *anItem;
	anItem = [[NSMenuItem alloc] initWithTitle:NLS(@"Show Help for current Function") action:@selector(showHelpForCurrentFunction) keyEquivalent:@"h"];
	[anItem setKeyEquivalentModifierMask:NSControlKeyMask];
	[anItem setTag:kShowHelpContextMenuItemTag];
	[menu addItem:anItem];
	[anItem release];

	return menu;

}

- (NSArray *)textView:(NSTextView *)aTextView willChangeSelectionFromCharacterRanges:(NSArray *)oldSelectedCharRanges toCharacterRanges:(NSArray *)newSelectedCharRanges
{
	// Check if snippet session is still valid
	if ([newSelectedCharRanges count] && ![[newSelectedCharRanges objectAtIndex:0] rangeValue].length && [consoleTextView isSnippetMode]) {
		[consoleTextView checkForCaretInsideSnippet];
	}
	return newSelectedCharRanges;
}

@end
