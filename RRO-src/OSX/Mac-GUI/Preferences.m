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


/*
 *  Short examples of intended usage for preferences:
 *
 *  "useHighlighting" is time-critical in a sense that it is used every time the 
 *  user presses a key - therefore the flag "useHighlighting" it's queried very
 *  often - It could be cached (see below)
 *
 *  "openInEditor" isn't time critical, because a file is opened only once in a
 *  while so it's ok to fetch it directly from Preferences
 *
 *  For uncached access, use something like: [Preferences flagForKey: openInEditorKey]
 * (see method in Prefernces.h for signatures supported
 *  For cached access, use:
 *  
 *  @implementation xxx
 *  - (void) updatePreferences
 *  {
 *    flag = [Preferences flagForKey: xxxKey withDefault:YES];
 *  }
 *	
 *  - (void) awakeFromNib
 *  {
 *    [[Preferences sharedPreferences] addDependent: self];
 *    [self updatePreferences];
 *    ....
 *  }
 *
 *  - (void) dealloc
 *  {
 *    [[Preferences sharedPreferences] removeDependent: self];
 *    ....
 *  }
 *
 *  For additional examples, see MiscPrefPane.m and EditorPrefPane.m
 */

#import "Preferences.h"
#import "RGUI.h"

Preferences *globalPrefs=nil;

@interface Preferences (Private)
- (BOOL) writeDefaults;
@end

@implementation Preferences

- (id) init
{
	self = [super init];
	
	dependents = [[NSMutableArray alloc] init];
	batch = NO;
	changed = NO;
	writeDefaults = YES;
	insideNotify = NO;
	
	return self;
}

- (void) dealloc
{
	[self commit];
	[super dealloc];
}

- (void) commit
{
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	if (defaults)
		[defaults synchronize];	
}

+ (void) commit
{
	[[Preferences sharedPreferences] commit];
}

- (void) addDependent: (id<PreferencesDependent>) dep
{
	[dependents addObject:dep];
}

- (void) removeDependent: (id<PreferencesDependent>) dep
{
	[dependents removeObject:dep];
}

- (void) notifyDependents
{
	if (!batch) {
		if (!insideNotify) {
			NSEnumerator *enumerator = [dependents objectEnumerator];	
			id<PreferencesDependent> dep;
			while ((dep = (id<PreferencesDependent>) [enumerator nextObject])) {
				insideNotify = dep;
				[dep updatePreferences];
			}
			insideNotify = nil;
			changed = NO;
		} else
			SLog(@"Preferences.notifyDependents: WARNING, cascaded notify attempted while %@ is being notified! Notify request cancelled.", insideNotify);
	}
}

- (void) beginBatch
{
	batch = YES;
}

- (void) endBatch
{
	batch = NO;
	if (changed) [self notifyDependents];
}

- (BOOL) writeDefaults
{
	return writeDefaults;
}

//--- global methods ---

+ (void) setKey: (NSString*) key withObject: (id) value
{
	[[Preferences sharedPreferences] setKey: key withObject: value];
}

+ (void) setKey: (NSString*) key withArchivedObject: (id) value
{
	[[Preferences sharedPreferences] setKey: key withObject: [NSArchiver archivedDataWithRootObject:value]];
}

+ (void) setKey: (NSString*) key withFlag: (BOOL) value
{
	[[Preferences sharedPreferences] setKey: key withObject: value?@"YES":@"NO"];
}

+ (void) setKey: (NSString*) key withFloat: (float) value
{
	[[Preferences sharedPreferences] setKey: key withFloat: value];
}

- (void) setKey: (NSString*) key withArchivedObject: (id) value
{
	[self setKey: key withObject: [NSArchiver archivedDataWithRootObject:value]];
}

- (void) setKey: (NSString*) key withFlag: (BOOL) value
{
	[self setKey: key withObject: value?@"YES":@"NO"];
}

- (void) setKey: (NSString*) key withFloat: (float) value
{
	SLog(@"Preferences.setKey:\"%@\" withFloat:\"%f\"", key, value);
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	if (defaults) {
		[defaults setFloat:value forKey:key];
		changed = YES;
		[self notifyDependents];
	}
}

- (void) setKey: (NSString*) key withObject: (id) value
{
	SLog(@"Preferences.setKey:\"%@\" withObject:\"%@\"", key, value);
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	if (defaults) {
		[defaults setObject:value forKey:key];
		changed=YES;
		[self notifyDependents];
	}
}

+ (NSString *) stringForKey: (NSString*) key withDefault: (NSString*) defaultString
{
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	if (defaults) {
		NSString *s=[defaults stringForKey:key];
		if (s) return s;
	}
	if (defaultString && [[Preferences sharedPreferences] writeDefaults])
		[globalPrefs setKey: key withObject: defaultString];
	return defaultString;
}

+ (NSString *) stringForKey: (NSString*) key
{
	return [Preferences stringForKey: key withDefault: nil];
}

+ (float) floatForKey: (NSString*) key withDefault: (float) defaultValue
{
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	if (defaults) {
		NSString *s=[defaults stringForKey:key];
		if (s) return [s floatValue];
	}
	return defaultValue;
}

+ (int) integerForKey: (NSString*) key withDefault: (int) defaultValue
{
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	if (defaults) {
		NSString *s=[defaults stringForKey:key];
		if (s) return [s intValue];
	}
	return defaultValue;
}

+ (BOOL) flagForKey: (NSString*) key withDefault: (BOOL) flag
{
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	if (defaults) {
		NSString *s=[defaults stringForKey:key];
		if (s) {
			if ([s isEqualTo: @"YES"]) return YES;
			if ([s isEqualTo: @"NO"]) return NO;
		}
	}
	if ((flag==YES || flag==NO) &&
		[[Preferences sharedPreferences] writeDefaults])
		[globalPrefs setKey: key withObject: flag?@"YES":@"NO"];
	return flag;
}

+ (BOOL) flagForKey: (NSString*) key
{
	return [Preferences flagForKey: key withDefault: UNKNOWN];
}

+ (id) objectForKey: (NSString*) key withDefault: (id) defaultObj
{
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	if (defaults) {
		id obj=[defaults objectForKey:key];
		if (obj) return obj;
	}
	if (defaultObj && [[Preferences sharedPreferences] writeDefaults])
		[globalPrefs setKey: key withObject: defaultObj];
	return defaultObj;
}

+ (id) unarchivedObjectForKey: (NSString*) key withDefault: (id) defaultObj
{
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	if (defaults) {
		NSData *data=[defaults dataForKey:key];
		if (data) {
			id obj = [NSUnarchiver unarchiveObjectWithData:data];
			if (obj) return obj;
		}
	}
	if (defaultObj && [[Preferences sharedPreferences] writeDefaults])
		[globalPrefs setKey: key withArchivedObject: defaultObj];
	return defaultObj;
}

+ (Preferences*) sharedPreferences
{
	if (!globalPrefs)
		globalPrefs=[[Preferences alloc] init];
	return globalPrefs;
}

@end
