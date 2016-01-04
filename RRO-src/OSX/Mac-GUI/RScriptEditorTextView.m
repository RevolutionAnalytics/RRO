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
 *  RScriptEditorTextView.m
 *
 *  Created by Hans-J. Bibiko on 15/02/2011.
 *
 */

#import "RScriptEditorTextView.h"
#import "RScriptEditorTextStorage.h"
#import "RScriptEditorTypeSetter.h"
#import "RScriptEditorLayoutManager.h"
#import "RGUI.h"
#import "Tools/RTooltip.h"


#pragma mark -
#pragma mark flex init

/**
 * Include all the extern variables and prototypes required for flex (used for syntax highlighting)
 */

#import "RScriptEditorTokens.h"
#import "RdScriptEditorTokens.h"

// R lexer
extern NSUInteger yylex();
extern NSUInteger yyuoffset, yyuleng;
typedef struct yy_buffer_state *YY_BUFFER_STATE;
void yy_switch_to_buffer(YY_BUFFER_STATE);
YY_BUFFER_STATE yy_scan_string (const char *);

// Rd lexer
extern NSUInteger rdlex();
typedef struct rd_buffer_state *RD_BUFFER_STATE;
void rd_switch_to_buffer(RD_BUFFER_STATE);
RD_BUFFER_STATE rd_scan_string (const char *);

static SEL _foldedSel;

#pragma mark -
#pragma mark attribute definition 

#define kAPlinked      @"Linked" // attribute for a via auto-pair inserted char
#define kAPval         @"linked"
#define kLEXToken      @"Quoted" // set via lex to indicate a quoted string
#define kLEXTokenValue @"isMarked"
#define kRkeyword      @"s"      // attribute for found R keywords
#define kQuote         @"Quote"
#define kQuoteValue    @"isQuoted"
#define kValue         @"x"
#define kBTQuote       @"BTQuote"
#define kBTQuoteValue  @"isBTQuoted"

#pragma mark -

#define R_SYNTAX_HILITE_BIAS 2000
#define R_MAX_TEXT_SIZE_FOR_SYNTAX_HIGHLIGHTING 20000000


static inline const char* NSStringUTF8String(NSString* self) 
{
	typedef const char* (*SPUTF8StringMethodPtr)(NSString*, SEL);
	static SPUTF8StringMethodPtr SPNSStringGetUTF8String;
	if (!SPNSStringGetUTF8String) SPNSStringGetUTF8String = (SPUTF8StringMethodPtr)[NSString instanceMethodForSelector:@selector(UTF8String)];
	const char* to_return = SPNSStringGetUTF8String(self, @selector(UTF8String));
	return to_return;
}

static inline void NSMutableAttributedStringAddAttributeValueRange (NSMutableAttributedString* self, NSString* aStr, id aValue, NSRange aRange) 
{
	typedef void (*SPMutableAttributedStringAddAttributeValueRangeMethodPtr)(NSMutableAttributedString*, SEL, NSString*, id, NSRange);
	static SPMutableAttributedStringAddAttributeValueRangeMethodPtr SPMutableAttributedStringAddAttributeValueRange;
	if (!SPMutableAttributedStringAddAttributeValueRange) SPMutableAttributedStringAddAttributeValueRange = (SPMutableAttributedStringAddAttributeValueRangeMethodPtr)[self methodForSelector:@selector(addAttribute:value:range:)];
	SPMutableAttributedStringAddAttributeValueRange(self, @selector(addAttribute:value:range:), aStr, aValue, aRange);
	return;
}

static inline id NSMutableAttributedStringAttributeAtIndex (NSMutableAttributedString* self, NSString* aStr, NSUInteger index, NSRangePointer range) 
{
	typedef id (*SPMutableAttributedStringAttributeAtIndexMethodPtr)(NSMutableAttributedString*, SEL, NSString*, NSUInteger, NSRangePointer);
	static SPMutableAttributedStringAttributeAtIndexMethodPtr SPMutableAttributedStringAttributeAtIndex;
	if (!SPMutableAttributedStringAttributeAtIndex) SPMutableAttributedStringAttributeAtIndex = (SPMutableAttributedStringAttributeAtIndexMethodPtr)[self methodForSelector:@selector(attribute:atIndex:effectiveRange:)];
	id r = SPMutableAttributedStringAttributeAtIndex(self, @selector(attribute:atIndex:effectiveRange:), aStr, index, range);
	return r;
}


@implementation RScriptEditorTextView

- (void)awakeFromNib
{

	// we are a subclass of RTextView which has its own awake and we must call it
	[super awakeFromNib];

	SLog(@"RScriptEditorTextView: awakeFromNib <%@>", self);

	selfDelegate = (RDocumentWinCtrl*)[self delegate];

	breakSyntaxHighlighting = 0;
	_foldedSel = @selector(foldedAtIndex:);
	
	// Bind scrollView programmatically - if done in RDocument.xib this'd lead to
	// calling awakeFromNib twice
	id scrView = (NSScrollView *)self.superview.superview;
	if ([scrView isKindOfClass:[NSScrollView class]]) {
		if(scrollView) [scrollView release];
		scrollView = [scrView retain];
		SLog(@"RScriptEditorTextView:awakeFromNib set scrollView");
	}

	prefs = [[NSUserDefaults standardUserDefaults] retain];
	[[Preferences sharedPreferences] addDependent:self];

	lineNumberingEnabled = [Preferences flagForKey:showLineNumbersKey withDefault:NO];

	// Init textStorage and set self as delegate for the textView's textStorage to enable
	// syntax highlighting, folding etc.
	theTextStorage = [[RScriptEditorTextStorage alloc] initWithDelegate:self];

	_foldedImp = [theTextStorage methodForSelector:_foldedSel];

	// Make sure using foldingLayoutManager
	if (![[self layoutManager] isKindOfClass:[RScriptEditorLayoutManager class]]) {
		RScriptEditorLayoutManager *layoutManager = [[RScriptEditorLayoutManager alloc] init];
		[[self textContainer] replaceLayoutManager:layoutManager];
		[layoutManager release];
	}

	// disabled to get the current text range in textView safer
	[[self layoutManager] setBackgroundLayoutEnabled:NO];
	[[self layoutManager] replaceTextStorage:theTextStorage];

	[(RScriptEditorTypeSetter*)[[self layoutManager] typesetter] setTextStorage:theTextStorage];

	isSyntaxHighlighting = NO;

	if([prefs objectForKey:highlightCurrentLine] == nil) [prefs setBool:YES forKey:highlightCurrentLine];
	if([prefs objectForKey:indentNewLines] == nil) [prefs setBool:YES forKey:indentNewLines];

	[self setFont:[Preferences unarchivedObjectForKey:RScriptEditorDefaultFont withDefault:[NSFont fontWithName:@"Monaco" size:11]]];

	// Set defaults for general usage
	braceHighlightInterval = [Preferences floatForKey:HighlightIntervalKey withDefault:0.3f];
	argsHints = [Preferences flagForKey:prefShowArgsHints withDefault:YES];
	lineWrappingEnabled = [Preferences flagForKey:enableLineWrappingKey withDefault:YES];
	syntaxHighlightingEnabled = [Preferences flagForKey:showSyntaxColoringKey withDefault:YES];

	deleteBackward = NO;
	startListeningToBoundChanges = NO;
	currentHighlight = -1;

	// For now replaced selectedTextBackgroundColor by redColor
	highlightColorAttr = [[NSDictionary alloc] initWithObjectsAndKeys:[NSColor redColor], NSBackgroundColorAttributeName, nil];

	if([selfDelegate isRdDocument])
		editorToolbar = [[RdEditorToolbar alloc] initWithEditor:selfDelegate];
	else
		editorToolbar = [[REditorToolbar alloc] initWithEditor:selfDelegate];

	[self setAllowsDocumentBackgroundColorChange:YES];
	[self setContinuousSpellCheckingEnabled:NO];

	if(![Preferences flagForKey:enableLineWrappingKey withDefault: YES])
		[scrollView setHasHorizontalScroller:YES];

	if(!lineWrappingEnabled)
		[self updateLineWrappingMode];

	// Re-define tab stops for a better editing
	[self setTabStops];

	NSColor *c = [Preferences unarchivedObjectForKey:normalSyntaxColorKey withDefault:nil];
	if (c) shColorNormal = c;
	else shColorNormal=[NSColor colorWithDeviceRed:0.025 green:0.085 blue:0.600 alpha:1.0];
	[shColorNormal retain];

	c=[Preferences unarchivedObjectForKey:stringSyntaxColorKey withDefault:nil];
	if (c) shColorString = c;
	else shColorString=[NSColor colorWithDeviceRed:0.690 green:0.075 blue:0.000 alpha:1.0];
	[shColorString retain];	

	c=[Preferences unarchivedObjectForKey:numberSyntaxColorKey withDefault:nil];
	if (c) shColorNumber = c;
	else shColorNumber=[NSColor colorWithDeviceRed:0.020 green:0.320 blue:0.095 alpha:1.0];
	[shColorNumber retain];

	c=[Preferences unarchivedObjectForKey:keywordSyntaxColorKey withDefault:nil];
	if (c) shColorKeyword = c;
	else shColorKeyword=[NSColor colorWithDeviceRed:0.765 green:0.535 blue:0.035 alpha:1.0];
	[shColorKeyword retain];

	c=[Preferences unarchivedObjectForKey:commentSyntaxColorKey withDefault:nil];
	if (c) shColorComment = c;
	else shColorComment=[NSColor colorWithDeviceRed:0.312 green:0.309 blue:0.309 alpha:1.0];
	[shColorComment retain];

	c=[Preferences unarchivedObjectForKey:identifierSyntaxColorKey withDefault:nil];
	if (c) shColorIdentifier = c;
	else shColorIdentifier=[NSColor colorWithDeviceRed:0.0 green:0.0 blue:0.0 alpha:1.0];
	[shColorIdentifier retain]; 

	c=[Preferences unarchivedObjectForKey:editorSelectionBackgroundColorKey withDefault:nil];
	if (!c) c=[NSColor colorWithDeviceRed:0.71f green:0.835f blue:1.0f alpha:1.0f];
	NSMutableDictionary *attr = [NSMutableDictionary dictionary];
	[attr setDictionary:[self selectedTextAttributes]];
	[attr setObject:c forKey:NSBackgroundColorAttributeName];
	[self setSelectedTextAttributes:attr];
	
	// Rd stuff
	// c=[Preferences unarchivedObjectForKey:sectionRdSyntaxColorKey withDefault:nil];
	// if (c) rdColorSection = c;
	// else rdColorSection=[NSColor colorWithDeviceRed:0.8 green:0.0353 blue:0.02 alpha:1.0];
	// [rdColorSection retain];
	// 
	// c=[Preferences unarchivedObjectForKey:macroArgRdSyntaxColorKey withDefault:nil];
	// if (c) rdColorMacroArg = c;
	// else rdColorMacroArg=[NSColor colorWithDeviceRed:0.0 green:0.0 blue:0.98 alpha:1.0];
	// [rdColorMacroArg retain];
	// 
	// c=[Preferences unarchivedObjectForKey:macroGenRdSyntaxColorKey withDefault:nil];
	// if (c) rdColorMacroGen = c;
	// else rdColorMacroGen=[NSColor colorWithDeviceRed:0.4 green:0.78 blue:0.98 alpha:1.0];
	// [rdColorMacroGen retain]; 
	// 
	// c=[Preferences unarchivedObjectForKey:directiveRdSyntaxColorKey withDefault:nil];
	// if (c) rdColorDirective = c;
	// else rdColorDirective=[NSColor colorWithDeviceRed:0.0 green:0.785 blue:0.0 alpha:1.0];
	// [rdColorDirective retain]; 

	// c=[Preferences unarchivedObjectForKey:commentRdSyntaxColorKey withDefault:nil];
	// if (c) rdColorComment = c;
	// else rdColorComment=[NSColor colorWithDeviceRed:0.1 green:0.55 blue:0.05 alpha:1.0];
	// [rdColorComment retain];

	// c=[Preferences unarchivedObjectForKey:normalRdSyntaxColorKey withDefault:nil];
	// if (c) rdColorNormal = c;
	// else rdColorNormal=[NSColor colorWithDeviceRed:0.0 green:0.0 blue:0.0 alpha:1.0];
	// [rdColorNormal retain]; 


	c=[Preferences unarchivedObjectForKey:editorBackgroundColorKey withDefault:nil];
	if (c) shColorBackground = c;
	else shColorBackground=[NSColor colorWithDeviceRed:1.0 green:1.0 blue:1.0 alpha:1.0];
	[shColorBackground retain]; 

	c=[Preferences unarchivedObjectForKey:editorCurrentLineBackgroundColorKey withDefault:nil];
	if (c) shColorCurrentLine = c;
	else shColorCurrentLine=[NSColor colorWithDeviceRed:0.9 green:0.9 blue:0.9 alpha:0.8];
	[shColorCurrentLine retain]; 

	c=[Preferences unarchivedObjectForKey:editorCursorColorKey withDefault:nil];
	if (c) shColorCursor = c;
	else shColorCursor=[NSColor blackColor];
	[shColorCursor retain]; 
	[self setInsertionPointColor:shColorCursor];

	// Register observers for the when editor background colors preference changes
	[prefs addObserver:self forKeyPath:normalSyntaxColorKey options:NSKeyValueObservingOptionNew context:NULL];
	[prefs addObserver:self forKeyPath:stringSyntaxColorKey options:NSKeyValueObservingOptionNew context:NULL];
	[prefs addObserver:self forKeyPath:numberSyntaxColorKey options:NSKeyValueObservingOptionNew context:NULL];
	[prefs addObserver:self forKeyPath:keywordSyntaxColorKey options:NSKeyValueObservingOptionNew context:NULL];
	[prefs addObserver:self forKeyPath:commentSyntaxColorKey options:NSKeyValueObservingOptionNew context:NULL];
	// [prefs addObserver:self forKeyPath:normalRdSyntaxColorKey options:NSKeyValueObservingOptionNew context:NULL];
	// [prefs addObserver:self forKeyPath:commentRdSyntaxColorKey options:NSKeyValueObservingOptionNew context:NULL];
	// [prefs addObserver:self forKeyPath:sectionRdSyntaxColorKey options:NSKeyValueObservingOptionNew context:NULL];
	// [prefs addObserver:self forKeyPath:macroArgRdSyntaxColorKey options:NSKeyValueObservingOptionNew context:NULL];
	// [prefs addObserver:self forKeyPath:macroGenRdSyntaxColorKey options:NSKeyValueObservingOptionNew context:NULL];
	// [prefs addObserver:self forKeyPath:directiveRdSyntaxColorKey options:NSKeyValueObservingOptionNew context:NULL];
	[prefs addObserver:self forKeyPath:editorBackgroundColorKey options:NSKeyValueObservingOptionNew context:NULL];
	[prefs addObserver:self forKeyPath:editorCurrentLineBackgroundColorKey options:NSKeyValueObservingOptionNew context:NULL];
	[prefs addObserver:self forKeyPath:identifierSyntaxColorKey options:NSKeyValueObservingOptionNew context:NULL];
	[prefs addObserver:self forKeyPath:editorCursorColorKey options:NSKeyValueObservingOptionNew context:NULL];
	[prefs addObserver:self forKeyPath:showSyntaxColoringKey options:NSKeyValueObservingOptionNew context:NULL];
	[prefs addObserver:self forKeyPath:prefShowArgsHints options:NSKeyValueObservingOptionNew context:NULL];
	[prefs addObserver:self forKeyPath:enableLineWrappingKey options:NSKeyValueObservingOptionNew context:NULL];
	[prefs addObserver:self forKeyPath:RScriptEditorDefaultFont options:NSKeyValueObservingOptionNew context:NULL];
	[prefs addObserver:self forKeyPath:HighlightIntervalKey options:NSKeyValueObservingOptionNew context:NULL];
	[prefs addObserver:self forKeyPath:highlightCurrentLine options:NSKeyValueObservingOptionNew context:NULL];
	[prefs addObserver:self forKeyPath:showLineNumbersKey options:NSKeyValueObservingOptionNew context:NULL];
	[prefs addObserver:self forKeyPath:editorSelectionBackgroundColorKey options:NSKeyValueObservingOptionNew context:NULL];

	if(syntaxHighlightingEnabled) {
		[self setTextColor:shColorNormal];
		[self setInsertionPointColor:shColorCursor];
	} else {
		[self setTextColor:shColorNormal];
		[self setInsertionPointColor:shColorCursor];
	}
#if MAC_OS_X_VERSION_MIN_REQUIRED >= MAC_OS_X_VERSION_10_5
	[[self layoutManager] setAllowsNonContiguousLayout:YES];
#endif

	// add NSViewBoundsDidChangeNotification to scrollView
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(boundsDidChangeNotification:) name:NSViewBoundsDidChangeNotification object:[scrollView contentView]];

}

- (void)dealloc {
	SLog(@"RScriptEditorTextView: dealloc <%@>", self);

	[theTextStorage release];

	if(scrollView) [scrollView release];
	if(editorToolbar) [editorToolbar release];

	if(highlightColorAttr) [highlightColorAttr release];

	if(shColorNormal) [shColorNormal release];
	if(shColorString) [shColorString release];
	if(shColorNumber) [shColorNumber release];
	if(shColorKeyword) [shColorKeyword release];
	if(shColorComment) [shColorComment release];
	if(shColorIdentifier) [shColorIdentifier release];
	if(shColorBackground) [shColorBackground release];
	if(shColorCurrentLine) [shColorCurrentLine release];
	if(shColorCursor) [shColorCursor release];

	// if(rdColorNormal) [rdColorNormal release];
	// if(rdColorComment) [rdColorComment release];
	// if(rdColorSection) [rdColorSection release];
	// if(rdColorMacroArg) [rdColorMacroArg release];
	// if(rdColorMacroGen) [rdColorMacroGen release];
	// if(rdColorDirective) [rdColorDirective release];

	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[[Preferences sharedPreferences] removeDependent:self];
	if(prefs) [prefs release];

	[super dealloc];

}

- (id)scrollView
{
	return scrollView;
}

- (void)setNonSyntaxHighlighting
{
	[theTextStorage removeAttribute:NSForegroundColorAttributeName range:NSMakeRange(0, [[theTextStorage string] length])];
	[theTextStorage removeAttribute:NSBackgroundColorAttributeName range:NSMakeRange(0, [[theTextStorage string] length])];
	[self setTextColor:shColorNormal];
	[self setInsertionPointColor:shColorCursor];
	[self setNeedsDisplayInRect:[self visibleRect]];
}

/**
 * This method is called as part of Key Value Observing which is used to watch for prefernce changes which effect the interface.
 */
- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{

	if ([keyPath isEqualToString:normalSyntaxColorKey]) {
		if(shColorNormal) [shColorNormal release];
		shColorNormal = [[NSUnarchiver unarchiveObjectWithData:[change objectForKey:NSKeyValueChangeNewKey]] retain];
		if([self isEditable])
			[self performSelector:@selector(doSyntaxHighlighting) withObject:nil afterDelay:0.1];
	} else if ([keyPath isEqualToString:stringSyntaxColorKey]) {
		if(shColorString) [shColorString release];
		shColorString = [[NSUnarchiver unarchiveObjectWithData:[change objectForKey:NSKeyValueChangeNewKey]] retain];
		if([self isEditable])
			[self performSelector:@selector(doSyntaxHighlighting) withObject:nil afterDelay:0.1];
	} else if ([keyPath isEqualToString:numberSyntaxColorKey]) {
		if(shColorNumber) [shColorNumber release];
		shColorNumber = [[NSUnarchiver unarchiveObjectWithData:[change objectForKey:NSKeyValueChangeNewKey]] retain];
		if([self isEditable])
			[self performSelector:@selector(doSyntaxHighlighting) withObject:nil afterDelay:0.1];
	} else if ([keyPath isEqualToString:keywordSyntaxColorKey]) {
		if(shColorKeyword) [shColorKeyword release];
		shColorKeyword = [[NSUnarchiver unarchiveObjectWithData:[change objectForKey:NSKeyValueChangeNewKey]] retain];
		if([self isEditable])
			[self performSelector:@selector(doSyntaxHighlighting) withObject:nil afterDelay:0.1];
	} else if ([keyPath isEqualToString:commentSyntaxColorKey]) {
		if(shColorComment) [shColorComment release];
		shColorComment = [[NSUnarchiver unarchiveObjectWithData:[change objectForKey:NSKeyValueChangeNewKey]] retain];
		if([self isEditable])
			[self performSelector:@selector(doSyntaxHighlighting) withObject:nil afterDelay:0.1];
	} else if ([keyPath isEqualToString:identifierSyntaxColorKey]) {
		if(shColorIdentifier) [shColorIdentifier release];
		shColorIdentifier = [[NSUnarchiver unarchiveObjectWithData:[change objectForKey:NSKeyValueChangeNewKey]] retain];
		if([self isEditable])
			[self performSelector:@selector(doSyntaxHighlighting) withObject:nil afterDelay:0.1];
	// } else if ([keyPath isEqualToString:sectionRdSyntaxColorKey]) {
	// 	if(rdColorSection) [rdColorSection release];
	// 	rdColorSection = [[NSUnarchiver unarchiveObjectWithData:[change objectForKey:NSKeyValueChangeNewKey]] retain];
	// 	if([self isEditable])
	// 		[self performSelector:@selector(doSyntaxHighlighting) withObject:nil afterDelay:0.1];
	// } else if ([keyPath isEqualToString:macroArgRdSyntaxColorKey]) {
	// 	if(rdColorMacroArg) [rdColorMacroArg release];
	// 	rdColorMacroArg = [[NSUnarchiver unarchiveObjectWithData:[change objectForKey:NSKeyValueChangeNewKey]] retain];
	// 	if([self isEditable])
	// 		[self performSelector:@selector(doSyntaxHighlighting) withObject:nil afterDelay:0.1];
	// } else if ([keyPath isEqualToString:macroGenRdSyntaxColorKey]) {
	// 	if(rdColorMacroGen) [rdColorMacroGen release];
	// 	rdColorMacroGen = [[NSUnarchiver unarchiveObjectWithData:[change objectForKey:NSKeyValueChangeNewKey]] retain];
	// 	if([self isEditable])
	// 		[self performSelector:@selector(doSyntaxHighlighting) withObject:nil afterDelay:0.1];
	// } else if ([keyPath isEqualToString:directiveRdSyntaxColorKey]) {
	// 	if(rdColorDirective) [rdColorDirective release];
	// 	rdColorDirective = [[NSUnarchiver unarchiveObjectWithData:[change objectForKey:NSKeyValueChangeNewKey]] retain];
	// 	if([self isEditable])
	// 		[self performSelector:@selector(doSyntaxHighlighting) withObject:nil afterDelay:0.1];
	} else if ([keyPath isEqualToString:editorCursorColorKey]) {
		if(shColorCursor) [shColorCursor release];
		shColorCursor = [[NSUnarchiver unarchiveObjectWithData:[change objectForKey:NSKeyValueChangeNewKey]] retain];
		[self setInsertionPointColor:shColorCursor];
		[self setNeedsDisplayInRect:[self visibleRect]];
	} else if ([keyPath isEqualToString:identifierSyntaxColorKey]) {
		if(shColorIdentifier) [shColorIdentifier release];
		shColorIdentifier = [[NSUnarchiver unarchiveObjectWithData:[change objectForKey:NSKeyValueChangeNewKey]] retain];
		if([self isEditable])
			[self performSelector:@selector(doSyntaxHighlighting) withObject:nil afterDelay:0.1];
	} else if ([keyPath isEqualToString:editorBackgroundColorKey]) {
		if(shColorBackground) [shColorBackground release];
		shColorBackground = [[NSUnarchiver unarchiveObjectWithData:[change objectForKey:NSKeyValueChangeNewKey]] retain];
		[self setNeedsDisplayInRect:[self visibleRect]];
	} else if ([keyPath isEqualToString:editorCurrentLineBackgroundColorKey]) {
		if(shColorCurrentLine) [shColorCurrentLine release];
		shColorCurrentLine = [[NSUnarchiver unarchiveObjectWithData:[change objectForKey:NSKeyValueChangeNewKey]] retain];
		[self setNeedsDisplayInRect:[self visibleRect]];
	} else if ([keyPath isEqualToString:editorSelectionBackgroundColorKey]) {
		NSColor *c = [[NSUnarchiver unarchiveObjectWithData:[change objectForKey:NSKeyValueChangeNewKey]] retain];
		NSMutableDictionary *attr = [NSMutableDictionary dictionary];
		[attr setDictionary:[self selectedTextAttributes]];
		[attr setObject:c forKey:NSBackgroundColorAttributeName];
		[self setSelectedTextAttributes:attr];
		[self setNeedsDisplayInRect:[self visibleRect]];

	} else if ([keyPath isEqualToString:showSyntaxColoringKey]) {
		syntaxHighlightingEnabled = [[change objectForKey:NSKeyValueChangeNewKey] boolValue];
		if(syntaxHighlightingEnabled) {
			[self performSelector:@selector(doSyntaxHighlighting) withObject:nil afterDelay:0.05f];
		} else {
			[self performSelector:@selector(setNonSyntaxHighlighting) withObject:nil afterDelay:0.05f];
		}
	} else if ([keyPath isEqualToString:enableLineWrappingKey]) {
		[self updateLineWrappingMode];
		[self performSelector:@selector(doSyntaxHighlighting) withObject:nil afterDelay:0.05f];
		[self setNeedsDisplay:YES];

	} else if ([keyPath isEqualToString:showLineNumbersKey]) {
		lineNumberingEnabled = [[change objectForKey:NSKeyValueChangeNewKey] boolValue];
		if(lineNumberingEnabled) {
			NoodleLineNumberView *theRulerView = [[NoodleLineNumberView alloc] initWithScrollView:scrollView];
			[scrollView setVerticalRulerView:theRulerView];
			[scrollView setHasHorizontalRuler:NO];
			[scrollView setHasVerticalRuler:YES];
			[scrollView setRulersVisible:YES];
			[theRulerView release];
			[(NoodleLineNumberView*)[[self enclosingScrollView] verticalRulerView] setLineWrappingMode:[Preferences flagForKey:enableLineWrappingKey withDefault: YES]];
		} else {
			[scrollView setHasHorizontalRuler:NO];
			[scrollView setHasVerticalRuler:NO];
			[scrollView setRulersVisible:NO];
		}
		[self setNeedsDisplay:YES];

	} else if ([keyPath isEqualToString:prefShowArgsHints]) {
		argsHints = [[change objectForKey:NSKeyValueChangeNewKey] boolValue];
		if(!argsHints) {
			[selfDelegate setStatusLineText:@""];
		} else {
			[self currentFunctionHint];
		}

	} else if ([keyPath isEqualToString:highlightCurrentLine]) {
		[self setNeedsDisplayInRect:[self visibleRect]];

	} else if ([keyPath isEqualToString:RScriptEditorDefaultFont] && ![[[[self window] windowController] document] isRTF] && ![self selectedRange].length) {
			[self setFont:[NSUnarchiver unarchiveObjectWithData:[change objectForKey:NSKeyValueChangeNewKey]]];
			[self setNeedsDisplayInRect:[self visibleRect]];
	
		} else if ([keyPath isEqualToString:HighlightIntervalKey]) {
		braceHighlightInterval = [Preferences floatForKey:HighlightIntervalKey withDefault:0.3f];
	}
}

- (void)updateLineWrappingMode
{

	NSSize layoutSize;
	
	lineWrappingEnabled = [Preferences flagForKey:enableLineWrappingKey withDefault: YES];

	[self setHorizontallyResizable:YES];
	if (!lineWrappingEnabled) {
		NSRange curRange = [self selectedRange];
		layoutSize = NSMakeSize(10e6,10e6);
		[scrollView setHasHorizontalScroller:YES];
		[self setMaxSize:layoutSize];
		[[self textContainer] setContainerSize:layoutSize];
		[[self textContainer] setWidthTracksTextView:NO];
		[self scrollRangeToVisible:NSMakeRange(curRange.location, 0)];
	} else {
		[scrollView setHasHorizontalScroller:NO];
		layoutSize = [self maxSize];
		[self setMaxSize:layoutSize];
		[[self textContainer] setContainerSize:layoutSize];
		[[self textContainer] setWidthTracksTextView:YES];
		// Enforce view to be re-layouted correctly
		// by re-inserting the the current text buffer
		[[self undoManager] disableUndoRegistration];
		NSRange curRange = [self selectedRange];
		NSString *t = [[NSString alloc] initWithString:[self string]];
		[self selectAll:nil];
		[self insertText:@""];
		usleep(1000);
		[self insertText:t];
		[t release];
		[self setSelectedRange:curRange];
		[self scrollRangeToVisible:NSMakeRange(curRange.location, 0)];
		[[self undoManager] enableUndoRegistration];
	}
	[[self textContainer] setHeightTracksTextView:NO];

}

- (void)drawRect:(NSRect)rect
{
	// Draw background only for screen display but not while printing
	if([NSGraphicsContext currentContextDrawingToScreen]) {

		// Draw textview's background
		[shColorBackground setFill];
		NSRectFill(rect);

		// Highlightes the current line if set in the Pref
		// and if nothing is selected in the text view
		if ([prefs boolForKey:highlightCurrentLine] && ![self selectedRange].length && ![self isSnippetMode]) {
			NSUInteger rectCount;
			NSRange curLineRange = [[self string] lineRangeForRange:[self selectedRange]];
			// [theTextStorage ensureAttributesAreFixedInRange:curLineRange];
			NSRectArray queryRects = [[self layoutManager] rectArrayForCharacterRange: curLineRange
														 withinSelectedCharacterRange: curLineRange
																	  inTextContainer: [self textContainer]
																			rectCount: &rectCount ];
			[shColorCurrentLine setFill];
			NSRectFillListUsingOperation(queryRects, rectCount, NSCompositeSourceOver);
		}
	}
	[super drawRect:rect];
}

#pragma mark -

/**
 *  Performs syntax highlighting, trigger undo behaviour
 */
- (void)textStorageDidProcessEditing:(NSNotification *)notification
{

	// Make sure that the notification is from the correct textStorage object
	if (theTextStorage != [notification object]) return;

	NSInteger editedMask = [theTextStorage editedMask];

	SLog(@"RScriptEditorTextView: textStorageDidProcessEditing <%@> with mask %d", self, editedMask);

	// if the user really changed the text
	if(editedMask != 1) {

		// For larger text break a running syntax highlighting for user interaction
		// to make them more responsive (typing and scrolling)
		// if([[theTextStorage string] length] > 120000) {
		// 	breakSyntaxHighlighting = 1;
		// }

		[self checkSnippets];

		breakSyntaxHighlighting = 1;

		// Cancel calling doSyntaxHighlighting
		[NSObject cancelPreviousPerformRequestsWithTarget:self 
								selector:@selector(doSyntaxHighlighting) 
								object:nil];

		[self performSelector:@selector(doSyntaxHighlighting) withObject:nil afterDelay:0.05f];

		// Cancel setting undo break point
		[NSObject cancelPreviousPerformRequestsWithTarget:self 
								selector:@selector(breakUndoCoalescing) 
								object:nil];

		// Improve undo behaviour, i.e. it depends how fast the user types
		[self performSelector:@selector(breakUndoCoalescing) withObject:nil afterDelay:0.8f];

		[NSObject cancelPreviousPerformRequestsWithTarget:(RDocumentWinCtrl*)[self delegate] 
								selector:@selector(functionRescan) 
								object:nil];

		// update function list to display the function in which the cursor is located
		[(RDocumentWinCtrl*)[self delegate] performSelector:@selector(functionRescan) withObject:nil afterDelay:0.3f];

	}

	deleteBackward = NO;
	startListeningToBoundChanges = YES;

}

#pragma mark -

- (BOOL)lineNumberingEnabled
{
	return lineNumberingEnabled;
}

- (void)setDeleteBackward:(BOOL)delBack
{
	deleteBackward = delBack;
}

/**
 * Sets Tab Stops width for better editing behaviour
 */
- (void)setTabStops
{

	SLog(@"RScriptEditorTextView: setTabStops <%@>", self);

	NSFont *tvFont = [self font];
	int i;
	NSTextTab *aTab;
	NSMutableArray *myArrayOfTabs;
	NSMutableParagraphStyle *paragraphStyle;

	BOOL oldEditableStatus = [self isEditable];
	[self setEditable:YES];

	int tabStopWidth = [Preferences integerForKey:RScriptEditorTabWidth withDefault:4];
	if(tabStopWidth < 1) tabStopWidth = 1;

	float theTabWidth = [[NSString stringWithString:@" "] sizeWithAttributes:[NSDictionary dictionaryWithObject:tvFont forKey:NSFontAttributeName]].width;
	theTabWidth = (float)tabStopWidth * theTabWidth;

	int numberOfTabs = 256/tabStopWidth;
	myArrayOfTabs = [NSMutableArray arrayWithCapacity:numberOfTabs];
	aTab = [[NSTextTab alloc] initWithType:NSLeftTabStopType location:theTabWidth];
	[myArrayOfTabs addObject:aTab];
	[aTab release];
	for(i=1; i<numberOfTabs; i++) {
		aTab = [[NSTextTab alloc] initWithType:NSLeftTabStopType location:theTabWidth + ((float)i * theTabWidth)];
		[myArrayOfTabs addObject:aTab];
		[aTab release];
	}
	paragraphStyle = [[NSParagraphStyle defaultParagraphStyle] mutableCopy];
	[paragraphStyle setTabStops:myArrayOfTabs];

	// Soft wrapped lines are indented slightly
	[paragraphStyle setHeadIndent:4.0];

	NSMutableDictionary *textAttributes = [[[NSMutableDictionary alloc] initWithCapacity:1] autorelease];
	[textAttributes setObject:paragraphStyle forKey:NSParagraphStyleAttributeName];

	NSRange range = NSMakeRange(0, [theTextStorage length]);
	if ([self shouldChangeTextInRange:range replacementString:nil]) {
		[theTextStorage setAttributes:textAttributes range: range];
		[self didChangeText];
	}
	[self setTypingAttributes:textAttributes];
	[self setDefaultParagraphStyle:paragraphStyle];
	[self setFont:tvFont];

	[self setEditable:oldEditableStatus];

	[paragraphStyle release];
}

- (BOOL)isSyntaxHighlighting
{
	return isSyntaxHighlighting;
}

- (BOOL)breakSyntaxHighlighting
{
	return breakSyntaxHighlighting;
}
/**
 * Syntax Highlighting.
 *  
 * (The main bottleneck is the [NSTextStorage addAttribute:value:range:] method - the parsing itself is really fast!)
 * Some sample code from Andrew Choi ( http://members.shaw.ca/akochoi-old/blog/2003/11-09/index.html#3 ) has been reused.
 */
- (void)doSyntaxHighlighting
{

	if(!syntaxHighlightingEnabled)
		breakSyntaxHighlighting = 0;

	if (!syntaxHighlightingEnabled || [selfDelegate plain]) return;

	isSyntaxHighlighting = YES;

	NSString *selfstr    = [theTextStorage string];
	NSInteger strlength  = (NSInteger)[selfstr length];

	// do not highlight if text larger than 10MB
	if(strlength > 10000000 || !strlength) {
		isSyntaxHighlighting = NO;
		breakSyntaxHighlighting = 0;
		return;
	}

	// == Do highlighting partly (max R_SYNTAX_HILITE_BIAS*2 around visibleRange
	// by considering entire lines).

	// Get the text range currently displayed in the view port
	NSRect visibleRect = [self visibleRect];
	NSRange visibleRange = [[self layoutManager] glyphRangeForBoundingRectWithoutAdditionalLayout:visibleRect inTextContainer:[self textContainer]];

	if(!visibleRange.length) {
		isSyntaxHighlighting = NO;
		breakSyntaxHighlighting = 0;
		return;
	}

	NSInteger start = visibleRange.location - R_SYNTAX_HILITE_BIAS;
	if (start > 0)
		while(start > 0) {
			if(CFStringGetCharacterAtIndex((CFStringRef)selfstr, start)=='\n')
				break;
			start--;
		}
	if(start < 0) start = 0;
	NSInteger end = NSMaxRange(visibleRange) + R_SYNTAX_HILITE_BIAS;
	if (end > strlength) {
		end = strlength;
	} else {
		while(end < strlength) {
			if(CFStringGetCharacterAtIndex((CFStringRef)selfstr, end)=='\n')
				break;
			end++;
		}
	}

	NSRange textRange = NSMakeRange(start, end-start);

	// only to be sure that nothing went wrongly
	textRange = NSIntersectionRange(textRange, NSMakeRange(0, [theTextStorage length])); 

	if (!textRange.length || textRange.length > 30000) {
		isSyntaxHighlighting = NO;
		breakSyntaxHighlighting = 0;
		return;
	}

	[theTextStorage beginEditing];

	NSColor *tokenColor = nil;

	size_t token;
	NSRange tokenRange;

	// initialise flex
	yyuoffset = textRange.location; yyuleng = 0;
	
	BOOL hasFoldedItems = [theTextStorage hasFoldedItems];

	if([selfDelegate isRdDocument]) {

			rd_switch_to_buffer(rd_scan_string(NSStringUTF8String([selfstr substringWithRange:textRange])));

			// now loop through all the tokens
			while ((token = rdlex())) {
				if(hasFoldedItems && (NSInteger)(_foldedImp)(theTextStorage, _foldedSel, yyuoffset) > -1) continue;
				switch (token) {
					case RDPT_COMMENT:
					    tokenColor = shColorComment;
					    break;
					case RDPT_SECTION:
					    tokenColor = shColorKeyword;
					    break;
					case RDPT_MACRO_ARG:
					    tokenColor = shColorNumber;
					    break;
					case RDPT_MACRO_GEN:
					    tokenColor = shColorNumber;
					    break;
					case RDPT_DIRECTIVE:
					    tokenColor = shColorString;
					    break;
					case RDPT_OTHER:
					    tokenColor = shColorNormal;
					    break;
					default:
					    tokenColor = shColorNormal;
				}

				tokenRange = NSMakeRange(yyuoffset, yyuleng);

				// make sure that tokenRange is valid (and therefore within textRange)
				// otherwise a bug in the lex code could cause the the TextView to crash
				// NOTE Disabled for testing purposes for speed it up
				tokenRange = NSIntersectionRange(tokenRange, textRange);
				if (!tokenRange.length) continue;

				NSMutableAttributedStringAddAttributeValueRange(theTextStorage, NSForegroundColorAttributeName, tokenColor, tokenRange);

				if(breakSyntaxHighlighting) {

					// Cancel calling doSyntaxHighlighting
					[NSObject cancelPreviousPerformRequestsWithTarget:self 
											selector:@selector(doSyntaxHighlighting) 
											object:nil];

					[self performSelector:@selector(doSyntaxHighlighting) withObject:nil afterDelay:0.08f];

					breakSyntaxHighlighting = 0;
					break;

				}

			}

	} else {

		yy_switch_to_buffer(yy_scan_string(NSStringUTF8String([selfstr substringWithRange:textRange])));

		// now loop through all the tokens
		while ((token = yylex())) {
			if(hasFoldedItems && (NSInteger)(_foldedImp)(theTextStorage, _foldedSel, yyuoffset) > -1) continue;
			switch (token) {
				case RPT_SINGLE_QUOTED_TEXT:
				case RPT_DOUBLE_QUOTED_TEXT:
				    tokenColor = shColorString;
				    break;
				case RPT_RESERVED_WORD:
				    tokenColor = shColorKeyword;
				    break;
				case RPT_NUMERIC:
					tokenColor = shColorNumber;
					break;
				case RPT_BACKTICK_QUOTED_TEXT:
				    tokenColor = shColorString;
				    break;
				case RPT_COMMENT:
				    tokenColor = shColorComment;
				    break;
				case RPT_VARIABLE:
				    tokenColor = shColorIdentifier;
				    break;
				default:
				    tokenColor = shColorNormal;
			}

			tokenRange = NSMakeRange(yyuoffset, yyuleng);

			// make sure that tokenRange is valid (and therefore within textRange)
			// otherwise a bug in the lex code could cause the the TextView to crash
			tokenRange = NSIntersectionRange(tokenRange, textRange);
			if (!tokenRange.length) continue;

			NSMutableAttributedStringAddAttributeValueRange(theTextStorage, NSForegroundColorAttributeName, tokenColor, tokenRange);

			if(breakSyntaxHighlighting) {

				// Cancel calling doSyntaxHighlighting
				[NSObject cancelPreviousPerformRequestsWithTarget:self 
										selector:@selector(doSyntaxHighlighting) 
										object:nil];
				
				[self performSelector:@selector(doSyntaxHighlighting) withObject:nil afterDelay:0.08f];

				breakSyntaxHighlighting = 0;
				break;

			}

		}

	}

	// set current textColor to the color of the caret's position - 1
	// to try to suppress writing in normalColor before syntax highlighting 
	NSUInteger ix = [self selectedRange].location;
	if(ix > 1) {
		NSMutableDictionary *typeAttr = [NSMutableDictionary dictionary];
		[typeAttr setDictionary:[self typingAttributes]];
		NSColor *c = [theTextStorage attribute:NSForegroundColorAttributeName atIndex:ix-1 effectiveRange:nil];
		if(c) [typeAttr setObject:c forKey:NSForegroundColorAttributeName];
		[self setTypingAttributes:typeAttr];
	}

	[theTextStorage endEditing];

	[self setNeedsDisplayInRect:visibleRect];

	breakSyntaxHighlighting = 0;

	isSyntaxHighlighting = NO;

}

-(void)resetHighlights
{

	SLog(@"RScriptEditorTextView: resetHighlights with current highlite %d", currentHighlight);

	if (currentHighlight>-1) {
		if (currentHighlight<[theTextStorage length]) {
			NSLayoutManager *lm = [self layoutManager];
			if (lm) {
				NSRange fr = NSMakeRange(currentHighlight,1);
				NSDictionary *d = [lm temporaryAttributesAtCharacterIndex:currentHighlight effectiveRange:&fr];
				if (!d || [d objectForKey:NSBackgroundColorAttributeName]==nil) {
					fr = NSMakeRange(0,[[self string] length]);
					SLog(@"resetHighlights: attribute at %d not found, clearing all %d characters - better safe than sorry", currentHighlight, fr.length);
				}
				[lm removeTemporaryAttribute:NSBackgroundColorAttributeName forCharacterRange:fr];
			}
		}
		currentHighlight=-1;
	}
}

-(void)highlightCharacter:(NSNumber*)loc
{
	NSInteger pos = [loc intValue];

	SLog(@"RScriptEditorTextView: highlightCharacter: %d", pos);

	if (pos>=0 && pos<[[self string] length]) {

#if MAC_OS_X_VERSION_MIN_REQUIRED >= MAC_OS_X_VERSION_10_5
		[self showFindIndicatorForRange:NSMakeRange(pos, 1)];
#else
		[self resetHighlights];
		NSLayoutManager *lm = [self layoutManager];
		if (lm) {
			currentHighlight = pos;
			[lm setTemporaryAttributes:highlightColorAttr forCharacterRange:NSMakeRange(pos, 1)];
			[self performSelector:@selector(resetBackgroundColor:) withObject:nil afterDelay:braceHighlightInterval];
		}

#endif

	}
	else SLog(@"highlightCharacter: attempt to set highlight %d beyond the text range 0:%d - I refuse!", pos, [[self string] length] - 1);
}

-(void)resetBackgroundColor:(id)sender
{
	[self resetHighlights];
}

/**
 * Scrollview delegate after the textView's view port was changed.
 * Manily used to update the syntax highlighting for a large text size
 */
- (void)boundsDidChangeNotification:(NSNotification *)notification
{

	if(startListeningToBoundChanges) {

		breakSyntaxHighlighting = 1;

		[NSObject cancelPreviousPerformRequestsWithTarget:self 
									selector:@selector(doSyntaxHighlighting) 
									object:nil];

		if(![theTextStorage changeInLength]) {
			if([[theTextStorage string] length] > 120000)
				breakSyntaxHighlighting = 2;
			[self performSelector:@selector(doSyntaxHighlighting) withObject:nil afterDelay:0.08];
		}
		if(lineNumberingEnabled) {
			[NSObject cancelPreviousPerformRequestsWithTarget:[[self enclosingScrollView] verticalRulerView] 
										selector:@selector(refresh) 
										object:nil];
			
			[[[self enclosingScrollView] verticalRulerView] performSelector:@selector(refresh) withObject:nil afterDelay:0.001f];
		}

	}

}

- (IBAction)undo:(id)sender
{
	if([[self undoManager] canUndo]) {
		[[self undoManager] undo];
		if(lineNumberingEnabled)
			[[[self enclosingScrollView] verticalRulerView] performSelector:@selector(refresh) withObject:nil afterDelay:0.0f];
	}
}

- (IBAction)redo:(id)sender
{
	if([[self undoManager] canRedo]) {
		[[self undoManager] redo];
		if(lineNumberingEnabled)
			[[[self enclosingScrollView] verticalRulerView] performSelector:@selector(refresh) withObject:nil afterDelay:0.0f];
	}
}

#pragma mark -
#pragma mark Folding

/*
The idea of code folding is to replace the folded range while layouting by NSControlGlyphs
which will be rendered as zero width glyphs. This has the advantage that all text actions like 
copying, line numbering, etc. works without additional stuff.

For now it is only possible to fold a block if:
- the starting { is placed at the end of a line (or with a following comment)
- there's only ONE starting { in that line and NO }
- the ending } is placed at the of a line (or with a following comment)
- there's only ONE ending } in that line and NO {

Due to speed issues all folded ranges will be stored in a 3d C array of the size
R_MAX_FOLDED_ITEMS = 1024 defined in RScriptEditorTextStorage.h whereby index:
0 - range location
1 - range length
2 - location + length (pre-calculate for speed)

If the user locates the cursor inside a folded range or an action will locate the cursor
inside such a range (go to line, find something) the folded range will be unfolded.
... for more info ask Hans-J. Bibiko
*/

- (IBAction)unfoldCurrentBlock:(id)sender
{
	NSUInteger caretPosition = [self selectedRange].location;

	NSRange r = [[self string] lineRangeForRange:NSMakeRange(caretPosition, 0)];

	if([theTextStorage foldedAtIndex:NSMaxRange(r)] > -1) {
		[self unfoldLinesContainingCharacterAtIndex:NSMaxRange(r)];
		return;
	}
	if([theTextStorage foldedAtIndex:r.location] > -1) {
		[self unfoldLinesContainingCharacterAtIndex:r.location];
		return;
	}
}

- (IBAction)foldCurrentBlock:(id)sender
{
	NSUInteger caretPosition = [self selectedRange].location;
	NSInteger foldItem = 0;
	unichar c;

	NSRange r = [[self string] lineRangeForRange:NSMakeRange(caretPosition, 0)];

	foldItem = [self foldStatusAtIndex:NSMaxRange(r)-2];
	if(foldItem == 1) { // is current line set to ▼ set caret to end of line
		caretPosition = NSMaxRange(r)-1;
	} else { // otherwise set caret to begin of line
		caretPosition = r.location;
	}
	
	NSUInteger stringLength = [[self string] length];
	if(!stringLength) return;
	if(caretPosition == 0 || caretPosition >= [[self string] length]) return;
		
	CFStringRef parserStringRef = (CFStringRef)[self string];

	unichar co = '{'; // opening char
	unichar cc = '}'; // closing char
	
	NSInteger start = -1;
	NSInteger end = -1;
	NSInteger bracketCounter = 0;

	c = CFStringGetCharacterAtIndex(parserStringRef, caretPosition);
	if(c == cc)
		bracketCounter--;
	if(c == co)
		bracketCounter++;

	for(NSInteger i=caretPosition; i>=0; i--) {
		if([self parserContextForPosition:i] != pcExpression) continue;
		c = CFStringGetCharacterAtIndex(parserStringRef, i);
		if(c == co) {
			if(!bracketCounter) {
				start = i;
				break;
			}
			bracketCounter--;
		}
		if(c == cc) {
			bracketCounter++;
		}
	}
	if(start < 0 ) return;

	// go up for lines like "} else {"
	if(start && [self foldStatusAtIndex:start-1] == 0) {
		for(NSInteger i=start-1; i>=0; i--) {
			c = CFStringGetCharacterAtIndex(parserStringRef, i);
			if(c == '\n' || c == '\r') break;
			if([self parserContextForPosition:i] != pcExpression) continue;
			if(c == cc && i > 0) {
				bracketCounter = 0;
				for(NSInteger j=i-1; j>=0; j--) {
					if([self parserContextForPosition:j] != pcExpression) continue;
					c = CFStringGetCharacterAtIndex(parserStringRef, j);
					if(c == co) {
						if(!bracketCounter) {
							start = j;
							break;
						}
						bracketCounter--;
					}
					if(c == cc) {
						bracketCounter++;
					}
				}
				break;
			}
		}
	}		


	bracketCounter = 0;
	for(NSUInteger i=caretPosition; i<stringLength; i++) {
		if([self parserContextForPosition:i] != pcExpression) continue;
		c = CFStringGetCharacterAtIndex(parserStringRef, i);
		if(c == co) {
			bracketCounter++;
		}
		if(c == cc) {
			if(!bracketCounter) {
				end = i+1;
				BOOL goAhead = NO;
				//go ahead for lines a la  "} else {"
				for(NSUInteger j=end; j<stringLength; j++) {
					c = CFStringGetCharacterAtIndex(parserStringRef, j);
					if(c == '\n' || c == '\r') {
						break;
					}
					if(c == '\t' || c == ' ') {
						continue;
					}
					if([self parserContextForPosition:j] != pcExpression) continue;
					if(c == co) {
						goAhead = YES;
						break;
					}
				}
				if(!goAhead) break;
			}
			bracketCounter--;
		}
	}

	if(end < 0 || bracketCounter || end-start < 1) return;

	NSRange foldRange = NSMakeRange(start, end-start);
	if(![theTextStorage existsFoldedRange:foldRange]) {
		// set caret for ▲ line inside {} for scrolling
		if(foldItem == 2)
			[self setSelectedRange:NSMakeRange(r.location, 0)];
		[self foldLinesInRange:foldRange blockMode:NO];
	}

}

- (IBAction)foldBlockAtLevel:(id)sender
{

	NSInteger level = [sender tag];
	NSInteger bracketCounter = 0;
	NSInteger start = 0;
	NSInteger end = 0;
	CFStringRef str = (CFStringRef)[self string];
	
	unichar c;
	
	[[self undoManager] disableUndoRegistration];
	
	for(NSInteger i=0; i<[[self string] length]; i++) {
		c = CFStringGetCharacterAtIndex(str, i);
		if([self parserContextForPosition:i] != pcExpression) continue;
		if(c == '{') {
			bracketCounter++;
			if([self foldStatusAtIndex:i] == 1) {
				if(bracketCounter == level+1) {
					start = i;
				}
			}
			continue;
		}
		if(c == '}') {
			bracketCounter--;
			if([self foldStatusAtIndex:i] == 2) {
				if(bracketCounter == level) {
					end = i;
					NSRange r = NSMakeRange(start, end - start+1);
					if(![theTextStorage existsFoldedRange:r])
						[self foldLinesInRange:r blockMode:YES];
				}
				if(bracketCounter < 0) {
					NSBeep();
					return;
				}
			}
		}
	}

	[self didChangeText];
	
	// NSRange r = [[self layoutManager] characterRangeForGlyphRange:[[self layoutManager] 
	// 									glyphRangeForBoundingRect:[scrollView documentVisibleRect] 
	// 											  inTextContainer:[self textContainer]] actualGlyphRange:NULL];
	// 
	// [theTextStorage ensureAttributesAreFixedInRange:r];

	if(lineNumberingEnabled)
		[[[self enclosingScrollView] verticalRulerView] performSelector:@selector(refresh) withObject:nil afterDelay:0.0f];
	
	[NSObject cancelPreviousPerformRequestsWithTarget:self 
							selector:@selector(doSyntaxHighlighting) 
							object:nil];

	[self performSelector:@selector(doSyntaxHighlighting) withObject:nil afterDelay:0.02f];

	[[self undoManager] enableUndoRegistration];
}

- (IBAction)unFoldAllBlocks:(id)sender
{
	[theTextStorage removeAllFoldedRanges];

	[self didChangeText];

	// NSRange r = NSMakeRange(0, [[self string] length]);

	// [theTextStorage fixAttributesInRange:r];
	// [theTextStorage fixAttachmentAttributeInRange:r];
	// [theTextStorage ensureAttributesAreFixedInRange:r];


	if(lineNumberingEnabled)
		[[[self enclosingScrollView] verticalRulerView] performSelector:@selector(refresh) withObject:nil afterDelay:0.0f];

	breakSyntaxHighlighting = 1;
	
	[NSObject cancelPreviousPerformRequestsWithTarget:self 
							selector:@selector(doSyntaxHighlighting) 
							object:nil];

	[self performSelector:@selector(doSyntaxHighlighting) withObject:nil afterDelay:0.01f];
}

- (void)refoldLinesInRange:(NSRange)range
{

	NSInteger foldId = [theTextStorage registerFoldedRange:range];

	if(foldId < 0) {
		[RTooltip showWithObject:NLS(@"Maximum number of folded code fragments is reached.") atLocation:[NSEvent mouseLocation]];
		return;
	}

	range.location++;
	range.length -= 2;

	if(!range.length) return;
	
	NSString *tooltip = nil;
	if(range.length < 300)
		tooltip = [[self string] substringWithRange:range];
	else
		tooltip = [[[self string] substringWithRange:NSMakeRange(range.location, 300)] stringByAppendingString:@"\n…"];

	[theTextStorage beginEditing];
	[theTextStorage addAttribute:NSCursorAttributeName value:[NSCursor arrowCursor] range:range];
	[theTextStorage addAttribute:NSToolTipAttributeName value:tooltip range:range];
	[theTextStorage endEditing];

}

- (BOOL)foldLinesInRange:(NSRange)range blockMode:(BOOL)blockMode
{
	if(range.length < 5) {
		return NO;
	}

	NSInteger caretPosition = [self selectedRange].location;
	BOOL caretWasInsideFoldedRange = NO;

	// Check for valid folding range
	// fold only range if { and } are the last chars at the line

	NSString *selfStr = [self string];
	NSRange startLineRange = [selfStr lineRangeForRange:NSMakeRange(range.location, 0)];
	NSRange endLineRange   = [selfStr lineRangeForRange:NSMakeRange(NSMaxRange(range), 0)];

	if(!startLineRange.length || !endLineRange.length) {
		return NO;
	}

	// Do not fold a single line
	if(startLineRange.location == endLineRange.location) {
		return NO;
	}

	NSInteger status;

	status = [self foldStatusAtIndex:NSMaxRange(startLineRange)-2];	
	if(status != 1) {
		return NO;
	}

	unichar c = CFStringGetCharacterAtIndex((CFStringRef)selfStr, NSMaxRange(endLineRange)-1);
	if(c == '\n' || c == '\r')
		status = [self foldStatusAtIndex:NSMaxRange(endLineRange)-2];
	else
		status = [self foldStatusAtIndex:NSMaxRange(endLineRange)-1];	
	if(status != 2) {
		return NO;
	}

	if(caretPosition >= range.location && caretPosition < NSMaxRange(range)) {
		[self setSelectedRange:NSMakeRange(NSMaxRange(range), 0)];
		caretWasInsideFoldedRange = YES;
	}

	NSInteger foldId = [theTextStorage registerFoldedRange:range];

	if(foldId < 0) {
		[RTooltip showWithObject:NLS(@"Maximum number of folded code fragments is reached.") atLocation:[NSEvent mouseLocation]];
		return NO;
	}

	range.location++;
	range.length -= 2;

	if(!range.length) return NO;
	
	if(!blockMode) {
		[[self undoManager] disableUndoRegistration];
		if(![self shouldChangeTextInRange:range replacementString:nil]) {
			[[self undoManager] enableUndoRegistration];
			return NO;
		}
		[[self undoManager] enableUndoRegistration];
	}

	NSString *tooltip = nil;
	if(range.length < 300)
		tooltip = [[self string] substringWithRange:range];
	else
		tooltip = [[[self string] substringWithRange:NSMakeRange(range.location, 300)] stringByAppendingString:@"\n…"];

	[theTextStorage beginEditing];
	[theTextStorage addAttribute:NSCursorAttributeName value:[NSCursor arrowCursor] range:range];
	[theTextStorage addAttribute:NSToolTipAttributeName value:tooltip range:range];
	[theTextStorage endEditing];

	if(!blockMode) {
		[self didChangeText];

		if(caretWasInsideFoldedRange)
			[self scrollRangeToVisible:[self selectedRange]];

		// NSRange r = [[self layoutManager] characterRangeForGlyphRange:[[self layoutManager] 
		// 									glyphRangeForBoundingRect:[scrollView documentVisibleRect] 
		// 											  inTextContainer:[self textContainer]] actualGlyphRange:NULL];

		// [theTextStorage ensureAttributesAreFixedInRange:r];

		if(lineNumberingEnabled)
			[[[self enclosingScrollView] verticalRulerView] performSelector:@selector(refresh) withObject:nil afterDelay:0.0f];
	
		[NSObject cancelPreviousPerformRequestsWithTarget:self 
								selector:@selector(doSyntaxHighlighting) 
								object:nil];

		[self performSelector:@selector(doSyntaxHighlighting) withObject:nil afterDelay:0.02f];
	}

	return YES;

}

- (NSInteger)foldStatusAtIndex:(NSInteger)index
{

	if(index < 0 || index >= [[self string] length]) return 0;

	NSInteger status = 0; // 0 = no; 1 = ▼; 2 = ▲

	NSInteger i = index;
	NSInteger type;
	NSString *selfStr = [self string];
	unichar c;

	BOOL isRd = [selfDelegate isRdDocument];

	unichar commentSign = (isRd) ? '%' : '#';

	// start checking from the end of a line
	while(i >= 0) {

		c = CFStringGetCharacterAtIndex((CFStringRef)selfStr, i);

		// Check only one line
		if(c=='\n' || c=='\r') break;

		// Ignore white spaces and comment sign
		if(c==' ' || c=='\t' || c==commentSign) {
			i--;
			continue;
		}

		type = [self parserContextForPosition:i];

		// Ignore comments
		if(type == pcComment || c==commentSign) {
			i--;
			continue;
		}

		// ======= Check for ▼ 
		if(c=='{' && type == pcExpression) {
			status = 1;
			// look for lines a la "} else {" - if so do not draw folding marker
			i--;
			while(i>=0) {
				c = CFStringGetCharacterAtIndex((CFStringRef)selfStr, i);
				if(c=='\n' || c=='\r') break;
				if((c=='}' || c=='{')&& [self parserContextForPosition:i] == pcExpression) {
					status = 0;
					break;
				}
				i--;
			}
			break;
		}

		// ======= Check for ▲
		if(c=='}') {
			status = 2;
			i--;
			while(i>=0) {
				c = CFStringGetCharacterAtIndex((CFStringRef)selfStr, i);
				if(c=='\n' || c=='\r') break;
				if((c=='}' || c=='{')&& [self parserContextForPosition:i] == pcExpression) {
					status = 0;
					break;
				}
				if(isRd) {
					if(c != '\t' || c != ' ') {
						status = 0;
						break;
					}
				}
				i--;
			}
		}
		break;

	}

	return status;
	
}

- (BOOL)unfoldLinesContainingCharacterAtIndex:(NSUInteger)charIndex
{

	NSInteger foldIndex = [theTextStorage foldedAtIndex:charIndex];

	if(foldIndex > -1) {

		NSRange range = [theTextStorage foldedRangeAtIndex:foldIndex];
		[[self undoManager] disableUndoRegistration];
		if(![self shouldChangeTextInRange:range replacementString:nil]) {
			[[self undoManager] enableUndoRegistration];
			return NO;
		}
		[[self undoManager] enableUndoRegistration];
		
		[theTextStorage removeFoldedRangeWithIndex:foldIndex];

		[self didChangeText];

		[NSObject cancelPreviousPerformRequestsWithTarget:self 
								selector:@selector(doSyntaxHighlighting) 
								object:nil];

		// NSRange r = [[self layoutManager] characterRangeForGlyphRange:[[self layoutManager] 
		// 									glyphRangeForBoundingRect:[scrollView documentVisibleRect] 
		// 											  inTextContainer:[self textContainer]] actualGlyphRange:NULL];
		// 
		// [theTextStorage ensureAttributesAreFixedInRange:r];

		if(lineNumberingEnabled)
			[[[self enclosingScrollView] verticalRulerView] performSelector:@selector(refresh) withObject:nil afterDelay:0.0f];
		
		[self performSelector:@selector(doSyntaxHighlighting) withObject:nil afterDelay:0.02f];

		return YES;
	}
	
	return NO;

}

- (void)mouseDown:(NSEvent *)event
{

	if(![theTextStorage isKindOfClass:[RScriptEditorTextStorage class]]) {
		[super mouseDown:event];
		return;
	}
	
	RScriptEditorLayoutManager *layoutManager = (RScriptEditorLayoutManager*)[self layoutManager];
	NSUInteger glyphIndex = [layoutManager glyphIndexForPoint:[self convertPointFromBase:[event locationInWindow]] inTextContainer:[self textContainer]];
	
	// trigger unfolding if inside foldingAttachmentCell
	if (glyphIndex < [layoutManager numberOfGlyphs]) {
	
		NSUInteger charIndex = [layoutManager characterIndexForGlyphAtIndex:glyphIndex];
		NSInteger foldIndex  = [theTextStorage foldedForIndicatorAtIndex:charIndex];
	
		if (foldIndex > -1) {
	
			NSInteger foldStart = [theTextStorage foldedRangeAtIndex:foldIndex].location+1;
			NSTextAttachment *attachment = [theTextStorage attribute:NSAttachmentAttributeName atIndex:foldStart effectiveRange:NULL];
	
			if (attachment) {
				NSTextAttachmentCell *cell = (NSTextAttachmentCell *)[attachment attachmentCell];
				NSRect cellFrame;
				NSPoint delta;
	
				glyphIndex = [layoutManager glyphIndexForCharacterAtIndex:foldStart];
	
				cellFrame.origin = [self textContainerOrigin];
				cellFrame.size = [layoutManager attachmentSizeForGlyphAtIndex:glyphIndex];
	
				delta = [layoutManager lineFragmentRectForGlyphAtIndex:glyphIndex effectiveRange:NULL].origin;
				cellFrame.origin.x += delta.x;
				cellFrame.origin.y += delta.y;
	
				cellFrame.origin.x += [layoutManager locationForGlyphAtIndex:glyphIndex].x;
	
				if ([cell wantsToTrackMouseForEvent:event inRect:cellFrame ofView:self atCharacterIndex:foldStart] 
						&& [cell trackMouse:event inRect:cellFrame ofView:self atCharacterIndex:foldStart untilMouseUp:YES]) return;
			}
		}
	}
	
	[super mouseDown:event];
}

// - (void)setSelectedRanges:(NSArray *)ranges affinity:(NSSelectionAffinity)affinity stillSelecting:(BOOL)stillSelectingFlag
// {
// 
// 	if(!stillSelectingFlag) {
// 
// 		if([ranges count] > 0) {
// 
// 			// Adjust range for folded text chunks; additional checks will be made in
// 			// the self's delegate [RDocumentWinCtrl:textViewDidChangeSelection:]
// 
// 			NSRange range = [[ranges objectAtIndex:0] rangeValue];
// 
// 			if(!range.length) {
// 				[super setSelectedRanges:ranges affinity:affinity stillSelecting:stillSelectingFlag];
// 				return;
// 			}
// 
// 			NSRange glyphRange = [[self layoutManager] glyphRangeForCharacterRange:range actualCharacterRange:NULL];
// 
// 			if(glyphRange.location != range.location || glyphRange.length != range.length) {
// 
// 				if([ranges count] == 2)
// 					glyphRange.length += [[ranges objectAtIndex:1] rangeValue].length;
// 
// 				SLog(@"RScriptEditorTextView:setSelectedRanges: adjust range via glyph range from %@ to %@", NSStringFromRange(range), NSStringFromRange(glyphRange));
// 
// 				[super setSelectedRange:glyphRange];
// 				return;
// 
// 			}
// 		}
// 	}
// 
// 	[super setSelectedRanges:ranges affinity:affinity stillSelecting:stillSelectingFlag];
// 
// }
// 

// - (void)setTypingAttributes:(NSDictionary *)attrs
// {
// 	// we don't want to store foldingAttributeId as a typing attribute
// 	if ([attrs objectForKey:foldingAttributeId]) {
// 		NSMutableDictionary *copy = [[attrs mutableCopyWithZone:NULL] autorelease];
// 		[copy removeObjectForKey:foldingAttributeId];
// 		attrs = copy;
// 	}
// 
// 	[super setTypingAttributes:attrs];
// }
// 
#pragma mark -

- (void)updatePreferences
{
	
}
@end


