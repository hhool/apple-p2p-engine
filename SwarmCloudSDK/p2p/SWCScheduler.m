//
//  SWCScheduler.m
//  SwarmCloudSDK
//
//  Created by Timmy on 2021/5/9.
//  Copyright © 2021 cdnbye. All rights reserved.
//

#import "SWCScheduler.h"
#import "CBLogger.h"
#import "CBTimerManager.h"
#import "SWCDataChannel.h"
#import "SWCP2pConfig.h"
#import "SWCP2pEngine.h"

#define SWCSchedulerThrowException @throw [NSException exceptionWithName:NSInternalInconsistencyException reason:[NSString stringWithFormat:@"%@ must be overriden", NSStringFromSelector(_cmd)] userInfo:nil];

static const NSTimeInterval CHECK_CONN_INTERVAL = 30.0;                // 定时检查p2p连接 单位秒
static const NSTimeInterval MAX_NO_EXCHANGE_TIME = 120;                // 最大允许的无数据交换时间 单位秒
static const NSTimeInterval MIN_P2P_LOAD_TIME = 2.0;                   // 保留给p2p下载的最小时间

static NSString *const SCHEDULER_CHECK_CONNS = @"SCHEDULER_CHECK_CONNS";

@interface SWCScheduler()<SWCDataChannelDelegate, SWCSegmentManagerDelegate>
{
    
    
}
@end

@implementation SWCScheduler

- (instancetype)initWithIsLive:(BOOL)live endSN:(NSUInteger)sn andConfig:(SWCP2pConfig *)config {
    if(self = [super init])
    {
        _p2pConfig = config;
        _isLive = live;
        
        _p2pUploaded = 0;
        _p2pDownloaded = 0;
        _httpDownloaded = 0;
        
        // 定时检查连接，超过5分钟没有数据交换则断开
        [self checkConnRecursively];
        
        NSUInteger limit = live ? _p2pConfig.memoryCacheLimit : _p2pConfig.diskCacheLimit;
        NSString *name = [NSString stringWithFormat:@"p2p"];
        BOOL useDisk = !live;
        if (config.diskCacheLimit == 0) {
            useDisk = NO;
        }
        _cacheManager = [[SWCSegmentManager alloc] initWithName:name cacheLimit:_p2pConfig.memoryCacheLimit diskLimit:limit useDisk:useDisk];
        _cacheManager.delegate = self;
        _peerManager = [[CBPeerManager alloc] initManager];
        
#ifdef DEBUG
        [self->_cacheManager clearAllSegments];
#endif
    }
    return self;
}

- (void)loadSegment:(SWCSegment *)segment withBlock:(void(^)(NSHTTPURLResponse *response, NSData *_Nullable data))block {
    CBError(@"Not implemented");
}

- (void)checkConnRecursively {
    __weak typeof(self) weakSelf = self;
    [[CBTimerManager sharedInstance] scheduledDispatchTimerWithName:SCHEDULER_CHECK_CONNS
                                                       timeInterval:CHECK_CONN_INTERVAL
                                                              queue:nil
                                                            repeats:YES
                                                      fireInstantly:NO
                                                             action:^{
                                                                 [weakSelf checkConns];
                                                             }];
    
}

- (void)checkConns {
    __block NSUInteger peerNum = _peerManager.size;
    [[self->_peerManager getPeerMap] enumerateKeysAndObjectsUsingBlock:^(NSString * _Nonnull key, SWCDataChannel * _Nonnull peer, BOOL * _Nonnull stop) {
        if (peer.connected) {
            [peer sendMsgStats:@(peerNum)];
        }
    }];
}

// TODO
- (void)clearDisconnectedPeers {
    // 清理连接断开的peer
    NSMutableArray *keys = [NSMutableArray array];
    for (NSString *peerId in  [_peerManager getPeerMap]) {
        SWCDataChannel *peer = [_peerManager getPeerWithId:peerId];
        if (!peer.connected) {
            peer.msgDelegate = nil;
            [keys addObject:peerId];
            CBInfo(@"remove peer %@", peerId);
        }
    }
    if (keys.count > 0) {
//        [_datachannelDic removeObjectsForKeys:keys];
        [_peerManager removePeersWithIds:keys];
        [self postPeersStatistics];
    }
}

- (void)closeAllPeers {
    [[_peerManager getPeerMap] enumerateKeysAndObjectsUsingBlock:^(NSString * _Nonnull key, SWCDataChannel * _Nonnull obj, BOOL * _Nonnull stop) {
        [obj close];
    }];
    [self postPeersStatistics];
}

- (void)postPeersStatistics {
    NSMutableArray *peers = [NSMutableArray array];
    for (NSString *peerId in [_peerManager getPeerMap]) {
        [peers addObject:peerId];
    }
    NSDictionary *message = @{@"peers": peers};
    [[NSNotificationCenter defaultCenter] postNotificationName:kP2pEngineDidReceiveStatistics object:message];
}

- (void)handshakePeer:(SWCDataChannel *)peer {
    SWCSchedulerThrowException
}

- (void)breakOffPeer:(SWCDataChannel *)peer{
    [_peerManager removePeerWithId:peer.remotePeerId];
    [self postPeersStatistics];
}

- (void)addPeer:(SWCDataChannel *)peer andBitfield:(NSArray *)field{
    peer.msgDelegate = self;
    [_peerManager addPeer:peer withId:peer.remotePeerId];
    if (self.shareOnly) {
        [peer shareOnly];
    }
    [self postPeersStatistics];
    CBInfo(@"add peer %@, now has %@ peers", peer.remotePeerId, @(_peerManager.size));
    if (peer.isInitiator && _peerManager.size <= 5 && peer.peersConnected > 1) {
        // 立即请求节点
        CBDebug(@"get peers from %@", peer.remotePeerId);
        [peer sendMsgGetPeers];
    }
}

- (BOOL)hasPeers {
    return _peerManager.size > 0;
}

- (BOOL)hasIdlePeers {
    return [_peerManager hasIdlePeers];
}

- (NSUInteger)peersNum {
    return _peerManager.size;
}

- (void)evictSN:(SWCSegment *)seg {
    CBError(@"Not implemented");
}

- (BOOL)isSequential {
    SWCSchedulerThrowException
}

- (void)broadcastPlaylist {
    SWCSchedulerThrowException
}

- (NSUInteger)allowP2pLimit {
    return MIN_P2P_LOAD_TIME + _p2pConfig.httpLoadTime;
}

- (void)notifyAllPeersWithSN:(NSNumber *)SN segId:(NSString *)segId {
    CBInfo(@"notifyAllPeers %@", SN);
    [[_peerManager getPeerMap] enumerateKeysAndObjectsUsingBlock:^(NSString * _Nonnull key, SWCDataChannel * _Nonnull peer, BOOL * _Nonnull stop) {
           // 对方没有时才发送
           if (peer && peer.connected && ![peer bitFieldHasSN:SN]) {
               // 直播模式下bitset没有并且比peer最新的SN大才发送，防止无效广播
               if (_isLive && [SN unsignedIntValue] > peer.liveEdgeSN) {
                   [peer sendMsgHave:SN segId:segId];
                   [peer bitFieldAddSN:SN];
               } else if (!_isLive) {
                   [peer sendMsgHave:SN segId:segId];
               }
              
           }
       }];
}

- (void)notifyAllPeersWithSegId:(NSString *)segId {
    CBInfo(@"notifyAllPeers %@", segId);
    [[_peerManager getPeerMap] enumerateKeysAndObjectsUsingBlock:^(NSString * _Nonnull key, SWCDataChannel * _Nonnull peer, BOOL * _Nonnull stop) {
           // 对方没有时才发送
           if (peer && peer.connected && ![peer bitFieldHasSegId:segId]) {
               // 直播模式下bitset没有并且比peer最新的SN大才发送，防止无效广播
               if (_isLive) {
                   [peer sendMsgHave:@(-1) segId:segId];
                   [peer bitFieldAddSegId:segId];
               } else if (!_isLive) {
                   [peer sendMsgHave:@(-1) segId:segId];
               }
              
           }
       }];
}

- (NSArray<SWCDataChannel *> *)getNonactivePeers {
    CFAbsoluteTime currentTs = CFAbsoluteTimeGetCurrent();
    NSMutableArray<SWCDataChannel *> *candidates = [NSMutableArray array];
    [[self->_peerManager getPeerMap] enumerateKeysAndObjectsUsingBlock:^(NSString * _Nonnull key, SWCDataChannel * _Nonnull peer, BOOL * _Nonnull stop) {
        NSTimeInterval duration = currentTs - peer.dataExchangeTs;
//         CBWarn(@"peer %@ no ex %@", peer.remotePeerId, @(duration));
        if (duration > MAX_NO_EXCHANGE_TIME) {
            [candidates addObject:peer];
        }
    }];
    // 排序
    [candidates sortedArrayUsingComparator:^NSComparisonResult(SWCDataChannel *  _Nonnull peer1, SWCDataChannel *  _Nonnull peer2) {
        return  [[NSNumber numberWithLong:peer1.dataExchangeTs] compare:[NSNumber numberWithLong:peer2.dataExchangeTs]];
    }];
    return candidates;
}

- (NSArray<SWCDataChannel *> *)getPeers {
    return [_peerManager.getPeerMap allValues];
}

- (void)requestPeers {
    CBInfo(@"request peers from peers");
    [[self->_peerManager getPeerMap] enumerateKeysAndObjectsUsingBlock:^(NSString * _Nonnull key, SWCDataChannel * _Nonnull peer, BOOL * _Nonnull stop) {
        [peer sendMsgGetPeers];
        }];
}

- (BOOL)isPlayListMapContainsUrl:(NSString *)url {
    SWCSchedulerThrowException
}

- (void)broadcastPlaylist:(NSString *)url data:(NSString *)data {
    SWCSchedulerThrowException
}

- (SWCPlaylistInfo *)getPlaylistFromPeerWithUrl:(NSString *)url {
    SWCSchedulerThrowException
}

- (void)destroy {
    CBInfo(@"destroy scheduler");
    
    [[CBTimerManager sharedInstance] cancelTimerWithName:SCHEDULER_CHECK_CONNS];
    
    // 停止http下载
    if (_currentHttpTask) {
        CBInfo(@"cancel _currentHttpTask");
        [_currentHttpTask cancel];
    }
    
    [self->_cacheManager clearAllSegments];
    [_peerManager clear];
    [self postPeersStatistics];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end
