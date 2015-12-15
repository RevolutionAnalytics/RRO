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
 *  Created by Simon Urbanek on 4/14/05.
 *  $Id: GlobalExHandler.m 5707 2011-03-14 22:00:36Z urbaneks $
 */

#import "GlobalExHandler.h"
#include <unistd.h>
#import "RGUI.h"

@implementation GlobalExHandler

- (id) init
{
	self = [super init];
	if (self) {
		[[NSExceptionHandler defaultExceptionHandler] setDelegate:self];
		SLog(@"[GlobalExHandler.init - ready to track exceptions]");
	}
	return self;
}

- (void) dealloc {
	[[NSExceptionHandler defaultExceptionHandler] setDelegate:nil];
	[super dealloc];
}

- (BOOL)exceptionHandler:(NSExceptionHandler *)sender shouldLogException:(NSException *)exception mask:(unsigned int)aMask	// mask is NSLog<exception type>Mask, exception's userInfo has stack trace for key NSStackTraceKey
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	NSString *stack = [[exception userInfo] objectForKey:NSStackTraceKey];
	NSTask *ls=[[NSTask alloc] init];
	NSString *pid = [[NSNumber numberWithInt:getpid()] stringValue];
	NSMutableArray *args = [NSMutableArray arrayWithCapacity:20];
	
	NSLog(@"Logged exception %@ with trace %@", exception, stack);
	if ([[NSFileManager defaultManager] fileExistsAtPath:@"/usr/bin/atos"]) {
		BOOL lastWasNewline = NO;
		NSPipe *sop = [[NSPipe alloc] init];
		NSFileHandle *soh = [sop fileHandleForReading];
		NSLog(@"Calling atos to retrieve symbols, please wait!");
		[args addObject:@"-p"];
		[args addObject:pid];
		[args addObjectsFromArray:[stack componentsSeparatedByString:@" "]];
		
		[ls setLaunchPath:@"/usr/bin/atos"];
		[ls setArguments:args];
		[ls setStandardOutput:sop];
		[ls launch];
		while ([ls isRunning]) {
			NSData *data = [soh availableData];
			if (data && [data length]>0) { /* remove empty lines in the trace */
				const char *c = [data bytes], *d = c, *cs = [data bytes] + [data length];
				if (*c == '\n' && lastWasNewline) d=++c;
				while (*d && d < cs) {
					if (*d=='\n' && d + 1 < cs && d[1]=='\n') {
						int l = d - c;
						while (d < cs && *d=='\n') d++;
						fwrite(c, 1, l+1, stderr);
						c=d;
					} else d++;
				}
				if (c < cs && *c && d-c)
					fwrite(c, 1, d-c, stderr);
				lastWasNewline = (*(cs-1) == '\n') ? YES : NO;
			}
		}
		[sop release];
	} else
	NSLog(@"Unable to find atos - symbols can't be dumped!");
        [ls release];
        
        [pool release];

	return NO;
}

- (BOOL)exceptionHandler:(NSExceptionHandler *)sender shouldHandleException:(NSException *)exception mask:(unsigned int)aMask	// mask is NSHandle<exception type>Mask, exception's userInfo has stack trace for key
{
	return NO;
}

@end
