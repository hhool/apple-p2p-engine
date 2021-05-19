//
//  SWCSegmentManager.h
//  SwarmCloudSDK
//
//  Created by Timmy on 2021/5/9.
//  Copyright © 2021 cdnbye. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <PINDiskCache.h>
#import <PINMemoryCache.h>
#import "SWCSegment.h"

@class SWCSegmentManager;

NS_ASSUME_NONNULL_BEGIN

@protocol SWCSegmentManagerDelegate <NSObject>

@optional

- (void)segmentManager:(SWCSegmentManager *)mgr diskCacheDidEvictSegment:(SWCSegment *)segment;

- (void)segmentManager:(SWCSegmentManager *)mgr memoryCacheDidEvictSegment:(SWCSegment *)segment;

@end

@interface SWCSegmentManager : NSObject

@property (nonatomic, assign, readonly) BOOL useDisk;

@property (nonatomic,weak) id<SWCSegmentManagerDelegate> delegate;

- (instancetype)init NS_UNAVAILABLE;

/**
 初始化方法
 
 @param cLimit 内存缓存的最大size
 @param dLimit 磁盘缓存的最大size
 @param flag 是否使用磁盘或者内存进行缓存
 @return The value associated with key, or nil if no value is associated with key.
 */
- (instancetype)initWithName:(NSString *)name cacheLimit:(NSUInteger)cLimit diskLimit:(NSUInteger)dLimit useDisk:(BOOL)flag;

- (BOOL)containsSegmentForId:(NSString *)segId;

- (SWCSegment *)segmentForId:(NSString *)segId;

- (void)setSegment:(SWCSegment *)segment forId:(NSString *)segId;

- (void)removeSegmentForId:(NSString *)segId;

- (void)clearAllSegments;

@end

NS_ASSUME_NONNULL_END
