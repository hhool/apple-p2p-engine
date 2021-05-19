//
//  CBQueue.h
//  WebRTC
//
//  Created by Timmy on 2019/5/20.
//  Copyright © 2019 cdnbye. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface CBQueue : NSObject



///size
@property (nonatomic,assign,readonly) NSUInteger size;

///isEmpty
@property (nonatomic,assign,getter=isEmpty) BOOL empty;

+ (instancetype)queue;
+ (instancetype)queueWithCapacity:(NSInteger)capacity;
- (instancetype)initWithCapacity:(NSInteger)capacity;

- (void)push:(id)obj;

- (id)pop;

- (void)unshift:(id)obj;

- (id)shift;

// 移除队列里边所有元素
- (void)clear;

- (NSArray *)getArray;

@end

NS_ASSUME_NONNULL_END
