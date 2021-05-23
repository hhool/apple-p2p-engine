//
//  SWCHlsMasterPlaylist.m
//  SwarmCloudSDK
//
//  Created by Timmy on 2021/5/22.
//  Copyright © 2021 cdnbye. All rights reserved.
//

#import "SWCHlsMasterPlaylist.h"

@interface SWCHlsMasterPlaylist()
{
    NSMutableArray<NSURL *> *_playlistUrls;
}
@end

@implementation SWCHlsMasterPlaylist

- (instancetype)initWithBaseUri:(NSURL *)uri
{
    self = [super initWithBaseUri:uri];
    if (self) {
        _playlistUrls = [NSMutableArray array];
    }
    return self;
}

- (void)addMediaPlaylistUrl:(NSURL *)url {
    [_playlistUrls addObject:url];
}

- (NSArray<NSURL *> *)mediaPlaylistUrls {
    return [NSArray arrayWithArray:_playlistUrls];
}

- (BOOL)isMultiPlaylisy {
    return _playlistUrls.count > 1;
}

@end
