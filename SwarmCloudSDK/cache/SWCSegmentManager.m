//
//  SWCSegmentManager.m
//  SwarmCloudSDK
//
//  Created by Timmy on 2021/5/9.
//  Copyright © 2021 cdnbye. All rights reserved.
//

#import "SWCSegmentManager.h"
#import "SWCSegment.h"

@interface SWCSegmentManager()
{
    NSString *_name;
    PINDiskCache *_diskCache;
    PINMemoryCache *_memoryCache;
}
@end

@implementation SWCSegmentManager

- (instancetype)initWithName:(NSString *)name cacheLimit:(NSUInteger)cLimit diskLimit:(NSUInteger)dLimit useDisk:(BOOL)flag {
    if (name.length == 0) return nil;
    NSString *cacheFolder = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) firstObject];
    NSString *path = [cacheFolder stringByAppendingPathComponent:name];
    if (path.length == 0) return nil;
    _useDisk = flag;
    _name = [name copy];
    
    //    NSLog(@"cacheLimit %@ diskLimit %@", @(cLimit), @(dLimit));
    __weak typeof(self) _self = self;
    if (_useDisk) {
        _diskCache = [[PINDiskCache alloc] initWithName:_name rootPath:cacheFolder];
        _diskCache.byteLimit = dLimit;
        _diskCache.willRemoveObjectBlock = ^(PINDiskCache * _Nonnull cache, NSString * _Nonnull key, id<NSCoding>  _Nullable object, NSURL * _Nullable fileURL) {
            __strong typeof(_self) self = _self;
//            NSLog(@"_diskCache willRemove key %@", key);
            if ([self->_delegate respondsToSelector:@selector(segmentManager:diskCacheDidEvictSegment:)])
            {
                SWCSegment *seg = (SWCSegment *)object;
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self->_delegate segmentManager:self diskCacheDidEvictSegment:seg];
                });
            }
        };
    }
    
    _memoryCache = [PINMemoryCache new];
    _memoryCache.costLimit = cLimit;
    _memoryCache.removeAllObjectsOnEnteringBackground = NO;
    _memoryCache.willRemoveObjectBlock = ^(PINMemoryCache * _Nonnull cache, NSString * _Nonnull key, id  _Nullable object) {
//        NSLog(@"_memoryCache willRemove key %@", key);
        __strong typeof(_self) self = _self;
        if ([self->_delegate respondsToSelector:@selector(segmentManager:memoryCacheDidEvictSegment:)])
        {
            SWCSegment *seg = (SWCSegment *)object;
            dispatch_async(dispatch_get_main_queue(), ^{
                [self->_delegate segmentManager:self memoryCacheDidEvictSegment:seg];
            });
        }
    };

    self = [super init];
    return self;
}

#pragma mark - **************** public methods

- (BOOL)containsSegmentForId:(NSString *)segId {
    return [self containsObjectForKey:segId];
}

- (SWCSegment *)segmentForId:(NSString *)segId {
    SWCSegment *seg = (SWCSegment *)[self objectForKey:segId];
    return seg;
}

- (void)setSegment:(SWCSegment *)segment forId:(NSString *)segId {
    [self setObject:segment forKey:segId withCost:segment.buffer.length];
}

- (void)removeSegmentForId:(NSString *)segId {
    [self removeObjectForKey:segId];
}

- (void)clearAllSegments {
    [self removeAllObjects];
}

#pragma mark - **************** private methods

- (BOOL)containsObjectForKey:(NSString *)key {
    if (_useDisk) {
        return [_memoryCache containsObjectForKey:key] || [_diskCache containsObjectForKey:key];
    }
    return [_memoryCache containsObjectForKey:key];
}

- (id<NSCoding>)objectForKey:(NSString *)key {
    if (_useDisk) {
        id<NSCoding> object = [_memoryCache objectForKey:key];
        if (!object) {
            object = [_diskCache objectForKey:key];
            if (object) {
                [_memoryCache setObject:object forKey:key];
            }
        }
        return object;
    }
    //    NSLog(@"_memoryCache.totalCost %ld", _memoryCache.totalCost);
    return [_memoryCache objectForKey:key];
}

- (void)setObject:(id<NSCoding>)object forKey:(NSString *)key withCost:(NSUInteger)cost {
    if (_useDisk) {
        if (!key || !object) return;                                          // 防止崩溃
        [_diskCache setObject:object forKey:key block:nil];
    }
    [_memoryCache setObject:object forKey:key withCost:cost];
}



- (void)removeObjectForKey:(NSString *)key {
    if (_useDisk) {
        [_diskCache removeObjectForKey:key block:nil];
    }
    [_memoryCache removeObjectForKey:key block:nil];
    
}

- (void)removeAllObjects {
    if (_useDisk) {
        [_diskCache removeAllObjects:nil];
    }
    [_memoryCache removeAllObjects:nil];
    
}

- (NSString *)description {
    if (_name) return [NSString stringWithFormat:@"<%@: %p> (%@)", self.class, self, _name];
    else return [NSString stringWithFormat:@"<%@: %p>", self.class, self];
}


@end
