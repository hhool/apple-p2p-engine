//
//  CBQueue.m
//  WebRTC
//
//  Created by Timmy on 2019/5/20.
//  Copyright © 2019 cdnbye. All rights reserved.
//

#import "CBQueue.h"

@interface CBQueue()
{
    NSMutableArray *_queue;
}
@end

@implementation CBQueue

+ (instancetype)queue {
    return [[self alloc] initWithCapacity:10];
}

+ (instancetype)queueWithCapacity:(NSInteger)capacity {
    return [[self alloc] initWithCapacity:capacity];
}

- (instancetype)initWithCapacity:(NSInteger)numItems {
    if (self = [super init]) {
        _queue = [NSMutableArray arrayWithCapacity:numItems];
    }
    return self;
}


- (void)push:(id)obj {
    [_queue addObject:obj];
}

- (id)pop {
    id obj = nil;
    if(_queue.count > 0)
    {
        obj = [_queue objectAtIndex:(_queue.count-1)];
        [_queue removeObjectAtIndex:(_queue.count-1)];
    }
    return obj;
}

- (void)unshift:(id)obj {
    [_queue insertObject:obj atIndex:0];
}

- (id)shift {
    id obj = nil;
    if(_queue.count > 0)
    {
        obj = [_queue objectAtIndex:0];
        [_queue removeObjectAtIndex:0];
    }
    return obj;
}


- (void)clear {
     [_queue removeAllObjects];
}

- (NSUInteger)size {
    return _queue.count;
}

- (BOOL)isEmpty {
    return _queue.count == 0;
}

- (NSArray *)getArray {
    return _queue;
}

@end
