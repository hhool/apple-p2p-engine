//
//  SWCHlsIdScheduler.m
//  SwarmCloudSDK
//
//  Created by Timmy on 2021/5/9.
//  Copyright © 2021 cdnbye. All rights reserved.
//

#import "SWCHlsIdScheduler.h"
#import "CBLogger.h"
#import "SWCHlsSegment.h"
#import "CBTimerManager.h"
#import "SWCHlsPredictor.h"

@interface SWCHlsIdScheduler()<SWCDataChannelDelegate, SWCSegmentManagerDelegate>
{
    NSMutableSet<NSString *> *_bitmap;                      // 记录缓存的segId
    NSMutableDictionary<NSString *, NSNumber *> *_bitCounts;    // 记录peers的每个buffer的总和   segId -> count
    NSString *_loadingSegId;                   // 正在下载的SegId
}
@end

@implementation SWCHlsIdScheduler

- (instancetype)initWithIsLive:(BOOL)live endSN:(NSUInteger)sn andConfig:(SWCP2pConfig *)config {
    _bitmap = [NSMutableSet set];
    _bitCounts  = [NSMutableDictionary dictionary];
    return [super initWithIsLive:live endSN:sn andConfig:config];
}

#pragma mark - **************** public methods

- (void)loadSegment:(SWCSegment *)segment withBlock:(void(^)(NSHTTPURLResponse *response, NSData *_Nullable data))block {
    SWCHlsSegment *segHls = (SWCHlsSegment *)segment;
    NSString *segId = segHls.segId;
    CBDebug(@"loadSegment segId %@", segId);
    
    NSTimeInterval bufferTime = [[SWCHlsPredictor sharedInstance] getAvailableDuration];
    CBDebug(@"CBHlsPredictor bufferTime %@", @(bufferTime));
    // 如果有playerStats并且大于等于0
    if ([self.delegate respondsToSelector:@selector(bufferedDuration)])
    {
        NSTimeInterval duration = [self.delegate bufferedDuration];
        CBInfo(@"scheduler bufferedDuration %@", @(duration));
        if (duration >= 0) {
            bufferTime = duration;
        }
    }
    CBInfo(@"bufferTime %@", @(bufferTime));
    _loadingSegId = segHls.segId;
    
    // 检查缓存中是否有
    if ([_cacheManager containsSegmentForId:segId]) {
        NSData *data = [self loadSegmentFromCache:segHls];
        block(nil, data);
        return;
    }
    
    if (bufferTime > self.allowP2pLimit) {
//            CBDebug(@"buffer time %@", @(bufferTime));
        // 计算loadTimeout 单位秒
        NSTimeInterval loadTimeout = bufferTime - _p2pConfig.httpLoadTime;
        if (loadTimeout > _p2pConfig.dcDownloadTimeout) {
            loadTimeout = _p2pConfig.dcDownloadTimeout;
        }
        
        // 如果该segId没在下载
        CFAbsoluteTime t1 = CFAbsoluteTimeGetCurrent();
        SWCDataChannel *target = [self getTargetPeerBySegId:segHls.segId];
        loadTimeout -= CFAbsoluteTimeGetCurrent()-t1;
        if (loadTimeout < 3.0) {
            // 超时时间太小
            loadTimeout = 3.0;
        }
        if (target) {
            CBDebug(@"request ts from peer %@ timeout %@ isMainThread %@", target.remotePeerId, @(loadTimeout), @([NSThread isMainThread]));
            SWCNetworkResponse *resp = [target loadSegmentSyncFromPeerById:segId SN:segHls.SN timeout:loadTimeout];
            if (resp.data) {
                block(nil, resp.data);
                // 更新时间
//                    [[CBTimer sharedInstance] updateAvailableSpanWithSegmentDuration:segment.duration];
//                    [[CBHlsPredictor sharedInstance] addDuration:segment.duration];
                
            } else {
                NSData *p2pPayload = [target getLoadedBuffer];
                if (self.isHttpRangeSupported
                    && target.currentBufSegId == segId
//                        && target.currentBufArrSize > 0
                    && p2pPayload
                    && [SWCUtils isVideoContentLength:p2pPayload.length]) {
                    // 剩余部分用http下载
                    _currentHttpTask = [self loadRemainSegmentFromHttpWithP2pPayload:p2pPayload andSegment:segHls block:^(NSHTTPURLResponse *response, NSData * _Nullable data) {
                        block(nil, data);
                    }];
                } else {
                    CBWarn(@"loadSegmentSyncFromPeerById failed, turn to http");
                    
                    // p2p下载失败转向http下载
                    _currentHttpTask = [self httpLoadSegment:segHls withBlock:^(NSHTTPURLResponse *response, NSData * _Nullable data) {
                        block((NSHTTPURLResponse *)response, data);
                        return;
                    }];
                    
                    // choke
                    if (target) [target checkIfNeedChoke];
                }
            }
        } else {
            _currentHttpTask = [self httpLoadSegment:segHls withBlock:^(NSHTTPURLResponse *response, NSData * _Nullable data) {
//                    _currentHttpTask = nil;
                block((NSHTTPURLResponse *)response, data);
                return;
            }];
        }

    } else {
        CBDebug(@"http 下载 buffer time %@", @(bufferTime));
        _currentHttpTask = [self httpLoadSegment:segHls withBlock:^(NSHTTPURLResponse *response, NSData * _Nullable data) {
            block((NSHTTPURLResponse *)response, data);
            return;
        }];
    }
}

- (SWCDataChannel *)getTargetPeerBySegId:(NSString *)segId {
    if (![self hasIdlePeers]) {
        return nil;
    }
    if ([_bitCounts objectForKey:segId] != nil) {
        for (SWCDataChannel *peer in [_peerManager getPeersOrderByWeight]) {
            if ([peer bitFieldHasSegId:segId]) {
                CBInfo(@"found segId %@ from peer %@", segId, peer.remotePeerId);
                return peer;
            }
        }
    }
    // 直播一定概率阻塞loadtimeout等待 msg have
//    CBDebug(@"_isLive %@ _liveLatch %@ shouldWaitForNextSeg %@", @(_isLive), _liveLatch, @(shouldWaitForNextSeg(_isReceiver, _isUploader)));
    if (_isLive) {
        [self notifyAllPeersWithSegId:segId];
    }
    return nil;
}

- (NSURLSessionDataTask *)httpLoadSegment:(SWCHlsSegment *)segment withBlock:(void(^)(NSHTTPURLResponse *response, NSData *_Nullable data))block {
    NSString *segId = segment.segId;
    NSString *url = segment.urlString;
    CBInfo(@"scheduler request ts from http %@ segId %@", url, segId);
    __weak typeof(self) weakSelf = self;
    NSURLSessionDataTask *task = [SWCUtils httpLoadSegment:segment timeout:_p2pConfig.downloadTimeout headers:_p2pConfig.httpHeadersForHls withBlock:^(NSHTTPURLResponse * _Nonnull response, NSData * _Nullable data) {
        
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
//        block((NSHTTPURLResponse *)response, data);
        if (data && [SWCUtils isVideoContentType:response.MIMEType length:data.length]) {
            block((NSHTTPURLResponse *)response, data);
            [strongSelf updateLoadedSegId:segment.segId];
            [self notifyAllPeersWithSegId:segment.segId];
            // 缓存起来
            if (![strongSelf->_cacheManager containsSegmentForId:segId] && data.length > 0) {
                CBInfo(@"cache segment %@ MIMEType %@", segId, response.MIMEType);
                segment.buffer = data;
                [strongSelf->_cacheManager setSegment:segment forId:segId];
            }
            // 上报http流量
            self.httpDownloaded += data.length/1024;
        } else {
            block((NSHTTPURLResponse *)response, nil);
        }
    }];
    // 清理连接断开的peer
    if (_isLive) {
        [self clearDisconnectedPeers];
    }
    return task;
}

- (NSURLSessionDataTask *)loadRemainSegmentFromHttpWithP2pPayload:(NSData *)p2pPayload andSegment:(SWCHlsSegment *)segment block:(void(^)(NSHTTPURLResponse *response, NSData *_Nullable data))block {
     __weak typeof(self) weakSelf = self;
    // 剩余部分用http下载
//    NSData *p2pPayload = [target getLoadedBuffer];
    CBInfo(@"continue download from %@  range: %@-", segment.urlString, @(p2pPayload.length));
    // 发起http请求
    return [SWCUtils httpLoadSegment:segment rangeFrom:p2pPayload.length timeout:self->_p2pConfig.downloadTimeout headers:_p2pConfig.httpHeadersForHls withBlock:^(NSHTTPURLResponse * _Nonnull response, NSData * _Nullable httpPayload) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return ;
        // 拼接buffer
        NSMutableData *data = [NSMutableData dataWithCapacity:(p2pPayload.length + httpPayload.length)];
        [data appendData:p2pPayload];
        [data appendData:httpPayload];
//        block(nil, data);
        if (data && [SWCUtils isVideoContentType:response.MIMEType length:data.length]) {
            block(nil, data);
            [strongSelf updateLoadedSegId:segment.segId];
            [self notifyAllPeersWithSegId:segment.segId];
            // 缓存起来
            if (![strongSelf->_cacheManager containsSegmentForId:segment.segId] && data.length > 0) {
                CBInfo(@"cache segment %@", segment.segId);
                segment.buffer = data;
                [strongSelf->_cacheManager setSegment:segment forId:segment.segId];
            }
            
            // 上报http流量
            self.httpDownloaded += httpPayload.length/1024;
        } else {
            block(nil, nil);
        }
    }];
}

- (NSData *)loadSegmentFromCache:(SWCHlsSegment *)segment{
    CBDebug(@"hit cache %@", segment.segId);
    SWCSegment *s = [_cacheManager segmentForId:segment.segId];
    return s.buffer;
}

- (void)updateLoadedSegId:(NSString *)segId {
    if ([_bitmap containsObject:segId]) return;
    [_bitmap addObject:segId];
    
    //在bitCounts清除，防止重复下载
    if ([_bitCounts objectForKey:segId] != nil) {
        [_bitCounts removeObjectForKey:segId];
    }
}

- (void)addPeer:(SWCDataChannel *)peer andBitfield:(NSArray *)field {
    [super addPeer:peer andBitfield:field];
    for (NSString *segId in field) {
        if (![_bitmap containsObject:segId]) {                    //防止重复下载
            [self increBitCounts:segId];
        }
    }
}

- (void)handshakePeer:(SWCDataChannel *)peer {
    if (peer) {
        [peer sendMetaData:_bitmap sequential:NO peersNum:[self peersNum]];
    }
}

- (void)breakOffPeer:(SWCDataChannel *)peer {
    if (peer) {
        [super breakOffPeer:peer];
        for (NSString *segId in peer.getBitMap) {
            [self decreBitCounts:segId];
        }
    }
}

- (void)decreBitCounts:(NSString *)segId {
    if ([[_bitCounts allKeys] containsObject:segId]) {
        NSUInteger last = [[_bitCounts objectForKey:segId] integerValue];
        if (last == 1) {
            [_bitCounts removeObjectForKey:segId];
        } else {
            [_bitCounts setObject:@(last-1) forKey:segId];
        }
    }
}

- (void)increBitCounts:(NSString *)segId {
    if ([_bitCounts objectForKey:segId] == nil) {
        [_bitCounts setObject:@(1) forKey:segId];
    } else {
        NSUInteger last = [[_bitCounts objectForKey:segId] integerValue];
        [_bitCounts setObject:@(last+1) forKey:segId];
    }
}

- (void)destroy {
    [super destroy];
    CBInfo(@"IdScheduler destroy");
}

- (BOOL)isSequential {
    return NO;
}

#pragma mark - **************** SWCDataChannelDelegate

/** have */
- (void)dataChannel:(SWCDataChannel *)peer didReceiveHaveSN:(NSNumber *)sn andSegId:(NSString *)segId {
    CBDebug(@"dc %@ have %@", peer.remotePeerId, segId);
    [peer bitFieldAddSegId:segId];
    if (![_bitmap containsObject:segId]) {       // bitmap没有的才加入bitCounts
        [self increBitCounts:segId];
    }
}

/** lost */
- (void)dataChannel:(SWCDataChannel *)peer didReceiveLostSN:(NSNumber *)sn andSegId:(NSString *)segId {
    CBInfo(@"dc %@ lost %@", peer.remotePeerId, segId);
    [peer bitFieldRemoveSegId:segId];
    [self decreBitCounts:segId];
}

/** piece_ack */
- (void)dataChannel:(SWCDataChannel *)peer didReceivePieceAckWithSegId:(NSString *)segId SN:(NSNumber *)sn andSize:(NSNumber *)size {
    // report Uploaded
    NSUInteger length = [size unsignedIntegerValue]/1024;
    self.p2pUploaded += length;
    NSDictionary *message = @{@"p2pUploaded": @(length)};
    [[NSNotificationCenter defaultCenter] postNotificationName:kP2pEngineDidReceiveStatistics object:message];
}

/** piece_not_found  接收到critical未找到的响应 */
- (void)dataChannel:(SWCDataChannel *)peer didReceivePieceNotFoundWithSegId:(NSString *)segId SN:(nonnull NSNumber *)sn{
    // segId可能不存在
    CBInfo(@"piece %@ not found", segId);
    [peer bitFieldRemoveSegId:segId];
    [self decreBitCounts:segId];
    [peer checkIfNeedChoke];
}

/** response 接收到piece头信息 */
- (void)dataChannel:(SWCDataChannel *)peer didReceivePieceWithSegId:(NSString *)segId SN:(NSNumber *)sn {
    CBDebug(@"receive piece %@ from %@", segId, peer.remotePeerId);
    if (_isLive) {
        [self notifyAllPeersWithSegId:segId];
    }
}

/** response 接收到完整二进制数据 */
- (void)dataChannel:(SWCDataChannel *)peer didReceiveResponseWithSN:(nonnull NSNumber *)sn segId:(nonnull NSString *)segId andData:(nonnull NSData *)data {
    // 进行缓存
    if (![_cacheManager containsSegmentForId:segId] && data.length > 0) {
        SWCHlsSegment *segment = [SWCHlsSegment.alloc initWithBuffer:data sn:sn segId:segId];
        [self updateLoadedSegId:segment.segId];
        if (!_isLive) {
            [self notifyAllPeersWithSegId:segId];
        }
        [_cacheManager setSegment:segment forId:segId];
        CBInfo(@"segment manager add seg %@", segId);
        // 上报p2p流量
        NSUInteger size = data.length/1024;
        self.p2pDownloaded += size;
        NSDictionary *message = @{@"p2pDownloaded": @(size)};
        [[NSNotificationCenter defaultCenter] postNotificationName:kP2pEngineDidReceiveStatistics object:message];
    }
}

/** request */
- (void)dataChannel:(SWCDataChannel *)peer didReceiveRequestWithSegId:(NSString *)segId SN:(NSNumber *)sn andUrgent:(BOOL)urgent {
//    CBDataChannel *peer = [_peerManager getPeerWithId:remotePeerId];
    if (!peer) return;
    // 命中缓存
//    CBDebug(@"didReceiveRequestWithSegId _segId %@ containsSegmentForId %d", _segId, [_cacheManager containsSegmentForId:_segId]);
    if (segId && [_cacheManager containsSegmentForId:segId]) {
        SWCHlsSegment *seg = (SWCHlsSegment *)[_cacheManager segmentForId:segId];
        [peer sendBuffer:seg.buffer segId:seg.segId SN:seg.SN];
    } else {
        // 发送peace_not_found
        [peer sendPieceNotFound:sn andSegId:segId];
        
//        [_cacheManager notifySegmentRemoved:sn];        // TODO 验证
    }
}

- (void)dataChannel:(SWCDataChannel *)peer didDownloadPieceErrorWithSN:(NSNumber *)sn segId:(NSString *)segId {
    
    CBWarn(@"datachannel download error %@ from %@", segId, peer.remotePeerId);
}

- (void)dataChannel:(SWCDataChannel *)peer didReceivePieceAbortWithReason:(NSString *)reason {
    CBWarn(@"peer %@ download aborted, reason %@", peer.remotePeerId, reason);
}

#pragma mark - **************** CBSegmentManagerDelegate

- (void)segmentManager:(SWCSegmentManager *)mgr diskCacheDidEvictSegment:(SWCSegment *)segment {
    SWCHlsSegment *segHls = (SWCHlsSegment *)segment;
    CBDebug(@"diskCacheDidEvictSegment %@", segment);
    NSString *segId = segHls.segId;
    if (!_isLive && [_bitmap containsObject:segId]) {
        // 删除内存对应的segId
        [_bitmap removeObject:segId];
        [_bitCounts removeObjectForKey:segId];
        // 广播lost
        [[_peerManager getPeerMap] enumerateKeysAndObjectsUsingBlock:^(NSString * _Nonnull key, SWCDataChannel * _Nonnull peer, BOOL * _Nonnull stop) {
            if (peer && peer.connected) {
                [peer sendMsgLost:@(-1) segId:segId];
            }
        }];
    }
}

- (void)segmentManager:(SWCSegmentManager *)mgr memoryCacheDidEvictSegment:(SWCSegment *)segment {
    SWCHlsSegment *segHls = (SWCHlsSegment *)segment;
    CBDebug(@"memoryCacheDidEvictSegment %@", segment);
    if (_isLive) {
        NSString *segId = segHls.segId;
        [_bitmap removeObject:segId];
        [_bitCounts removeObjectForKey:segId];
    }
    
}

@end
