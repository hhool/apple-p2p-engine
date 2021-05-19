//
//  SWCDataChannel.m
//  SwarmCloudSDK
//
//  Created by Timmy on 2021/5/9.
//  Copyright © 2021 cdnbye. All rights reserved.
//

#import "SWCDataChannel.h"
#import "CBPeerChannel.h"
#import "CBQueue.h"
#import "CBLogger.h"
#import "CBTimerManager.h"
#import "SWCP2pEngine.h"
#import "SWCUtils.h"

static NSString *const DC_VERSION = @"5";          // 私有协议版本

static NSString * const CONN_TIMER = @"CONN_TIMER";

const NSUInteger LIVE_SN_LIMIT = 40;        // LIVE保存的最多SN数

const NSUInteger DEFAULT_PACKET_SIZE = 64*1000;     // 默认每次通过datachannel发送的包的大小   发送不能大于64KB

const NSUInteger DC_TOLERANCE = 3;                   // 请求超时或错误多少次阻塞该peer

// 事件映射
//static NSString *const DC_PING = @"PING";
//static NSString *const DC_PONG = @"PONG";
static NSString *const DC_REQUEST = @"REQUEST";
static NSString *const DC_PIECE_NOT_FOUND = @"PIECE_NOT_FOUND";
static NSString *const DC_PIECE = @"PIECE";
static NSString *const DC_PIECE_ACK = @"PIECE_ACK";
static NSString *const DC_METADATA = @"METADATA";
static NSString *const DC_PLAT_ANDROID = @"ANDROID";
static NSString *const DC_PLAT_IOS = @"IOS";
static NSString *const DC_PLAT_WEB = @"WEB";
static NSString *const DC_CHOKE = @"CHOKE";
static NSString *const DC_UNCHOKE = @"UNCHOKE";
static NSString *const DC_HAVE = @"HAVE";
static NSString *const DC_LOST = @"LOST";
static NSString *const DC_CLOSE = @"CLOSE";
static NSString *const DC_GET_PEERS = @"GET_PEERS";
static NSString *const DC_PEERS = @"PEERS";
static NSString *const DC_STATS = @"STATS";
static NSString *const DC_PEER_SIGNAL = @"PEER_SIGNAL";
static NSString *const DC_PLAY_LIST = @"PLAY_LIST";
static NSString *const DC_SUBSCRIBE = @"SUBSCRIBE";
static NSString *const DC_UNSUBSCRIBE = @"UNSUBSCRIBE";
static NSString *const DC_SUBSCRIBE_ACCEPT = @"SUBSCRIBE_ACCEPT";
static NSString *const DC_SUBSCRIBE_REJECT = @"SUBSCRIBE_REJECT";
static NSString *const DC_SUBSCRIBE_LEVEL = @"SUBSCRIBE_LEVEL";

typedef void (^SuccessBlock)(NSString *segId, NSData *data);

#define dispatch_main_async_safe(block)\
if ([NSThread isMainThread]) {\
block();\
} else {\
dispatch_async(dispatch_get_main_queue(), block);\
}

@interface SWCDataChannel()<CBSimpleChannelDelegate>
{
    CBPeerChannel* _simpleChannel;
    SWCP2pConfig *_p2pConfig;
    NSMutableSet *_bitmap;
//    NSTimer *_uploadTimer;
//    NSTimer *_connTimer;
    
    
    CBQueue *_rcvdReqQueue;             // 上传等待队列
    
    // 用于DC_PIECE
    NSMutableArray<NSData *> *_bufArr;    // 用于接受二进制数组
    NSUInteger _remainAttachments;           // 剩余的未接收的packet
    NSString *_segId;                        // 即将接收的二进制数据的id
    NSNumber *_bufSN;
    NSNumber *_expectedSize;
    
    NSUInteger _packetSize;               // 每个数据包的大小
    
//    dispatch_queue_t _serialQueue;
    dispatch_queue_t _concurrentQueue;
    
    BOOL _isLive;
    NSString *_channel;
    
    NSUInteger _miss;
    
    NSString *_criticalSegId;
    
    // 统计
    CFAbsoluteTime _timeSendRequest;     // 发送request的时刻
    
    NSString *_timerID;
    long _uploadSPeed;
    
    NSMutableDictionary<NSString *, SWCPlaylistInfo *> *_playlistMap;
    BOOL _typeExpected;
    BOOL _sequential;
}
@property (nonatomic, copy) SuccessBlock success;
@end

@implementation SWCDataChannel

- (instancetype)initWithPeerId:(NSString *)peerId remotePeerId:(NSString *)remotePeerId isInitiator:(BOOL)isInitiator factory:(RTCPeerConnectionFactory *)factory andConfig:(SWCP2pConfig *)config isLive:(BOOL)live sequential:(BOOL)sequential channal:(NSString *)channel {
    return [self initWithPeerId:peerId remotePeerId:remotePeerId isInitiator:isInitiator factory:factory andConfig:config isLive:live sequential:sequential channal:channel intermediator:nil];
}

- (instancetype)initWithPeerId:(NSString *)peerId remotePeerId:(NSString *)remotePeerId isInitiator:(BOOL)isInitiator factory:(RTCPeerConnectionFactory *)factory andConfig:(SWCP2pConfig *)config isLive:(BOOL)live sequential:(BOOL)sequential channal:(NSString *)channel intermediator:(NSString *_Nullable)intermediator {
    if(self = [super init])
    {
        _p2pConfig = config;
        _intermediator = intermediator;
        _remotePeerId = remotePeerId;
        _isInitiator = isInitiator;
        _typeExpected = sequential;
        _channelId = isInitiator ? [NSString stringWithFormat:@"%@-%@", peerId, remotePeerId] : [NSString stringWithFormat:@"%@-%@", remotePeerId, peerId];
        CBInfo(@"create datachannel %@", self.channelId);
        _isLive = live;
        _channel = channel;
        [self initData];
        _simpleChannel = [[CBPeerChannel alloc] initWithIsInitiator:isInitiator channelId:self.channelId factory:factory andConfiguration:_p2pConfig];
        // 设置代理
        _simpleChannel.delegate = self;
        
        _timerID = [NSString stringWithFormat:@"%@-%@", CONN_TIMER, _remotePeerId];
        
        _playlistMap = [NSMutableDictionary dictionary];
        
        // P2P连接超时控制
//        dispatch_main_async_safe(^{
//            self->_connTimer = [NSTimer scheduledTimerWithTimeInterval:30 target:self selector:@selector(connTimeout) userInfo:nil repeats:NO];
//            [[NSRunLoop currentRunLoop] addTimer:self->_connTimer forMode:NSRunLoopCommonModes];
//        })
        
        __weak typeof(self) weakSelf = self;
        CBInfo(@"set timer for dc %@", _remotePeerId);
        [[CBTimerManager sharedInstance] scheduledDispatchTimerWithName:_timerID
                                                               timeInterval:30.0
                                                                      queue:nil
                                                                    repeats:NO
                                                              fireInstantly:NO
                                                                     action:^{
//                                                                         CBInfo(@"fire timer for dc %@", _remotePeerId);
                                                                         [weakSelf connTimeout];
                                                                     }];
    }
    return self;
}

// 初始化成员变量
- (void)initData{
    _platform = @"unknown";
    _bitmap = [NSMutableSet set];
    _rcvdReqQueue = [CBQueue queue];
    _bufArr = [NSMutableArray array];
    
    _concurrentQueue = dispatch_queue_create("com.cdnbye.ios", DISPATCH_QUEUE_SERIAL);
//    _concurrentQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0);      // TODO 是否需要串行
    
    _miss = 0;
    
    _peersConnected = 1;
    
    _packetSize = DEFAULT_PACKET_SIZE;              // 数据包大小
    
    _dataExchangeTs = CFAbsoluteTimeGetCurrent();
}

#pragma mark - **************** public methods

+ (NSString *)dcVersion {
    return DC_VERSION;
}

- (void)shareOnly {
    _choked = YES;
}

- (NSMutableSet *)getBitMap {
    return _bitmap;
}

- (SWCNetworkResponse *)loadSegmentSyncFromPeerById:(NSString *)segId SN:(NSNumber *)sn timeout:(NSTimeInterval)timeout {
    __block SWCNetworkResponse *resp;
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    [self loadSegmentFromPeerById:segId SN:sn timeout:timeout success:^(NSString * _Nonnull segId, NSData * _Nonnull buffer) {
        if (buffer) {
            resp = [[SWCNetworkResponse alloc] initWithData:buffer contentType:@"video/mp2t"];
        }
        dispatch_semaphore_signal(semaphore);
    }];
    
    dispatch_semaphore_wait(semaphore, dispatch_time(DISPATCH_TIME_NOW, timeout * NSEC_PER_SEC));
    
    if (!resp) {
        CBWarn(@"datachannel timeout while downloading seg %@ from %@", _criticalSegId, self.remotePeerId);
        resp = [[SWCNetworkResponse alloc] initWithNoResponse];  // TODO 验证
    }
    return resp;
}

- (void)loadSegmentFromPeerById:(NSString *)segId SN:(NSNumber *)sn timeout:(NSTimeInterval)timeout success:(void (^)(NSString * segId, NSData * buffer))success {
    _success = success;
    _criticalSegId = segId;
    [self sendRequestSegmentById:segId SN:(NSNumber *)sn isUrgent:YES];

}


- (BOOL)isAvailable {
    return self.connected && self.downloading == NO && self.choked == NO;
}

- (void)close {
//    [self sendMsgClose];
//    CBInfo(@"test before cancelTimerWithName %@", _timerID);
    [[CBTimerManager sharedInstance] cancelTimerWithName:_timerID];
//    if (_simpleChannel && self.connected) {
    if (_simpleChannel) {
//        CBInfo(@"test before _simpleChannel close");
        [_simpleChannel close];
//        __weak typeof(self) weakSelf = self;
//        dispatch_async(_concurrentQueue, ^{
//            __strong typeof(weakSelf) strongSelf = weakSelf;
//            [strongSelf->_simpleChannel close];
//        });
        self.connected = NO;
    }
//    CBInfo(@"test after _simpleChannel close");
}

-(void)receiveSignal:(NSDictionary *)dataDic {
    if (_simpleChannel) {
        [_simpleChannel receiveSignal:dataDic];
    } else {
        CBWarn(@"_simpleChannel is nil");
    }
}

- (void)initBitField:(NSArray *)field {
    [_bitmap removeAllObjects];
    [_bitmap addObjectsFromArray:field];
}

- (void)bitFieldAddSN:(NSNumber *)sn {
    [_bitmap addObject:sn];
    // 直播淘汰最旧的SN
    if (_isLive) {
        NSUInteger oldest = [sn unsignedIntegerValue] - LIVE_SN_LIMIT;
        if (oldest > 0) {
            [_bitmap removeObject:@(oldest)];
            CBDebug(@"datachannel bitmap remove %@", @(oldest));
        }
    }
}

- (void)bitFieldRemoveSN:(NSNumber *)sn {
    [_bitmap removeObject:sn];
}

- (BOOL)bitFieldHasSN:(NSNumber *)sn {
    return [_bitmap containsObject:sn];
}

- (void)sendMetaData:(NSMutableSet *)field sequential:(BOOL)sequential peersNum:(NSUInteger)num {
//    CBInfo(@"field.count: %ld", field.count);
    NSArray *arr = field.allObjects;
    if (arr.count == 0) {
        arr = [NSArray array];
    }
    BOOL isMobile = YES;
#if TARGET_OS_OSX || TARGET_OS_TV
    isMobile = NO;
#endif
    NSDictionary *dict = @{@"event":DC_METADATA, @"field":arr, @"platform":DC_PLAT_IOS, @"mobile":@(isMobile), @"channel": _channel, @"version": SWCP2pEngine.engineVersion, @"sequential": @(sequential), @"peers": @(num)};
//    CBInfo(@"sendBitfield");
//    [_simpleChannel sendJSONMessage:dict];
    dispatch_async(_concurrentQueue, ^{
         [self->_simpleChannel sendJSONMessage:dict];
    });
}

- (void)sendMsgGetPeers {
    NSDictionary *dict = @{@"event":DC_GET_PEERS};
    dispatch_async(_concurrentQueue, ^{
        [self->_simpleChannel sendJSONMessage:dict];
    });
}

- (void)sendMsgPeers:(NSArray *)peers {
    NSDictionary *dict = @{@"event":DC_PEERS, @"peers":peers};
    dispatch_async(_concurrentQueue, ^{
        [self->_simpleChannel sendJSONMessage:dict];
    });
}

- (void)sendMsgHave:(NSNumber *)sn segId:(NSString *)segId {
    NSDictionary *dict = @{@"event":DC_HAVE, @"sn":sn, @"seg_id":segId};
    dispatch_async(_concurrentQueue, ^{
        [self->_simpleChannel sendJSONMessage:dict];
    });
}

- (void)sendMsgLost:(NSNumber *)sn segId:(NSString *)segId {
    NSDictionary *dict = @{@"event":DC_LOST, @"sn":sn, @"seg_id":segId};
//    [_simpleChannel sendJSONMessage:dict];
    dispatch_async(_concurrentQueue, ^{
        [self->_simpleChannel sendJSONMessage:dict];
    });
}

- (void)sendMsgChoke {
    NSDictionary *dict = @{@"event":DC_CHOKE};
    dispatch_async(_concurrentQueue, ^{
        [self->_simpleChannel sendJSONMessage:dict];
    });
}

- (void)sendMsgUnchoke {
    NSDictionary *dict = @{@"event":DC_UNCHOKE};
    dispatch_async(_concurrentQueue, ^{
        [self->_simpleChannel sendJSONMessage:dict];
    });
}

- (void)sendPieceNotFound:(NSNumber *)sn andSegId:(NSString *)segId {
    NSDictionary *dict = @{@"event":DC_PIECE_NOT_FOUND, @"sn":sn, @"seg_id":segId};
    dispatch_async(_concurrentQueue, ^{
        [self->_simpleChannel sendJSONMessage:dict];
    });
}

- (void)sendBuffer:(NSData *)buffer segId:(NSString *)segId SN:(NSNumber *)sn {
    _uploading = YES;
    //开始计时
//    dispatch_main_async_safe(^{
//        self->_uploadTimer = [NSTimer scheduledTimerWithTimeInterval:self->_p2pConfig.dcUploadTimeout target:self selector:@selector(uploadtimeout) userInfo:nil repeats:NO];
//        [[NSRunLoop currentRunLoop] addTimer:self->_uploadTimer forMode:NSRunLoopCommonModes];
//    })
    
    NSUInteger dataSize = buffer.length;                      // 二进制数据大小
//    NSUInteger packetSize = DEFAULT_PACKET_SIZE;                // 每个数据包的大小
    NSUInteger packetSize = _packetSize;                // 每个数据包的大小
    NSUInteger remainder = 0;                                     // 最后一个包的大小
    NSUInteger attachments = 0;                                   // 分多少个包发
    if (dataSize % packetSize == 0) {
        attachments = dataSize/packetSize;
    } else {
        attachments = dataSize/packetSize + 1;
        remainder = dataSize % packetSize;
    }
    NSDictionary *dict = @{@"event":DC_PIECE, @"attachments":@(attachments), @"seg_id":segId, @"sn":sn, @"size":@(dataSize)};
//    NSLog(@"send segment to %@ %@ packetSize %@", self.remotePeerId, dict, @(packetSize));
//    [_simpleChannel sendJSONMessage:dict];
    
    dispatch_async(_concurrentQueue, ^{
        BOOL isSucess;
        isSucess = [self->_simpleChannel sendJSONMessage:dict];
        if (isSucess) {
            NSData *payload = buffer;
            NSMutableArray<NSData *> *bufArr = [NSMutableArray arrayWithCapacity:attachments];
            if (remainder != 0) {
                NSData *packet;
                for (NSUInteger i=0;i<attachments-1;i++) {
                    packet = [payload subdataWithRange:NSMakeRange(i*packetSize, packetSize)];
                    [bufArr addObject:packet];
//                    NSLog(@"bufArr addObject size %@ for %@", @(packet.length), seg.segId);
                }
                packet = [payload subdataWithRange:NSMakeRange(dataSize-remainder, remainder)];
                [bufArr addObject:packet];
//                NSLog(@"bufArr addObject size %@", @(packet.length));
            } else {
                NSData *packet;
                for (NSUInteger i=0;i<attachments;i++) {
                    packet = [payload subdataWithRange:NSMakeRange(i*packetSize, packetSize)];
                    [bufArr addObject:packet];
                }
            }
            for (NSUInteger j=0;j<bufArr.count;j++) {
                [self sendBinaryData:bufArr[j]];
            }
        }
    });
}

- (void)sendRequestSegmentById:(NSString *)segId SN:(NSNumber *)sn isUrgent:(BOOL)urgent {
    NSDictionary *dict = @{@"event":DC_REQUEST, @"urgent":@(urgent), @"seg_id":segId, @"sn":sn};
//    [_simpleChannel sendJSONMessage:dict];
    dispatch_async(_concurrentQueue, ^{
      [self->_simpleChannel sendJSONMessage:dict];
        // test 下载超时测试
//        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
//            [self->_simpleChannel sendJSONMessage:dict];
//        });
    });
    // 开始计时
    _timeSendRequest = CFAbsoluteTimeGetCurrent();
    _downloading = YES;
}

- (void)sendRequestSegmentBySN:(NSNumber *)sn isUrgent:(BOOL)urgent {
    NSDictionary *dict = @{@"event":DC_REQUEST, @"urgent":@(urgent), @"sn":sn};
//    [_simpleChannel sendJSONMessage:dict];
    dispatch_async(_concurrentQueue, ^{
        [self->_simpleChannel sendJSONMessage:dict];
    });
    // 开始计时
    _timeSendRequest = CFAbsoluteTimeGetCurrent();
    _downloading = YES;
}

- (void)sendMsgClose {
    NSDictionary *dict = @{@"event":DC_CLOSE};
    // 需要同步执行
    [self->_simpleChannel sendJSONMessage:dict];
}

- (void)sendMsgSubscribe {
    NSDictionary *dict = @{@"event":DC_SUBSCRIBE};
    dispatch_async(_concurrentQueue, ^{
        [self->_simpleChannel sendJSONMessage:dict];
    });
}

- (void)sendMsgUnsubscribe {
    NSDictionary *dict = @{@"event":DC_UNSUBSCRIBE};
    dispatch_async(_concurrentQueue, ^{
        [self->_simpleChannel sendJSONMessage:dict];
    });
}

- (void)sendMsgSubscribeReject:(NSString *)reason {
    NSDictionary *dict = @{@"event":DC_SUBSCRIBE_REJECT, @"reason":reason};
    dispatch_async(_concurrentQueue, ^{
        [self->_simpleChannel sendJSONMessage:dict];
    });
}

- (void)sendMsgSubscribeAccept:(int)level {
    NSDictionary *dict = @{@"event":DC_SUBSCRIBE_ACCEPT, @"level":@(level)};
    dispatch_async(_concurrentQueue, ^{
        [self->_simpleChannel sendJSONMessage:dict];
    });
}

- (void)sendMsgSubscribeLevel:(int)level {
    NSDictionary *dict = @{@"event":DC_SUBSCRIBE_LEVEL, @"level":@(level)};
    dispatch_async(_concurrentQueue, ^{
        [self->_simpleChannel sendJSONMessage:dict];
    });
}

- (void)sendMsgStats:(NSNumber *)totalConns {
    NSDictionary *dict = @{@"event":DC_STATS, @"total_conns":totalConns};
    dispatch_async(_concurrentQueue, ^{
        [self->_simpleChannel sendJSONMessage:dict];
    });
}

- (BOOL)sendMsgSignalToPeerId:(NSString *)toPeerId fromPeerId:(NSString *)fromPeerId data:(NSDictionary *)data {
    NSDictionary *dict = @{
        @"event":DC_PEER_SIGNAL,
        @"action":@"signal",
        @"to_peer_id":toPeerId,
        @"from_peer_id": fromPeerId,
    };
    if (data) {
        [dict setValue:data forKey:@"data"];
    }
    return [self->_simpleChannel sendJSONMessage:dict];
}

- (BOOL)sendMsgSignalRejectToPeerId:(NSString *)toPeerId fromPeerId:(NSString *)fromPeerId reason:(NSString *)reason {
    NSDictionary *dict = @{
        @"event":DC_PEER_SIGNAL,
        @"action":@"reject",
        @"to_peer_id":toPeerId,
        @"from_peer_id": fromPeerId,
    };
    if (reason) {
        [dict setValue:reason forKey:@"reason"];
    }
    return [self->_simpleChannel sendJSONMessage:dict];
}

- (void)sendMsgPlaylistWithUrl:(NSString *)url text:(NSString *)text {
    NSDictionary *dict = @{@"event":DC_PLAY_LIST, @"url":url, @"data":text};
    dispatch_async(_concurrentQueue, ^{
        [self->_simpleChannel sendJSONMessage:dict];
    });
}

- (void)checkIfNeedChoke {
    _miss ++;
    if (_miss == DC_TOLERANCE) {
        CBWarn(@"Choke peer %@", self.remotePeerId);
//        [self sendMsgClose];
        _choked = YES;
    }
}

- (NSUInteger)currentBufSN {
    return _bufSN.unsignedIntegerValue;
}

-(NSUInteger)currentBufArrSize {
    return _bufArr.count;
}

- (NSData *)getLoadedBuffer {
    NSUInteger count = _bufArr.count;
    
    if (count == 0) return nil;
    
    NSUInteger packetSize = _bufArr[0].length;
//    NSLog(@"packetSize %@", @(packetSize));
    NSMutableData *buffer = [[NSMutableData alloc] initWithCapacity:packetSize * count];
//    NSMutableData *buffer = [[NSMutableData alloc] initWithCapacity:DEFAULT_PACKET_SIZE * count];
    for (int i=0;i<count;i++) {
         [buffer appendData:_bufArr[i]];
    }
    return buffer;
}

- (NSComparisonResult)compareByWeight:(SWCDataChannel *)peer {
    if (peer.weight == 0 && self.weight != 0) {
        return NSOrderedAscending;
    } else if (self.weight == 0 && peer.weight != 0) {
        return NSOrderedDescending;
    } else {
        return [[NSNumber numberWithLong:peer.weight] compare:[NSNumber numberWithLong:self.weight]];
    }
}

- (SWCPlaylistInfo *)getLatestPlaylistWithUrl:(NSString *)url lastTs:(NSNumber *)lastTs {
    if (![_playlistMap objectForKey:url]) return nil;
    SWCPlaylistInfo *playlistInfo = [_playlistMap objectForKey:url];
    if (!playlistInfo) return nil;
    if ([playlistInfo.ts longValue] <= [lastTs longValue]) {
        return nil;
    }
    return playlistInfo;
}

#pragma mark - **************** private methods

- (void)connTimeout {
    CBWarn(@"dc %@ connection timeout", self.channelId);
    if ([self->_delegate respondsToSelector:@selector(dataChannelDidFail:fatal:)])
    {
        [self->_delegate dataChannelDidFail:self fatal:NO];
    }
}

- (void)sendJSON:(NSDictionary *)dict {
    if (_simpleChannel && self.connected) {
        [_simpleChannel sendJSONMessage:dict];
    }
}

- (void)sendBinaryData:(NSData *)data {
    if (_simpleChannel && self.connected) {
//        CFAbsoluteTime t1 = CFAbsoluteTimeGetCurrent();
        [_simpleChannel sendBinaryMessage:data];
//        CFAbsoluteTime t2 = CFAbsoluteTimeGetCurrent();
//        CBInfo(@"sendBinaryData 耗时 %f isMainThread %@", (t2-t1)*1000, @([NSThread isMainThread]));
        // test 上传超时测试
        //        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(7 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        //            [self->_simpleChannel sendBinaryMessage:data];
        //        });
    }
}

//- (void)uploadtimeout {
//    CBWarn(@"datachannel timeout while uploading to %@", self.remotePeerId);
//    _uploading = NO;
//    _uploadTimer = nil;
//
//    NSNumber *SN = [self getRequestFromQueue];
//    if (SN) {
//        if ([self->_msgDelegate respondsToSelector:@selector(dataChannel:didReceiveRequestWithSegId:SN:andUrgent:)])
//        {
//            [self->_msgDelegate dataChannel:self.remotePeerId didReceiveRequestWithSegId:nil SN:SN andUrgent:NO];
//        }
//    }
//}

- (void)handlePieceAck:(NSNumber *)speed {
    _uploading = NO;
    _uploadSPeed = [speed longValue];
}

- (void)handleBinaryData {
    NSMutableData *buffer = [[NSMutableData alloc] initWithCapacity:[_expectedSize unsignedIntegerValue]];
    NSUInteger totalSize = 0;
    for (NSData *data in _bufArr) {
        totalSize += data.length;
        [buffer appendData:data];
    }
    // 校验大小
    if (totalSize == [_expectedSize unsignedIntegerValue] && [SWCUtils isVideoContentLength:totalSize]) {
        // 如果当前下载的ts刚好是critical
        if ([_segId isEqualToString:_criticalSegId] && self.success) {
            self.success(_segId, buffer);
            self.success = nil;
            
            _miss = 0;                                 // 重置miss
        }
        
        if ([self->_msgDelegate respondsToSelector:@selector(dataChannel:didReceiveResponseWithSN:segId:andData:)])
        {
            [self->_msgDelegate dataChannel:self didReceiveResponseWithSN:_bufSN segId:_segId andData:buffer];
        }
    } else {
        [_bufArr removeAllObjects];
        if (![SWCUtils isVideoContentLength:totalSize]) {
            CBError(@"VideoContentLength <= 10000");
        } else{
            CBError(@"expectedSize not equal to totalSize!");
        }
        if (self.success) {
            self.success(_segId, nil);
            self.success = nil;
        }
        if ([self->_msgDelegate respondsToSelector:@selector(dataChannel:didDownloadPieceErrorWithSN:segId:)])
        {
            [self->_msgDelegate dataChannel:self didDownloadPieceErrorWithSN:_bufSN segId:_segId];
        }
    }
    
    _downloading = NO;
}

- (void)handlePieceRequest:(NSDictionary *)dict {
    BOOL urgent= [dict[@"urgent"] boolValue];
    NSString *segId = (NSString *)dict[@"seg_id"];
    NSNumber *SN = (NSNumber *)dict[@"sn"];
    if (self.uploading == YES || _rcvdReqQueue.size > 0) {
        CBDebug(@"_rcvdReqQueue push %@", SN);
        if (SN == nil) return;                              // 防止崩溃
        if (urgent) {
            [_rcvdReqQueue push:SN];                  // urgent的放在队列末尾
        } else {
             [_rcvdReqQueue unshift:SN];
        }
    } else {
        if ([self->_msgDelegate respondsToSelector:@selector(dataChannel:didReceiveRequestWithSegId:SN:andUrgent:)])
        {
            [self->_msgDelegate dataChannel:self didReceiveRequestWithSegId:segId SN:SN andUrgent:urgent];
        }
    }
}

- (void)handleStats:(NSDictionary *)dict {
    NSNumber *conns = (NSNumber *)dict[@"conns"];
    if (conns) {
        _peersConnected += [conns intValue];
        CBInfo(@"%@ now has %d peers", self.remotePeerId, _peersConnected);
    }
}

- (void)dealloc {
//    [CBUtils destroyTimer:_connTimer];
//    [[CBTimerManager sharedInstance] cancelTimerWithName:_timerID];
//    CBInfo(@"test after cancel CBTimerManager %@", _remotePeerId);
}

#pragma mark - **************** Sunscribe Mode

- (void)resetContinuousHits {
    CBInfo(@"reset %@ continuousHits", _remotePeerId);
    _continuousHits = 0;
}

- (void)increContinuousHits {
    _continuousHits ++;
}

#pragma mark - **************** CBSimpleChannelDelegate

- (void)simpleChannel:(CBPeerChannel *)simpleChannel
didReceiveJSONMessage:(NSDictionary *)dict {
    NSString *event = dict[@"event"];
    if ([event isEqualToString:DC_METADATA]) {
        CBDebug(@"Receive METADATA %@", dict);
        // 识别频道ID
        NSString *channel = (NSString *)dict[@"channel"];
        if (!channel) {
            CBError(@"peer channel %@ is null!", channel);
            [self close];
            return;
        }
//        CBInfo(@"channel %@ peer channel %@", _channel, channel);
        if (![channel isEqualToString:_channel]) {
            CBError(@"peer channel %@ not matched!", channel);
            [self close];
            return;
        }
        // 识别平台
        NSString *plat = (NSString *)dict[@"platform"];
        if (plat) {
            if ([plat isEqualToString:DC_PLAT_ANDROID]) {
                _platform = DC_PLAT_ANDROID;
            } else if ([plat isEqualToString:DC_PLAT_IOS]) {
                _platform = DC_PLAT_IOS;
            } else if ([plat isEqualToString:DC_PLAT_WEB]) {
                _platform = DC_PLAT_WEB;
            }
        }
        // 识别移动设备
        NSNumber *isMobile = dict[@"mobile"];
        _mobile = [isMobile boolValue];
        _sequential = [dict[@"sequential"] boolValue];
        if (_sequential != _typeExpected) {
            CBError(@"peer sequential type %@ not matched!", @(_sequential));
            [self close];
            return;
        }
        NSString *version = (NSString *)dict[@"version"];
        CBInfo(@"%@ platform %@ version %@ sequential %@", self.remotePeerId, plat, version, @(_sequential));
        
        NSNumber *peersNum = (NSNumber *)dict[@"peers"];
        if (peersNum) {
            _peersConnected += [peersNum intValue];
            CBInfo(@"%@ now has %d peers", self.remotePeerId, _peersConnected);
        }
        CBInfo(@"%@ platform %@", self.remotePeerId, self.platform);
        NSArray *field = (NSArray *)dict[@"field"];
        if ([self->_delegate respondsToSelector:@selector(dataChannel:didReceiveBitField:)])
        {
            [self->_delegate dataChannel:self didReceiveBitField:field];
        }
    }

    else if ([event isEqualToString:DC_REQUEST]) {
        CBDebug(@"Receive REQUEST %@", dict);
        [self handlePieceRequest:dict];
    }
    
    else if ([event isEqualToString:DC_PIECE_NOT_FOUND]) {
        CBDebug(@"Receive DC_PIECE_NOT_FOUND %@", dict);
        NSString *segId = (NSString *)dict[@"seg_id"];
        NSNumber *SN = (NSNumber *)dict[@"sn"];
        if ([self->_msgDelegate respondsToSelector:@selector(dataChannel:didReceivePieceNotFoundWithSegId:SN:)])
        {
            [self->_msgDelegate dataChannel:self didReceivePieceNotFoundWithSegId:segId SN:SN];
        }
        if (self.success && segId && [segId isEqualToString:_criticalSegId]) {
            self.success(segId, nil);
            self.success = nil;
        }
        _downloading = NO;
    }
    
    else if ([event isEqualToString:DC_PIECE]) {
        CBDebug(@"Receive DC_PIECE %@", dict);
        _dataExchangeTs = CFAbsoluteTimeGetCurrent();
        // 准备接收二进制数据
        NSString *segId = (NSString *)dict[@"seg_id"];
        NSNumber *SN = (NSNumber *)dict[@"sn"];
        NSNumber *attachments = (NSNumber *)dict[@"attachments"];
        NSNumber *size = (NSNumber *)dict[@"size"];
        _remainAttachments = [attachments unsignedIntegerValue];
        _bufArr = [[NSMutableArray alloc] initWithCapacity:_remainAttachments];
//        [_bufArr removeAllObjects];
        _segId = segId;
        _bufSN = SN;
        _expectedSize = size;
        if ([self->_msgDelegate respondsToSelector:@selector(dataChannel:didReceivePieceWithSegId:SN:)])
        {
            [self->_msgDelegate dataChannel:self didReceivePieceWithSegId:segId SN:SN];
        }
    }
    
    else if ([event isEqualToString:DC_PIECE_ACK]) {
        CBDebug(@"Receive DC_PIECE_ACK %@", dict);
        _dataExchangeTs = CFAbsoluteTimeGetCurrent();
        NSString *segId = (NSString *)dict[@"seg_id"];
        NSNumber *SN = (NSNumber *)dict[@"sn"];
        NSNumber *size = (NSNumber *)dict[@"size"];
        NSNumber *speed = (NSNumber *)dict[@"speed"];
        [self handlePieceAck:speed];
        if ([self->_msgDelegate respondsToSelector:@selector(dataChannel:didReceivePieceAckWithSegId:SN:andSize:)])
        {
            [self->_msgDelegate dataChannel:self didReceivePieceAckWithSegId:segId SN:SN andSize:size];
        }
    }
    
    else if ([event isEqualToString:DC_CHOKE]) {
        CBInfo(@"choke peer %@", self.remotePeerId);
        _choked = YES;
    }
    
    else if ([event isEqualToString:DC_UNCHOKE]) {
        CBInfo(@"unchoke peer %@", self.remotePeerId);
        _choked = NO;
    }
    
    else if ([event isEqualToString:DC_HAVE]) {
        CBVerbose(@"Receive DC_HAVE %@", dict);
        NSNumber *SN = (NSNumber *)dict[@"sn"];
        if (_isLive) self->_liveEdgeSN = [SN unsignedIntValue];
        if ([self->_msgDelegate respondsToSelector:@selector(dataChannel:didReceiveHaveSN:)])
        {
            [self->_msgDelegate dataChannel:self didReceiveHaveSN:SN];
        }
    }
    
    else if ([event isEqualToString:DC_LOST]) {
        CBDebug(@"Receive DC_LOST %@", dict);
        NSNumber *SN = (NSNumber *)dict[@"sn"];
        if ([self->_msgDelegate respondsToSelector:@selector(dataChannel:didReceiveLostSN:)])
        {
            [self->_msgDelegate dataChannel:self didReceiveLostSN:SN];
        }
    }
    
    else if ([event isEqualToString:DC_PLAY_LIST]) {
        if (_p2pConfig.isSharePlaylist) {
            NSString *url = (NSString *)dict[@"url"];
            NSString *data = (NSString *)dict[@"data"];
            [_playlistMap setObject:[SWCPlaylistInfo.alloc initWithTs:[SWCUtils getTimestamp] data:data] forKey:url];
        }
    }
    
    else if ([event isEqualToString:DC_STATS]) {
        [self handleStats:dict];
    }
    
    else if ([event isEqualToString:DC_CLOSE]) {
        self.connected = NO;
        CBDebug(@"Receive DC_CLOSE %@", dict);
        if ([self->_delegate respondsToSelector:@selector(dataChannelDidClose:)])
        {
            [self->_delegate dataChannelDidClose:self];
        }
    }
    
    else if ([event isEqualToString:DC_GET_PEERS]) {
        CBDebug(@"Receive DC_GET_PEERS");
        if ([self->_msgDelegate respondsToSelector:@selector(dataChannelDidReceiveGetPeersRequest:)])
        {
            [self->_msgDelegate dataChannelDidReceiveGetPeersRequest:self];
        }
    }
    
    else if ([event isEqualToString:DC_PEERS]) {
        CBDebug(@"Receive DC_PEERS");
        NSArray *peers = (NSArray *)dict[@"peers"];
        if ([self->_msgDelegate respondsToSelector:@selector(dataChannel:didReceivePeers:)])
        {
            [self->_msgDelegate dataChannel:self didReceivePeers:peers];
        }
    }
    
    else {
        CBError(@"unknown dc event %@", dict);
    }
}

- (void)simpleChannel:(CBPeerChannel *)simpleChannel didReceiveBinaryMessage:(NSData *)data {
    [_bufArr addObject:data];
    _remainAttachments --;
    if (_remainAttachments == 0) {
        
        // 计算下载速度
        long downloadSpeed = _expectedSize.integerValue / lround((CFAbsoluteTimeGetCurrent() - _timeSendRequest)*1000);
//        CBInfo(@"%@ expectedSize %@ time %@ downloadSpeed %@", _remotePeerId, _expectedSize, @(CFAbsoluteTimeGetCurrent() - _timeSendRequest), @(downloadSpeed));
//        long totalWeight = _weight * _times;
//        _weight = (totalWeight + downloadSpeed) / (++_times);
        _weight = downloadSpeed;
//        CBDebug(@"weight %@ times %@", @(_weight), @(_times));
        
        [self handleBinaryData];
        // TODO 验证
        NSDictionary *dict = @{@"event":DC_PIECE_ACK, @"sn":_bufSN, @"seg_id":_segId, @"size":_expectedSize, @"speed":@(downloadSpeed)};
//        [_simpleChannel sendJSONMessage:dict];
        dispatch_async(_concurrentQueue, ^{
            [self->_simpleChannel sendJSONMessage:dict];
        });
    }
}

/** 产生了信令信息，通过ws发送出去 */
- (void)simpleChannel:(CBPeerChannel *)simpleChannel didHaveSignal:(NSDictionary *)data {
    
    if ([self->_delegate respondsToSelector:@selector(dataChannel:didHaveSignal:)])
    {
        [self->_delegate dataChannel:self didHaveSignal:data];
    }
    
    
}

/** datachannel开启 */
- (void)simpleChannelDidOpen:(CBPeerChannel *)simpleChannel {
    CBDebug(@"simpleChannelDidOpen %@", simpleChannel.channelId);
//    [CBUtils destroyTimer:_connTimer];
    [[CBTimerManager sharedInstance] cancelTimerWithName:_timerID];
    self.connected = YES;
    if ([self->_delegate respondsToSelector:@selector(dataChannelDidOpen:)])
    {
        [self->_delegate dataChannelDidOpen:self];
    }
}

/** datachannelf关闭 */
- (void)simpleChannelDidClose:(CBPeerChannel *)simpleChannel {
    CBDebug(@"simpleChannelDidClose %@", simpleChannel.channelId);
    // 没有回调
//    self.connected = NO;
//    if ([self->_delegate respondsToSelector:@selector(dataChannelDidClose:)])
//    {
//        [self->_delegate dataChannelDidClose:self.remotePeerId];
//    }
}

/** datachannelf连接失败 */
- (void)simpleChannelDidFail:(CBPeerChannel *)simpleChannel {
//    self.connected = NO;
    CBDebug(@"simpleChannelDidFail %@", _remotePeerId);
    if ([self->_delegate respondsToSelector:@selector(dataChannelDidFail:fatal:)])
    {
        [self->_delegate dataChannelDidFail:self fatal:YES];
    }
}

@end
