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

#import "CodeCompletion.h"
#import "../REngine/REngine.h"
#import "../RegexKitLite.h"
#import "FileCompletion.h"
#import "RGUI.h"
#import "../RController.h"


@implementation CodeCompletion

// + (NSString*) complete: (NSString*) part {
// 	return nil;
// 	if (preventReentrance && insideR>0) {
// 		SLog(@"CodeCompletion.complete: returning nil completion to prevent R re-entrance [***]");
// 		return nil;
// 	}
//     REngine *re = [REngine mainEngine];
// 	if (![re beginProtected]) {
// 		SLog(@"CodeCompletion.complete: returning nil completion because protected REngine entry failed [***]");
// 		return nil;
// 	}
//     // first get the length of the search path so we can go environment by environment
//     RSEXP *x = [re evaluateString:@"length(search())"];
//     int pos=1, maxpos;
//     if (x==nil || ((maxpos = [x integer])==0)) { [re endProtected]; return nil; }
// 
//     // ok, we got the search path length; search in each environment and if something matches, get it, otherwise go to the next one
//     while (pos<=maxpos) {
//         // use ls to get the names of the objects in the specific environment
//         NSString *ls=[NSString stringWithFormat:@"ls(pos=%d, all.names=TRUE, pattern=\"^%@.*\")", pos, part];
//         RSEXP *x = [re evaluateString:ls];
//         //NSLog(@"attepmting to find %@ via %@", part, ls);
//         if (x==nil) {
// 			[re endProtected];
//             return nil;
// 		}
//         NSArray *a = [x array];
//         if (a == nil) {
//             [x release];
// 			[re endProtected];
//             return nil;
//         }
//         
//         { // the following code works also if pattern is not specified; with pattern present we could make it even easier, but currently we use it just to narrow the search (e.g. "." could still be matched by something else ...)
//             int i=0, matches=0;
//             NSString *common=nil;
//             while (i<[a count]) {
//                 NSString *sx = (NSString*) [a objectAtIndex:i];
//                 if ([sx hasPrefix: part]) {
//                     if (matches==0)
//                         common = [[NSString alloc] initWithString: sx];
//                     else {
//                         NSString *cpref=[[NSString alloc] initWithString:[common commonPrefixWithString:sx options:0]];
//                         [common release];
//                         common = cpref;
//                     }
//                     matches++;
//                 }
//                 i++;
//             }
//             if (common) { // attempt to get class of the object - it will fail if that's just a partial object, but who cares..
//                     x = [re evaluateString:[NSString stringWithFormat:@"try(class(%@),silent=TRUE)",common]];
//                     [re endProtected];
//                 if (x && [x string] && [[x string] isEqualToString:@"function"])
//                     return [[common autorelease] stringByAppendingString:@"("];
//                 else
//                     return [common autorelease];
//             }
//         }
//         pos++;
//     }
// 	[re endProtected];
//     return nil;
// }
// 
// + (NSArray*) completeAll: (NSString*) part cutPrefix: (int) prefix {
// 	if (preventReentrance && insideR>0) {
// 		SLog(@"CodeCompletion.completeAll: returning nil completion to prevent R re-entrance [***]");
// 		return nil;
// 	}
// 	
//     REngine *re = [REngine mainEngine];
// 	if (![re beginProtected]) {
// 		SLog(@"CodeCompletion.completeAll: returning nil completion because protected REngine entry failed [***]");
// 		return nil;
// 	}
// 	
//     // first get the length of the search path so we can go environment by environment
//     RSEXP *x = [re evaluateString:@"length(search())"];
//     int pos=1, maxpos, matches=0;
// 	NSMutableArray *ca = nil;
// 	NSString *common=nil;
// 
//     if (x==nil || ((maxpos = [x integer])==0)) { [re endProtected]; return nil; }
// 	
// 	ca = [[NSMutableArray alloc] initWithCapacity: 8];
// 	
//     // ok, we got the search path length; search in each environment and if something matches, get it, otherwise go to the next one
//     while (pos<=maxpos) {
//         // use ls to get the names of the objects in the specific environment
//         NSString *ls=[NSString stringWithFormat:@"ls(pos=%d, all.names=TRUE, pattern=\"^%@.*\")", pos, part];
//         RSEXP *x = [re evaluateString:ls];
//         //NSLog(@"attepmting to find %@ via %@", part, ls);
//         if (x==nil) {
// 			[re endProtected];
//             return nil;
// 		}
// 		
//         NSArray *a = [x array];
// 		
//         if (a == nil) {
//             [x release];
// 			[re endProtected];
//             return nil;
//         }
//         
//         { // the following code works also if pattern is not specified; with pattern present we could make it even easier, but currently we use it just to narrow the search (e.g. "." could still be matched by something else ...)
//             int i=0, firstMatch=-1;
//             while (i<[a count]) {
//                 NSString *sx = (NSString*) [a objectAtIndex:i];
//                 if ([sx hasPrefix: part]) {
//                     if (matches==0) {
//                         firstMatch=i;
//                         common=[[NSString alloc] initWithString: sx];
//                     } else {
//                         NSString *cpref=[[NSString alloc] initWithString:[common commonPrefixWithString:sx options:0]];
//                         [common release];
//                         common=cpref;
//                     }
// 					if (prefix<[sx length]) {
// 						[ca addObject: [sx substringFromIndex:prefix]];
// 						matches++;
// 					}
//                 }
//                 i++;
//             }
//         }
//         pos++;
//     }
// 	if (common) { 
// 		if (matches==1) {
// 			// attempt to get class of the object - it will fail if that's just a partial object, but who cares..
// 			x = [re evaluateString:[NSString stringWithFormat:@"try(class(%@),silent=TRUE)",common]];
// 			[ca release];
// 			if (x!=nil && [x string]!=nil && [[x string] isEqualToString:@"function"]) {
// 				[re endProtected];
// 				return [NSArray arrayWithObject: [[[common autorelease] stringByAppendingString:@"("] substringFromIndex:prefix]];
// 			} else {
// 				[re endProtected];
// 				return [NSArray arrayWithObject: [[common autorelease] substringFromIndex:prefix]];
// 			}
// 		} else {
// 			[common release];
// 			[re endProtected];
// 			return ca;
// 		}
// 	}
// 	[re endProtected];
// 	[ca release];
//     return nil;
// }

+ (NSArray*) retrieveSuggestionsForScopeRange:(NSRange)scopeRange inTextView:(NSTextView*)textView
{

	if (preventReentrance && insideR>0) {
		SLog(@"CodeCompletion.retrieveSuggestionForScope: returning nil completion to prevent R re-entrance [***]");
		return nil;
	}

	REngine *re = [REngine mainEngine];
	if (![re beginProtected]) {
		SLog(@"CodeCompletion.retrieveSuggestionForScope: returning nil completion because protected REngine entry failed [***]");
		return nil;
	}

	NSString *linebuffer = [[[textView textStorage] string] substringWithRange:scopeRange];

	SLog(@" - passed string for completion:\n%@", [linebuffer description]);
	if(!linebuffer || ![linebuffer length]) {
		[re endProtected];
		return nil;
	}

	// delete all lines consisting of comments
	linebuffer = [linebuffer stringByReplacingOccurrencesOfRegex:@"(?sm)^\\s*#.*?$" withString:@""];

	// convert scope string to single line
	linebuffer = [linebuffer stringByReplacingOccurrencesOfRegex:@"[\n\r\t]+" withString:@" "];

	// first we need to find out whether we're in a text part or code part
	unichar c;
	int tl = [linebuffer length], tp=0, quotes=0, dquotes=0, lastQuote=-1;
	while (tp < tl) {
		c = CFStringGetCharacterAtIndex((CFStringRef)linebuffer, tp);
		if (c=='\\') 
			tp++; // skip the next char after a backslash (we don't have to worry about \023 and friends)
		else {
			if (dquotes==0 && c=='\'') {
				quotes^=1;
				if (quotes) lastQuote=tp;
			}
			if (quotes==0 && c=='"') {
				dquotes^=1;
				if (dquotes) lastQuote=tp;
			}
		}
		tp++;
	}

	// if we're inside any quotes, bail via file completion
	if (quotes+dquotes>0) {
		SLog(@" - cursor is inside quotes - call file completion");
		[re endProtected];
		return [FileCompletion completeAll:[linebuffer substringFromIndex:lastQuote+1] cutPrefix:0];
	}

	// use internal rcompgen to retrieve completion suggestions;
	// can be modified by the user via rc.setting s() and rc.options() resp.

	// remove all content in quotes and replace '' by "" for passing it through rcompgen.completion('%@')
	linebuffer = [linebuffer stringByReplacingOccurrencesOfRegex:@"([\"']).*?(?<!\\\\)\\1" withString:@"\"\""];

	// escape backslashes
	linebuffer = [linebuffer stringByReplacingOccurrencesOfRegex:@"\\\\" withString:@"\\"];

	SLog(@" - rcompgen completion will be invoked with:\n%@", linebuffer);
	RSEXP *xx = [re evaluateString:[NSString stringWithFormat:@"rcompgen.completion('%@')", linebuffer]];
	[re endProtected];
	if(xx) {

		NSArray *ca = [xx array];

		// if only one suggestion was found set function hint in status bar
		if (ca && [ca count]==1) {

			NSString *foundItem = [ca objectAtIndex:0];

			// ignore all spaces, equal signs, and opened paranthesis at the end
			BOOL showIt = YES;
			int i = [foundItem length]-1;
			unichar c;
			while(i>0) {
				c = CFStringGetCharacterAtIndex((CFStringRef)foundItem, i);
				if(c == ' ' || c == '(') {
					i--;
				}
				else if (c == '=') {
					// if suggestion ends with a = do not show the hint, since
					// it's a parameter
					showIt = NO;
					break;
				}
				else
					break;
			}
			i++;
			foundItem = [foundItem substringToIndex:i];
			SLog(@" - show function hint '%@' with display %d", foundItem, showIt);
			if(showIt && [[(NSTextView*)[[NSApp keyWindow] firstResponder] delegate] respondsToSelector:@selector(hintForFunction:)])
				// (RController*) is only a dummy to avoid compiler warnings
				[(RController*)[(NSTextView*)[[NSApp keyWindow] firstResponder] delegate] hintForFunction:foundItem];
		}

		SLog(@" - found %d suggestions", [ca count]);
		[xx release];
		return (ca && [ca count]) ? ca : nil;

	}

	return nil;

}

@end
