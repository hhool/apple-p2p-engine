//
//  SWCHlsPredictor.m
//  SwarmCloudSDK
//
//  Created by Timmy on 2021/5/8.
//  Copyright © 2021 cdnbye. All rights reserved.
//

#import "SWCHlsPredictor.h"

@interface SWCHlsPredictor()
{
    NSTimeInterval _startTime;                // 当前请求的时刻
    NSTimeInterval _totalDuration;           // 目前可用的缓冲时间
}
@end

@implementation SWCHlsPredictor

+ (SWCHlsPredictor *)sharedInstance {
    static SWCHlsPredictor *Instance = nil;
    static dispatch_once_t predicate;
    dispatch_once(&predicate, ^{
        Instance = [[SWCHlsPredictor alloc] init];
    });
    return Instance;
}

- (void)reset {
    _startTime = [NSDate timeIntervalSinceReferenceDate];
    _totalDuration = 0;
}

- (void)addDuration:(NSTimeInterval)duration {
//    NSLog(@"duration %@", @(duration));
    _totalDuration += duration;
}

- (NSTimeInterval)getAvailableDuration {
    NSTimeInterval now = [NSDate timeIntervalSinceReferenceDate];
    NSTimeInterval elapsedTime = now - _startTime;
    return _totalDuration - elapsedTime;
}


@end
