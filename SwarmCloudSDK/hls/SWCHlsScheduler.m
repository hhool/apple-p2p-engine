//
//  SWCHlsScheduler.m
//  SwarmCloudSDK
//
//  Created by Timmy on 2021/5/9.
//  Copyright © 2021 cdnbye. All rights reserved.
//

#import "SWCHlsScheduler.h"
#import "SWCHlsPredictor.h"
#import "CBLogger.h"
#import "SWCPlaylistInfo.h"
#import "SWCUtils.h"

@interface SWCHlsScheduler()
{
    NSMutableDictionary<NSString *, SWCPlaylistInfo *> *_playlistInfoMap;          // url -> {hash, ts}
}
@end

@implementation SWCHlsScheduler

- (instancetype)initWithIsLive:(BOOL)live endSN:(NSUInteger)sn andConfig:(SWCP2pConfig *)config {
    _playlistInfoMap = [NSMutableDictionary dictionary];
    return [super initWithIsLive:live endSN:sn andConfig:config];
}

- (BOOL)isPlayListMapContainsUrl:(NSString *)url {
    return [_playlistInfoMap objectForKey:url] != nil;
}

- (void)broadcastPlaylist:(NSString *)url data:(NSString *)data {
    if (!_isLive) return;
    [[self->_peerManager getPeerMap] enumerateKeysAndObjectsUsingBlock:^(NSString * _Nonnull key, SWCDataChannel * _Nonnull peer, BOOL * _Nonnull stop) {
        [peer sendMsgPlaylistWithUrl:url text:data];
    }];
    NSNumber *ts = [SWCUtils getTimestamp];
    NSString *hash = [SWCUtils MD5:data];
    [_playlistInfoMap setObject:[SWCPlaylistInfo.alloc initWithMd5:hash ts:ts] forKey:url];
}

- (SWCPlaylistInfo *)getPlaylistFromPeerWithUrl:(NSString *)url {
    if (!_isLive) return nil;
    SWCPlaylistInfo *info = [_playlistInfoMap objectForKey:url];
    if (!info) return  nil;
    NSNumber *ts = info.ts;
    NSString *lastHash = info.md5;
    NSDictionary *peerMap = [self->_peerManager getPeerMap];
    for (NSString *peerId in peerMap) {
        SWCDataChannel *peer = [peerMap objectForKey:peerId];
        SWCPlaylistInfo *playlist = [peer getLatestPlaylistWithUrl:url lastTs:ts];
        if (playlist) {
            NSString *curHash = [SWCUtils MD5:playlist.data];
            CBDebug(@"lastHash %@ curHash %@", lastHash, curHash);
            if (![lastHash isEqualToString:curHash]) {
                [_playlistInfoMap setObject:[SWCPlaylistInfo.alloc initWithMd5:curHash ts:playlist.ts] forKey:url];
                return playlist;
            }
        }
    }
    return nil;
}

- (void)destroy {
    [super destroy];
    CBInfo(@"destroy SWCHlsScheduler");
    
}

@end
