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


#import "RGUI.h"
#import "RDocument.h"
#import "RDocumentController.h"
#import "RDocumentWinCtrl.h"
#import "RController.h"
#import "Preferences.h"
#import "RChooseEncodingPopupAccessory.h"
#import "REngine.h"
#import "HelpManager.h"
#import "NSString_RAdditions.h"

// R defines "error" which is deadly as we use open ... with ... error: where error then gets replaced by Rf_error
#ifdef error
#undef error
#endif

@implementation RDocument

- (id)init
{
    self = [super init];
    if (self) {
		SLog(@"RDocument(%@) init", self);
	    documentEncoding = NSUTF8StringEncoding;
		initialContents=nil;
		initialContentsType=nil;
		isEditable=YES;
		isREdit=NO;
		myWinCtrl=nil;
		rdToolsAreWorking=NO;
		fileTypeWasChangedWhileSaving = NO;
    }
    return self;
}

- (void)close {
	SLog(@"RDocument.close <%@> (wctrl=%@)", self, myWinCtrl);
	if (initialContents) [initialContents release], initialContents=nil;
	if (initialContentsType) [initialContentsType release], initialContentsType=nil;
	if (myWinCtrl) {
		SLog(@" - window: %@", [myWinCtrl window]);
		[self removeWindowController:myWinCtrl];
		[myWinCtrl close];
		// --- something is broken - winctrl close doesn't work - I have no idea why - this is a horrible hack to cover up
		//NSWindow *w = [myWinCtrl window];
		//if (w) [NSApp removeWindowsItem: w];
		//[[(RDocumentController*)[NSDocumentController sharedDocumentController] walkKeyListBack] makeKeyAndOrderFront:self];
		// --- end of hack
		[myWinCtrl release];
		myWinCtrl=nil;
	}
	
	[super close];
}

- (void)dealloc {
	if (myWinCtrl) [self close];
	[super dealloc];
}

// FIXME: I don't like this - we should use common text storage instead; conceptually textView is NOT the storage part
- (NSTextView *)textView {
	return [myWinCtrl textView];
}

- (void) makeWindowControllers {
	SLog(@"RDocument.makeWindowControllers: creating RDocumentWinCtrl");
	if (myWinCtrl) {
		SLog(@"*** RDocument.makeWindowControllers: my assumption is that I have only one win controller, but I already have %@! I'll autorelease the first one but won't detach it - don't blame me if this crashes...", myWinCtrl);
		[myWinCtrl autorelease];
	}
	// create RDocumentWinCtrl which is a window controller - it loads the corresponding NIB and sets up the window
	myWinCtrl = [[RDocumentWinCtrl alloc] initWithWindowNibName:@"RDocument"];
	[self addWindowController:myWinCtrl];
	
}

- (NSString*)windowNibName
{
	return @"RDocument";
}

- (int) fileEncoding
{
	return (int) documentEncoding;
}

- (void) setFileEncoding: (int) encoding
{
	SLog(@" - setFileEncoding: %d", encoding);
	documentEncoding = (NSStringEncoding) encoding;
}

- (void)didSaveSelector
{

	// Reopen file if file type was changed while saving
	if(fileTypeWasChangedWhileSaving) {
		NSError *theError = nil;
		fileTypeWasChangedWhileSaving = NO;
		[myWinCtrl close];
		[[NSDocumentController sharedDocumentController] openDocumentWithContentsOfURL:[self fileURL] display:YES error:&theError];
		if (theError) {
			NSLog(@"*** openDocumentWithContentsOfURL: failed with %@", theError);
			NSBeep();
		}
		return;
	}

	// Remain focus on current document after closing SaveAs panel
	[[myWinCtrl window] makeKeyWindow];
	encodingPopUp = nil;

}

- (void)runModalSavePanelForSaveOperation:(NSSaveOperationType)saveOperation delegate:(id)delegate didSaveSelector:(SEL)didSaveSelector contextInfo:(void *)contextInfo
{
	// dispatch didSaveSelector: in order to remain input focus to current document
	[super runModalSavePanelForSaveOperation:saveOperation delegate:self didSaveSelector:@selector(didSaveSelector) contextInfo:contextInfo];
}

// customize Save panel by adding "encoding" view for R documents
- (BOOL)prepareSavePanel:(NSSavePanel *)savePanel
{

	if([[self fileType] isEqualToString:ftRSource]) {
		[savePanel setAllowedFileTypes:[NSArray arrayWithObject:@"R"]];
		if (myWinCtrl)
			[savePanel setAccessoryView:[[[NSDocumentController sharedDocumentController] class] encodingAccessory:(NSStringEncoding)documentEncoding 
																							   includeDefaultEntry:NO 
																									 encodingPopUp:&encodingPopUp]];
		if(encodingPopUp) [encodingPopUp setEnabled:YES];
		[savePanel setAllowsOtherFileTypes:YES];
	}
	else if([[self fileType] isEqualToString:ftRdDoc]) {
		[savePanel setAllowedFileTypes:[NSArray arrayWithObject:@"Rd"]];
		if (myWinCtrl)
			[savePanel setAccessoryView:[[[NSDocumentController sharedDocumentController] class] encodingAccessory:(NSStringEncoding)documentEncoding 
																							   includeDefaultEntry:NO 
																									 encodingPopUp:&encodingPopUp]];
		if(encodingPopUp) [encodingPopUp setEnabled:YES];
		[savePanel setAllowsOtherFileTypes:YES];
	}
	else if(initialContentsType && [initialContentsType hasSuffix:@".rtf"]) {
		[savePanel setAllowedFileTypes:[NSArray arrayWithObject:@"rtf"]];
		[savePanel setAllowsOtherFileTypes:NO];
		[savePanel setAccessoryView:nil];
	}

	[savePanel setCanSelectHiddenExtension:YES];

	return YES;

}

- (BOOL)writeToURL:(NSURL *)absoluteURL ofType:(NSString *)docType error:(NSError **)outError
{

	SLog(@"RDocument.writeToFile: %@ ofType: %@ ", absoluteURL, docType);

	NSString *oldFileType = (initialContentsType)?:ftRSource; 

	if([[[absoluteURL absoluteString] lowercaseString] hasSuffix:@".rtf"]) {
		SLog(@" - docType was changed to rtf due to file extension");
		if(initialContentsType) [initialContentsType release], initialContentsType = nil;
		initialContentsType = [[NSString stringWithString:@"public.rtf"] retain];
	}
	else if([[[absoluteURL absoluteString] lowercaseString] hasSuffix:@".rd"]) {
		SLog(@" - docType was changed to Rd due to file extension");
		if(initialContentsType) [initialContentsType release], initialContentsType = nil;
		initialContentsType = [[NSString stringWithString:ftRdDoc] retain];
		[self setFileType:ftRdDoc];
	}
	else {
		if(initialContentsType) [initialContentsType release], initialContentsType = nil;
		initialContentsType = [[NSString stringWithString:ftRSource] retain];
		[self setFileType:ftRSource];
	}

	SLog(@" - used docType %@", (initialContentsType)?:ftRSource);

	fileTypeWasChangedWhileSaving = ([initialContentsType isEqualToString:oldFileType]) ? NO : YES;

	return [super writeToURL:absoluteURL ofType:(initialContentsType)?:ftRSource error:outError];

}

- (void) loadInitialContents
{

	if (!initialContents) {
		SLog(@"RDocument.loadInitialContents: empty contents, skipping");
		return;
	}
	
	SLog(@"RDocument.loadInitialContents: loading");
	NSEnumerator *e = [[self windowControllers] objectEnumerator];
	RDocumentWinCtrl *wc = nil;
	while ((wc = (RDocumentWinCtrl*)[e nextObject])) { 
		if ([initialContentsType hasSuffix:@".rtf"]) {
			SLog(@" - new RTF contents (%d bytes) for window controller %@", [initialContents length], wc);
			[wc replaceContentsWithRtf: initialContents];
		} else {
			const unsigned char *ic = [initialContents bytes];
			NSString *cs;
			SLog(@" - try to auto-detect file encoding");
			documentEncoding = NSUTF8StringEncoding;
			if ([initialContents length] > 1 
					&& ((ic[0] == 0xff && ic[1] == 0xfe) || (ic[0] == 0xfe && ic[1] == 0xff))) // Unicode BOM
				documentEncoding = NSUnicodeStringEncoding;

			cs = [[NSString alloc] initWithData:initialContents encoding:documentEncoding];
			if(!cs && [self fileURL]) {
				SLog(@" - failed to load as %d encoding, try to autodetect via initWithContentsOfURL:documentEncoding:error:", documentEncoding);
				cs = [[NSString alloc] initWithContentsOfURL:[self fileURL] usedEncoding:&documentEncoding error:nil];
			}
			if (!cs) { // fall back to Latin1 since it's widely used
				SLog(@" - failed to load as %d encoding, falling back to Latin1", documentEncoding);
				documentEncoding = NSISOLatin1StringEncoding;
				cs = [[NSString alloc] initWithData:initialContents encoding:documentEncoding];
			}
			if (!cs) { // fall back to MacRoman - old default
				SLog(@" - failed to load as %d encoding, falling back to MacRoman", documentEncoding);
				documentEncoding = NSMacOSRomanStringEncoding;
				cs = [[NSString alloc] initWithData:initialContents encoding:documentEncoding];
			}
			if (cs) {
				SLog(@" - new string contents (%d chars) for window controller %@", [cs length], wc);
				// Important! otherwise the save box won't know
				[wc setFileEncoding:documentEncoding];
				if(![initialContentsType isEqualToString:ftRSource] && ![initialContentsType isEqualToString:ftRdDoc]) {
					SLog(@" - set plain text mode");
					[wc setPlain:YES];
				}
				[wc replaceContentsWithString:cs];
			}
			[cs release];
		}
	}

	// release initialContents to clean heap esp. for large files
	if(initialContents) [initialContents release], initialContents=nil;

}
- (BOOL)revertToContentsOfURL:(NSURL *)absoluteURL ofType:(NSString *)typeName error:(NSError **)outError
{

	SLog(@"RDocument:revertToContentsOfURL %@ of type %@", absoluteURL, typeName);

	if([typeName hasSuffix:@".rtf"]) {
		NSData *cs = [[NSData alloc] initWithContentsOfURL:absoluteURL];
		if(cs) {
			[myWinCtrl replaceContentsWithRtf:cs];
			[cs release];

			// Remain focus
			[[myWinCtrl window] makeKeyWindow];
			// Clear edited status
			[self updateChangeCount:NSChangeCleared];
			return YES;
		}
	} else {
		NSString *cs = [[NSString alloc] initWithContentsOfURL:absoluteURL encoding:documentEncoding error:nil];
		if(cs) {
			[myWinCtrl replaceContentsWithString:cs];
			[cs release];

			// Remain focus
			[[myWinCtrl window] makeKeyWindow];
			// Clear edited status
			[self updateChangeCount:NSChangeCleared];
			return YES;
		}
	}

	SLog(@" - couldn't revert document");

	NSBeginAlertSheet(NLS(@"Reverting Document"), NLS(@"OK"), nil, nil,
		[myWinCtrl window], self,
		@selector(sheetDidEnd:returnCode:contextInfo:), nil, nil,
		NLS(@"Couldn't revert to saved document"));

	outError = nil;

	return YES;

}


- (void) reinterpretInEncoding: (NSStringEncoding) encoding
{
	SLog(@"RDocument:reinterpretInEncoding - new encoding: %ld", encoding);

	NSString *sc = [myWinCtrl contentsAsString];

	NSData *data = [sc dataUsingEncoding:documentEncoding allowLossyConversion:YES];
	if(!data) {
		NSBeginAlertSheet(NLS(@"Convertion Error"), NLS(@"OK"), nil, nil,
			[myWinCtrl window], self,
			@selector(sheetDidEnd:returnCode:contextInfo:), nil, nil,
			[NSString stringWithFormat:@"%@ %@", NLS(@"Couldn't reinterpret the text by using the encoding"), 
				[NSString localizedNameOfStringEncoding:encoding]]);
		SLog(@"- can't get data");
		return;
	}

	NSString *ns = [[NSString alloc] initWithData:data encoding:encoding];
	if (!ns) {
		[ns release];
		NSBeginAlertSheet(NLS(@"Convertion Error"), NLS(@"OK"), nil, nil,
			[myWinCtrl window], self,
			@selector(sheetDidEnd:returnCode:contextInfo:), nil, nil,
			[NSString stringWithFormat:@"%@ %@", NLS(@"Couldn't reinterpret the text by using the encoding"), 
				[NSString localizedNameOfStringEncoding:encoding]]);
		SLog(@" - can't create string");
		return;
	}

	// Check for any non-valid (surrogate issues esp. if UTF16 is chosen)
	if ([ns UTF8String] == NULL) {
		[ns release];
		NSBeginAlertSheet(NLS(@"Convertion Error"), NLS(@"OK"), nil, nil,
			[myWinCtrl window], self,
			@selector(sheetDidEnd:returnCode:contextInfo:), nil, nil,
			[NSString stringWithFormat:@"%@ %@", NLS(@"Couldn't reinterpret the text by using the encoding"), 
				[NSString localizedNameOfStringEncoding:encoding]]);
		SLog(@" - string contains invalid bytes for chosen encoding");
		return;
	}

	documentEncoding = encoding;
	[myWinCtrl setFileEncoding:documentEncoding];

	// replace text in such a way that the user can perform undo:
	[[myWinCtrl textView] selectAll:nil];
	[[myWinCtrl textView] insertText:ns];

	[ns release];

}

- (NSData *)dataRepresentationOfType:(NSString *)aType
{
	if(encodingPopUp) {
		[[NSUserDefaults standardUserDefaults] setInteger:[[[encodingPopUp selectedItem] representedObject] unsignedIntegerValue] forKey:lastUsedFileEncoding];
		documentEncoding = (NSStringEncoding)[[[encodingPopUp selectedItem] representedObject] unsignedIntegerValue];
	}

	encodingPopUp = nil;

	// Insert code here to write your document from the given data.  You can also choose to override -fileWrapperRepresentationOfType: or -writeToFile:ofType: instead.
	NSEnumerator *e = [[self windowControllers] objectEnumerator];
	RDocumentWinCtrl *wc = nil;
	while ((wc = (RDocumentWinCtrl*)[e nextObject])) { 
		if([aType hasSuffix:@".rtf"])
			return [wc contentsAsRtf];
		else
			return [[wc contentsAsString] dataUsingEncoding: documentEncoding];
	}
	return nil;
}

/* This method is implemented to allow image data file to be loaded into R using open
or drag and drop. In case of a successfull loading of image file, we don't want to
create the UI for the document.
*/
- (BOOL)readFromFile:(NSString *)fileName ofType:(NSString *)docType{
	if( [docType isEqual:@"R Data File"] || [[RController sharedController] isImageData:fileName] == 0){
		[[RController sharedController] sendInput: [NSString stringWithFormat:@"load(\"%@\")",fileName]];
		// [[NSDocumentController sharedDocumentController]  setShouldCreateUI:NO];
		return(YES);
	} else {
		// [[NSDocumentController sharedDocumentController] setShouldCreateUI:YES];
		return( [super readFromFile: fileName ofType: docType] );
	}
}

- (BOOL) loadDataRepresentation: (NSData *)data ofType:(NSString *)aType{

	if (initialContents) [initialContents release], initialContents=nil;
	if (initialContentsType) [initialContentsType release], initialContentsType = nil;

	initialContentsType = [[NSString alloc] initWithString:aType];

	initialContents = [data retain];

	SLog(@"RDocument.loadDataRepresentation loading %d bytes of data and docType %@", [data length], initialContentsType);

	return YES;
}

+ (void) changeDocumentTitle: (NSDocument *)document Title:(NSString *)title{
	NSEnumerator *e = [[document windowControllers] objectEnumerator];
	NSWindowController *wc = nil;
	
	while ((wc = [e nextObject])) {
		NSWindow *dw = [wc window];
		[dw setTitle: title];
	}
}

- (void) setEditable: (BOOL) editable
{
	isEditable=editable;
	NSEnumerator *e = [[self windowControllers] objectEnumerator];
	RDocumentWinCtrl *wc = nil;
	while ((wc = (RDocumentWinCtrl*)[e nextObject]))
		[wc setEditable: editable];
}

- (BOOL) editable
{
	return isEditable;
}

- (void) setREditFlag: (BOOL) flag
{
	isREdit=flag;
}

- (BOOL) hasREditFlag
{
	return isREdit;
}

- (NSString *)displayName
{
	if(isREdit) return NLS(@"Object Editor");
	return [super displayName];
}

- (BOOL) isRTF
{
	return (([self fileName] && [[[self fileName] lowercaseString] hasSuffix:@".rtf"]) || ([self fileType] && [[self fileType] hasSuffix:@".rtf"]));
}

- (BOOL) checkRdDocumentWithFilePath:(NSString*)inputFile reportSuccess:(BOOL)reportSuccess
{

	[myWinCtrl setStatusLineText:[NSString stringWithFormat:@"%@ (%@)", NLS(@"Check Rd document…"), NLS(@"press ⌘. to cancel")]];

	NSError *error = nil;
	[[[myWinCtrl textView] string] writeToFile:inputFile atomically:YES encoding:NSUTF8StringEncoding error:&error];

	if(error != nil){
		NSBeep();
		NSLog(@"RDocument.checkRdDocument couldn't save a temporary file");
		[myWinCtrl setStatusLineText:@""];
		return NO;
	}

	NSString *convCmd = [NSString stringWithFormat:@"R --vanilla -q --slave --encoding=UTF-8 -e 'tools:::checkRd(\"%@\")'", inputFile];
	NSError *bashError = nil;
	NSString *errMessage = [convCmd evaluateAsBashCommandAndError:&bashError];

	if(bashError != nil) {
		if([bashError code] == 1) {
			errMessage = [NSString stringWithFormat:@"%@%@%@", errMessage, ([errMessage length])?@"\n":@"", [[bashError userInfo] objectForKey:NSLocalizedDescriptionKey]];
		} else {
			NSBeep();
			NSLog(@"RDocument.checkRdDocument bailed due to BASH error:\n%@", bashError);
			[myWinCtrl setStatusLineText:@""];
			return NO;
		}
	}

	NSInteger errorMessageMaxLength = 900;

	if(![errMessage length])
		errMessage = (reportSuccess) ? NLS(@"Check was successful.") : @"";
	else {
		errMessage = [errMessage stringByReplacingOccurrencesOfString:inputFile withString:NLS(@"Rd file")];
		errMessage = [errMessage stringByReplacingOccurrencesOfString:[inputFile lastPathComponent] withString:NLS(@"Rd file")];
	}

	if(![errMessage length]) {
		[myWinCtrl setStatusLineText:@""];
		return YES;
	}

	if([errMessage length] > errorMessageMaxLength)
		errMessage = [[errMessage substringWithRange:NSMakeRange(0,errorMessageMaxLength)] stringByAppendingString:@"\n…"];

	NSArray *errorLines = [errMessage componentsMatchedByRegex:[NSString stringWithFormat:@"%@:\\s*\\(?(\\d+)(\\)|-)?\\s*:?", NLS(@"Rd file")] capture:1L];

	// Find first error line number since checkRd messages are appended and in
	// most cases more precise
	NSInteger errorLineNumber = -1;
	if([errorLines count]) {
		NSInteger i;
		NSInteger firstErrorLine = 10000000;
		NSInteger anErrorLine;
		for(i=0; i<[errorLines count]; i++) {
			anErrorLine = [(NSString*)[errorLines objectAtIndex:i] integerValue];
			if(anErrorLine > 0 && (anErrorLine < firstErrorLine))
				firstErrorLine = anErrorLine;
		}
		errorLineNumber = firstErrorLine;
	}

	[myWinCtrl setStatusLineText:@""];

	NSAlert *alert = [NSAlert alertWithMessageText:NLS(@"Rd Check") 
			defaultButton:NLS(@"OK") 
			alternateButton:nil 
			otherButton:nil 
			informativeTextWithFormat:errMessage];

	[alert setAlertStyle:NSWarningAlertStyle];
	[alert runModal];

	[[myWinCtrl window] makeKeyAndOrderFront:self];
	[[myWinCtrl window] makeFirstResponder:[myWinCtrl textView]];

	if(errorLineNumber >=0) {
		NSRange currentLineRange = NSMakeRange(0, 0);
		NSString *s = [[[myWinCtrl textView] textStorage] string];
		NSInteger lineCounter = 0;

		while(lineCounter++ < errorLineNumber)
			currentLineRange = [s lineRangeForRange:NSMakeRange(NSMaxRange(currentLineRange), 0)];

		SLog(@" - go to error line number %d", errorLineNumber);
		// select found line
		[[myWinCtrl textView] setSelectedRange:currentLineRange];
		// scroll to found line
		[[myWinCtrl textView] centerSelectionInVisibleArea:nil];
		// remove selection after 500ms
		[[myWinCtrl textView] performSelector:@selector(moveLeft:) withObject:nil afterDelay:0.5];
	}

	return NO;

}

- (BOOL) checkRdDocument
{

	if(rdToolsAreWorking) return NO;
	rdToolsAreWorking = YES;

	NSString *tempName = [NSTemporaryDirectory() stringByAppendingPathComponent: [NSString stringWithFormat: @"%.0f.", [NSDate timeIntervalSinceReferenceDate] * 1000.0]];
	NSString *inputFile = [NSString stringWithFormat: @"%@%@", tempName, @"rd"];

	BOOL success = [self checkRdDocumentWithFilePath:inputFile reportSuccess:YES];

	[[NSFileManager defaultManager] removeItemAtPath:inputFile error:NULL];

	rdToolsAreWorking = NO;
	return success;

}

- (void) insertRdDataTemplate
{

	if(rdToolsAreWorking) return;
	rdToolsAreWorking = YES;

	[myWinCtrl setStatusLineText:[NSString stringWithFormat:@"%@", NLS(@"press ⌘. to cancel")]];

	NSError *bashError = nil;
	NSString *templateStr = [@"R --vanilla --slave -e 'cat(unlist(prompt(Formaldehyde,NA)), sep=\"§\")'" evaluateAsBashCommandAndError:&bashError];

	[myWinCtrl setStatusLineText:@""];

	if(bashError != nil) {
		NSBeep();
		NSLog(@"RDocumentWinCtrl.insertRdDataTemplate bailed due to BASH error:\n%@", bashError);
		rdToolsAreWorking = NO;
		return;
	}

	if(!templateStr) {
		NSBeep();
		NSLog(@"RDocumentWinCtrl.insertRdDataTemplate bailed; no response from called R session");
		rdToolsAreWorking = NO;
		return;
	}

	templateStr = [templateStr stringByReplacingOccurrencesOfString:@"§" withString:@"\n"];
	templateStr = [templateStr stringByReplacingOccurrencesOfString:@"Formaldehyde" withString:NLS(@"DATA_NAME")];
	templateStr = [templateStr stringByReplacingOccurrencesOfString:@"carb" withString:NLS(@"VAR_NAME_1")];
	templateStr = [templateStr stringByReplacingOccurrencesOfString:@"optden" withString:NLS(@"VAR_NAME_2")];
	[[myWinCtrl textView] insertText:templateStr];

	NSRange newFunRange = [templateStr rangeOfString:NLS(@"DATA_NAME")];
	[[myWinCtrl textView] setSelectedRange:newFunRange];
	[[myWinCtrl textView] scrollRangeToVisible:newFunRange];

	rdToolsAreWorking = NO;

}

- (void) insertRdFunctionTemplate
{

	if(rdToolsAreWorking) return;
	rdToolsAreWorking = YES;

	[myWinCtrl setStatusLineText:[NSString stringWithFormat:@"%@", NLS(@"press ⌘. to cancel")]];

	NSError *bashError = nil;
	NSString *templateStr = [@"R --vanilla --slave -e 'cat(unlist(prompt(mean.POSIXct,NA)), sep=\"§\")'" evaluateAsBashCommandAndError:&bashError];

	[myWinCtrl setStatusLineText:@""];

	if(bashError != nil) {
		NSBeep();
		NSLog(@"RDocumentWinCtrl.insertRdFunctionTemplate bailed due to BASH error:\n%@", bashError);
		rdToolsAreWorking = NO;
		return;
	}

	if(!templateStr) {
		NSBeep();
		NSLog(@"RDocumentWinCtrl.insertRdFunctionTemplate bailed; no response from called R session");
		rdToolsAreWorking = NO;
		return;
	}

	templateStr = [templateStr stringByReplacingOccurrencesOfString:@"§" withString:@"\n"];
	templateStr = [templateStr stringByReplacingOccurrencesOfString:@"mean.POSIXct" withString:NLS(@"FUNCTION_NAME")];
	templateStr = [templateStr stringByReplacingOccurrencesOfRegex:@"\\n\\.POSIXct[^\\n]+" withString:@""];
		
	[[myWinCtrl textView] insertText:templateStr];

	NSRange newFunRange = [templateStr rangeOfString:NLS(@"FUNCTION_NAME")];
	[[myWinCtrl textView] setSelectedRange:newFunRange];
	[[myWinCtrl textView] scrollRangeToVisible:newFunRange];

	rdToolsAreWorking = NO;

}

- (BOOL) convertRd2PDF
{

	if(rdToolsAreWorking) return NO;
	rdToolsAreWorking = YES;

	BOOL success = YES;
	NSError *bashError = nil;

	// Try to find the path to the default tex distribution
	NSString *texPath = @"";
	[myWinCtrl setStatusLineText:[NSString stringWithFormat:@"%@", NLS(@"press ⌘. to cancel")]];
	NSString *aPath = [@"which tex" evaluateAsBashCommand];
	[myWinCtrl setStatusLineText:@""];
	if(aPath && [aPath length]) {
		;
	} else {
		[myWinCtrl setStatusLineText:[NSString stringWithFormat:@"%@", NLS(@"press ⌘. to cancel")]];
		aPath = [@"eval `/usr/libexec/path_helper -s` && dirname `which tex`" evaluateAsBashCommand];
		[myWinCtrl setStatusLineText:@""];
		if(aPath && [aPath length]) {
			texPath = [NSString stringWithFormat:@"export PATH=$PATH:%@", aPath];
		}
	}

	NSString *tempName = [NSTemporaryDirectory() stringByAppendingPathComponent: [NSString stringWithFormat: @"%.0f.", [NSDate timeIntervalSinceReferenceDate] * 1000.0]];
	NSError *error;
	NSString *inputFile = [NSString stringWithFormat: @"%@%@", tempName, @"rd"];
	NSString *pdfOutputFile = [NSString stringWithFormat: @"%@%@", tempName, @"pdf"];
	NSString *errOutputFile = [NSString stringWithFormat: @"%@%@", tempName, @"txt"];

	NSURL *pdfOutputFileURL = [NSURL URLWithString:pdfOutputFile];

	[[[myWinCtrl textView] string] writeToFile:inputFile atomically:YES encoding:NSUTF8StringEncoding error:&error];

	if(![self checkRdDocumentWithFilePath:inputFile reportSuccess:NO]) {
		[[NSFileManager defaultManager] removeItemAtPath:inputFile error:NULL];
		[[NSFileManager defaultManager] removeItemAtPath:pdfOutputFile error:NULL];
		[myWinCtrl setStatusLineText:@""];
		rdToolsAreWorking = NO;
		return NO;
	}

	NSString *convCmd = [NSString stringWithFormat:@"#!/bin/sh\n%@\nR CMD Rd2pdf --no-preview --title='%@' --force --output='%@' '%@' 2>'%@'", texPath, [self displayName], pdfOutputFile, inputFile, errOutputFile];
	bashError = nil;

	[myWinCtrl setStatusLineText:[NSString stringWithFormat:@"%@ (%@)", NLS(@"Rd → PDF…"), NLS(@"press ⌘. to cancel")]];
	[convCmd runAsBashCommandAndError:&bashError];
	[myWinCtrl setStatusLineText:@""];

	NSFileManager *man = [NSFileManager defaultManager];

	if(bashError == nil) {
		if([man fileExistsAtPath:pdfOutputFile])
			[[HelpManager sharedController] showHelpFileForURL:pdfOutputFileURL];
	} else {
		NSString *errMessage = [[bashError userInfo] objectForKey:NSLocalizedDescriptionKey];
		if([man fileExistsAtPath:errOutputFile]) {
			bashError = nil;
			NSString *errMessages = [[[NSString alloc]
				initWithContentsOfFile:errOutputFile
					encoding:NSUTF8StringEncoding
						error:&bashError] autorelease];
			if(bashError == nil && errMessages && [errMessages length])
				errMessage = [errMessage stringByAppendingString:errMessages];
		}
		
		NSAlert *alert = [NSAlert alertWithMessageText:NLS(@"Error") 
				defaultButton:NLS(@"OK") 
				alternateButton:nil 
				otherButton:nil 
				informativeTextWithFormat:[errMessage stringByReplacingOccurrencesOfString:inputFile withString:NLS(@"Rd file")]];

		[alert setAlertStyle:NSWarningAlertStyle];
		[alert runModal];

		[[myWinCtrl window] makeKeyAndOrderFront:self];
		[[myWinCtrl window] makeFirstResponder:[myWinCtrl textView]];
		[[NSFileManager defaultManager] removeItemAtPath:inputFile error:NULL];
		[[NSFileManager defaultManager] removeItemAtPath:pdfOutputFile error:NULL];
		[[NSFileManager defaultManager] removeItemAtPath:errOutputFile error:NULL];
		rdToolsAreWorking = NO;
		return NO;
	}

	rdToolsAreWorking = NO;

	// After 100 secs all temporary files will be deleted even if R was quitted meanwhile
	[self performSelector:@selector(removeFiles:) withObject:[NSArray arrayWithObjects:inputFile, pdfOutputFile, errOutputFile, nil] afterDelay:100];

	return success;
}

- (BOOL) convertRd2HTML
{

	if(rdToolsAreWorking) return NO;
	rdToolsAreWorking = YES;

	BOOL success = YES;

	NSString *tempName = [NSTemporaryDirectory() stringByAppendingPathComponent: [NSString stringWithFormat: @"%.0f.", [NSDate timeIntervalSinceReferenceDate] * 1000.0]];
	NSString *RhomeCSS = @"R.css";
	NSString *Rhome = [[RController sharedController] home];
	
	if(!Rhome || ![Rhome length]) {
		[myWinCtrl setStatusLineText:[NSString stringWithFormat:@"%@", NLS(@"press ⌘. to cancel")]];
		Rhome = [@"R --slave --vanilla -e 'cat(R.home())'" evaluateAsBashCommand];
		[myWinCtrl setStatusLineText:@""];
	}

	if(Rhome && [Rhome length]) {
		RhomeCSS = [NSString stringWithFormat:@"file://%@/doc/html/R.css", Rhome];
	}

	NSError *error;
	NSString *inputFile = [NSString stringWithFormat: @"%@%@", tempName, @"rd"];
	NSString *htmlOutputFile = [NSString stringWithFormat: @"%@%@", tempName, @"html"];

	NSURL *htmlOutputFileURL = [NSURL URLWithString:htmlOutputFile];

	[[[myWinCtrl textView] string] writeToFile:inputFile atomically:YES encoding:NSUTF8StringEncoding error:&error];

	if(![self checkRdDocumentWithFilePath:inputFile reportSuccess:NO]) {
		[[NSFileManager defaultManager] removeItemAtPath:inputFile error:NULL];
		rdToolsAreWorking = NO;
		return NO;
	}

	error = nil;

	[myWinCtrl setStatusLineText:[NSString stringWithFormat:@"%@ (%@)", NLS(@"Rd → HTML…"), NLS(@"press ⌘. to cancel")]];
	NSString *convCmd = [NSString stringWithFormat:@"R CMD Rdconv -t html '%@' 2>/dev/null | perl -pe 's!R.css!%@!'> '%@'", inputFile, RhomeCSS, htmlOutputFile];
	[convCmd evaluateAsBashCommandAndError:&error];
	[myWinCtrl setStatusLineText:@""];
	
	// Try to check if htmlOutputFile has content; if not don't come up with an empty window
	BOOL fsizeChecked = NO;
#if MAC_OS_X_VERSION_MIN_REQUIRED >= MAC_OS_X_VERSION_10_5
	UInt32 fsize = 0;
	NSFileManager *man = [[NSFileManager alloc] init];
	NSDictionary *attrs = [man attributesOfItemAtPath:htmlOutputFile error:nil];
	if(attrs) {
		fsize = [attrs fileSize];
		fsizeChecked = YES;
	}
	[man release];
#endif

	if(!fsizeChecked || (fsizeChecked && fsize > 0)) {
		if(error == nil && [[NSFileManager defaultManager] fileExistsAtPath:htmlOutputFile])
			[[HelpManager sharedController] showHelpFileForURL:htmlOutputFileURL];
		else {
			NSBeep();
			success = NO;
		}
	}

	rdToolsAreWorking = NO;

	// After 100 secs all temporary files will be deleted even if R was quitted meanwhile
	[self performSelector:@selector(removeFiles:) withObject:[NSArray arrayWithObjects:inputFile, htmlOutputFile, nil] afterDelay:100];

	return success;

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

	// Set the input focus to the last doc after closing a sheet
	[[(RDocumentController*)[NSDocumentController sharedDocumentController] findLastWindowForDocType:ftRSource] makeKeyAndOrderFront:nil];

}
- (BOOL) validateToolbarItem: (NSToolbarItem *) toolbarItem
{

	NSString *iid = [toolbarItem itemIdentifier];
	if ([iid isEqualToString: RETI_Save ] || [iid isEqualToString: RDETI_Save ])
		return [self isDocumentEdited];

	return YES;
}

- (void) removeFiles:(NSArray*)files
{
	if(files && [files count]) {
		NSInteger i = 0;
		for(i=0; i<[files count]; i++)
			[[NSFileManager defaultManager] removeItemAtPath:[files objectAtIndex:i] error:NULL];
	}
}

@end

