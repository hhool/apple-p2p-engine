//
//  SWCSchedulerFactory.h
//  SwarmCloudSDK
//
//  Created by Timmy on 2021/5/9.
//  Copyright © 2021 cdnbye. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SWCScheduler.h"
#import "SWCP2pConfig.h"

NS_ASSUME_NONNULL_BEGIN

@interface SWCSchedulerFactory : NSObject

+ (SWCScheduler *)createSchedulerWithMediaType:(SWCMediaType)mediaType multiBitrate:(BOOL)multiBitrate isLive:(BOOL)isLive endSN:(NSUInteger)endSN P2pConfig:(SWCP2pConfig *)config;

@end

NS_ASSUME_NONNULL_END
