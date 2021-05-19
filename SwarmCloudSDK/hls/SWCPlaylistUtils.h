//
//  SWCPlaylistUtils.h
//  SwarmCloudSDK
//
//  Created by Timmy on 2021/5/7.
//  Copyright © 2021 cdnbye. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface SWCPlaylistUtils : NSObject

+ (NSString *)checkAndRewritePlaylist:(NSString *)m3u8  isLive:(BOOL)isLive;

+ (NSString *)insertTimeOffsetTag:(NSString *)m3u8;

+ (BOOL)isLivePlaylist:(NSString *)m3u8;

@end

NS_ASSUME_NONNULL_END
