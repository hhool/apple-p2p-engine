//
//  SWCHlsMasterPlaylist.h
//  SwarmCloudSDK
//
//  Created by Timmy on 2021/5/22.
//  Copyright © 2021 cdnbye. All rights reserved.
//

#import "SWCHlsPlaylist.h"

NS_ASSUME_NONNULL_BEGIN

@interface SWCHlsMasterPlaylist : SWCHlsPlaylist

@property (nonatomic, readonly, strong) NSArray<NSURL *> *mediaPlaylistUrls;

- (BOOL)isMultiPlaylisy;

- (void)addMediaPlaylistUrl:(NSURL *)url;

@end

NS_ASSUME_NONNULL_END
