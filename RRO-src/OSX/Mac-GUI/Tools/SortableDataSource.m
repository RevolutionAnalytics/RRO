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

#import "SortableDataSource.h"

@implementation SortableDataSource

- (void) addColumn: (NSArray*) colCont withName: (NSString*) name
{
    [col addObject: colCont];
    [colNames addObject: name];
    if ([col count]==1) {
		NSUInteger i = 0;
		rows = [colCont count];
		sortMap = (int*) malloc(sizeof(int)*rows);
		invSortMap = (int*) malloc(sizeof(int)*rows);
		while (i<rows) { sortMap[i]=invSortMap[i]=i; i++; }
    } else if ([colCont count] != rows) {
		NSLog(@"SortableDataSource: column %@ has %d rows, but the data source has %d rows! Bad things may happen...", name, rows, [colCont count]);
    }
}

- (void) addColumnOfLength: (int) clen withCStrings: (char**) cstr name: (NSString*) name
{
	NSString **ca = (NSString**) malloc(sizeof(NSString*)*clen);
	int i=0;
	while (i<clen) {
		ca[i] = [NSString stringWithUTF8String: cstr[i]];
		i++;
	}
	[self addColumn: [NSArray arrayWithObjects:ca count:clen] withName:name];
	free(ca);
}

- (void) addColumnOfLength: (int) clen withUTF8Strings: (char**) cstr name: (NSString*) name
{
	NSString **ca = (NSString**) malloc(sizeof(NSString*)*clen);
	int i=0;
	while (i<clen) {
		ca[i] = [NSString stringWithUTF8String: cstr[i]];
		i++;
	}
	[self addColumn: [NSArray arrayWithObjects:ca count:clen] withName:name];
	free(ca);
}

- (id) init
{
    self = [super init];
    if (self) {
		col=[[NSMutableArray alloc] init];
		colNames=[[NSMutableArray alloc] init];
		rows=0;
		sortMap=invSortMap=0;
		filter=0; filterLen=0;
    }
    return self;
}

- (void) dealloc
{
    [self reset];
    [col release];
    [colNames release];
    [super dealloc];
}

- (int*) sortMap
{
    return sortMap;
}

- (int*) inverseSortMap
{
    return invSortMap;
}

- (void) reset
{
	[self resetFilter];
    [col removeAllObjects];
    [colNames removeAllObjects];
    rows=0;
    if (sortMap) free(sortMap); sortMap=0;
    if (invSortMap) free(invSortMap); invSortMap=0;
}

- (int)numberOfRowsInTableView:(NSTableView *)tableView
{
    return (filter)?filterLen:rows;
}

- (unsigned) count
{
	return rows;
}

- (unsigned) rows
{
    return (filter)?filterLen:rows;
}

- (void) setFilter: (int*) f length: (int) fl
{
	[self resetFilter];
	filter = (int*) malloc(sizeof(int)*(fl+1));
	filterLen=fl;
	memcpy(filter, f, sizeof(int)*fl);
}

- (void) resetFilter
{
	if (filter) free(filter);
	filter=0;
	filterLen=0;
}

- (id) objectAtColumn: (NSString*) name index: (int) row
{
    if (row<0 || row>=rows || !name)
		return nil;
    else {
		NSUInteger c = [colNames indexOfObject:name];
		if (c == NSNotFound) return nil;
		else {
			NSArray *cc = (NSArray*) [col objectAtIndex: c];
			return (!cc)?nil:[cc objectAtIndex: sortMap[row]];
		}
    }
}

- (id) objectAtColumn: (NSString*) name row: (int) row
{
	return (filter)?
	((row<filterLen)?[self objectAtColumn: name index: filter[row]]:nil)
	:[self objectAtColumn: name index: row];
}

- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(int)row
{
	return [self objectAtColumn: [tableColumn identifier] row: row];
}

- (void)tableView:(NSTableView *)tableView setObjectValue:(id)object forTableColumn:(NSTableColumn *)tableColumn row:(int)row
{
}

- (void)tableView:(NSTableView *)tableView sortDescriptorsDidChange:(NSArray *) oldDescriptors
{
}

@end
