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
 *
 *  $Id: RController.h 6731 2014-04-10 21:40:59Z urbaneks $
 */

#import "RGUI.h"

#include <R.h>
#include <Rinternals.h>
#include "REngine/Rcallbacks.h"
#include <R_ext/eventloop.h>
#import <sys/types.h>

#import "CCComp.h"
#import <WebKit/WebKit.h>

#import "Tools/History.h"
#import "Tools/ConnectionCache.h"
#import "PrefPanes/PrefWindowController.h"

#define RToolbarIdentifier                       @"R Toolbar Identifier"
#define FontSizeToolbarItemIdentifier            @"Font Size Item Identifier"
#define NewEditWinToolbarItemIdentifier          @"New Edit Window Item Identifier"
#define SaveDocToolbarItemIdentifier             @"Save R ConsoleWindow Item Identifier"
#define	SourceRCodeToolbarIdentifier             @"Source/Load R Code Identifier"
#define	InterruptToolbarItemIdentifier           @"Interrupt Computation Item Identifier"
#define	NewQuartzToolbarItemIdentifier           @"New Quartz Device Item Identifier"
#define	LoadFileInEditorToolbarItemIdentifier    @"Load File in Editor Item Identifier"
#define	AuthenticationToolbarItemIdentifier      @"Authentication Item Identifier"
#define	ShowHistoryToolbarItemIdentifier         @"Show History Item Identifier"
#define	QuitRToolbarItemIdentifier               @"Quit R Item Identifier"
#define	X11ToolbarItemIdentifier                 @"X11 Item Identifier"
#define	SetColorsToolbarItemIdentifier           @"SetColors Item Identifier"

#import "AMPrefs/AMPreferenceWindowController.h"
#import "Preferences.h"
#import "PreferenceKeys.h"
#import "RTextView.h"
#import "RConsoleTextStorage.h"
#import "RProgressIndicator.h"

// R defines "error" which is deadly as we use open ... with ... error: where error then gets replaced by Rf_error
#ifdef error
#undef error
#endif

@interface RController : NSObject <REPLHandler, CocoaHandler, PreferencesDependent, NSTextStorageDelegate, NSToolbarDelegate>
{
	IBOutlet RTextView *consoleTextView;
	IBOutlet RProgressIndicator *progressWheel;
	IBOutlet NSTableView *historyView;            /* TableView for the package manager */ 
	IBOutlet NSTextField *WDirView;               /* Mini-TextField for the working directory */
	IBOutlet NSSearchField *helpSearch;           /* help search  field */
	IBOutlet NSButton *clearHistory;
	IBOutlet NSButton *loadHistory;
	IBOutlet NSButton *saveHistory;
	IBOutlet NSButton *deleteEntry;
	IBOutlet NSDrawer *HistoryDrawer;
	IBOutlet NSWindow *RConsoleWindow;
	IBOutlet NSTextField *statusLine;
	IBOutlet NSSearchField *searchInWebViewSearchField;
	IBOutlet NSPanel *searchInWebViewSheet;
	IBOutlet NSMenu *reinterpretEncodingMenu;
	IBOutlet NSSearchField *historySearchField;

	WebView *currentWebViewForFindAction;
	id searchInWebViewWindow;

	IMP _nextEventImp;
	IMP _sendEventImp;
	IMP _doProcessImp;

	NSTimer *timer;
	NSTimer *RLtimer;
	NSTimer *Flushtimer;
	NSTimer *WDirtimer;
	History *hist;
	NSToolbar *toolbar;
	NSToolbarItem *toolbarStopItem;
	RConsoleTextStorage *textStorage;             /* the global Console textStorage */
	
	NSString *textViewSync;
	
	NSString *requestSaveAction;
	
    IBOutlet NSStepper *fontSizeStepper;
    IBOutlet NSTextField *fontSizeField;
    IBOutlet NSView *fontSizeView;
	
	IBOutlet PrefWindowController *prefsCtrl;

	unsigned committedLength; // any text before this position cannot be edited by the user
    unsigned promptPosition;  // the last prompt is positioned at this position
	unsigned outputPosition;  // any output (stdxx or consWrite) is to be place here, if -1 then the text can be appended
	int outputOverwrite;      // length of text that can be overwriten on output

	NSUInteger lastCommittedLength;

    int stdoutFD;
    int stderrFD;
	int rootFD;
	
	pid_t childPID;
	
    BOOL runSystemAsRoot;
	BOOL busyRFlag;
	BOOL appLaunched;
	BOOL argsHints;

	int currentConsoleWidth;
	
	char *readConsTransBuffer; // transfer buffer returned by handeReadConsole
	int readConsTransBufferSize; // size of the above buffer
	
	NSMutableArray *consoleColors;
	NSArray *consoleColorsKeys;
	NSArray *defaultConsoleColors;

	NSArray *filteredHistory;

	NSMutableArray *consoleInputQueue;
	NSString *currentConsoleInput;
	
	BOOL forceStdFlush;
	BOOL terminating;
	BOOL processingEvents;
	BOOL breakPending;
	BOOL isREditMode;
	BOOL ignoreMagnifyingEvent;
	
	char *writeBuffer;
	char *writeBufferPos;
	int  writeBufferLen;
	int writeBufferType;
    
	NSCharacterSet *specialCharacters;
	
	NSString *lastShownWD; // holds current directory after it has been shown (in non-abreviated form)
	
	NSMutableArray *pendingDocsToOpen; // paths of documents to open once initialized
	
	NSString *home;
	NSString *lastFunctionForHint;
	NSString *lastFunctionHintText;

	NSString *appSupportPath;

	NSMenuItem *toggleFullScreenMenuItem;

}

#if MAC_OS_X_VERSION_MAX_ALLOWED >= MAC_OS_X_VERSION_10_9
#define USE_APPNAP_API
@property (strong) id  activity;
#endif

	/* process pending events. if blocking is set to YES then the method waits indefinitely for one event. otherwise only pending events are processed. */
- (void) doProcessEvents: (BOOL) blocking;

- (void) addChildProcess: (pid_t) pid;
- (void) rmChildProcess: (pid_t) pid;

- (void) setRootFlag: (BOOL) flag;
- (BOOL) getRootFlag;
- (void) setRootFD: (int) fd;

- (BOOL) textView:(NSTextView *)textView doCommandBySelector:(SEL)commandSelector;
- (BOOL) textView:(NSTextView *)textView shouldChangeTextInRange:(NSRange)affectedCharRange replacementString:(NSString *)replacementString;

	/* write to the console bypassing any cache buffers - for internal use only! */
- (void) writeConsoleDirectly: (NSString*) text withColor: (NSColor*) color;

/* sendInput is an alias for "consoleInput: text interactive: YES" */
- (void) sendInput: (NSString*) text;

	/* replace the current console input with the "cmd" string. if "inter" is set to YES, then the input is immediatelly committed, otherwise it is only written to the input area, but not committed. Int tje interactive mode an optimization is made to not display the content before commit, because the lines are displayed as they are processed anyway. */
- (void) consoleInput: (NSString*) cmd interactive: (BOOL) inter;

- (IBAction)otherEventLoops:(id)sender;
- (IBAction)flushconsole:(id)sender;

-(IBAction) fontSizeBigger:(id)sender;
-(IBAction) fontSizeSmaller:(id)sender;
-(IBAction) changeFontSize:(id)sender;
- (void) fontSizeChangedBy:(float)delta withSender:(id)sender;

-(IBAction) getWorkingDir:(id)sender;
-(IBAction) resetWorkingDir:(id)sender;
-(IBAction) setWorkingDir:(id)sender;
-(IBAction) showWorkingDir:(id)sender;
-(IBAction) runX11:(id)sender;
-(IBAction) openColors:(id)sender;
-(IBAction) checkForUpdates:(id)sender;

-(IBAction) showVignettes:(id)sender;

-(IBAction) clearConsole:(id)sender;
-(IBAction) toggleFullScreenMode:(id)sender;

-(IBAction) searchInHistory:(id)sender;
-(IBAction) activateSearchInHistory:(id)sender;

- (int) numberOfRowsInTableView: (NSTableView *)tableView;
- (id) tableView: (NSTableView *)tableView
		objectValueForTableColumn: (NSTableColumn *)tableColumn
			 row: (int)row;

- (int) quitRequest: (int) saveFlag withCode: (int) code last: (int) runLast;

- (IBAction)doClearHistory:(id)sender;
- (IBAction)doLoadHistory:(id)sender;
- (IBAction)doSaveHistory:(id)sender;
- (IBAction)historyDoubleClick:(id)sender;
- (IBAction)historyDeleteEntry:(id)sender;

- (IBAction)newQuartzDevice:(id)sender;
- (IBAction)breakR:(id)sender;
- (IBAction)quitR:(id)sender;
- (IBAction)toggleHistory:(id)sender;
- (IBAction)toggleAuthentication:(id)sender;

- (IBAction)installFromBinary:(id)sender;
- (IBAction)installFromDir:(id)sender;
- (IBAction)installFromSource:(id)sender;

- (IBAction)togglePackageInstaller:(id)sender;

- (IBAction)openDocument:(id)sender;
- (IBAction)customizeEncodingList:(id)sender;

- (IBAction)loadWorkSpace:(id)sender;
- (IBAction)loadWorkSpaceFile:(id)sender;
- (IBAction)saveWorkSpace:(id)sender;
- (IBAction)saveWorkSpaceFile:(id)sender;
- (IBAction)clearWorkSpace:(id)sender;
- (IBAction)showWorkSpace:(id)sender;

- (IBAction)togglePackageManager:(id)sender;
- (IBAction)toggleDataManager:(id)sender;
- (IBAction)toggleWSBrowser:(id)sender;
- (IBAction)performHelpSearch:(id)sender;
- (IBAction)editObject:(id)sender;

- (IBAction)sourceFile:(id)sender;
- (IBAction)sourceOrLoadFile:(id)sender;

- (IBAction)makeConsoleKey:(id)sender;
- (IBAction)makeLastQuartzKey:(id)sender;
- (IBAction)makeLastEditorKey:(id)sender;

- (void) shouldClearWS:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo;

- (void) addConnectionLog;

- (void) writeLogsWithBytes: (char*) buf length: (int) len type: (int) outputType;
- (void) openHelpFor: (char*) topic;

- (void)setupToolbar;

- (int) isImageData:(NSString *)fname;
- (void) loadFile:(NSString *)fname;

- (void) RConsoleDidResize: (NSNotification *)notification;
- (void) setOptionWidth:(BOOL)force;

- (IBAction) setDefaultColors:(id)sender;

+ (RController*) sharedController;
- (NSView*) searchToolbarView;

- (void) flushROutput;
- (void) flushTimerHook: (NSTimer*) source; // hook for flush timer

- (void) handleWriteConsole: (NSString *)txt;
- (void) handleWritePrompt: (NSString *)prompt;
- (void) handleProcessEvents;
- (void) handleFlushConsole;
- (void) handleBusy: (BOOL)i;
- (int)  handleChooseFile: (char *)buf len:(int)len isNew:(int)isNew;	
- (void) handlePromptRdFileAtPath: (NSString*)filepath isTempFile:(BOOL)isTempFile;

- (void) setStatusLineText: (NSString*) text;
- (NSString*) statusLineText;

- (BOOL) hintForFunction: (NSString*) fn;

- (NSFont*) currentFont;

- (NSWindow*) window;

- (NSTextView *)getRTextView;
- (NSWindow *)getRConsoleWindow;
- (BOOL)appLaunched;

- (NSString*) home;
- (NSString*) currentWorkingDirectory;
- (NSString*)getAppSupportPath;
- (int) helpServerPort;
- (BOOL)isREditMode;
- (void)ignoreMagnifyingEventTimer;


- (IBAction)performFindPanelAction:(id)sender;
- (IBAction)performFindPanelFindInWebViewAction:(id)sender;
- (IBAction)closeFindInWebViewSheet:(id)sender;
- (void)resizeSearchInWebViewWindow:(NSNotification*)aNotification;

- (BOOL)windowShouldClose:(id)sender;

- (BOOL)application:(NSApplication *)theApplication openFile:(NSString *)filename;

- (void)updateReInterpretEncodingMenu;

- (void) helpSearchTypeChanged;

- (NSUInteger)lastCommittedLength;

// Service methods
- (void)doPerformServiceRunInConsole:(NSPasteboard *)pboard userData:(NSString *)data error:(NSString **)error;
- (void)doPerformServiceOpenRScript:(NSPasteboard *)pboard userData:(NSString *)data error:(NSString **)error;


@end

