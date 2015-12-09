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
 *  Create by Simon Urbanek on 12/5/2004
 */

#import "CCComp.h"

@protocol PreferencesDependent
- (void) updatePreferences;
@end

// YES=1, NO=0
#ifndef UNKNOWN
#define UNKNOWN 2
#endif

@interface Preferences : NSObject
{
	NSMutableArray *dependents;
	BOOL batch, changed; // batch-operation related flags
	BOOL writeDefaults; // if YES then any pref retrival fn with non-nil default will write the default if the key is empty. this means that the apps should be aware that fetching a key may result in an update due to an implicit write
	id<PreferencesDependent> insideNotify;   // contains the reference to the currently updated dependent or nil if no update is running atm
}

- (void) beginBatch;
- (void) endBatch;

- (void) addDependent: (id<PreferencesDependent>) dep;
- (void) removeDependent: (id<PreferencesDependent>) dep;

- (void) setKey: (NSString*) key withObject: (id) value;
- (void) setKey: (NSString*) key withFlag: (BOOL) value; // note: set doesn't recognize UNKNOWN!
- (void) setKey: (NSString*) key withArchivedObject: (id) value;
- (void) setKey: (NSString*) key withFloat: (float) value;

- (void) commit;

// global actions
+ (void) setKey: (NSString*) key withObject: (id) value;
+ (void) setKey: (NSString*) key withFlag: (BOOL) value;
+ (void) setKey: (NSString*) key withArchivedObject: (id) value;
+ (void) setKey: (NSString*) key withFloat: (float) value;

+ (NSString *) stringForKey: (NSString*) key withDefault: (NSString*) defaultString;
+ (NSString *) stringForKey: (NSString*) key; // returns nil if there is no such entry
+ (float) floatForKey: (NSString*) key withDefault: (float) defaultValue;
+ (int) integerForKey: (NSString*) key withDefault: (int) defaultValue;
+ (BOOL) flagForKey: (NSString*) key withDefault: (BOOL) flag;
+ (BOOL) flagForKey: (NSString*) key; // returns UNKNOWN if there is no such entry
+ (id) objectForKey: (NSString*) key withDefault: (id) defaultObj;
+ (id) unarchivedObjectForKey: (NSString*) key withDefault: (id) defaultObj;
+ (void) commit;

+ (Preferences*) sharedPreferences;

@end
