//
//  SWCHlsSnScheduler.m
//  SwarmCloudSDK
//
//  Created by Timmy on 2021/5/9.
//  Copyright © 2021 cdnbye. All rights reserved.
//

#import "SWCHlsSnScheduler.h"
#import "SWCHlsPredictor.h"
#import "CBLogger.h"
#import "SWCHlsSegment.h"
#import "CBTimerManager.h"

const NSUInteger VOD_MAX_PREFETCH_COUNT = 100;
const NSUInteger MAX_PREFETCH_NUM = 10;                     // 同时预下载的ts最大数量
const NSTimeInterval CHECK_PEERS_INTERVAL = 3;              // 定时p2p下载的时间间隔
const NSUInteger VOD_PREFETCH_OFFSET = 2;                  // 点播模式下P2P请求的偏移量

static NSString *const SCHEDULER_CHECK_PEERS = @"SCHEDULER_CHECK_PEERS";

@interface SWCHlsSnScheduler()<SWCDataChannelDelegate, SWCSegmentManagerDelegate>
{
    NSMutableSet<NSNumber *> *_bitmap;                      // 记录缓存的sn
    NSMutableDictionary<NSNumber *, NSNumber *> *_bitCounts;    // 记录peers的每个buffer的总和   SNindex -> count
    NSUInteger _loadingSN;                      // 正在下载的SN
    NSMutableDictionary<NSNumber *, NSString *> *_requestingMap;               // 保存正在p2p下载的SN  sn -> remotePeerId
    dispatch_semaphore_t _latch;
    NSUInteger _currentLoadedSN;                // 当前已加载的最新SN(播放器请求的)
    NSUInteger _loadedPeerNum;                  // 上次下载的peer的数量
    NSMutableDictionary<NSNumber *, NSString *> *_sn2IdMap;      // 以sn查找segId      sn -> segId
    NSUInteger _maxPrefetchCount;               // 一次遍历的预下载SN最大数量
    NSUInteger _prefetchOffset;                 // P2P请求的偏移量
    NSUInteger _endSN;                          // vod的最后一个切片sn
    NSUInteger _currLostSN;                     // 当前被disk淘汰的SN
    
    // 直播控制参数
    BOOL _isUploader;
    BOOL _isReceiver;
    dispatch_semaphore_t _liveLatch;
    NSUInteger _requestingSN;
    BOOL isSubscribeMode;
    
}
@end

@implementation SWCHlsSnScheduler

- (instancetype)initWithIsLive:(BOOL)live endSN:(NSUInteger)sn andConfig:(SWCP2pConfig *)config {
    _requestingMap = [NSMutableDictionary dictionary];
    if (_isLive) {
        
    } else {
        _maxPrefetchCount = VOD_MAX_PREFETCH_COUNT;
        _prefetchOffset = VOD_PREFETCH_OFFSET;
        _endSN = sn;
        
        // 点播模式下开启定时器
        [self checkPeersRecursively];        // TODO 打开
    }
    _bitmap = [NSMutableSet set];
    _bitCounts  = [NSMutableDictionary dictionary];
    
    _sn2IdMap = [[NSMutableDictionary alloc] init];
    _requestingMap = [NSMutableDictionary dictionary];
    _currLostSN = 0;
    return [super initWithIsLive:live endSN:sn andConfig:config];
}

- (void)loadSegment:(SWCSegment *)segment withBlock:(void(^)(NSHTTPURLResponse *response, NSData *_Nullable data))block {
    SWCHlsSegment *segHls = (SWCHlsSegment *)segment;
    NSString *segId = segHls.segId;
    CBDebug(@"loadSegment sn %@", segHls.SN);
    
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
    _loadingSN = [segHls.SN unsignedIntValue];
    
    // 检查缓存中是否有
    if ([_cacheManager containsSegmentForId:segId]) {
        NSData *data = [self loadSegmentFromCache:segHls];
        block(nil, data);
        return;
    }
    
    if (bufferTime > self.allowP2pLimit || isSubscribeMode) {
//            CBDebug(@"buffer time %@", @(bufferTime));
        // 计算loadTimeout 单位秒
        NSTimeInterval loadTimeout = bufferTime - _p2pConfig.httpLoadTime;
        if (loadTimeout > _p2pConfig.dcDownloadTimeout) {
            loadTimeout = _p2pConfig.dcDownloadTimeout;
        } else if (loadTimeout < 3.5 && isSubscribeMode) {
            // 超时时间太小
            loadTimeout = 3.5;
        }
        
        // 如果该SN正在下载
        if ([_requestingMap objectForKey:segHls.SN]) {
            CBInfo(@"waiting for requesting sn %@", segHls.SN);
            _latch = dispatch_semaphore_create(0);
            if (loadTimeout > 6.0) loadTimeout = 6.0;            // 最多等6秒
            CBInfo(@"latch await for %@", @(loadTimeout));
            dispatch_semaphore_wait(_latch, dispatch_time(DISPATCH_TIME_NOW, loadTimeout * NSEC_PER_SEC));
            _latch = nil;
            // 检查缓存中是否有
            if ([_cacheManager containsSegmentForId:segId]) {
//                CBInfo(@"hit cache %@", segId);
//                CBSegment *s = [_cacheManager segmentForId:segId];
//                block(nil, s.buffer);
//                _currentLoadedSN = s.SN;
//                [[CBTimer sharedInstance] updateAvailableSpanWithSegmentDuration:segment.duration];
//                return;
                NSData *data = [self loadSegmentFromCache:segHls];
                block(nil, data);
            } else {
                // 如果已经下载一部分，用http补足
                SWCDataChannel *target;
                NSData *p2pPayload;
                NSString *remotePeerId = [_requestingMap objectForKey:segHls.SN];
                if (remotePeerId) {
//                    target = [_datachannelDic objectForKey:remotePeerId];
                    target = [_peerManager getPeerWithId:remotePeerId];
                }
                if (target) p2pPayload = [target getLoadedBuffer];
                
                if (target
                    && self.isHttpRangeSupported
                    && target.currentBufSN == [segHls.SN unsignedIntValue]
//                    && target.currentBufArrSize > 0
                    && p2pPayload
                    && [SWCUtils isVideoContentLength:p2pPayload.length]) {
                    CBInfo(@"miss cache, target has loaded partial");
                    _currentHttpTask = [self loadRemainSegmentFromHttpWithP2pPayload:p2pPayload andSegment:segHls block:^(NSHTTPURLResponse *response, NSData * _Nullable data) {
                        block(nil, data);
                    }];
                    if (_peerManager.size >= _p2pConfig.maxPeerConnections/3 && target) {
                        [target checkIfNeedChoke];
                    }
                } else {
                    CBInfo(@"miss cache turn to http loadSegment %@", segId);
                    // choke
                    if (target) [target checkIfNeedChoke];
                    _currentHttpTask = [self httpLoadSegment:segHls withBlock:^(NSHTTPURLResponse *response, NSData * _Nullable data) {
                        block((NSHTTPURLResponse *)response, data);
                        return;
                    }];
                }
            }
        }
        else {
            // 如果该SN没在下载
            CBDebug(@"isUploader %@ isReceiver %@", @(_isUploader), @(_isReceiver));
            CFAbsoluteTime t1 = CFAbsoluteTimeGetCurrent();
            SWCDataChannel *target = [self getTargetPeerBySN:segHls.SN andTimeout:loadTimeout];
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
                    
                    self->_currentLoadedSN = [segHls.SN unsignedIntValue];
                } else {
                    NSData *p2pPayload = [target getLoadedBuffer];
                    if (self.isHttpRangeSupported
                        && target.currentBufSN == [segHls.SN unsignedIntValue]
//                        && target.currentBufArrSize > 0
                        && p2pPayload
                        && [SWCUtils isVideoContentLength:p2pPayload.length]) {
                        // 剩余部分用http下载
                        _currentHttpTask = [self loadRemainSegmentFromHttpWithP2pPayload:p2pPayload andSegment:segHls block:^(NSHTTPURLResponse *response, NSData * _Nullable data) {
                            block(nil, data);
                        }];
                    } else {
                        CBWarn(@"loadSegmentFromPeerById failed, turn to http");
                        
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
        }
    } else {
        CBDebug(@"http 下载 buffer time %@", @(bufferTime));
        _currentHttpTask = [self httpLoadSegment:segHls withBlock:^(NSHTTPURLResponse *response, NSData * _Nullable data) {
            block((NSHTTPURLResponse *)response, data);
            return;
        }];
    }
}

- (SWCDataChannel *)getTargetPeerBySN:(NSNumber *)sn andTimeout:(NSTimeInterval)timeout {
//    if (!([self hasIdlePeers] && [_bitCounts objectForKey:sn])) {
//        return nil;
//    }
    if (![self hasIdlePeers]) {
        return nil;
    }
    if ([_bitCounts objectForKey:sn] != nil) {
        for (SWCDataChannel *peer in [_peerManager getPeersOrderByWeight]) {
            if ([peer bitFieldHasSN:sn]) {
                CBInfo(@"found sn %@ from peer %@", sn, peer.remotePeerId);
                return peer;
            }
        }
    }
    // 直播一定概率阻塞loadtimeout等待 msg have
//    CBDebug(@"_isLive %@ _liveLatch %@ shouldWaitForNextSeg %@", @(_isLive), _liveLatch, @(shouldWaitForNextSeg(_isReceiver, _isUploader)));
    if (_isLive && !_liveLatch && shouldWaitForNextSeg(_isReceiver, _isUploader)) {
        _requestingSN = [sn unsignedIntegerValue];
        CBDebug(@"getTargetPeerBySN strat hangup");
        _liveLatch = dispatch_semaphore_create(0);
        if (timeout > 5.0) timeout = 5.0;            // 最多等5秒
        CBDebug(@"latch await for %@", @(timeout));
        dispatch_semaphore_wait(_liveLatch, dispatch_time(DISPATCH_TIME_NOW, timeout * NSEC_PER_SEC));
        CBDebug(@"latch end wait");
        _liveLatch = nil;
        if (_requestingSN == 0) {
            for (SWCDataChannel *peer in [_peerManager getAvailablePeers]) {
                if ([peer bitFieldHasSN:sn]) {
                    CBInfo(@"found sn %@ from peer %@", sn, peer.remotePeerId);
//                    [NSThread sleepForTimeInterval:0.10];         // 等待100毫秒让peer有时间缓存
                    return peer;
                }
            }
        }
    }
    
    return nil;
}

bool shouldWaitForNextSeg(bool isReceiver, bool isUploader) {
//    CBInfo(@"arc4random %@", @(arc4random()%100));
    if (isReceiver || isUploader) {
        if (isReceiver && isUploader) {
            // 都是的话一半概率等
//            if (arc4random()%100 > 50) {
//                return true;
//            }
            // 都是的话等待
            return true;
        } else if (isReceiver) {
            // 只是接收者
            return true;
        } else {
            // 只是上传者
            return false;
        }
    } else {
        // 都不是的话80%概率等
        if (arc4random()%100 > 20) {
            return true;
        }
    }
    // 都不是的话20%概率不等
    return false;
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
            [strongSelf updateLoadedSN:segment.SN];
            [self notifyAllPeersWithSN:segment.SN segId:segment.segId];
            // 缓存起来
            if (![strongSelf->_cacheManager containsSegmentForId:segId] && data.length > 0) {
                CBInfo(@"cache segment %@ MIMEType %@", segId, response.MIMEType);
                segment.buffer = data;
                [strongSelf->_cacheManager setSegment:segment forId:segId];
            }
            
            strongSelf->_currentLoadedSN = [segment.SN unsignedIntValue];
            [strongSelf->_sn2IdMap setObject:segId forKey:segment.SN];
            
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
            NSUInteger sn = [segment.SN unsignedIntValue];
            strongSelf->_currentLoadedSN = sn;
            [strongSelf->_sn2IdMap setObject:segment.segId forKey:segment.SN];
            [strongSelf updateLoadedSN:segment.SN];
            [self notifyAllPeersWithSN:segment.SN segId:segment.segId];
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
    _currentLoadedSN = [segment.SN unsignedIntValue];
    return s.buffer;
}

- (void)checkPeersRecursively {
//    CBInfo(@"_correntLoadedSN %ld _endSN %ld", _correntLoadedSN, _endSN);
//    __weak typeof(self) _self = self;
    double checkDelay = [self calculateDelay];
    
    CBInfo(@"loaded peers %@ next checkDelay is %f", @(_loadedPeerNum), checkDelay);
    _loadedPeerNum = 0;
//    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(checkDelay * NSEC_PER_SEC)), dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
//        __strong typeof(_self) self = _self;
//        if (!self) return;
//        [self checkPeers];
//        [self checkRecursively];
//    });
    
    __weak typeof(self) weakSelf = self;
    [[CBTimerManager sharedInstance] scheduledDispatchTimerWithName:SCHEDULER_CHECK_PEERS
                                                       timeInterval:checkDelay
                                                              queue:nil
                                                            repeats:YES
                                                      fireInstantly:NO
                                                             action:^{
                                                                 [weakSelf checkPeers];
                                                             }];
    
}

- (void)checkPeers {
    // 清理连接断开的peer
    [self clearDisconnectedPeers];
    
    if (_currentLoadedSN == 0) return;
    if (!_isLive && _currentLoadedSN == _endSN) return;
    if (_currLostSN > 0 && _loadingSN - _currLostSN <= 30) return;       
    if (![self hasIdlePeers]) return;
    NSArray *availablePeers = [_peerManager getPeersOrderByWeight];
    NSUInteger prefetchCount = 0;
    NSUInteger offset = _loadingSN + _prefetchOffset;
    NSMutableSet *requestedPeers = [NSMutableSet set];
    while (requestedPeers.count < MAX_PREFETCH_NUM && requestedPeers.count < availablePeers.count
           && prefetchCount < _maxPrefetchCount) {
        
        if (!_isLive && offset > _endSN) return;
//        CBInfo(@"while2");
        if ([_bitmap containsObject:@(offset)]) {
            offset ++;
            continue;
        }
//        CBInfo(@"while3");
        if (offset != _loadingSN && [_bitCounts objectForKey:@(offset)] && ![_requestingMap objectForKey:@(offset)]) {         //如果这个块没有缓存并且peers有并且没有在请求
            for (SWCDataChannel *peer in availablePeers) {             //找到拥有这个块并且空闲的peer
                if (![requestedPeers containsObject:peer] && [peer bitFieldHasSN:@(offset)]) {
                    CBInfo(@"request prefetch %@ from peer %@", @(offset), peer.remotePeerId);
                    [peer sendRequestSegmentBySN:@(offset) isUrgent:NO];
                    [requestedPeers addObject:peer];
                    [_requestingMap setObject:peer.remotePeerId forKey:@(offset)];
                    break;
                }
            }
        }
        prefetchCount ++;
        offset ++;
    }
    _loadedPeerNum = requestedPeers.count;
}

// 单位 秒
- (double)calculateDelay {
    if (_loadedPeerNum == 0) return CHECK_PEERS_INTERVAL;
    return 0.33*_loadedPeerNum + 0.67;                    // 假设最高下载peer数为10
}

- (void)updateLoadedSN:(NSNumber *)SN {
    if ([_bitmap containsObject:SN]) return;
    [_bitmap addObject:SN];
    
    //在bitCounts清除，防止重复下载
    if ([_bitCounts objectForKey:SN] != nil) {
        [_bitCounts removeObjectForKey:SN];
    }
}

- (void)addPeer:(SWCDataChannel *)peer andBitfield:(NSArray *)field {
    [super addPeer:peer andBitfield:field];
    for (NSNumber *sn in field) {
        if (![_bitmap containsObject:sn]) {                    //防止重复下载
            [self increBitCounts:sn];
        }
    }
}

- (void)handshakePeer:(SWCDataChannel *)peer {
    if (peer) {
        [peer sendMetaData:_bitmap sequential:YES peersNum:[self peersNum]];
    }
}

- (void)breakOffPeer:(SWCDataChannel *)peer {
    if (peer) {
        [super breakOffPeer:peer];
        for (NSNumber *sn in peer.getBitMap) {
            [self decreBitCounts:sn];
        }
    }
}

- (void)decreBitCounts:(NSNumber *)SN {
    if ([[_bitCounts allKeys] containsObject:SN]) {
        NSUInteger last = [[_bitCounts objectForKey:SN] integerValue];
        if (last == 1) {
            [_bitCounts removeObjectForKey:SN];
        } else {
            [_bitCounts setObject:@(last-1) forKey:SN];
        }
    }
}

- (void)increBitCounts:(NSNumber *)SN {
    if ([_bitCounts objectForKey:SN] == nil) {
//        CBDebug(@"_bitCounts setObject %@", SN);
        [_bitCounts setObject:@(1) forKey:SN];
    } else {
        NSUInteger last = [[_bitCounts objectForKey:SN] integerValue];
        [_bitCounts setObject:@(last+1) forKey:SN];
    }
//    CBInfo(@"_bitCounts %@", _bitCounts);
}

- (void)destroy {
    CBInfo(@"reset CBHlsPredictor");
    [[SWCHlsPredictor sharedInstance] reset];
    
    [[CBTimerManager sharedInstance] cancelTimerWithName:SCHEDULER_CHECK_PEERS];
    
    [super destroy];
}

- (BOOL)isSequential {
    return YES;
}

#pragma mark - **************** SWCDataChannelDelegate

/** have */
- (void)dataChannel:(SWCDataChannel *)peer didReceiveHaveSN:(NSNumber *)sn andSegId:(NSString *)segId {
    CBDebug(@"dc %@ have %@", peer.remotePeerId, sn);
    [peer bitFieldAddSN:sn];
    //        [self increBitCounts:sn];
    if (![_bitmap containsObject:sn]) {       // bitmap没有的才加入bitCounts
        [self increBitCounts:sn];
    }
    
    // 如果SN正是目前在请求的
    if (_isLive && _liveLatch && ([sn unsignedShortValue] == _requestingSN)) {
        CBInfo(@"receive requestingSN %@", sn);
        _requestingSN = 0;            // 置0作为标记
        dispatch_semaphore_signal(_liveLatch);
    }
}

/** lost */
- (void)dataChannel:(SWCDataChannel *)peer didReceiveLostSN:(NSNumber *)sn andSegId:(NSString *)segId {
    CBInfo(@"dc %@ lost %@", peer.remotePeerId, sn);
    [peer bitFieldRemoveSN:sn];
    [self decreBitCounts:sn];
}

/** piece_ack */
- (void)dataChannel:(SWCDataChannel *)peer didReceivePieceAckWithSegId:(NSString *)segId SN:(NSNumber *)sn andSize:(NSNumber *)size {
    // 上传数据后成为uploader
    _isUploader = YES;
    
    // report Uploaded
    NSUInteger length = [size unsignedIntegerValue]/1024;
    self.p2pUploaded += length;
    NSDictionary *message = @{@"p2pUploaded": @(length)};
    [[NSNotificationCenter defaultCenter] postNotificationName:kP2pEngineDidReceiveStatistics object:message];
}

/** piece_not_found  接收到critical未找到的响应 */
- (void)dataChannel:(SWCDataChannel *)peer didReceivePieceNotFoundWithSegId:(NSString *)segId SN:(nonnull NSNumber *)sn{
    // segId可能不存在
    CBInfo(@"piece %@ not found", sn);
    if ([_requestingMap objectForKey:sn]) {
        [_requestingMap removeObjectForKey:sn];
        if (_latch) dispatch_semaphore_signal(_latch);
    }
    [peer bitFieldRemoveSN:sn];
    [self decreBitCounts:sn];
}

/** response 接收到piece头信息 */
- (void)dataChannel:(SWCDataChannel *)peer didReceivePieceWithSegId:(NSString *)segId SN:(NSNumber *)sn {
    CBDebug(@"receive piece %@ from %@", sn, peer.remotePeerId);
    if (_isLive) {
        [self notifyAllPeersWithSN:sn segId:segId];
    }
}

/** response 接收到完整二进制数据 */
- (void)dataChannel:(SWCDataChannel *)peer didReceiveResponseWithSN:(nonnull NSNumber *)sn segId:(nonnull NSString *)segId andData:(nonnull NSData *)data {
    // 下载数据后成为receiver
    _isReceiver = YES;
    // 进行缓存
    if (![_cacheManager containsSegmentForId:segId] && data.length > 0) {
        SWCHlsSegment *segment = [SWCHlsSegment.alloc initWithBuffer:data sn:sn segId:segId];
        [self updateLoadedSN:segment.SN];
        if (!_isLive) {
            [self notifyAllPeersWithSN:sn segId:segId];
        }
        [_sn2IdMap setObject:segId forKey:segment.SN];
        [_cacheManager setSegment:segment forId:segId];
        CBInfo(@"segment manager add seg %@", segId);
        if ([_requestingMap objectForKey:segment.SN]) {
            [_requestingMap removeObjectForKey:segment.SN];
            if (_latch) dispatch_semaphore_signal(_latch);
        }
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
    NSString *_segId;
    if (!segId) {
        _segId = [_sn2IdMap objectForKey:sn];
    } else {
        _segId = segId;
        
    }
    // 命中缓存
//    CBDebug(@"didReceiveRequestWithSegId _segId %@ containsSegmentForId %d", _segId, [_cacheManager containsSegmentForId:_segId]);
    if (_segId && [_cacheManager containsSegmentForId:_segId]) {
        SWCHlsSegment *seg = (SWCHlsSegment *)[_cacheManager segmentForId:_segId];
        [peer sendBuffer:seg.buffer segId:seg.segId SN:seg.SN];
    } else {
        // 发送peace_not_found
        [peer sendPieceNotFound:sn andSegId:_segId];
        
//        [_cacheManager notifySegmentRemoved:sn];        // TODO 验证
    }
}

- (void)dataChannel:(SWCDataChannel *)peer didDownloadPieceErrorWithSN:(NSNumber *)sn segId:(NSString *)segId {
    
    CBWarn(@"datachannel download error %@ from %@", sn, peer.remotePeerId);
    if ([_requestingMap objectForKey:sn]) {
        [_requestingMap removeObjectForKey:sn];
        if (_latch) dispatch_semaphore_signal(_latch);
    }
}

#pragma mark - **************** CBSegmentManagerDelegate

- (void)segmentManager:(SWCSegmentManager *)mgr diskCacheDidEvictSegment:(SWCSegment *)segment {
    SWCHlsSegment *segHls = (SWCHlsSegment *)segment;
    CBDebug(@"diskCacheDidEvictSegment %@", segment);
    _currLostSN = [segHls.SN unsignedIntValue];
    NSNumber *sn = segHls.SN;
    if (!_isLive && [_bitmap containsObject:sn]) {
        // 删除内存对应的SN
        [_bitmap removeObject:sn];
        [_bitCounts removeObjectForKey:sn];
        [_sn2IdMap removeObjectForKey:sn];
        // 广播lost
        [[_peerManager getPeerMap] enumerateKeysAndObjectsUsingBlock:^(NSString * _Nonnull key, SWCDataChannel * _Nonnull peer, BOOL * _Nonnull stop) {
            if (peer && peer.connected) {
                [peer sendMsgLost:sn segId:segHls.segId];
            }
        }];
    }
}

- (void)segmentManager:(SWCSegmentManager *)mgr memoryCacheDidEvictSegment:(SWCSegment *)segment {
    SWCHlsSegment *segHls = (SWCHlsSegment *)segment;
    CBDebug(@"memoryCacheDidEvictSegment %@", segment);
    if (_isLive) {
        NSNumber *sn = segHls.SN;
        [_bitmap removeObject:sn];
        [_bitCounts removeObjectForKey:sn];
        [_sn2IdMap removeObjectForKey:sn];
    }
    
}

@end
