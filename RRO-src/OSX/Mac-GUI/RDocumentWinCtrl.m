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
 *  Created by Simon Urbanek on 1/11/05.
 */

#import "RGUI.h"
#import "RDocumentWinCtrl.h"
#import "PreferenceKeys.h"
#import "RController.h"
#import "RDocumentController.h"
#import "REngine/REngine.h"
#import "Tools/FileCompletion.h"
#import "Tools/CodeCompletion.h"
#import "RegexKitLite.h"
#import "RTextView.h"
#import "HelpManager.h"
#import "NSTextView_RAdditions.h"
#import "RScriptEditorTextStorage.h"
#import "NSString_RAdditions.h"
#import "RWindow.h"
#import "NoodleLineNumberView.h"
#import "Tools/RTooltip.h"

// R defines "error" which is deadly as we use open ... with ... error: where error then gets replaced by Rf_error
#ifdef error
#undef error
#endif


/**
 * Include all the extern variables and prototypes required for flex (used for symbol parsing)
 */

#import "RSymbolTokens.h"

// Symbol lexer
extern NSUInteger symlex();
extern NSUInteger symuoffset, symuleng;
typedef struct sym_buffer_state *SYM_BUFFER_STATE;
void sym_switch_to_buffer(SYM_BUFFER_STATE);
SYM_BUFFER_STATE sym_scan_string (const char *);

BOOL defaultsInitialized = NO;

NSColor *shColorNormal;
NSColor *shColorString;
NSColor *shColorNumber;
NSColor *shColorKeyword;
NSColor *shColorComment;
NSColor *shColorIdentifier;

NSInteger _alphabeticSort(id string1, id string2, void *reverse);

static inline const char* NSStringUTF8String(NSString* self) 
{
	typedef const char* (*SPUTF8StringMethodPtr)(NSString*, SEL);
	static SPUTF8StringMethodPtr SPNSStringGetUTF8String;
	if (!SPNSStringGetUTF8String) SPNSStringGetUTF8String = (SPUTF8StringMethodPtr)[NSString instanceMethodForSelector:@selector(UTF8String)];
	const char* to_return = SPNSStringGetUTF8String(self, @selector(UTF8String));
	return to_return;
}

static inline int RPARSERCONTEXTFORPOSITION (RTextView* self, NSUInteger index) 
{
	typedef int (*RPARSERCONTEXTFORPOSITIONMethodPtr)(RTextView*, SEL, NSUInteger);
	static RPARSERCONTEXTFORPOSITIONMethodPtr _RPARSERCONTEXTFORPOSITION;
	if (!_RPARSERCONTEXTFORPOSITION) _RPARSERCONTEXTFORPOSITION = (RPARSERCONTEXTFORPOSITIONMethodPtr)[self methodForSelector:@selector(parserContextForPosition:)];
	int r = _RPARSERCONTEXTFORPOSITION(self, @selector(parserContextForPosition:), index);
	return r;
}


@implementation RDocumentWinCtrl

//- (id)init { // NOTE: init is *not* used! put any initialization in windowDidLoad

static RDocumentWinCtrl *staticCodedRWC = nil;

// FIXME: this is a very, very ugly hack to work around a bug in Cocoa: 
// "Customize Toolbar.." creates a copy of the custom views in the tollbar and
// one of it is the help search view (defined in the RDocument NIB). It turns
// out that a copy is made by encoding and decoding it. However, due to some
// strange bug in Cocoa this leads to instantiation of RDocumentWinCtrl via initWithCoder:
// which is then released immediately. This leads to a crash, so we work
// around this by retaining that copy thus making sure it won't be released.
// In order to reduce the memory overhead we keep around only one instance
// of this "special" controller and keep returning it.
- (id)initWithCoder: (NSCoder*) coder {
	SLog(@"RDocumentWinCtrl.initWithCoder<%@>: %@ **** this is due to a bug in Cocoa! Working around it:", self, coder);
	if (!staticCodedRWC) {
		staticCodedRWC = [super initWithCoder:coder];
		SLog(@" - creating static answer: %@", staticCodedRWC);
	} else {
		SLog(@" - release original, return static answer %@", staticCodedRWC);
		[self release];
		self = staticCodedRWC;
	}
	return [self retain]; // add a retain because it will be matched by the caller
}

- (void)dealloc {
	SLog(@"RDocumentWinCtrl.dealloc<%@>", self);
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[[Preferences sharedPreferences] removeDependent:self];
	[texItems release];
	if (helpTempFile) [[NSFileManager defaultManager] removeFileAtPath:helpTempFile handler:nil];
	if (functionMenuInvalidAttribute) [functionMenuInvalidAttribute release];
	if (pragmaMenuAttribute) [pragmaMenuAttribute release];
	if (functionMenuCommentAttribute) [functionMenuCommentAttribute release];
	[super dealloc];
}

/**
 * Sort function (mainly used to sort the words in the textView)
 */
NSInteger _alphabeticSort(id string1, id string2, void *reverse)
{
	return [string1 localizedCaseInsensitiveCompare:string2];
}

/**
 * This method is called as part of Key Value Observing which is used to watch for prefernce changes which effect the interface.
 */
- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
	if ([keyPath isEqualToString:prefShowArgsHints])
		argsHints = [Preferences flagForKey:prefShowArgsHints withDefault:YES];
	else if ([keyPath isEqualToString:showBraceHighlightingKey])
		showMatchingBraces = [Preferences flagForKey:showBraceHighlightingKey withDefault:YES];

}

- (void) replaceContentsWithRtf: (NSData*) rtfContents
{
	[textView replaceCharactersInRange:
		NSMakeRange(0, [[textView textStorage] length])
							   withRTF:rtfContents];
	[textView setSelectedRange:NSMakeRange(0,0)];
}

- (void)layoutTextView
{
	[[textView layoutManager] ensureLayoutForCharacterRange:NSMakeRange([[textView string] length],0)];
}

- (void) replaceContentsWithString: (NSString*) strContents
{
	[textView setString:strContents];

#if MAC_OS_X_VERSION_MIN_REQUIRED >= MAC_OS_X_VERSION_10_5
	[textView setSelectedRange:NSMakeRange(0,0)];
	[self performSelector:@selector(layoutTextView) withObject:nil afterDelay:0.5];
#endif

	[[self window] setDocumentEdited:NO];
}

- (NSData*) contentsAsRtf
{
	return [textView RTFFromRange:
		NSMakeRange(0, [[textView string] length])];
}

- (NSString*) contentsAsString
{
	return [textView string];
}	

- (NSTextView *) textView {
	return textView;
}

- (void) setPlain: (BOOL) plain
{
	plainFile=plain;
	if (plain && useHighlighting && textView)
		[textView setTextColor:shColorNormal range:NSMakeRange(0,[[textView textStorage] length])];
	else if (!plain && useHighlighting && textView)
		[textView performSelector:@selector(doSyntaxHighlighting) withObject:nil afterDelay:0.0];
}

- (BOOL) plain
{
	return plainFile;
}

- (BOOL) isRdDocument
{
	return ([[[self document] fileType] isEqualToString:ftRdDoc]) ? YES : NO;
}

// fileEncoding is passed through to the document - bound by the save box
- (int) fileEncoding
{
	SLog(@"%@ fileEncoding (%@ gives %d)", self, [self document], [[self document] fileEncoding]);
	return [[self document] fileEncoding];
}

- (void) setFileEncoding: (int) encoding
{
	SLog(@"%@ setFileEncoding: %d (doc %@)", self, encoding, [self document]);
	[[self document] setFileEncoding:encoding];
}

- (id) initWithWindowNibName:(NSString*) nib
{
	self = [super initWithWindowNibName:nib];
	SLog(@"RDocumentWinCtrl<%@>.initWithNibName:%@", self, nib);
	if (self) {
		plainFile=NO;
		hsType=1;
		currentHighlight=-1;
		updating=NO;
		helpTempFile=nil;
		execNewlineFlag=NO;
		lastLineWasCodeIndented = NO;
		isFormattingRcode = NO;
		isFunctionScanning = NO;

		texItems = [[NSArray arrayWithObjects:
			@"R",
			@"RdOpts",
			@"Rdversion",
			@"CRANpkg",
			@"S3method",
			@"S4method",
			@"Sexpr",
			@"acronym",
			@"alias",
			@"arguments",
			@"author",
			@"begin",
			@"bold",
			@"cite",
			@"code",
			@"command",
			@"concept",
			@"cr",
			@"dQuote",
			@"deqn",
			@"describe",
			@"description",
			@"details",
			@"dfn",
			@"docType",
			@"dontrun",
			@"dontshow",
			@"donttest",
			@"dots",
			@"email",
			@"emph",
			@"enc",
			@"encoding",
			@"end",
			@"enumerate",
			@"env",
			@"eqn",
			@"examples",
			@"file",
			@"figure",
			@"format",
			@"ge",
			@"href",
			@"if",
			@"ifelse",
			@"item",
			@"itemize",
			@"kbd",
			@"keyword",
			@"ldots",
			@"left",
			@"link",
			@"linkS4class",
			@"method",
			@"name",
			@"newcommand",
			@"note",
			@"option",
			@"out",
			@"pkg",
			@"preformatted",
			@"references",
			@"renewcommand",
			@"right",
			@"sQuote",
			@"samp",
			@"section",
			@"seealso",
			@"source",
			@"special",
			@"strong",
			@"subsection",
			@"synopsis",
			@"tab",
			@"tabular",
			@"testonly",
			@"title",
			@"url",
			@"usage",
			@"value",
			@"var",
			@"verb",
			nil] retain];

		[self setShouldCloseDocument:YES];

		[[NSNotificationCenter defaultCenter] addObserver:self 
							 selector:@selector(helpSearchTypeChanged) 
							     name:@"HelpSearchTypeChanged" 
							   object:nil];

		[[NSNotificationCenter defaultCenter] 
			addObserver:self
			   selector:@selector(RDocumentDidResize:)
				   name:NSWindowDidResizeNotification
				 object:nil];

	}
	return self;
}

// we don't need this one, because the default implementation automatically calls the one w/o owner
// - (id) initWithWindowNibName:(NSString*) nib owner: (id) owner

- (void) windowDidLoad
{

	SLog(@"RDocumentWinCtrl(%@).windowDidLoad", self);

	// Add full screen support for MacOSX Lion or higher
	// [[self window] setCollectionBehavior:[[self window] collectionBehavior] | NSWindowCollectionBehaviorFullScreenPrimary];


	showMatchingBraces = [Preferences flagForKey:showBraceHighlightingKey withDefault: YES];
	argsHints = [Preferences flagForKey:prefShowArgsHints withDefault:YES];

	[[NSUserDefaults standardUserDefaults] addObserver:self forKeyPath:showBraceHighlightingKey options:NSKeyValueObservingOptionNew context:NULL];
	[[NSUserDefaults standardUserDefaults] addObserver:self forKeyPath:prefShowArgsHints options:NSKeyValueObservingOptionNew context:NULL];

	[[self window] setBackgroundColor:[NSColor clearColor]];
	[[self window] setOpaque:NO];

	SLog(@" - load document contents into textView");
	[(RDocument*)[self document] loadInitialContents];

	// If not line wrapping update textView explicitly in order to set scrollView correctly
	if(![Preferences flagForKey:enableLineWrappingKey withDefault: YES])
		[textView updateLineWrappingMode];

	[[textView undoManager] removeAllActions];

	[self helpSearchTypeChanged];

	if(plainFile) [fnListBox setHidden:YES];

	[super windowDidLoad];
	[[self window] makeKeyAndOrderFront:self];

	// TODO control font size due to tollbar setting small or normal
	// now the new size will set for any new opened doc
	pragmaMenuAttribute = [[NSDictionary dictionaryWithObjectsAndKeys:
		[NSColor blueColor], NSForegroundColorAttributeName,
		[fnListBox font], NSFontAttributeName,
	nil] retain];
		functionMenuInvalidAttribute = [[NSDictionary dictionaryWithObjectsAndKeys:
		[NSColor redColor], NSForegroundColorAttributeName,
		[fnListBox font], NSFontAttributeName,
	nil] retain];
	functionMenuCommentAttribute =[[NSDictionary dictionaryWithObjectsAndKeys:
		[NSColor grayColor], NSForegroundColorAttributeName,
		[fnListBox font], NSFontAttributeName,
	nil] retain];

	SLog(@" - scan document for functions");
	// [self functionRescan];

	if([textView lineNumberingEnabled]) {

		SLog(@" - set up line numbering for text view");

		NoodleLineNumberView *theRulerView = [[NoodleLineNumberView alloc] initWithScrollView:[textView enclosingScrollView]];
		[[textView enclosingScrollView] setVerticalRulerView:theRulerView];
		[[textView enclosingScrollView] setHasHorizontalRuler:NO];
		[[textView enclosingScrollView] setHasVerticalRuler:YES];
		[[textView enclosingScrollView] setRulersVisible:YES];
		[theRulerView release];

		[(NoodleLineNumberView*)[[textView enclosingScrollView] verticalRulerView] setLineWrappingMode:[Preferences flagForKey:enableLineWrappingKey withDefault: YES]];

	}
	
	[self functionReset];
	
	// Needed for showing tooltips of folded items
	[[self window] setAcceptsMouseMovedEvents:YES];

	SLog(@" - windowDidLoad is done");

	return;

}

- (void) RDocumentDidResize: (NSNotification *)notification
{
	[self setStatusLineText:[self statusLineText]];
}

- (NSView*) saveOpenAccView
{
	return saveOpenAccView;
}

- (NSUndoManager*) windowWillReturnUndoManager: (NSWindow*) sender
{
	return [[self document] undoManager];
}

- (void) setStatusLineText: (NSString*) text
{

	SLog(@"RDocumentWinCtrl.setStatusLine: \"%@\"", [text description]);

	if(text == nil || ![text length]) {
		[statusLine setStringValue:@""];
		[statusLine setToolTip:@""];
		return;
	}

	// Adjust status line to show a single line in the middle of the status bar
	// otherwise to come up with at least two visible lines
	float w = NSSizeToCGSize([text sizeWithAttributes:[NSDictionary dictionaryWithObject:[statusLine font] forKey:NSFontAttributeName]]).width + 2.0f;
	NSSize p = [statusLine frame].size;
	p.height = (w > p.width) ? 22 : 17;
	[statusLine setFrameSize:p];
	[statusLine setToolTip:text];
	[statusLine setStringValue:text];
	[statusLine setNeedsDisplay:YES];
	// Run NSDefaultRunLoopMode to allow to update status line
	[[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode 
							 beforeDate:[NSDate distantPast]];

}

- (BOOL) hintForFunction: (NSString*) fn
{

	BOOL success = NO;

	if([[self document] hasREditFlag]) {
		[self setStatusLineText:NLS(@"(arguments lookup is disabled while R is busy)")];
		return NO;
	}

	if (preventReentrance && insideR>0) {
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
			}
		}
		[x release];
	}
	[[REngine mainEngine] endProtected];
	return success;
}

- (NSString*) statusLineText
{
	return [statusLine stringValue];
}

- (void) functionReset
{
	SLog(@"RDocumentWinCtrl.functionReset");
	if (fnListBox) {
		NSString *placeHolderStr = @"";
		NSString *tooltipStr = @"";
		if([[[self document] fileType] isEqualToString:ftRSource]) {
			placeHolderStr = NLS(@"<functions>");
			tooltipStr = NLS(@"List of Functions");
		}
		else if([[[self document] fileType] isEqualToString:ftRdDoc]) {
			placeHolderStr = NLS(@"<sections>");
			tooltipStr = NLS(@"List of Sections");
		}
		NSMenuItem *fmi = [[NSMenuItem alloc] initWithTitle:placeHolderStr action:nil keyEquivalent:@""];
		[fmi setTag:-1];
		[fnListBox removeAllItems];
		[fnListBox setToolTip:tooltipStr];
		[[fnListBox menu] addItem:fmi];
		[fmi release];
		[fnListBox setEnabled:NO];
	}
	SLog(@" - reset done");
}

- (void) functionAdd: (NSString*) fn atPosition: (int) pos
{
	if (fnListBox) {
		[fnListBox setEnabled:YES];
		if ([[[fnListBox menu] itemAtIndex:0] tag]==-1)
			[fnListBox removeAllItems];
		NSMenuItem *mi = [fnListBox itemWithTitle:fn];
		if (!mi) {
			mi = [[NSMenuItem alloc] initWithTitle:fn action:@selector(goFunction:) keyEquivalent:@""];
			[mi setTag: pos];
			[[fnListBox menu] addItem:mi];
		} else {
			[mi setTag:pos];
		}
	}
}

- (void) functionGo: (id) sender
{
	NSString *s = [[textView textStorage] string];
	NSMenuItem *mi = (NSMenuItem*) sender;
	int pos = [mi tag];
	if (pos>=0 && pos<[s length]) {
		NSRange fr = NSMakeRange(pos,0);
		[textView setSelectedRange:fr];
		[textView scrollRangeToVisible:fr];
	}
}

- (BOOL) isFunctionScanning
{
	return isFunctionScanning;
}

- (void) functionRescan
{

	if(plainFile || isFunctionScanning || [textView isSyntaxHighlighting]) {
		if(plainFile)
			[fnListBox setEnabled:NO];
		return;
	}

	// Cancel pending functionRescan calls
	[NSObject cancelPreviousPerformRequestsWithTarget:self 
							selector:@selector(functionRescan) 
							object:nil];

	if([textView breakSyntaxHighlighting]) {
		// Cancel calling functionRescan
		[NSObject cancelPreviousPerformRequestsWithTarget:self 
								selector:@selector(functionRescan) 
								object:nil];
		[self performSelector:@selector(functionRescan) withObject:nil afterDelay:0.3f];		
		return;
	}

	isFunctionScanning = YES;

	NSTextStorage *ts = [textView textStorage];
	NSString *s = [ts string];
	unsigned long strLength = [s length];
	int oix = 0;
	int pim = 0;
	int sit = 0;
	int fnf = 0;
	NSMenu *fnm = [fnListBox menu];
	NSRange sr = [textView selectedRange];
	[self functionReset];

	if([s length]<8) {
		isFunctionScanning = NO;
		return;
	}

	NSString *fn = nil;
	NSMenuItem *mi = nil;
	NSAttributedString *fna = nil;

	SLog(@"RDoumentWinCtrl.functionRescan");
	if([[[self document] fileType] isEqualToString:ftRSource]) {

		NSInteger level = 0;        // counter for function declaration inside a function declaration

		// Dummy string for generating n times the string "   " for structuring the menu
		NSString *levelTemplate = @"                                                ";
		NSArray *d = nil;

		// initialise flex
		size_t token;
		NSRange tokenRange;
		symuoffset = 0; symuleng = 0;
		sym_switch_to_buffer(sym_scan_string(NSStringUTF8String(s)));

		// now loop through all the tokens
		while ((token = symlex())) {
			if([textView breakSyntaxHighlighting]) {
				isFunctionScanning = NO;
				return;
			}
			switch (token) {
				case RSYM_FUNCTION: // a valid function name was found
					fn = [NSString stringWithFormat:@" %@%@%@", 
						[levelTemplate substringWithRange:NSMakeRange(0,(level>16) ? 48 : (level*3))], 
						(level)?@" └ ":@"", 
						[s substringWithRange:NSMakeRange(symuoffset, symuleng)]];
					fn = [fn stringByReplacingOccurrencesOfRegex:@"\\s*<.*" withString:@""];
					mi = nil;
					SLog(@" - found function %d:%d \"%@\"", symuoffset, symuleng, fn);
					fnf++;
					if (symuoffset<=sr.location) sit=pim;
					mi = [[NSMenuItem alloc] initWithTitle:fn action:@selector(functionGo:) keyEquivalent:@""];
					[mi setTag:symuoffset];
					[mi setTarget:self];
					[fnm addItem:mi];
					[mi release];
					pim++;
				    break;
				case RSYM_INV_FUNCTION: // an invalid function name was found
					fn = [NSString stringWithFormat:@" %@%@%@", 
						[levelTemplate substringWithRange:NSMakeRange(0,(level>16) ? 48 : (level*3))], 
						(level)?@" └ ":@"", 
						[s substringWithRange:NSMakeRange(symuoffset, symuleng)]];
					fn = [fn stringByReplacingOccurrencesOfRegex:@"\\s*<.*" withString:@""];
					mi = nil;
					SLog(@" - found invalid function %d:%d \"%@\"", symuoffset, symuleng, fn);
					fnf++;
					if (symuoffset<=sr.location) sit=pim;
					mi = [[NSMenuItem alloc] initWithTitle:fn action:@selector(functionGo:) keyEquivalent:@""];
					fna = [[NSAttributedString alloc] initWithString:fn attributes:functionMenuInvalidAttribute];
					[mi setAttributedTitle:fna];
					[fna release];
					[mi setTag:symuoffset];
					[mi setTarget:self];
					[fnm addItem:mi];
					[mi release];
					pim++;
					break;
				case RSYM_METHOD1: // setMethod(f, sig)
					d = [s captureComponentsMatchedByRegex:@"(?m)([\"'])([^\"']+)\\1[^\"']+?([\"'])([^\"']+)\\3" range:NSMakeRange(symuoffset, symuleng)];
					if(d && [d count] == 5) {
						fn = [NSString stringWithFormat:@" %@%@- %@ (%@)", 
							[levelTemplate substringWithRange:NSMakeRange(0,(level>16) ? 48 : (level*3))], 
							(level)?@" └ ":@"", 
							[d objectAtIndex:2], 
							[d lastObject]];
						mi = nil;
						SLog(@" - found method1 %d:%d \"%@\"", symuoffset, symuleng, fn);
						fnf++;
						if (symuoffset<=sr.location) sit=pim;
						mi = [[NSMenuItem alloc] initWithTitle:fn action:@selector(functionGo:) keyEquivalent:@""];
						[mi setTag:symuoffset];
						[mi setTarget:self];
						[fnm addItem:mi];
						[mi release];
						pim++;
					}
				    break;
				case RSYM_METHOD2: // setMethod(sig, f)
					d = [s captureComponentsMatchedByRegex:@"(?m)([\"'])([^\"']+)\\1[^\"']+?([\"'])([^\"']+)\\3" range:NSMakeRange(symuoffset, symuleng)];
					if(d && [d count] == 5) {
						fn = [NSString stringWithFormat:@" %@%@- %@ (%@)", 
							[levelTemplate substringWithRange:NSMakeRange(0,(level>16) ? 48 : (level*3))], 
							(level)?@" └ ":@"", 
							[d lastObject], 
							[d objectAtIndex:2]];
						mi = nil;
						SLog(@" - found method2 %d:%d \"%@\"", symuoffset, symuleng, fn);
						fnf++;
						if (symuoffset<=sr.location) sit=pim;
						mi = [[NSMenuItem alloc] initWithTitle:fn action:@selector(functionGo:) keyEquivalent:@""];
						[mi setTag:symuoffset];
						[mi setTarget:self];
						[fnm addItem:mi];
						[mi release];
						pim++;
					}
				    break;
				case RSYM_CLASS: // setClass
					tokenRange = NSMakeRange(symuoffset, symuleng);
					fn = [NSString stringWithFormat:@" %@%@- (%@)", 
						[levelTemplate substringWithRange:NSMakeRange(0,(level>16) ? 48 : (level*3))], 
						(level)?@" └ ":@"", 
						[[s substringWithRange:tokenRange] stringByMatching:@"([\"'])([^\"']+)\\1" capture:2L]];
					mi = nil;
					SLog(@" - found class %d:%d \"%@\"", symuoffset, symuleng, fn);
					fnf++;
					if (symuoffset<=sr.location) sit=pim;
					mi = [[NSMenuItem alloc] initWithTitle:fn action:@selector(functionGo:) keyEquivalent:@""];
					[mi setTag:symuoffset];
					[mi setTarget:self];
					[fnm addItem:mi];
					[mi release];
					pim++;
				    break;
				case RSYM_PRAGMA: // a literal pragma mark was found; it will displayed in blue to structure large R scripts
					fn = [[s substringWithRange:NSMakeRange(symuoffset, symuleng)] stringByMatching:@"^(#pragma\\s+mark\\s+)(.*?)\\s*$" capture:2L];
					mi = nil;
					SLog(@" - found pragma %d:%d \"%@\"", symuoffset, symuleng, fn);
					fnf++;
					if (symuoffset<=sr.location) sit=pim;
					mi = [[NSMenuItem alloc] initWithTitle:fn action:@selector(functionGo:) keyEquivalent:@""];
					fna = [[NSAttributedString alloc] initWithString:fn attributes:pragmaMenuAttribute];
					[mi setAttributedTitle:fna];
					[fna release];
					[mi setTag:symuoffset];
					[mi setTarget:self];
					[fnm addItem:mi];
					[mi release];
					pim++;
					break;
				case RSYM_PRAGMA_LINE: // insert a menu separator line
					mi = nil;
					SLog(@" - found identifier for separator");
					fnf++;
					if (symuoffset<=sr.location) sit=pim;
					[fnm addItem:[NSMenuItem separatorItem]];
					pim++;
					break;
				case RSYM_LEVEL_DOWN: // { was found; increase level
					level++;
					break;
				case RSYM_LEVEL_UP: // } was found; decrease level
					level--;
					if(level<0) level = 0;
					break;
				default:
					;
			}
		}

	}
	else if([[[self document] fileType] isEqualToString:ftRdDoc]) {
		while (1) {

			NSError *err = nil;

			NSRange r = [s rangeOfRegex:@"\\\\(s(ynopsis\\{|ource\\{|ubsection\\{|e(ction\\{|ealso\\{))|Rd(Opts\\{|version\\{)|n(ote\\{|ame\\{)|concept\\{|title\\{|Sexpr(\\{|\\[)|d(ocType\\{|e(scription\\{|tails\\{))|usage\\{|e(ncoding\\{|xamples\\{)|value\\{|keyword\\{|format\\{|a(uthor\\{|lias\\{|rguments\\{)|references\\{)" options:0 inRange:NSMakeRange(oix,strLength-oix) capture:1 error:&err];
			// RdOpts{, Rdversion{, Sexpr[, Sexpr{, alias{, arguments{, author{, concept{, description{, details{, docType{, encoding{, examples{, format{, keyword{, name{, note{, references{, section{, seealso{, source{, synopsis{, title{, usage{, value{

			// Break if nothing is found
			if (!r.length) break;
			if (err) break;

			oix = NSMaxRange(r);

			SLog(@" - potential section at %d \"\"", r.location, fn);

			int li = r.location-1;

			unichar fc;
			while (li>0 && ((fc=CFStringGetCharacterAtIndex((CFStringRef)s, li)) ==' ' || fc=='\t' || fc=='\r' || fc=='\n')) li--;

			if(RPARSERCONTEXTFORPOSITION(textView, (li+2)) == pcComment)
				continue; // section declaration is commented out

			// due to finial bracket decrease range length by 1
			r.length--;
			fn = [s substringWithRange:r];

			// get (sub)section name
			if([fn isEqualToString:@"section"] || [fn isEqualToString:@"subsection"]) {
				BOOL found = NO;
				NSInteger start = oix;
				NSInteger i = start;
				NSInteger nameLen = 0;
				while(i < strLength) {
					if( CFStringGetCharacterAtIndex((CFStringRef)s,i) == '}' ) {
						found = YES;
						break;
					}
					i++;
					nameLen++;
					if( nameLen > 99 ) {
						break;
					}
				}
				fn = [NSString stringWithFormat:@"%@ - %@%@", 
					fn, 
					[s substringWithRange:NSMakeRange(start, nameLen)], 
					(found) ? @"" : (nameLen<100) ? @"~" : @"…"];
			}

			int fp = r.location-1;
			
			mi = nil;
			fnf++;
			if (fp<=sr.location) sit=pim;
			mi = [[NSMenuItem alloc] initWithTitle:fn action:@selector(functionGo:) keyEquivalent:@""];
			[mi setTag:fp];
			[mi setTarget:self];
			[fnm addItem:mi];
			[mi release];
			pim++;
		}
	}
	if (fnf) {
		[fnListBox setEnabled:YES];
		[fnListBox removeItemAtIndex:0];
		[fnListBox selectItemAtIndex:sit];
	}

	isFunctionScanning = NO;

	SLog(@" - rescan finished (%d sections)", fnf);
}

- (void) updatePreferences {
	SLog(@"RDocumentWinCtrl.updatePreferences");
	// for sanity's sake
	// if (!defaultsInitialized) {
	// 	[RDocumentWinCtrl setDefaultSyntaxHighlightingColors];
	// 	defaultsInitialized=YES;
	// }
	// 
	// NSColor *c = [Preferences unarchivedObjectForKey: backgColorKey withDefault: nil];
	// if (c && c != [[self window] backgroundColor]) {
	// 	[[self window] setBackgroundColor:c];
	// 	//		[[self window] display];
	// }
	// c=[Preferences unarchivedObjectForKey:normalSyntaxColorKey withDefault:nil];
	// if (c) { [shColorNormal release]; shColorNormal = [c retain]; [textView setInsertionPointColor:c]; }
	// c=[Preferences unarchivedObjectForKey:stringSyntaxColorKey withDefault:nil];
	// if (c) { [shColorString release]; shColorString = [c retain]; }
	// c=[Preferences unarchivedObjectForKey:numberSyntaxColorKey withDefault:nil];
	// if (c) { [shColorNumber release]; shColorNumber = [c retain]; }
	// c=[Preferences unarchivedObjectForKey:keywordSyntaxColorKey withDefault:nil];
	// if (c) { [shColorKeyword release]; shColorKeyword = [c retain]; }
	// c=[Preferences unarchivedObjectForKey:commentSyntaxColorKey withDefault:nil];
	// if (c) { [shColorComment release]; shColorComment = [c retain]; }
	// c=[Preferences unarchivedObjectForKey:identifierSyntaxColorKey withDefault:nil];
	// if (c) { [shColorIdentifier release]; shColorIdentifier = [c retain]; }

	// argsHints=[Preferences flagForKey:prefShowArgsHints withDefault:YES];
	// 
	// [self setHighlighting:[Preferences flagForKey:showSyntaxColoringKey withDefault: YES]];
	// showMatchingBraces = [Preferences flagForKey:showBraceHighlightingKey withDefault: YES];
	// [textView setNeedsDisplay:YES];
	SLog(@" - preferences updated");
}

- (IBAction)saveDocumentAs:(id)sender
{

	RDocument *cd = [[RDocumentController sharedDocumentController] currentDocument];

	// if cd document is a REdit call do not allow to save it under another name
	// to preserving REdit editing
	if (cd && [cd hasREditFlag]) {
		[cd saveDocument:sender];
		return;
	}
	[cd saveDocumentAs:sender];
}

- (IBAction)saveDocument:(id)sender
{

	RDocument *cd = [[RDocumentController sharedDocumentController] currentDocument];

	// if cd document is a REdit call ensure that the last character is a line ending
	// to avoid error in edit()
	if (cd && [cd hasREditFlag]) {
		NSRange selectedRange = [textView selectedRange];
		if(![[textView string] length])
			[[[textView textStorage] mutableString] setString:@"\n"];
		if([[textView string] characterAtIndex:[[textView string] length]-1] != '\n') {
			[[[textView textStorage] mutableString] appendString:@"\n"];
			[textView setSelectedRange:NSIntersectionRange(selectedRange, NSMakeRange(0, [[textView string] length]))];
		}
	}
	[cd saveDocument:sender];
}

- (IBAction)printDocument:(id)sender
{
	NSPrintInfo *printInfo;
	NSPrintInfo *sharedInfo;
	NSPrintOperation *printOp;
	NSMutableDictionary *printInfoDict;
	NSMutableDictionary *sharedDict;
	
	sharedInfo = [NSPrintInfo sharedPrintInfo];
	sharedDict = [sharedInfo dictionary];
	printInfoDict = [NSMutableDictionary dictionaryWithDictionary:
		sharedDict];
	
	printInfo = [[NSPrintInfo alloc] initWithDictionary: printInfoDict];
	[printInfo setHorizontalPagination: NSFitPagination];
	[printInfo setVerticalPagination: NSAutoPagination];
	[printInfo setVerticallyCentered:NO];
	
	[textView setBackgroundColor:[NSColor whiteColor]];
	printOp = [NSPrintOperation printOperationWithView:textView 
											 printInfo:printInfo];
	[printOp setShowPanels:YES];

	[printOp runOperationModalForWindow:[self window] 
							   delegate:self 
						 didRunSelector:@selector(sheetDidEnd:returnCode:contextInfo:) 
						    contextInfo:@""];
	[self updatePreferences];
}

- (IBAction)reInterpretDocument:(id)sender;
{

	RDocument* doc = [[NSDocumentController sharedDocumentController] documentForWindow:[NSApp keyWindow]];
	if(doc)
		[doc reinterpretInEncoding:(NSStringEncoding)[[sender representedObject] unsignedIntValue]];
	else
		NSBeep();

}

- (IBAction)shiftRight:(id)sender
{
	[textView shiftSelectionRight];
}

- (IBAction)shiftLeft:(id)sender
{
	[textView shiftSelectionLeft];
}

- (IBAction)goToLine:(id)sender
{
	[NSApp beginSheet:goToLineSheet
	   modalForWindow:[self window]
		modalDelegate:self
	   didEndSelector:@selector(sheetDidEnd:returnCode:contextInfo:)
	      contextInfo:@"goToLine"];
}

- (IBAction)goToLineCloseSheet:(id)sender
{
	[NSApp endSheet:goToLineSheet returnCode:[sender tag]];
}

- (void) setHighlighting: (BOOL) use
{
	useHighlighting=use;
	if (textView) {
		if (use)
			[textView performSelector:@selector(doSyntaxHighlighting) withObject:nil afterDelay:0.0];
		else
			[textView setTextColor:[NSColor blackColor] range:NSMakeRange(0,[[textView textStorage] length])];
	}
}

- (void)highlightBracesAfterDidProcessEditing
{
	[self highlightBracesWithShift:0 andWarn:YES];
}

- (void) highlightBracesWithShift: (int) shift andWarn: (BOOL) warn
{

	NSString *completeString = [[textView textStorage] string];
	NSUInteger completeStringLength = [completeString length];
	if (completeStringLength < 2) return;
	
	NSRange selRange = [textView selectedRange];
	NSInteger cursorLocation = selRange.location;
	cursorLocation += shift; // add any shift as cursor movement guys need it
	if (cursorLocation < 0 || cursorLocation >= completeStringLength) return;

	// bail if current character is in quotes or comments
	if(RPARSERCONTEXTFORPOSITION(textView, cursorLocation) != pcExpression) return;

	unichar characterToCheck;
	unichar openingChar = 0;
	characterToCheck = CFStringGetCharacterAtIndex((CFStringRef)completeString, cursorLocation);
	int skipMatchingBrace = 0;
	
	[textView resetHighlights];
	if (characterToCheck == ')') openingChar='(';
	else if (characterToCheck == ']') openingChar='[';
	else if (characterToCheck == '}') openingChar='{';

	unichar c;
	NSInteger breakCounter = 3000;
	// well, this is rather simple so far, because it ignores cross-quoting, but for a first shot it's not too bad ;)
	if (openingChar) {
		while (cursorLocation--) {
			if(!breakCounter--) return;
			if(RPARSERCONTEXTFORPOSITION(textView, cursorLocation) == pcExpression) {
				c = CFStringGetCharacterAtIndex((CFStringRef)completeString, cursorLocation);
				if (c == openingChar) {
					if (!skipMatchingBrace) {
						[textView performSelector:@selector(highlightCharacter:) withObject:[NSNumber numberWithInt:cursorLocation] afterDelay:0.01];
						return;
					} else
						skipMatchingBrace--;
				} else if (c == characterToCheck)
					skipMatchingBrace++;
			}
		}
		if (warn) NSBeep();
	} else { // ok, now reverse the roles and find the closing brace (if any)
		unsigned maxLimit=completeStringLength;
		//if (cursorLocation-maxLimit>4000) maxLimit=cursorLocation+4000; // just a soft limit to not search too far (but I think we're fast enough...)
		if (characterToCheck == '(') openingChar=')';
		else if (characterToCheck == '[') openingChar=']';
		else if (characterToCheck == '{') openingChar='}';
		if (openingChar) {
			while ((++cursorLocation)<maxLimit) {
				if(!breakCounter--) return;
				if(RPARSERCONTEXTFORPOSITION(textView, cursorLocation) == pcExpression) {
					c = CFStringGetCharacterAtIndex((CFStringRef)completeString, cursorLocation);
					if (c == openingChar) {
						if (!skipMatchingBrace) {
							[textView performSelector:@selector(highlightCharacter:) withObject:[NSNumber numberWithInt:cursorLocation] afterDelay:0.01];
							return;
						} else
							skipMatchingBrace--;
					} else if (c == characterToCheck)
						skipMatchingBrace++;
				}
			}
		}
	}
}

- (BOOL)textView:(NSTextView *)textViewSrc doCommandBySelector:(SEL)commandSelector {
	BOOL retval = NO;
	if (textViewSrc!=textView) return NO;
	//NSLog(@"RTextView commandSelector: %@\n", NSStringFromSelector(commandSelector));
	if (@selector(insertNewline:) == commandSelector && execNewlineFlag) {
		execNewlineFlag=NO;
		return YES;
	}
	if (@selector(insertNewline:) == commandSelector) {

		if(![[NSUserDefaults standardUserDefaults] boolForKey:indentNewLines]) return NO;

		// handling of indentation
		// currently we just copy what we get and add tabs for additional non-matched { brackets
		NSTextStorage *ts = [textView textStorage];
		NSString *s = [ts string];
		NSRange csr = [textView selectedRange];
		NSRange ssr = NSMakeRange(csr.location, 0);
		NSRange lr = [s lineRangeForRange:ssr];

		[self setStatusLineText:@""];

		// line on which enter was pressed - this will be taken as guide
		if (csr.location>0) {
			int i = lr.location;
			int last = csr.location;
			int whiteSpaces = 0, addShift = 0;
			BOOL initial=YES;
			BOOL caretIsAdjacentCurlyBrackets = NO;
			NSString *indentString = @"\t";
			NSString *wss = @"\n";
			NSString *wssForClosingCurlyBracket = @"";
			while (i<last) {
				unichar c=CFStringGetCharacterAtIndex((CFStringRef)s,i);
				if (initial) {
					if (c=='\t' || c==' ') {
						whiteSpaces++;
					}
					else initial=NO;
				}
				if (c=='{') addShift++;
				if (c=='}' && addShift>0) addShift--;
				i++;
			}
			if(lastLineWasCodeIndented && [textView parserContextForPosition:NSMaxRange(lr)] != pcComment) {
				lastLineWasCodeIndented = NO;
				whiteSpaces--;
			}
			if (whiteSpaces>0)
				wss = [wss stringByAppendingString:[s substringWithRange:NSMakeRange(lr.location,whiteSpaces)]];
			if(last > 0 && CFStringGetCharacterAtIndex((CFStringRef)s,last-1) == '{' && last < NSMaxRange(lr) && [s characterAtIndex:last] == '}') {
				wssForClosingCurlyBracket = [NSString stringWithString:wss];
				caretIsAdjacentCurlyBrackets = YES;
			}
			while (addShift>0) { wss=[wss stringByAppendingString:indentString]; addShift--; }
			// add an undo checkpoint before actually committing the changes
			[textView breakUndoCoalescing];
			[textView insertText:wss];

			// if caret is adjacent by {} add new line with the original indention
			// and place the caret one line up at the line's end
			if(caretIsAdjacentCurlyBrackets) {
				[textView insertText:wssForClosingCurlyBracket];
				[textView doCommandBySelector:@selector(moveUp:)];
				[textView doCommandBySelector:@selector(moveToEndOfLine:)];
			}


			else if([Preferences flagForKey:indentNewLineAfterSimpleClause withDefault:NO]) {

				// indent only next line after simple if,for,while,function commands without trailing {
				// and if line has more opened ( than )
				NSString *line = [[textView string] substringWithRange:lr];
				if([line length] > 3) {
					NSInteger cntP = 0;
					NSInteger lastClosedP = -1;
					BOOL oneBlock = YES;
					BOOL firstRun = YES;
					unichar c;
					for(i=0; i<[line length]; i++) {
						if(RPARSERCONTEXTFORPOSITION(textView, i) == pcExpression) {
							c=CFStringGetCharacterAtIndex((CFStringRef)line,i);
							if(c==')') {
								cntP--;
								lastClosedP = i;
							}
							else if (c=='(') {
								if(oneBlock && !firstRun && cntP == 0) {
									oneBlock = NO;
								}
								firstRun = NO;
								cntP++;
							}
						}
					}
					if(cntP > 0) {
						[textView breakUndoCoalescing];
						[textView insertText:indentString];
					} 
					else if(oneBlock && lastClosedP > -1
						&& [[line substringFromIndex:lastClosedP] isMatchedByRegex:@"^\\)[ \t]*$"] 
						&& ([line isMatchedByRegex:@"^[ \t]*(if|for|while)[ \t]*\\(.+\\)[ \t]*$"]
							|| [line isMatchedByRegex:@"(<-|=)[ \t]*function[ \t]*\\(.*\\)[ \t]*$"])) {
						[textView breakUndoCoalescing];
						[textView insertText:indentString];
						lastLineWasCodeIndented = YES;
					}
				}
			}

			// [textView setNeedsDisplayInRect:[textView frame]];
			return YES;
		}
	}
	if (showMatchingBraces && ![self plain]) {
		if (commandSelector == @selector(deleteBackward:)) {
			[textView setDeleteBackward:YES];
			lastLineWasCodeIndented = NO;
		}
		if (commandSelector == @selector(moveLeft:))
			[self highlightBracesWithShift: -1 andWarn:NO];
		if(commandSelector == @selector(moveRight:))
			[self highlightBracesWithShift: 0 andWarn:NO];
	}
	return retval;
}

- (NSMenu *)textView:(NSTextView *)view menu:(NSMenu *)menu forEvent:(NSEvent *)event atIndex:(NSUInteger)charIndex
{

	if(view != textView) return menu;

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

- (NSArray *)textView:(NSTextView *)aTextView completions:(NSArray *)words forPartialWordRange:(NSRange)charRange indexOfSelectedItem:(NSInteger *)index 
{

	NSInteger scopeBias = 500;

	NSRange sr = [aTextView selectedRange];
	BOOL texMode = (sr.location && [[textView string] characterAtIndex:sr.location-1] == '\\') ? YES : NO;

	unsigned caretPosition = NSMaxRange(sr);

	SLog(@"completion attempt; cursor at %d, complRange: %d-%d", sr.location, charRange.location, charRange.location+charRange.length);

	if(charRange.length)
		*index=0;
	else
		*index=-1;

	// avoid selecting of token if nothing was found
	// [textView setSelectedRange:NSMakeRange(NSMaxRange(sr), 0)];

	NSMutableSet *uniqueArray = [NSMutableSet setWithCapacity:100];
	
	NSString *currentWord = [[aTextView string] substringWithRange:charRange];

	if([self isRdDocument]) {
		if(texMode) {
			if(sr.length) {
				NSPredicate *predicate = [NSPredicate predicateWithFormat:@"SELF BEGINSWITH %@", currentWord];
				NSArray *result = [texItems filteredArrayUsingPredicate:predicate];
				if(result && [result count])
					[uniqueArray addObjectsFromArray:result];
			} else {
				[uniqueArray addObjectsFromArray:texItems];
			}
		} else {
			// For better current function detection we pass maximal 1000 left from caret
			// and considering full starting line
			NSRange scopeRange;
			NSInteger breakCounter = 1000;
			NSString *str = [aTextView string];
			if(sr.location > scopeBias) {
				NSInteger start = sr.location - scopeBias;
				if (start > 0)
					while(start > 0) {
						if(!breakCounter--) break;
						if(CFStringGetCharacterAtIndex((CFStringRef)str, start)=='\n')
							break;
						start--;
					}
				if(start < 0) start = 0;
				scopeRange = NSMakeRange(start, caretPosition - start);
			} else {
				scopeRange = NSMakeRange(0, caretPosition);
			}
			[uniqueArray addObjectsFromArray:[CodeCompletion retrieveSuggestionsForScopeRange:scopeRange inTextView:aTextView]];
			[uniqueArray addObjectsFromArray:words];
		}
	} else {
		// For better current function detection we pass maximal scopeBias left from caret
		// and considering full starting line
		NSRange scopeRange;
		NSInteger breakCounter = 1000;
		NSString *str = [aTextView string];
		if(sr.location > scopeBias) {
			NSInteger start = sr.location - scopeBias;
			if (start > 0)
				while(start > 0) {
					if(!breakCounter--) break;
					if(CFStringGetCharacterAtIndex((CFStringRef)str, start)=='\n')
						break;
					start--;
				}
			if(start < 0) start = 0;
			scopeRange = NSMakeRange(start, caretPosition - start);
		} else {
			scopeRange = NSMakeRange(0, caretPosition);
		}
		[uniqueArray addObjectsFromArray:[CodeCompletion retrieveSuggestionsForScopeRange:scopeRange inTextView:aTextView]];
	}

	// Only parse for words if text size is less than 3MB
	if([currentWord length]>1 && [[aTextView string] length] && [[aTextView string] length]<3000000) {
		NSMutableString *parserString = [NSMutableString string];
		[parserString setString:[aTextView string]];
		// ignore any words in quotes or comments
		[parserString replaceOccurrencesOfRegex:@"(?<!\\\\)\\\\['\"]" withString:@""];
		[parserString replaceOccurrencesOfRegex:@"([\"']).*?\\1" withString:@""];
		if(![self isRdDocument])
			[parserString replaceOccurrencesOfRegex:@"#.*" withString:@""];
		NSString *re;
		if(texMode && [self isRdDocument])
			re = [NSString stringWithFormat:@"(?<=\\\\)%@[\\w\\d]+", currentWord];
		else
		 	re = [NSString stringWithFormat:@"(?<!\\.)\\b%@[\\w\\d\\.:_]+", currentWord];

		if([re isRegexValid]) {
			NSArray *words = [parserString componentsMatchedByRegex:re];
			if(words && [words count]) {
				[uniqueArray addObjectsFromArray:words];
			}
		}
	}

	[uniqueArray removeObject:currentWord];

	NSInteger reverseSort = NO;

	return [[uniqueArray allObjects] sortedArrayUsingFunction:_alphabeticSort context:&reverseSort];
}

- (NSString *)textView:(NSTextView *)tv willDisplayToolTip:(NSString *)tooltip forCharacterAtIndex:(NSUInteger)characterIndex
{
	if([tv isKindOfClass:[RScriptEditorTextView class]]) {
		// After undoing it could happen that a tooltip is still stored
		// whereby the folded chunk was removed, thus remove it
		// <TODO> find a better method
		if([(RScriptEditorTextStorage*)[tv textStorage] foldedAtIndex:characterIndex] < 0) {
			NSRange eff;
			[(RScriptEditorTextStorage*)[tv textStorage] attribute:NSToolTipAttributeName atIndex:characterIndex longestEffectiveRange:&eff inRange:NSMakeRange(0, [[tv string] length])];
			[(RScriptEditorTextStorage*)[tv textStorage] removeAttribute:NSCursorAttributeName range:eff];
			[(RScriptEditorTextStorage*)[tv textStorage] removeAttribute:NSToolTipAttributeName range:eff];
			return nil;
		}
		[RTooltip showWithObject:[NSString stringWithFormat:@"<pre>%@</pre>", tooltip] 
				atLocation:NSMakePoint(-1,-1)
				ofType:@"html" 
				displayOptions:[NSDictionary dictionaryWithObjectsAndKeys:
				[[textView font] familyName], @"fontname", 
				[NSString stringWithFormat:@"%f", [[textView font] pointSize]], @"fontsize", 
					nil]
					];
		return nil;
	}
	return tooltip;
}

- (void)textViewDidChangeSelection:(NSNotification *)aNotification
{

	if(![[aNotification object] isKindOfClass:[RTextView class]]) return;

	RTextView *tv = [aNotification object];

#if MAC_OS_X_VERSION_MIN_REQUIRED >= MAC_OS_X_VERSION_10_5
	// TODO set it to YES for fast editing of very large docs
	// but there're issues for syntax hiliting and scrollview stability
	[[tv layoutManager] setAllowsNonContiguousLayout:NO];
#endif

	if([[NSUserDefaults standardUserDefaults] boolForKey:highlightCurrentLine])
		[tv setNeedsDisplayInRect:[tv visibleRect] avoidAdditionalLayout:YES];

	// Adjust cursor position if cursor is inside of a folded text chunk;
	// additional checks were made in [RScriptEditorTextView:setSelectedRanges:]
	if([tv isKindOfClass:[RScriptEditorTextView class]]) {
		NSRange r = [tv selectedRange];
		NSUInteger len = [[tv string] length];
		if(r.location < len) {
			NSInteger foldIndex = [(RScriptEditorTextStorage*)[tv textStorage] foldedAtIndex:r.location];
			if(foldIndex > -1) {
				NSRange effectiveRange = [(RScriptEditorTextStorage*)[tv textStorage] foldedRangeAtIndex:foldIndex];
				if(effectiveRange.length) {
					if(r.location > effectiveRange.location && r.location < NSMaxRange(effectiveRange)) {
						[(RScriptEditorTextView*)tv unfoldLinesContainingCharacterAtIndex:r.location];
					}
				}
			}
		}
	}

	if(argsHints && ![[self document] hasREditFlag] && ![self plain]) {

		// show functions hints due to current caret position or selection
		SLog(@"RDocumentWinCtrl: textViewDidChangeSelection and calls currentFunctionHint");

		// Cancel pending currentFunctionHint calls
		[NSObject cancelPreviousPerformRequestsWithTarget:tv 
								selector:@selector(currentFunctionHint) 
								object:nil];

		// update current function hint
		[tv performSelector:@selector(currentFunctionHint) withObject:nil afterDelay:0.1f];

		// update function list to display the function in which the cursor is located
		// by iterating through the fnListBox menu items
		if(fnListBox && [fnListBox isEnabled]) {
			CFArrayRef items    = (CFArrayRef)[[fnListBox menu] itemArray];
			NSUInteger pos      = [tv selectedRange].location;
			NSInteger listItem  = -100;
			NSInteger fnStart   = 0;
			NSInteger itemCount = (NSInteger)CFArrayGetCount(items);
			for(NSInteger i=0; i < itemCount; i++) {
				fnStart = (NSInteger)[(NSMenuItem*)CFArrayGetValueAtIndex(items, i) tag];
				if(pos <= fnStart) {
					listItem = i - ((pos == fnStart) ? 0 : 1);
					break;
				}
			}
			if(listItem == -100)  // for loop didn't find -> cursor in last item
				listItem = itemCount-1;
			else if(listItem < 0) // cursor in first item
				listItem = 0;
			[fnListBox selectItemAtIndex:listItem];
		}
	}
}

- (void)sheetDidEnd:(id)sheet returnCode:(int)returnCode contextInfo:(NSString *)contextInfo
{

	SLog(@"RDocumentWinCtrl: sheetDidEnd: returnCode: %d contextInfo: %@", returnCode, contextInfo);

	// Order out the sheet - could be a NSPanel or NSWindow
	if ([sheet respondsToSelector:@selector(orderOut:)]) {
		[sheet orderOut:nil];
	}
	else if ([sheet respondsToSelector:@selector(window)]) {
		[[sheet window] orderOut:nil];
	}

	// callback for "Go To Line Number"
	if([contextInfo isEqualToString:@"goToLine"]) {
		if(returnCode == 1) {
			NSRange currentLineRange = NSMakeRange(0, 0);
			NSString *s = [[textView textStorage] string];
			int lineCounter = 0;
			int l = [goToLineField intValue];

			while(lineCounter++ < l)
				currentLineRange = [s lineRangeForRange:NSMakeRange(NSMaxRange(currentLineRange), 0)];

			SLog(@" - go to line %d", l);
			// select found line
			[textView setSelectedRange:currentLineRange];
			// scroll to found line
			[textView centerSelectionInVisibleArea:nil];
			// remove selection after 500ms
			[textView performSelector:@selector(moveLeft:) withObject:nil afterDelay:0.5];

		}
	}

	// Make window at which the sheet was attached key window
	[[self window] makeKeyAndOrderFront:nil];

}

- (BOOL)windowShouldClose:(id)sender
{

	SLog(@"RDocumentWinCtrl%@.windowShouldClose: (doc=%@, win=%@, self.rc=%d)", self, [self document], [self window], [self retainCount]);

	// Cancel pending calls
	[NSObject cancelPreviousPerformRequestsWithTarget:[[textView enclosingScrollView] verticalRulerView] 
							selector:@selector(refresh) 
							object:nil];

	[NSObject cancelPreviousPerformRequestsWithTarget:textView 
							selector:@selector(currentFunctionHint) 
							object:nil];

	[NSObject cancelPreviousPerformRequestsWithTarget:textView 
							selector:@selector(doSyntaxHighlighting) 
							object:nil];

	[NSObject cancelPreviousPerformRequestsWithTarget:self 
							selector:@selector(functionRescan) 
							object:nil];

	return YES;

}

- (void) close
{
	SLog(@"RDocumentWinCtrl<%@>.close", self);	
	[super close];
}

- (void) setEditable: (BOOL) editable
{
	[textView setEditable:editable];
}

- (IBAction)tidyRCode: (id)sender
{

	if(isFormattingRcode) return;

	isFormattingRcode = YES;

	[self setStatusLineText:[NSString stringWithFormat:@"%@ (%@)", NLS(@"Formatting…"), NLS(@"press ⌘. to cancel")]];

	NSMutableString *tidyStr = [NSMutableString string];
	NSString *startIndentation = @"";
	NSUInteger lineOffset = 0;

	NSString *tempRFuncFile = [NSString stringWithFormat:@"%@/RGUI_Rtidy_func.R", NSTemporaryDirectory()];
	NSString *tempRFile = [NSString stringWithFormat:@"%@/RGUI_Rtidy.R", NSTemporaryDirectory()];
	NSString *tempErrFile = [NSString stringWithFormat:@"%@/RGUI_Rtidy_func_error.txt", NSTemporaryDirectory()];

	if([textView selectedRange].length) {

		[tidyStr setString:[[textView string] substringWithRange:[textView selectedRange]]];
		if([tidyStr length] < 2) {
			[self setStatusLineText:@""];
			isFormattingRcode = NO;
			return;
		}
		if([tidyStr isMatchedByRegex:@"[\n\r]$"]) {
			[textView setSelectedRange:NSMakeRange([textView selectedRange].location, [textView selectedRange].length-1)];
		}

		// get start indention for selected text
		startIndentation = [tidyStr stringByMatching:@"^([ \t]*)" capture:1L];

		// go through all empty lines and replace them by "....e_m_p_t_y....=0"
		// to preserve the user's structure
		[tidyStr replaceOccurrencesOfRegex:@"(?m-s:^[ \t]*$)" withString:@"....e_m_p_t_y....=0"];

		// prefix the selected text with n empty lines according
		// the cursor location for possible line numbers in error message
		NSString *string = [textView string];
		NSUInteger index, stringLength = [string length];
		NSUInteger currentCursorPosition = [textView selectedRange].location;
		for (index = 0; index < stringLength; lineOffset++) {
		    index = NSMaxRange([string lineRangeForRange:NSMakeRange(index, 0)]);
			if(index > currentCursorPosition)
				break;
		}

	} else {
		[tidyStr setString:[textView string]];
		if([tidyStr length] < 2) {
			[self setStatusLineText:@""];
			isFormattingRcode = NO;
			return;
		}
		// go through all empty lines and replace them by "....e_m_p_t_y....=0"
		// to preserve the user's structure
		[tidyStr replaceOccurrencesOfRegex:@"(?m-s:^[ \t]*$)" withString:@"....e_m_p_t_y....=0"];
	}


	NSString *rs = nil;
	NSRange r;
	NSString *comre = @"^\\s*(#([^\n]*))";
	NSRange searchRange = NSMakeRange(0, [tidyStr length]);

	// first line begins with a comment?
	if([tidyStr isMatchedByRegex:comre inRange:searchRange]) {
		r = [tidyStr rangeOfRegex:comre options:0 inRange:searchRange capture:1L error:nil];
		rs = [tidyStr substringWithRange:[tidyStr rangeOfRegex:comre options:0 inRange:searchRange capture:2L error:nil]];
		rs = [rs stringByReplacingOccurrencesOfString:@"\"" withString:@"\\\""];
		[tidyStr replaceCharactersInRange:r withString:[NSString stringWithFormat:@"c=\"@_@_@_@%@\"", rs]];
		[tidyStr flushCachedRegexData];
		searchRange = NSMakeRange(NSMaxRange(r), [tidyStr length]-NSMaxRange(r));
	}

	[tidyStr setString:[NSString stringWithFormat:@"dummy<-function(){%@\n}\n", tidyStr]];

	// go through all comment lines beginning with a #
	// and replace them by e.g. "c="@_@_@_@print 1""
	comre = @"\n\\s*(#([^\n]*))";
	searchRange = NSMakeRange(0, [tidyStr length]);
	while([tidyStr isMatchedByRegex:comre inRange:searchRange]) {
		r = [tidyStr rangeOfRegex:comre options:0 inRange:searchRange capture:1L error:nil];
		rs = [tidyStr substringWithRange:[tidyStr rangeOfRegex:comre options:0 inRange:searchRange capture:2L error:nil]];
		rs = [rs stringByReplacingOccurrencesOfString:@"\"" withString:@"\\\""];
		[tidyStr replaceCharactersInRange:r withString:[NSString stringWithFormat:@"c=\"@_@_@_@%@\"", rs]];
		[tidyStr flushCachedRegexData];
		searchRange = NSMakeRange(r.location+[rs length], [tidyStr length]-r.location-[rs length]);
	}
	NSEvent* event = [NSApp nextEventMatchingMask:NSAnyEventMask
										untilDate:[NSDate distantPast]
										   inMode:NSDefaultRunLoopMode
										  dequeue:YES];
	if(event){
		if ([event type] == NSKeyDown) {
			unichar key = [[event characters] length] == 1 ? [[event characters] characterAtIndex:0] : 0;
			if (([event modifierFlags] & NSCommandKeyMask) && key == '.') {
				SLog(@"RDocumentWinCtrl.tidyRCode terminated by user");
				[[NSFileManager defaultManager] removeItemAtPath:tempRFuncFile error:NULL];
				[[NSFileManager defaultManager] removeItemAtPath:tempRFile error:NULL];
				[[NSFileManager defaultManager] removeItemAtPath:tempErrFile error:NULL];
				[self setStatusLineText:@""];
				isFormattingRcode = NO;
				return;
			}
		}
		[NSApp sendEvent:event];
	}

	// check for comments at end of lines as for print(1) # print 1
	// and replace them by e.g. "print(1) ;c="@__@_@_@print 1" "
	comre = @"(?s)(#([^\n]*))";
	RTextView *rtv = [[RTextView alloc] init];
	[rtv insertText:tidyStr];
	searchRange = NSMakeRange(0, [[rtv string] length]);
	NSRange fr;
	NSString *rstr = nil;
	NSString *rtvstr = [rtv string];
	while(1) {
		fr = [rtvstr rangeOfString:@"#" options:0 range:searchRange];
		if(!fr.length) break;
		r = [rtvstr rangeOfRegex:comre options:0 inRange:NSMakeRange(fr.location, [rtvstr length]-fr.location) capture:1L error:nil];
		// check if first # is a comment character i.e. not quoted
		if(r.location+1 < [rtvstr length] && RPARSERCONTEXTFORPOSITION(rtv, r.location+1) == pcComment) {
			rs = [rtvstr substringWithRange:[rtvstr rangeOfRegex:comre options:0 inRange:NSMakeRange(fr.location, [rtvstr length]-fr.location) capture:2L error:nil]];
			rs = [rs stringByReplacingOccurrencesOfString:@"\"" withString:@"\\\""];
			rstr = [NSString stringWithFormat:@";c=\"@__@_@_@%@\"", rs];
			[rtv replaceCharactersInRange:r withString:rstr];
			[rtvstr flushCachedRegexData];
			searchRange = NSMakeRange(r.location + [rstr length], [rtvstr length] - r.location - [rstr length]);
		} else {
			searchRange.location = fr.location+1;
			searchRange.length = [rtvstr length]-fr.location-1;
			searchRange = NSIntersectionRange(searchRange, NSMakeRange(0,[[rtv string] length]));
			[rtvstr flushCachedRegexData];
		}
	}
	[tidyStr setString:[rtv string]];
	[rtv release];

	// Write R code to file
	[tidyStr writeToFile:tempRFuncFile atomically:YES encoding:NSUTF8StringEncoding error:nil];

	NSInteger usersWidthCutoff = [Preferences integerForKey:RScriptEditorFormatWidthCutoff withDefault:0];
	NSInteger width = 60;
	// if usersWidthCutoff == 0 -> calculate deparse's width.cutoff due to window width
	if(usersWidthCutoff > 0) {
		width = usersWidthCutoff;
	} else {
		// We assume that a 'W' is the widest character and get its width
		NSAttributedString *s = [[NSAttributedString alloc] initWithString:@"W" attributes:
			[NSDictionary dictionaryWithObject:[textView font] forKey:NSFontAttributeName]];
		float char_maxWidth = [s size].width;
		[s release];
		int newSize = (int)[textView visibleRect].size.width-(int)(2*char_maxWidth);
		width = (int)(newSize/char_maxWidth)-8; // minus an empirical margin
	}
	if(width<20)
		width=20;
	else if(width>500)
		width=500;

	SLog(@"RDocumentWinCtrl.tidyRCode - width.cutoff was set to %d", width);

	// init R function for deparsing
	NSString *tidyR = [NSString stringWithFormat:
		@"options(keep.source = FALSE)\n"
		"options(warn = -1)\n"
		"options(show.error.messages = TRUE)\n"
		"source(\"%@\")\n"
		"cat(paste(deparse(dummy,width.cutoff=%dL,control=c(\"keepInteger\", \"keepNA\", \"quoteExpressions\")),collapse='\n'))",
			tempRFuncFile, width];

	[tidyR writeToFile:tempRFile atomically:YES encoding:NSUTF8StringEncoding error:nil];

	// run tidy command as separate R session
	NSString *tidyCmd = [NSString stringWithFormat:
			@"R --vanilla --slave --encoding=UTF-8 < %@ 2> %@" // run R's deparse
			@" | sed '1,2d;$d' |" // delete first two lines and the last one = dummy wrapper function
			@" perl -e '$a=0;$b=0;$t=\"\t\";$p=\"@__@__@__@\";while(<>){"
			@"s/^\\s*\\.{4}e_m_p_t_y\\.{4} = 0$//g;" // recover empty lines
			@"s/^ {4}/@__@__@__@/g;" // recover start indention by temporary placeholder
			// get rid of 4 spaces followed by two
			@"m/^@__@__@__@( *)(?=\\S)/;$a=length($1);if($a<=12){$b=$a/4}else{$b=3+(($a-12)/2)};s/^@__@__@__@( *)(?=\\S)/$p.$t x $b/eg;" 
			@"s/^@__@__@__@/%@/g;" // recover start indention finally
			@"print};'"
				, tempRFile, tempErrFile, startIndentation];

	NSError *bashError = nil;
	NSString *tidiedStr = [tidyCmd evaluateAsBashCommandAndError:&bashError];

	NSString *errMessage = @"";

	if(bashError != nil) {
		errMessage = [[bashError userInfo] objectForKey:NSLocalizedDescriptionKey];
	}

	// read outputted data
	NSError *error1 = nil;
	NSString *errMessages = [[[NSString alloc]
		initWithContentsOfFile:tempErrFile
			encoding:NSUTF8StringEncoding
				error:&error1] autorelease];

	if(error1 != nil) {
		SLog(@"RDocumentWinCtrl.tidyRCode read error.\n%@", error1);
		[[NSFileManager defaultManager] removeItemAtPath:tempRFuncFile error:NULL];
		[[NSFileManager defaultManager] removeItemAtPath:tempRFile error:NULL];
		[[NSFileManager defaultManager] removeItemAtPath:tempErrFile error:NULL];
		[self setStatusLineText:@""];
		isFormattingRcode = NO;
		return;
	}
	if([errMessage length])
		errMessages = [NSString stringWithFormat:@"%@\n%@", errMessage, errMessages];
	if([errMessages length]) {
		// Clean error message
		errMessages = [errMessages stringByReplacingOccurrencesOfRegex:@"(?s)^.*?\n" withString:@""];
		errMessages = [errMessages stringByReplacingOccurrencesOfRegex:@"dummy<-function\\(\\)\\{" withString:@""];
		errMessages = [errMessages stringByReplacingOccurrencesOfRegex:@"\\.{4}e_m_p_t_y\\.{4}=0" withString:@""];
		errMessages = [errMessages stringByReplacingOccurrencesOfRegex:@"(?m-s);?c=\"@__?@_@_@(.*?)\"" withString:@"#$1"];
		errMessages = [errMessages stringByReplacingOccurrencesOfRegex:@" *\\^" withString:@""];

		// Find error line number
		NSInteger errorLineNumber = -1;
		NSArray *a = [errMessages componentsMatchedByRegex:@"\n(\\d+):" capture:1L];
		NSInteger i;
		NSInteger firstErrorLine = 0;
		NSInteger anErrorLine;
		for(i=0; i<[a count]; i++) {
			anErrorLine = [(NSString*)[a objectAtIndex:i] integerValue];
			if(anErrorLine > 0 && (anErrorLine > firstErrorLine))
				firstErrorLine = anErrorLine;
		}
		errorLineNumber = firstErrorLine;
		[self setStatusLineText:@""];

		NSAlert *alert = [NSAlert alertWithMessageText:NLS(@"Parsing Error") 
				defaultButton:NLS(@"OK") 
				alternateButton:nil 
				otherButton:nil 
				informativeTextWithFormat:errMessages];

		[alert setAlertStyle:NSWarningAlertStyle];
		[alert runModal];
		[[self window] makeKeyAndOrderFront:self];
		[[self window] makeFirstResponder:textView];

		// for selection synchronize line number
		errorLineNumber += --lineOffset;

		// Go to possible error line
		if(errorLineNumber >=0) {
			NSRange currentLineRange = NSMakeRange(0, 0);
			NSString *s = [[textView textStorage] string];
			NSInteger lineCounter = 0;

			while(lineCounter++ < errorLineNumber)
				currentLineRange = [s lineRangeForRange:NSMakeRange(NSMaxRange(currentLineRange), 0)];

			SLog(@"RDocumentWinCtrl.tidyRCode - go to error line number %d", errorLineNumber);
			// select found line
			[textView setSelectedRange:currentLineRange];
			// scroll to found line
			[textView centerSelectionInVisibleArea:nil];
			// remove selection after 500ms
			[textView performSelector:@selector(moveLeft:) withObject:nil afterDelay:0.5];
		}

		// Remove temporary files
		[[NSFileManager defaultManager] removeItemAtPath:tempRFuncFile error:NULL];
		[[NSFileManager defaultManager] removeItemAtPath:tempRFile error:NULL];
		[[NSFileManager defaultManager] removeItemAtPath:tempErrFile error:NULL];

		isFormattingRcode = NO;
		return;
	}

	// Continue Ccleaning formatted R code
	tidiedStr = [tidiedStr stringByReplacingOccurrencesOfRegex:@"\\}\\s*else" withString:@"} else"];
	tidiedStr = [@"\n" stringByAppendingString:tidiedStr];

	event = [NSApp nextEventMatchingMask:NSAnyEventMask
										untilDate:[NSDate distantPast]
										   inMode:NSDefaultRunLoopMode
										  dequeue:YES];
	if(event){
		if ([event type] == NSKeyDown) {
			unichar key = [[event characters] length] == 1 ? [[event characters] characterAtIndex:0] : 0;
			if (([event modifierFlags] & NSCommandKeyMask) && key == '.') {
				SLog(@"RDocumentWinCtrl.tidyRCode terminated by user");
				[[NSFileManager defaultManager] removeItemAtPath:tempRFuncFile error:NULL];
				[[NSFileManager defaultManager] removeItemAtPath:tempRFile error:NULL];
				[[NSFileManager defaultManager] removeItemAtPath:tempErrFile error:NULL];
				[self setStatusLineText:@""];
				isFormattingRcode = NO;
				return;
			}
		}
		[NSApp sendEvent:event];
	}

	// Re-convert comment lines
	//  - first for comment lines which began with a #
	[tidyStr setString:tidiedStr];
	[tidyStr flushCachedRegexData];
	comre = @"(?m)^([ \t]*)(c = \"@_@_@_@([^\n]*)\"\n[ \t]*)";
	NSRange r2;
	NSRange r3;
	searchRange = NSMakeRange(0, [tidyStr length]);
	while([tidyStr isMatchedByRegex:comre inRange:searchRange]) {
		r  = [tidyStr rangeOfRegex:comre options:0 inRange:searchRange capture:1L error:nil];
		r2 = [tidyStr rangeOfRegex:comre options:0 inRange:searchRange capture:2L error:nil];
		r3 = [tidyStr rangeOfRegex:comre options:0 inRange:searchRange capture:3L error:nil];
		rs = [[[tidyStr substringWithRange:r3] stringByReplacingOccurrencesOfString:@"\\t" withString:@"\t"] 
			stringByReplacingOccurrencesOfString:@"\\\"" withString:@"\""];
		NSString *p = [NSString stringWithFormat:@"#%@\n%@", rs, [tidyStr substringWithRange:r]];
		[tidyStr replaceCharactersInRange:r2 withString:p];
		searchRange = NSMakeRange(r2.location+[p length], [tidyStr length]-r2.location-[p length]);
		[tidyStr flushCachedRegexData];
	}

	event = [NSApp nextEventMatchingMask:NSAnyEventMask
										untilDate:[NSDate distantPast]
										   inMode:NSDefaultRunLoopMode
										  dequeue:YES];
	if(event){
		if ([event type] == NSKeyDown) {
			unichar key = [[event characters] length] == 1 ? [[event characters] characterAtIndex:0] : 0;
			if (([event modifierFlags] & NSCommandKeyMask) && key == '.') {
				SLog(@"RDocumentWinCtrl.tidyRCode terminated by user");
				[[NSFileManager defaultManager] removeItemAtPath:tempRFuncFile error:NULL];
				[[NSFileManager defaultManager] removeItemAtPath:tempRFile error:NULL];
				[[NSFileManager defaultManager] removeItemAtPath:tempErrFile error:NULL];
				[self setStatusLineText:@""];
				isFormattingRcode = NO;
				return;
			}
		}
		[NSApp sendEvent:event];
	}

	// if last line is a comment remove trailing \n if present
	if([tidyStr length])
		[tidyStr replaceOccurrencesOfRegex:@"^(\\s*#[^\n]*)\n$" withString:@"$1" range:[tidyStr lineRangeForRange:NSMakeRange([tidyStr length]-1,0)]];

	//  - for all comments which occurred after a R command
	[tidyStr flushCachedRegexData];
	comre = @"(?m)(\n[ \t]*c = \"@__@_@_@([^\n]*?)\")";
	while([tidyStr isMatchedByRegex:comre]) {
		r  = [tidyStr rangeOfRegex:comre capture:1L];
		r2 = [tidyStr rangeOfRegex:comre capture:2L];
		rs = [[[tidyStr substringWithRange:r2] stringByReplacingOccurrencesOfString:@"\\t" withString:@"\t"] 
			stringByReplacingOccurrencesOfString:@"\\\"" withString:@"\""];
		[tidyStr replaceCharactersInRange:r withString:[@" #" stringByAppendingString:rs]];
		[tidyStr flushCachedRegexData];
	}

	[tidyStr replaceOccurrencesOfRegex:@"^\n" withString:@""];
	// Delete a next last \n character for selected code
	if([textView selectedRange].length)
		[tidyStr replaceOccurrencesOfRegex:@"\n$" withString:@""];

	if([tidyStr length]) {
		// Insert formatted R code
		if(![textView selectedRange].length)
			[textView setSelectedRange:NSMakeRange(0, [[textView string] length])];
		[textView insertText:tidyStr];
	} else {
		NSBeep();
	}
	isFormattingRcode = NO;

	// Remove temporary files
	[[NSFileManager defaultManager] removeItemAtPath:tempRFuncFile error:NULL];
	[[NSFileManager defaultManager] removeItemAtPath:tempRFile error:NULL];
	[[NSFileManager defaultManager] removeItemAtPath:tempErrFile error:NULL];

	[self setStatusLineText:@""];

}

- (IBAction)comment: (id)sender
{

	NSString *commentString = @"#";
	if([self isRdDocument])
		commentString = @"%";

	NSRange sr = [textView selectedRange];

	if (sr.length == 0) { // comment out the current line only by inserting a "# " after the indention

		SLog(@"RDocumentWinCtrl: comment current line");
		NSRange lineRange = [[textView string] lineRangeForRange:sr];
		// for empty line simply insert "# "
		if(!lineRange.length) {
			SLog(@" - empty line thus insert # only");
			[textView insertText:[NSString stringWithFormat:@"%@ ", commentString]];
			return;
		}
		[textView setSelectedRange:lineRange];

		// set undo break point
		[textView breakUndoCoalescing];
		// insert commented string
		[textView insertText:
			[[[textView string] substringWithRange:lineRange] stringByReplacingOccurrencesOfRegex:@"^(\\s*)(.*)" 
					withString:[NSString stringWithFormat:@"%@%@ %@", @"$1", commentString, @"$2"]]
			];
		// restore cursor position
		sr.location+=2;
		[textView setSelectedRange:sr];
		return;
	}

	SLog(@"RDocumentWinCtrl: comment selected block");

	// comment out the selected block by inserting a "# " after the indention for each line;
	// empty lines won't be commented out
	NSMutableString *selectedString = [NSMutableString stringWithCapacity:sr.length];
	[selectedString setString:[[textView string] substringWithRange:sr] ];
	// handle first line separately since it doesn't start with a \n or \r
	NSRange firstLineRange = [selectedString lineRangeForRange:NSMakeRange(0,0)];
	NSString *firstLineString = [[selectedString substringWithRange:firstLineRange] stringByReplacingOccurrencesOfRegex:@"^(\\s*)(.*)" 
		withString:[NSString stringWithFormat:@"%@%@ %@", @"$1", commentString, @"$2"]];
	[selectedString replaceCharactersInRange:firstLineRange withString:firstLineString];
	NSString *commentedString = [selectedString stringByReplacingOccurrencesOfRegex:@"(?m)([\r\n]+)(\\s*)(?=\\S)" 
			withString:[NSString stringWithFormat:@"%@%@%@ ", @"$1", @"$2", commentString]];
	[textView setSelectedRange:sr];

	// set undo break point
	[textView breakUndoCoalescing];
	// insert commented string
	[textView insertText:commentedString];
	// restore selection
	[textView setSelectedRange:NSMakeRange(sr.location, [commentedString length])];

}

- (IBAction)uncomment: (id)sender
{

	NSString *commentString = @"#";
	if([self isRdDocument])
		commentString = @"%";

	NSRange sr = [textView selectedRange];

	if (sr.length == 0) { // uncomment the current line only

		SLog(@"RDocumentWinCtrl: uncomment current line");
		NSRange lineRange = [[textView string] lineRangeForRange:sr];
		// for empty line does nothing
		if(!lineRange.length) {
			SLog(@" - no line found");
			return;
		}
		
		[textView setSelectedRange:lineRange];
		// set undo break point
		[textView breakUndoCoalescing];
		NSString *uncommentedString = [[[textView string] substringWithRange:lineRange] stringByReplacingOccurrencesOfRegex:
			[NSString stringWithFormat:@"^(\\s*)(%@ ?)", commentString] withString:@"$1"];
		[textView insertText:uncommentedString];
		// restore cursor position
		[textView setSelectedRange:NSMakeRange(sr.location - lineRange.length + [uncommentedString length], 0)];
		return;
	}

	SLog(@"RDocumentWinCtrl: uncomment selected block");

	// uncomment selected block
	NSString *uncommentedString = [[[textView string] substringWithRange:sr] stringByReplacingOccurrencesOfRegex:
		[NSString stringWithFormat:@"(?m)^(\\s*)(%@ ?)", commentString] withString:@"$1"];
	// set undo break point
	[textView breakUndoCoalescing];
	[textView insertText:uncommentedString];
	// restore selection
	[textView setSelectedRange:NSMakeRange(sr.location, [uncommentedString length])];

}

- (IBAction)executeSelection:(id)sender
{

	NSRange sr = [textView selectedRange];
	if (sr.length>0) {
		NSString *stx = [[[textView textStorage] string] substringWithRange:sr];
		[[RController sharedController] sendInput:stx];
	} else { // if nothing is selected, execute the current line
		NSRange lineRange = [[[textView textStorage] string] lineRangeForRange:sr];
		if (lineRange.length < 1)
			NSBeep(); // nothing to execute
		else
			[[RController sharedController] sendInput:
			[[[textView textStorage] string] substringWithRange: lineRange]];
	}
	execNewlineFlag=YES;
}

- (IBAction)sourceCurrentDocument:(id)sender
{
	if ([[self document] isDocumentEdited]) {
		RSEXP *x=[[REngine mainEngine] evaluateString:@"tempfile()"];
		NSString *fn=nil;
		if (x && (fn=[x string])) {
			NSString *str = [textView string];
			if ([str length]) {
				if ([str characterAtIndex:[str length]-1] != '\n') 
					str = [str stringByAppendingString: @"\n"];
				if ([str writeToFile:fn atomically:YES encoding:NSUTF8StringEncoding error:nil])
					[[RController sharedController] sendInput:[NSString stringWithFormat:@"source(\"%@\")\nunlink(\"%@\")", fn, fn]];
				else
					NSLog(@"Temporary file for “source current document” couldn't be saved.");
			}
		}
	} else {
		NSString *fn=[[self document] fileName];
		if (fn) {
			[[RController sharedController] sendInput:[NSString stringWithFormat:@"source(\"%@\")", fn]];
		}
	}
}


- (IBAction)setHelpSearchType:(id)sender
{
	NSMenuItem *mi = (NSMenuItem*) sender;
	NSMenu *m = [(NSSearchFieldCell*) searchToolbarField searchMenuTemplate];
	int hst = [mi tag];
	if (mi && m && hst!=hsType) {
		SLog(@"setHelpSearchType: old=%d, new=%d", hsType, hst);
		NSMenuItem *cmi = [m itemWithTag:hsType];
		if (cmi) [cmi setState:NSOffState];
		hsType = hst;
		cmi = (NSMenuItem*) [m itemWithTag:hsType];
		if (cmi) [cmi setState:NSOnState];
		// sounds weird, but we have to re-set the tempate to force sf to update the real menu
		[(NSSearchFieldCell*) searchToolbarField setSearchMenuTemplate:m];
		[[HelpManager sharedController] setSearchType:hsType];
	}
}

- (IBAction)goHelpSearch:(id)sender
{

	NSString *ss = [[(NSSearchField*)sender stringValue] stringByTrimmingCharactersInSet:
										[NSCharacterSet whitespaceAndNewlineCharacterSet]];

	SLog(@"%@.goHelpSearch: \"%@\", type=%d", self, ss, hsType);

	if(![ss length]) return;

	SLog(@" - call [HelpManager showHelpFor:]");

	[[HelpManager sharedController] showHelpFor:ss];

}

- (NSView*) searchToolbarView
{
	return searchToolbarView;
}

- (NSView*) fnListView
{
	return fnListView;
}

- (NSView*) rdToolboxView
{
	return rdToolboxView;
}

- (BOOL)validateMenuItem:(NSMenuItem *)menuItem
{

	if ([menuItem action] == @selector(reInterpretDocument:)) {
		return ([[RDocumentController sharedDocumentController] currentDocument] && [[[RDocumentController sharedDocumentController] currentDocument] fileURL]);
	}

	if ([menuItem action] == @selector(comment:) || [menuItem action] == @selector(uncomment:)) {
		id firstResponder = [[NSApp keyWindow] firstResponder];
		return ([firstResponder respondsToSelector:@selector(isEditable)] && [firstResponder isEditable]);
	}

	if ([menuItem action] == @selector(sourceCurrentDocument:)) {

		// disable for empty docs
		if([[RDocumentController sharedDocumentController] currentDocument] 
			&& ![[textView string] length])
				return NO;

		// disable for Rd docs
		return ![self isRdDocument];
	}

	if ([menuItem action] == @selector(makeASCIIconform:) || [menuItem action] == @selector(unescapeUnicode:))
		return ([textView selectedRange].length || [textView getRangeForCurrentWord].length) ? YES : NO;

	if ([menuItem action] == @selector(tidyRCode:))
		// disable for Rd docs
		return ![self isRdDocument];

	return YES;
}

- (void) helpSearchTypeChanged
{
	int type = [[HelpManager sharedController] searchType];
	NSMenu *m = [[searchToolbarField cell] searchMenuTemplate];
	SLog(@"RDocumentWinCtrl - received notification about search type change to %d", type);
	[[m itemWithTag:kExactMatch] setState:(type == kExactMatch) ? NSOnState : NSOffState];
	[[m itemWithTag:kFuzzyMatch] setState:(type == kExactMatch) ? NSOffState : NSOnState];
	[[searchToolbarField cell] setSearchMenuTemplate:m];
}

- (IBAction)insertRdFunctionTemplate:(id)sender
{
	[[self document] insertRdFunctionTemplate];
}

- (IBAction)insertRdDataTemplate:(id)sender
{
	[[self document] insertRdDataTemplate];
}

- (IBAction)insertRdTempalte:(id)sender
{
	[[self document] convertRd2HTML];
}

- (IBAction)convertRd2HTML:(id)sender
{
	[[self document] convertRd2HTML];
}

- (IBAction)convertRd2PDF:(id)sender
{
	[[self document] convertRd2PDF];
}

- (IBAction)checkRdDocument:(id)sender
{
	[[self document] checkRdDocument];
}

- (NSArray *)textView:(NSTextView *)aTextView willChangeSelectionFromCharacterRanges:(NSArray *)oldSelectedCharRanges toCharacterRanges:(NSArray *)newSelectedCharRanges
{
	// Check if snippet session is still valid
	if ([newSelectedCharRanges count] && ![[newSelectedCharRanges objectAtIndex:0] rangeValue].length && [textView isSnippetMode]) {
		[textView checkForCaretInsideSnippet];
	}
	return newSelectedCharRanges;
}

@end
