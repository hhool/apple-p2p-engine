//
//  SWCHlsPredictor.h
//  SwarmCloudSDK
//
//  Created by Timmy on 2021/5/8.
//  Copyright © 2021 cdnbye. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface SWCHlsPredictor : NSObject

+ (SWCHlsPredictor *)sharedInstance;

- (void)reset;

- (void)addDuration:(NSTimeInterval)duration;

- (NSTimeInterval)getAvailableDuration;

@end

NS_ASSUME_NONNULL_END
