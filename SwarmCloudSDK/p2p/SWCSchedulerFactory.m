//
//  SWCSchedulerFactory.m
//  SwarmCloudSDK
//
//  Created by Timmy on 2021/5/9.
//  Copyright © 2021 cdnbye. All rights reserved.
//

#import "SWCSchedulerFactory.h"
#import "SWCHlsSnScheduler.h"
#import "SWCHlsIdScheduler.h"
#import "SWCMp4Scheduler.h"

@implementation SWCSchedulerFactory

+ (SWCScheduler *)createSchedulerWithMediaType:(SWCMediaType)mediaType multiBitrate:(BOOL)multiBitrate isLive:(BOOL)isLive endSN:(NSUInteger)endSN P2pConfig:(SWCP2pConfig *)config {
    switch (mediaType) {
        case SWCMediaTypeHls:
            if (multiBitrate) {
                return [SWCHlsIdScheduler.alloc initWithIsLive:isLive endSN:endSN andConfig:config];
            } else {
                return [SWCHlsSnScheduler.alloc initWithIsLive:isLive endSN:endSN andConfig:config];
            }
            break;
        case SWCMediaTypeMp4:
            return [SWCMp4Scheduler.alloc initWithIsLive:isLive endSN:endSN andConfig:config];
            break;
        case SWCMediaTypeFile:
            return nil;
            break;
    }
}

@end
