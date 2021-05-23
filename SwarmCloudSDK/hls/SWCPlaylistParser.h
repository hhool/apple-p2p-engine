//
//  SWCPlaylistParser.h
//  SwarmCloudSDK
//
//  Created by Timmy on 2021/5/21.
//  Copyright © 2021 cdnbye. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SWCHlsPlaylist.h"
#import "SWCHlsMasterPlaylist.h"
#import "SWCHlsMediaPlaylist.h"

NS_ASSUME_NONNULL_BEGIN

@interface SWCPlaylistParser : NSObject


- (SWCHlsPlaylist *)parseWithUri:(NSURL *)uri m3u8:(NSString *)m3u8 error:(NSError **)err;

@end

NS_ASSUME_NONNULL_END
