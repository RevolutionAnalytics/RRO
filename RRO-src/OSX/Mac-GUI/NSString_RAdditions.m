/*
 *  R.app : a Cocoa front end to: "R A Computer Language for Statistical Data Analysis"
 *  
 *  R.app Copyright notes:
 *                     Copyright (C) 2004-12  The R Foundation
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
 *  NSString_RAdditions.m
 *
 *  Created by Hans-J. Bibiko on 02/01/2012.
 *
 */

#import "RGUI.h"
#import "NSString_RAdditions.h"
#import "RegexKitLite.h"
#import "PreferenceKeys.h"

@implementation NSString (NSString_RAdditions)

/**
 * Returns a new created UUID string.
 */
+ (NSString*)stringWithNewUUID
{
	// Create a new UUID
	CFUUIDRef uuidObj = CFUUIDCreate(nil);

	// Get the string representation of the UUID
	NSString *newUUID = (NSString*)CFUUIDCreateString(nil, uuidObj);
	CFRelease(uuidObj);
	return [newUUID autorelease];
}

/**
 * Run self as BASH command(s) and return the result.
 * This task can be interrupted by pressing ⌘.
 *
 * @param shellEnvironment A dictionary of environment variable values whose keys are the variable names.
 *
 * @param path The current directory for the bash command. If path is nil, the current directory is inherited from the process that created the receiver (normally /).
 *
 * @param caller The SPDatabaseDocument which invoked that command to register the command for cancelling; if nil the command won't be registered.
 *
 * @param name The menu title of the command.
 *
 * @param theError If not nil and the bash command failed it contains the returned error message as NSLocalizedDescriptionKey
 * 
 */
- (NSString *)evaluateAsBashCommandWithEnvironment:(NSDictionary*)shellEnvironment atPath:(NSString*)path callerInstance:(id)caller contextInfo:(NSDictionary*)contextInfo error:(NSError**)theError ignoreOutput:(BOOL)ignoreOutput
{
	
	NSFileManager *fm = [NSFileManager defaultManager];
	
	BOOL userTerminated = NO;
	BOOL redirectForScript = NO;
	BOOL isDir = NO;
	BOOL nonWaitingMode = ([self hasSuffix:@"&"]) ? YES : NO;
	
	NSMutableArray *scriptHeaderArguments = [NSMutableArray array];
	NSString *scriptPath = @"";
	NSString *uuid = (contextInfo && [contextInfo objectForKey:kBASHFileInternalexecutionUUID]) ? [contextInfo objectForKey:kBASHFileInternalexecutionUUID] : [NSString stringWithNewUUID];
	NSString *stdoutFilePath = [NSString stringWithFormat:@"%@_%@", kBASHTaskOutputFilePath, uuid];
	NSString *scriptFilePath = [NSString stringWithFormat:@"%@_%@", kBASHTaskScriptCommandFilePath, uuid];
	
	[fm removeItemAtPath:scriptFilePath error:nil];
	[fm removeItemAtPath:stdoutFilePath error:nil];
	
	// Parse first line for magic header #! ; if found save the script content and run the command after #! with that file.
	// This allows to write perl, ruby, osascript scripts natively.
	if([self length] > 3 && [self hasPrefix:@"#!"]) {
		
		NSRange firstLineRange = NSMakeRange(2, [self rangeOfString:@"\n"].location - 2);
		
		[scriptHeaderArguments setArray:[[self substringWithRange:firstLineRange] componentsSeparatedByString:@" "]];
		
		while([scriptHeaderArguments containsObject:@""])
			[scriptHeaderArguments removeObject:@""];
		
		if([scriptHeaderArguments count])
			scriptPath = [scriptHeaderArguments objectAtIndex:0];
		
		if([scriptPath hasPrefix:@"/"] && [fm fileExistsAtPath:scriptPath isDirectory:&isDir] && !isDir) {
			NSString *script = [self substringWithRange:NSMakeRange(NSMaxRange(firstLineRange), [self length] - NSMaxRange(firstLineRange))];
			NSError *writeError = nil;
			[script writeToFile:scriptFilePath atomically:YES encoding:NSUTF8StringEncoding error:&writeError];
			if(writeError == nil) {
				redirectForScript = YES;
				[scriptHeaderArguments addObject:scriptFilePath];
			} else {
				NSBeep();
				NSLog(@"Couldn't write script file.");
			}
		}
	} else {
		[scriptHeaderArguments addObject:@"/bin/bash"];
		NSError *writeError = nil;
		[self writeToFile:scriptFilePath atomically:YES encoding:NSUTF8StringEncoding error:&writeError];
		if(writeError == nil) {
			redirectForScript = YES;
			[scriptHeaderArguments addObject:scriptFilePath];
		} else {
			NSBeep();
			NSLog(@"Couldn't write script file.");
		}
	}
	
	NSTask *bashTask = [[NSTask alloc] init];
	[bashTask setLaunchPath:@"/bin/bash"];

	NSMutableDictionary *theEnv = [NSMutableDictionary dictionary];
	// set current environment variables to shell
	[theEnv setDictionary:[[NSProcessInfo processInfo] environment]];
	// overwrite or set additional variables
	if(shellEnvironment) [theEnv addEntriesFromDictionary:shellEnvironment];

	// set exit codes
	[theEnv setObject:[NSNumber numberWithInteger:kBASHTaskRedirectActionNone] forKey:kBASHTaskShellVariableExitNone];
	[theEnv setObject:[NSNumber numberWithInteger:kBASHTaskRedirectActionReplaceSection] forKey:kBASHTaskShellVariableExitReplaceSelection];
	[theEnv setObject:[NSNumber numberWithInteger:kBASHTaskRedirectActionReplaceContent] forKey:kBASHTaskShellVariableExitReplaceContent];
	[theEnv setObject:[NSNumber numberWithInteger:kBASHTaskRedirectActionInsertAsText] forKey:kBASHTaskShellVariableExitInsertAsText];
	[theEnv setObject:[NSNumber numberWithInteger:kBASHTaskRedirectActionInsertAsSnippet] forKey:kBASHTaskShellVariableExitInsertAsSnippet];
	[theEnv setObject:[NSNumber numberWithInteger:kBASHTaskRedirectActionShowAsHTML] forKey:kBASHTaskShellVariableExitShowAsHTML];
	[theEnv setObject:[NSNumber numberWithInteger:kBASHTaskRedirectActionShowAsTextTooltip] forKey:kBASHTaskShellVariableExitShowAsTextTooltip];
	[theEnv setObject:[NSNumber numberWithInteger:kBASHTaskRedirectActionShowAsHTMLTooltip] forKey:kBASHTaskShellVariableExitShowAsHTMLTooltip];
	
	if(theEnv != nil && [theEnv count])
		[bashTask setEnvironment:theEnv];
	
	if(path != nil)
		[bashTask setCurrentDirectoryPath:path];
	
	// STDOUT will be redirected to kBASHTaskOutputFilePath in order to avoid nasty pipe programming due to block size reading
	if([shellEnvironment objectForKey:kBASHTaskShellVariableInputFilePath])
		[bashTask setArguments:[NSArray arrayWithObjects:@"-c", [NSString stringWithFormat:@"%@ > %@ < %@", [scriptHeaderArguments componentsJoinedByString:@" "], stdoutFilePath, [shellEnvironment objectForKey:kBASHTaskShellVariableInputFilePath]], nil]];
	else
		[bashTask setArguments:[NSArray arrayWithObjects:@"-c", [NSString stringWithFormat:@"%@ > %@", [scriptHeaderArguments componentsJoinedByString:@" "], stdoutFilePath], nil]];
	

	NSFileHandle *stderr_file = nil;
	NSPipe *stderr_pipe = nil;
	if(!nonWaitingMode && theError != NULL) {
		stderr_pipe = [NSPipe pipe];
		[bashTask setStandardError:stderr_pipe];
		stderr_file = [stderr_pipe fileHandleForReading];
	} else {
		[bashTask setStandardError:[NSFileHandle fileHandleForWritingAtPath:@"/dev/null"]];
	}
	[bashTask launch];

	NSInteger pid = -1;
	pid = [bashTask processIdentifier];

	if(!nonWaitingMode) {
		// Listen to ⌘. to terminate
		while(1) {
			if(![bashTask isRunning] || [bashTask processIdentifier] == 0) break;
			usleep(1000);
			NSEvent* event = [NSApp nextEventMatchingMask:NSAnyEventMask
												untilDate:[NSDate distantPast]
												   inMode:NSDefaultRunLoopMode
												  dequeue:YES];
			if(!event) continue;
			if ([event type] == NSKeyDown) {
				unichar key = [[event characters] length] == 1 ? [[event characters] characterAtIndex:0] : 0;
				if (([event modifierFlags] & NSCommandKeyMask) && key == '.') {
					[bashTask terminate];
					userTerminated = YES;
					break;
				}
				[NSApp sendEvent:event];
			} else {
				[NSApp sendEvent:event];
			}
		}
		[bashTask waitUntilExit];
	} else {
		if (bashTask) [bashTask release];
		[fm removeItemAtPath:scriptFilePath error:nil];
		[fm removeItemAtPath:stdoutFilePath error:nil];
		return @"";
	}

	// Remove files
	[fm removeItemAtPath:scriptFilePath error:nil];
	
	// If return from bash re-activate R.app
	[NSApp activateIgnoringOtherApps:YES];
	
	NSInteger status = [bashTask terminationStatus];
	NSData *errdata  = nil;
	if(stderr_file) errdata = [stderr_file readDataToEndOfFile];

	if(status == 9 || userTerminated) {
		if(theError != NULL)
		*theError = [[[NSError alloc] initWithDomain:NSPOSIXErrorDomain 
												code:status 
											userInfo:[NSDictionary dictionaryWithObjectsAndKeys:
													  NLS(@"User Termination"),
													  NSLocalizedDescriptionKey, 
													  @"",
													  @"terminated",
													  nil]] autorelease];
		return @"";
	}


	// Check STDERR
	if(theError != NULL && errdata && [errdata length] && (status < kBASHTaskRedirectActionNone || status > kBASHTaskRedirectActionLastCode)) {
		[fm removeItemAtPath:stdoutFilePath error:nil];
		if(theError != NULL && errdata && [errdata length]) {
			NSMutableString *errMessage = [[[NSMutableString alloc] initWithData:errdata encoding:NSUTF8StringEncoding] autorelease];
			[errMessage replaceOccurrencesOfString:[NSString stringWithFormat:@"%@: ", scriptFilePath] withString:@"" options:NSLiteralSearch range:NSMakeRange(0, [errMessage length])];
			*theError = [[[NSError alloc] initWithDomain:NSPOSIXErrorDomain 
													code:status 
												userInfo:[NSDictionary dictionaryWithObjectsAndKeys:
														  errMessage,
														  NSLocalizedDescriptionKey, 
														  nil]] autorelease];
		}
		return @"";
	}

	if(ignoreOutput && theError == NULL) {
		if (bashTask) [bashTask release];
		[fm removeItemAtPath:stdoutFilePath error:nil];
		return @"";
	}

	// Read STDOUT saved to file 
	if([fm fileExistsAtPath:stdoutFilePath isDirectory:nil]) {
		NSString *stdoutContent = [NSString stringWithContentsOfFile:stdoutFilePath encoding:NSUTF8StringEncoding error:nil];
		if(bashTask) [bashTask release], bashTask = nil;
		[fm removeItemAtPath:stdoutFilePath error:nil];
		if(stdoutContent != nil) {
			if (status == 0) {
				return stdoutContent;
			} else {
				if(theError != NULL) {
					if(status == 9 || userTerminated) return @"";
					if(stderr_file) {
						[stderr_file readDataToEndOfFile];
						NSMutableString *errMessage = [[[NSMutableString alloc] initWithData:errdata encoding:NSUTF8StringEncoding] autorelease];
						[errMessage replaceOccurrencesOfString:kBASHTaskScriptCommandFilePath withString:@"" options:NSLiteralSearch range:NSMakeRange(0, [errMessage length])];
						*theError = [[[NSError alloc] initWithDomain:NSPOSIXErrorDomain 
															code:status 
														userInfo:[NSDictionary dictionaryWithObjectsAndKeys:
																  errMessage,
																  NSLocalizedDescriptionKey, 
																  nil]] autorelease];
					}
				}
				if(status > kBASHTaskRedirectActionNone && status <= kBASHTaskRedirectActionLastCode)
					return stdoutContent;
				else
					return @"";
			}
		} else {
			NSLog(@"Couldn't read return string from “%@” by using UTF-8 encoding.", self);
			NSBeep();
		}
	}
	
	if (bashTask) [bashTask release];
	[fm removeItemAtPath:stdoutFilePath error:nil];
	return @"";

}

/**
 * Run self as BASH command(s) and return the result.
 * This task can be interrupted by pressing ⌘.
 *
 * @param shellEnvironment A dictionary of environment variable values whose keys are the variable names.
 *
 * @param path The current directory for the bash command. If path is nil, the current directory is inherited from the process that created the receiver (normally /).
 *
 * @param theError If not nil and the bash command failed it contains the returned error message as NSLocalizedDescriptionKey
 * 
 */
- (NSString *)evaluateAsBashCommandWithEnvironment:(NSDictionary*)shellEnvironment atPath:(NSString*)path error:(NSError**)theError
{
	return [self evaluateAsBashCommandWithEnvironment:shellEnvironment atPath:path callerInstance:nil contextInfo:nil error:theError ignoreOutput:NO];
}

/**
 * Run self as BASH command(s) and return the result.
 * This task can be interrupted by pressing ⌘.
 *
 * @param theError If not nil and the bash command failed it contains the returned error message as NSLocalizedDescriptionKey
 * 
 */
- (NSString *)evaluateAsBashCommandAndError:(NSError**)theError
{
	return [self evaluateAsBashCommandWithEnvironment:nil atPath:nil callerInstance:nil contextInfo:nil error:theError ignoreOutput:NO];
}

/**
 * Run self as BASH command(s) and return the result.
 * This task can be interrupted by pressing ⌘.
 *
 */
- (NSString *)evaluateAsBashCommand
{
	return [self evaluateAsBashCommandWithEnvironment:nil atPath:nil callerInstance:nil contextInfo:nil error:nil ignoreOutput:NO];
}

/**
 * Run self as BASH command(s).
 * This task can be interrupted by pressing ⌘.
 *
 * @param shellEnvironment A dictionary of environment variable values whose keys are the variable names.
 *
 * @param path The current directory for the bash command. If path is nil, the current directory is inherited from the process that created the receiver (normally /).
 *
 * @param caller The SPDatabaseDocument which invoked that command to register the command for cancelling; if nil the command won't be registered.
 *
 * @param name The menu title of the command.
 *
 * @param theError If not nil and the bash command failed it contains the returned error message as NSLocalizedDescriptionKey
 * 
 */
- (void)runAsBashCommandWithEnvironment:(NSDictionary*)shellEnvironment atPath:(NSString*)path callerInstance:(id)caller contextInfo:(NSDictionary*)contextInfo error:(NSError**)theError
{
	[self evaluateAsBashCommandWithEnvironment:shellEnvironment atPath:path callerInstance:caller contextInfo:contextInfo error:theError ignoreOutput:YES];
}

/**
 * Run self as BASH command(s).
 * This task can be interrupted by pressing ⌘.
 *
 * @param shellEnvironment A dictionary of environment variable values whose keys are the variable names.
 *
 * @param path The current directory for the bash command. If path is nil, the current directory is inherited from the process that created the receiver (normally /).
 *
 * @param theError If not nil and the bash command failed it contains the returned error message as NSLocalizedDescriptionKey
 * 
 */
- (void)runAsBashCommandWithEnvironment:(NSDictionary*)shellEnvironment atPath:(NSString*)path error:(NSError**)theError
{
	[self evaluateAsBashCommandWithEnvironment:shellEnvironment atPath:path callerInstance:nil contextInfo:nil error:theError ignoreOutput:YES];
}

/**
 * Run self as BASH command(s).
 * This task can be interrupted by pressing ⌘.
 *
 * @param theError If not nil and the bash command failed it contains the returned error message as NSLocalizedDescriptionKey
 * 
 */
- (void)runAsBashCommandAndError:(NSError**)theError
{
	[self evaluateAsBashCommandWithEnvironment:nil atPath:nil callerInstance:nil contextInfo:nil error:theError ignoreOutput:YES];
}

/**
 * Run self as BASH command(s).
 * This task can be interrupted by pressing ⌘.
 *
 */
- (void)runAsBashCommand
{
	[self evaluateAsBashCommandWithEnvironment:nil atPath:nil callerInstance:nil contextInfo:nil error:nil ignoreOutput:YES];
}

@end
