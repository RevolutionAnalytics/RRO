//
//  ConnectionCache.m
//  RCocoaBundle
//
//  Created by Simon Urbanek on Sun Mar 07 2004.
//  Copyright (c) 2004 Simon Urbanek. All rights reserved.
//

#import "ConnectionCache.h"
#import <Cocoa/Cocoa.h>
#import <sys/fcntl.h>
#import <sys/select.h>
#import <sys/types.h>
#import <sys/time.h>
#import <unistd.h>

@implementation ConnectionCache

- (id) initWithDescriptor: (int) fileDescriptor
{
	maxSize=2048;
	flushMark = (maxSize-(maxSize>>2)); // 3/4 of the buffer as flushMark
    fd = fileDescriptor;
    mutex = [[NSLock alloc] init];
	first = last = 0;
    [NSThread detachNewThreadSelector:@selector(readThread:) toTarget:self withObject:nil];
    return self;
}

#define D_NEXT(d) (*((void**)d))
#define D_LEN(d) (*((unsigned int*)(d+sizeof(void*))))
#define D_PTR(d) (d+sizeof(unsigned int)+sizeof(void*))

- (void) addBytes: (const char*) c length: (unsigned) len
{
    [mutex lock];
	char *d=(char *)malloc(len+sizeof(unsigned int)+sizeof(void*));
	D_LEN(d)=len;
	D_NEXT(d)=0;
	memcpy(D_PTR(d),c,len);
	if (last)
		last=D_NEXT(last)=d;
	else
		last=first=d;
    [mutex unlock];
}

- (NSData*) next
{
	char *f;
	NSData *d;
	
    [mutex lock];
    if (!first) {
        [mutex unlock];
        return nil;
    }
    d=[[NSData alloc] initWithBytes:D_PTR(first) length:D_LEN(first)];
	f=first;
	first=D_NEXT(first);
	if (!first) last=0;
	free(f);
    [mutex unlock];
    return d;
}

- (BOOL) hasData
{
    BOOL really=NO;
    [mutex lock];
    if (first) really=YES;
    [mutex unlock];
    return really;
}

- (void) readThread: (id) argument
{
    //NSAutoreleasePool *pool=[[NSAutoreleasePool alloc] init];
	unsigned int bufSize=maxSize;
    char *buf=(char*) malloc(bufSize);
    int n,pib=0;
    fd_set readfds;
	struct timeval timv;

	timv.tv_sec=0; timv.tv_usec=300000; /* timeout */

    fcntl(fd, F_SETFL, O_NONBLOCK);
    while (1) {
        FD_ZERO(&readfds);
        FD_SET(fd,&readfds);
        select(fd+1, &readfds, 0, 0, &timv);
        if (FD_ISSET(fd, &readfds)) {
            while (pib<bufSize && (n=read(fd,buf+pib,bufSize-pib))>0)
				pib+=n;
			if (pib>flushMark) { // if we reach the flush mark, dump it
                [self addBytes:buf length:pib];
				pib=0;
            }
        } else if (pib>0) { // dump also if we got a timeout
			[self addBytes:buf length:pib];
			pib=0;
		}
    }
    free(buf);
    //[pool release];
}

@end
