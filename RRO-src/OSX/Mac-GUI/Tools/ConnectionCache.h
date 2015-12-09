//
//  ConnectionCache.h
//  RCocoaBundle
//
//  Created by Simon Urbanek on Sun Mar 07 2004.
//  Copyright (c) 2004 Simon Urbanek. All rights reserved.
//

#import <Cocoa/Cocoa.h>

/** This class provides an unlimited (thread-safe) cache for connections. It listens on a file descriptor and caches the input until it is fetched by the "next" or "nextWithLimit" method. The file descriptor is read by a separate thread (hence makes the application multi-threaded when necessary). All methods are thread-safe since the cache maintains its own mutex. */
@interface ConnectionCache : NSObject {
    NSLock *mutex;
    int fd, maxSize, flushMark;
    char *first, *last;
}

- (id) initWithDescriptor: (int) fileDescriptor;
- (BOOL) hasData;
- (NSData*) next;
//- (NSData*) nextWithLimit: (int) maxlen;

@end
