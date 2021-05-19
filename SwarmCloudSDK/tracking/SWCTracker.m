//
//  SWCTracker.m
//  SwarmCloudSDK
//
//  Created by Timmy on 2021/5/9.
//  Copyright © 2021 cdnbye. All rights reserved.
//

#import "SWCTracker.h"
#import "SWCSignalClient.h"
#import "SWCDataChannel.h"
#import "SWCPeer.h"
#import <WebRTC/RTCPeerConnectionFactory.h>
#import "CBTimerManager.h"
#import <WebRTC/RTCIceServer.h>
#import "SWCScheduler.h"
#import "SWCUtils.h"
#import "SWCP2pEngine.h"
#import "CBLogger.h"
#import "SWCSchedulerFactory.h"
#if TARGET_OS_OSX

#else
#import <UIKit/UIDevice.h>
#endif


#define dispatch_main_async_safe(block)\
if ([NSThread isMainThread]) {\
block();\
} else {\
dispatch_async(dispatch_get_main_queue(), block);\
}

NSString *const CHANNEL_PATH = @"/channel";
NSString *const USER_AGENT = @"ios-native";
const NSTimeInterval BASE_INTERVAL = 75;   // 获取节点的基准时间间隔
const float FACTOR = 1.0;                   // 获取节点的乘数因子
const int MIN_CONNS = 3;                    // 最小连接数
const NSUInteger MIN_PEER_SHARE_TIME = 30;         // 分享peers的最低加入时间间隔 秒
const NSUInteger MAX_TRY_CONNS = 8;                // GET_PEERS后一次最多尝试连接的peer数量
const NSUInteger MIN_PEERS_FOR_TRACKER = 3;        // 留给tracker调度的节点数量

static NSString *const TRACKER_HEARTBEAT = @"TRACKER_HEARTBEAT";
static NSString *const TRACKER_GET_PEERS = @"TRACKER_GET_PEERS";
static NSString *const DEFAULT_SIGNAL_ADDR = @"wss://signal.cdnbye.com";

@interface SWCTracker()<SWCDataChannelDelegate>
{
    SWCP2pConfig *_p2pConfig;
    RTCPeerConnectionFactory *_factory;
    NSMutableArray<SWCPeer *> *_peersReceived;
    NSString *_baseUrl;
    NSString *_channel;         // 频道
    NSMutableDictionary<NSString*, SWCDataChannel*> *_datachannelDic;
    NSMutableSet *_failedDCSet;       // 存放失败的连接 <peerId>
    
    NSString *_channelUrl;
    NSString *_statsUrl;
    NSString *_peersUrl;
    
//    NSTimer *_heartBeat;   // 心跳上报
    
    int _minConns;
    
//    NSTimer *_getPeersTimer;   // 获取节点的计时器
    NSTimeInterval _getPeersDelay;
    
    BOOL _isLive;
    NSNumber *_timestamp;
    
    SWCSignalClient *_signaler;
    
    NSURLSession *_httpSession;
    
    NSString *_natType;
    SWCMediaType _mediaType;
    
    dispatch_queue_t _serialQueue;
    
    NSString *_netType;
    BOOL _downloadOnly;
    BOOL _multiBitrate;
    
    // 断开信令
    int _fuseRate;
    
}
@end

@implementation SWCTracker

#pragma mark - **************** public methods

- (instancetype)initWithToken:(NSString *)token BaseUrl:(NSString *)url channel:(NSString *)channel isLive:(BOOL)live endSN:(NSUInteger)endSN nat:(NSString*)natType mediaType:(SWCMediaType)mediaType multiBitrate:(BOOL)multiBitrate andConfig:(SWCP2pConfig *)config {
    if(self = [super init])
    {
        _token = token;
        _p2pConfig = config;
        _isLive = live;
        _baseUrl = url;
        _channel = channel;
        _peersReceived = [[NSMutableArray alloc] init];
        
        _datachannelDic = [NSMutableDictionary dictionary];
        _failedDCSet = [NSMutableSet set];
        
        _getPeersDelay = 0;
        _fuseRate = -1;
        
        _mediaType = mediaType;
        if (natType) {
            _natType = natType;
        } else {
            _natType = @"Unknown";
        }
        _multiBitrate = multiBitrate;
        
        NSURLSessionConfiguration *httpConfig = [NSURLSessionConfiguration defaultSessionConfiguration];
        httpConfig.HTTPAdditionalHeaders = @{
                                         @"User-Agent": USER_AGENT,
                                         @"token": _token,
                                         @"appid": [[NSBundle mainBundle] bundleIdentifier],
                                         };
        httpConfig.allowsCellularAccess = YES;
        _httpSession = [NSURLSession sessionWithConfiguration:httpConfig];
        
        _scheduler = [SWCSchedulerFactory createSchedulerWithMediaType:mediaType multiBitrate:multiBitrate isLive:live endSN:endSN P2pConfig:config];
        
        _timestamp = [SWCUtils getTimestamp];
        
        //先初始化工厂
        _factory = [[RTCPeerConnectionFactory alloc] init];
        
        _serialQueue = dispatch_queue_create("com.cdnbye.ios", DISPATCH_QUEUE_SERIAL);
    }
    return self;
}

- (void)channelRequest {
    
    _channelUrl = [NSString stringWithFormat:@"%@%@", _baseUrl, CHANNEL_PATH];
    NSURL *url=[NSURL URLWithString:_channelUrl];
//    CBInfo(@"channelUrl %@ token %@", _channelUrl, _token);
    
    // 封装参数
    NSBundle *mainBundle = [NSBundle mainBundle];
    NSString *bundleName = [mainBundle bundleIdentifier];
    NSString *appName = [[mainBundle infoDictionary] objectForKey:@"CFBundleDisplayName"];
    if (!appName) {
        appName = [[mainBundle infoDictionary] objectForKey:@"CFBundleName"];
    }
    NSString *announceHost = url.host;
    if (url.port != nil) {
        announceHost = [NSString stringWithFormat:@"%@:%@", announceHost, url.port];
    }
    NSString *domain;
    domain = [NSString stringWithFormat:@"%@-%@", _token, bundleName];
    _netType = [SWCUtils getNetconnType];
    NSString *tag = _p2pConfig.tag;
    if (!tag) {
        NSString *platform;
        NSString *sysVersion;
#if TARGET_OS_IOS
        sysVersion = [[UIDevice currentDevice] systemVersion];
        platform = @"iOS";
#elif TARGET_OS_TV
        sysVersion = [[UIDevice currentDevice] systemVersion];
        platform = @"tvOS";
#elif TARGET_OS_OSX
        NSOperatingSystemVersion version = [[NSProcessInfo processInfo] operatingSystemVersion];
        sysVersion = [NSString stringWithFormat:@"%ld.%ld", version.majorVersion, version.minorVersion];
        platform = @"macOS";
#endif
        tag = [NSString stringWithFormat:@"%@-%@", platform, sysVersion];
    }
    
    
//    _netType = @"4g";          // test
//    CBInfo(@"announceHost %@ %@ %@", announceHost, _netType, _natType);
    NSDictionary *dict = @{
                           @"device": @"ios-native",
                           @"tag": tag,
                           @"type": @"hls",
                           @"live": @(_isLive),
                           @"channel": _channel,
                           @"ts": _timestamp,
                           @"version": SWCP2pEngine.engineVersion,
                           @"bundle": bundleName,
                           @"app": appName,
                           @"announce": announceHost,
                           @"netType": _netType,
                           @"nat": _natType,
                           };
    CBInfo(@"channel post body %@", dict);

    NSMutableURLRequest *request=[NSMutableURLRequest requestWithURL:url];
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    request.HTTPMethod=@"POST";
    request.HTTPBody= [NSJSONSerialization dataWithJSONObject:dict options:NSJSONWritingPrettyPrinted error:nil];
    __weak typeof(self) weakSelf = self;
    NSURLSessionDataTask *dataTask=[_httpSession dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
         NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
        if (error == nil && httpResponse.statusCode == 200) {
            NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingAllowFragments error:nil];
            CBInfo(@"channelRequest success--%@", json);
            [strongSelf handleChannelMsg:json];
        } else {
            CBWarn(@"channelRequest failure--%@",error);
            if (strongSelf.connected) {
                strongSelf.connected = NO;
                NSDictionary *message = @{@"serverConnected": @(NO)};
                [[NSNotificationCenter defaultCenter] postNotificationName:kP2pEngineDidReceiveStatistics object:message];
            }
            
        }
    }];
    [dataTask resume];
    
}

- (void)peersRequest {
    NSURL *url=[NSURL URLWithString:_peersUrl];
    NSMutableURLRequest *request=[NSMutableURLRequest requestWithURL:url];
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    request.HTTPMethod=@"POST";
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    NSMutableSet<NSString *> *peers = [NSMutableSet set];
    for (NSString *peerId in _datachannelDic) {
        [peers addObject:peerId];
    }
    [peers unionSet:_failedDCSet];
    [dict setObject:[peers allObjects] forKey:@"exclusions"];   // 需要排除的peers
    CBInfo(@"peers request body %@", dict);
    request.HTTPBody= [NSJSONSerialization dataWithJSONObject:dict options:NSJSONWritingPrettyPrinted error:nil];
    NSURLSessionDataTask *dataTask=[_httpSession dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
        if (error == nil && httpResponse.statusCode == 200) {
            NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingAllowFragments error:nil];
            CBInfo(@"get peers success--%@", json);
            [self handlePeersMsg:json];
        } else {
            CBWarn(@"get peers failure--%@",error);
        }
    }];
    [dataTask resume];
    
//    if (_getPeersTimer) {
//        _getPeersTimer = nil;
//    }
}

- (void)stopP2p {
    CFAbsoluteTime t1 = CFAbsoluteTimeGetCurrent();
//    self.peerId = @"";
    if (self.connected) {
        self.connected = NO;
        NSDictionary *message = @{@"serverConnected": @(NO)};
        [[NSNotificationCenter defaultCenter] postNotificationName:kP2pEngineDidReceiveStatistics object:message];
    }
//    CBInfo(@"test after postNotificationName");
    
    [self.scheduler destroy];
    
//    [_failedDCSet removeAllObjects];
//    CFAbsoluteTime t2 = CFAbsoluteTimeGetCurrent();
    // 关闭所有datachannel
//    CBInfo(@"test _datachannelDic remain %@", @(_datachannelDic.count));
    [_datachannelDic enumerateKeysAndObjectsUsingBlock:^(NSString * _Nonnull key, SWCDataChannel * _Nonnull obj, BOOL * _Nonnull stop) {
        [(SWCDataChannel *)obj close];
    }];
//    CBInfo(@"test after close all peers");
//    CFAbsoluteTime t3 = CFAbsoluteTimeGetCurrent();
//    CBInfo(@"datachannel close 耗时 %f", (t3-t2)*1000.0);
    
    
//    [_datachannelDic enumerateKeysAndObjectsUsingBlock:^(NSString * _Nonnull key, CBDataChannel * _Nonnull obj, BOOL * _Nonnull stop) {
//        CBInfo(@"_datachannelDic key %@", key);
//    }];
//    [_datachannelDic removeAllObjects];
//    CBInfo(@"test after _datachannelDic removeAllObjects");
//    [_peers removeAllObjects];
//    CBInfo(@"test after _peers removeAllObjects");
    // 关闭信令
    if (_signaler) {
//         CBInfo(@"test before close signaler");
        [_signaler close];
    }
//    CBInfo(@"test after close signaler");
    [self destoryStats];
    [self destroyGetPeersInterval];
//    CBInfo(@"test after destroyGetPeersInterval");
//    CFAbsoluteTime t4 = CFAbsoluteTimeGetCurrent();
    
    CFAbsoluteTime t5 = CFAbsoluteTimeGetCurrent();
//    CBInfo(@"scheduler destroy 耗时 %f", (t5-t4)*1000.0);
    CBWarn(@"tracker stop p2p 耗时 %f", (t5-t1)*1000.0);
}

- (void)resumeP2P {
    [self channelRequest];
}

#pragma mark - **************** private mothodes

- (void)handleChannelMsg:(NSDictionary *)dict {
    
    NSNumber *ret = dict[@"ret"];
    NSDictionary *data =dict[@"data"];
    
    // test
//    NSMutableDictionary *data = [[NSMutableDictionary alloc] initWithDictionary:dict[@"data"]];
//    NSNumber *ret = @(-1);
//    NSDictionary *data = @{@"msg": @"888888888"};
//    data[@"info"] = @"66666666";
//    data[@"warn"] = @"77777777";
    
    if ([ret intValue] == 0) {
        
        // 正常响应
        
        BOOL rejected = [data[@"rejected"] boolValue];
        BOOL shareOnly = [data[@"share_only"] boolValue];
        if (rejected && !shareOnly) {
            NSString *warn = (NSString *)data[@"warn"];
            if (warn) {
                NSLog(@"P2P warning: Channel request rejected, reason: %@", warn);
            }
            return;
        }
        
        NSString *warn = (NSString *)data[@"warn"];
        if (warn) {
            NSLog(@"P2P warning: %@", warn);
        }
        NSString *info = (NSString *)data[@"info"];
        if (info) {
            NSLog(@"CDNBye info: %@", info);
        }
        
        self.peerId = (NSString *)data[@"id"];
        self.vcode = (NSString *)data[@"v"];
        self.reportInterval = [data[@"report_interval"] doubleValue];
        if (self.reportInterval < 10) {
            self.reportInterval = 10;
        }
        
        int minConns = [data[@"min_conns"] intValue];
        if (minConns > 0) {
            _minConns = minConns;
        } else {
            _minConns = MIN_CONNS;
        }
        CBDebug(@"minConns %d", _minConns);
        
        NSArray *peers = (NSArray *)data[@"peers"];
        
        // 连接数足够了断开信令
        _fuseRate = [data[@"fuse_rate"] intValue];
        
        // 防御性检查
        if (!(self.peerId && self.reportInterval && peers)) {
            NSLog(@"P2P warning: Channel request check failed");
            return;
        }
        
        if (shareOnly) {
            self.scheduler.shareOnly = YES;
        }
        
        // 是否只允许p2p下载
        BOOL wifiOnly = [data[@"wifi_only"] boolValue];
//        wifiOnly = YES;             // test
        if ((wifiOnly || _p2pConfig.wifiOnly) && ![_netType isEqualToString:@"wifi"]) {
            _downloadOnly = YES;
        }
        
        if (peers.count > 0) {
//            [_peers addObjectsFromArray:peers];
//            for(NSDictionary *dict in peers) {
//                NSString *platform = dict[@"plat"];
//                if (!platform) {
//                    platform = @"ios";
//                }
//                NSString *_id = dict[@"id"];
//                Peer *peer = [[Peer alloc] initWithId:_id andPlatform:platform];
//                [_peers addObject:peer];
//            }
            [self makePeersFromArray:peers];
        } else {
            [self getMorePeers];
        }
        
        
        _statsUrl = [NSString stringWithFormat:@"%@/%@/node/%@/stats", _channelUrl, _channel, self.peerId];
        _peersUrl = [NSString stringWithFormat:@"%@/%@/node/%@/peers", _channelUrl, _channel, self.peerId];
        
//        CBInfo(@"_statsUrl %@", _statsUrl);
//        CBInfo(@"_peersUrl %@", _peersUrl);
        
        // 优先使用下发的信令
        NSString *signalAddr = (NSString *)data[@"signal"];
        if (!signalAddr) {
            signalAddr = _p2pConfig.wsSignalerAddr ? _p2pConfig.wsSignalerAddr : DEFAULT_SIGNAL_ADDR;
        }
        NSString *signalUrl = [NSString stringWithFormat:@"%@?id=%@&p=ios", signalAddr, self.peerId];
        NSString *token = (NSString *)data[@"token"];
        if (token) {
            signalUrl = [NSString stringWithFormat:@"%@&token=%@", signalUrl, token];
        }
        _signaler = [SWCSignalClient sharedInstance];
        [_signaler openWithUrl:signalUrl reset:YES];
        
        // 优先使用下发的stun  TODO 验证
        NSArray<NSString *> *stunArr = (NSArray<NSString *> *)data[@"stun"];
        if (stunArr && stunArr.count > 0) {
            NSMutableArray *ICEServers = [NSMutableArray array];
            RTCIceServer *servers = [[RTCIceServer alloc] initWithURLStrings:stunArr];
            [ICEServers addObject:servers];
            _p2pConfig.webRTCConfig.iceServers = ICEServers;
        }
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(SRWebSocketDidOpen) name:kWebSocketDidOpenNote object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(SRWebSocketDidReceiveMsg:) name:kWebSocketdidReceiveMessageNote object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(SRWebSocketDidClose) name:kWebSocketDidCloseNote object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(SRWebSocketDidFail) name:kWebSocketDidFailNote object:nil];
        
        // 开始心跳
        [self statsPeriodically];
        
    } else {
        // 异常响应
        if (self.connected) {
            self.connected = NO;
            NSDictionary *message = @{@"serverConnected": @(NO)};
            [[NSNotificationCenter defaultCenter] postNotificationName:kP2pEngineDidReceiveStatistics object:message];
        }
        NSString *msg = (NSString *)data[@"msg"];
        if (msg) {
            NSLog(@"P2P warning: Channel request failed, reason: %@", msg);
        }
    }
}

- (void)makePeersFromArray:(NSArray *)peerIds {
    NSMutableArray *peers = [NSMutableArray array];
    for(NSDictionary *dict in peerIds) {
        NSString *_id = dict[@"id"];
        SWCPeer *peer = [[SWCPeer alloc] initWithId:_id];
        [peers addObject:peer];
//        if (peers.count >= _p2pConfig.maxPeerConnections) {
//            CBInfo(@"peers size exceed maxPeerConnections");
//            break;
//        }
    }
    _peersReceived = [self filterPeers:peers];
}

- (void)handlePeersMsg:(NSDictionary *)dict {
    NSNumber *ret = dict[@"ret"];
    NSDictionary *data =dict[@"data"];
    if ([ret intValue] == 0) {
        // 正常响应 开始连接
        [_peersReceived removeAllObjects];
//        [_peers addObjectsFromArray:(NSArray *)data[@"peers"]];
        [self makePeersFromArray:(NSArray *)data[@"peers"]];
        [self tryConnectToAllPeers];
        
    } else {
        
        // 异常响应
//        NSString *msg = (NSString *)data[@"msg"];
//        if (msg) {
//            NSLog(@"P2P warning: Peers request failed, reason: %@", msg);
//        }
    }
}

- (void)tryConnectToAllPeers {
    if (_peersReceived.count == 0) return;
    CBInfo(@"try connect to %@ peers", @(_peersReceived.count));
    NSArray *copyArr = [NSArray arrayWithArray:_peersReceived];
    for (SWCPeer *peer in copyArr) {
        NSString *peerId = peer.peerId;
        //过滤掉已经连接的节点和连接失败的节点
        if ([_datachannelDic objectForKey:peerId] || [_failedDCSet containsObject:peerId]) {
            continue;
        }
        
        // 限制最大连接数
        if (self.scheduler && self.scheduler.peersNum > _p2pConfig.maxPeerConnections) {
            CBInfo(@"p2p connections reach MAX_CONNS");
            break;
        }
        
        // 不能超过12个，否则卡住 TODO 验证
        if (_datachannelDic.count > 12) {
            break;
        }
        
        SWCDataChannel *dataChannel = [self createDatachannelWithRemoteId:peerId isInitiator:YES intermediator:peer.intermediator];
        // 设置代理
        dataChannel.delegate = self;
        [_datachannelDic setObject:dataChannel forKey:peerId];
        CBInfo(@"_datachannelDic setObject forKey %@ remain %@", peerId, @(_datachannelDic.count));
    }
    // 清空peers
    [_peersReceived removeAllObjects];
}

- (void)report {
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    NSUInteger lastP2pDownloaded = 0;
    NSUInteger lastP2pUploaded = 0;
    NSUInteger lastHttpDownloaded = 0;
    NSUInteger lastFailedConns = 0;
    NSUInteger lastConns = 0;
    if (self.scheduler.p2pDownloaded > 0) {
        lastP2pDownloaded = self.scheduler.p2pDownloaded;
        [dict setObject:@(self.scheduler.p2pDownloaded) forKey:@"p2p"];
    }
    if (self.scheduler.p2pUploaded > 0) {
        lastP2pUploaded = self.scheduler.p2pUploaded;
        [dict setObject:@(self.scheduler.p2pUploaded) forKey:@"share"];
    }
    if (self.scheduler.httpDownloaded > 0) {
        lastHttpDownloaded = self.scheduler.httpDownloaded;
        [dict setObject:@(self.scheduler.httpDownloaded) forKey:@"http"];
    }
    if (self.scheduler.failConns > 0) {
        lastFailedConns = self.scheduler.failConns;
        [dict setObject:@(self.scheduler.failConns) forKey:@"failConns"];
    }
    if (self.scheduler.conns != 0) {
        lastConns = self.scheduler.conns;
        [dict setObject:@(self.scheduler.conns) forKey:@"conns"];
    }
    CBInfo(@"report %@", dict);
    
    NSURL *url=[NSURL URLWithString:_statsUrl];
    NSMutableURLRequest *request=[NSMutableURLRequest requestWithURL:url];
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    request.HTTPMethod=@"POST";
    request.HTTPBody= [NSJSONSerialization dataWithJSONObject:dict options:NSJSONWritingPrettyPrinted error:nil];
    NSURLSessionDataTask *dataTask=[_httpSession dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
        if (error == nil && httpResponse.statusCode == 200) {
            NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingAllowFragments error:nil];
            NSNumber *ret = json[@"ret"];
            if ([ret intValue] == 0) {
                
                // 减去上报的部分
                if (self.scheduler) {
                    if (self.scheduler.p2pDownloaded >= lastP2pDownloaded) self.scheduler.p2pDownloaded -= lastP2pDownloaded;
                    if (self.scheduler.p2pUploaded >= lastP2pUploaded) self.scheduler.p2pUploaded -= lastP2pUploaded;
                    if (self.scheduler.httpDownloaded >= lastHttpDownloaded) self.scheduler.httpDownloaded -= lastHttpDownloaded;
                    self.scheduler.conns -= lastConns;
                    self.scheduler.failConns -= lastFailedConns;
                }
                
                // test
                //            [self stopP2p];
                //            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(10 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                //                [self resumeP2P];
                //            });
                
            } else {
                
                // 上报失败
                CBWarn(@"stats ret -1");
                // 销毁定时器
                [self destoryStats];
                [self destroyGetPeersInterval];
            }
        } else {
            CBError(@"stats request failure--%@",error);
            if (error) {
                
            }
//            self.connected = NO;
        }
    }];
    [dataTask resume];
}

// 心跳统计
- (void)statsPeriodically {
//    dispatch_main_async_safe(^{
//        [self destoryStats];
//        self->_heartBeat = [NSTimer timerWithTimeInterval:self.reportInterval target:self selector:@selector(report) userInfo:nil repeats:YES];
//        [[NSRunLoop currentRunLoop] addTimer:self->_heartBeat forMode:NSRunLoopCommonModes];
//    })
    
    __weak typeof(self) weakSelf = self;
    [[CBTimerManager sharedInstance] scheduledDispatchTimerWithName:TRACKER_HEARTBEAT
                                                       timeInterval:self.reportInterval
                                                              queue:nil
                                                            repeats:YES
                                                      fireInstantly:NO
                                                             action:^{
                                                                 [weakSelf report];
                                                             }];
}

- (void)destoryStats {
//    dispatch_main_async_safe(^{
//        [CBUtils destroyTimer:self->_heartBeat];
        
        
//    })
    [[CBTimerManager sharedInstance] cancelTimerWithName:TRACKER_HEARTBEAT];
}

// TODO 验证
- (void)doSignalFusing:(NSInteger)conns {
    if (_fuseRate <= 0 || _signaler == nil) return;
    if (_signaler.socketReadyState == SR_OPEN && conns >= _fuseRate+2) {
        // 上报stats
        CBInfo(@"reach fuseRate, report stats close signaler");
        if (self.scheduler.conns > 0) [self report];
        // 断开信令
        [_signaler close];
    } else if (_signaler.socketReadyState == SR_CLOSED && conns < _fuseRate) {
        // 重连信令
        CBInfo(@"low conns, reconnect signaler");
        [_signaler reconnectImmediately];
    }
}

// 获取更多节点
- (void)getMorePeers {
    if (!self.connected) return;
    if (_datachannelDic.count >= _minConns) return;   // 连接达到上限
    __weak typeof(self) weakSelf = self;
    [[CBTimerManager sharedInstance] checkExistTimer:TRACKER_GET_PEERS completion:^(BOOL doExist) {
        if (!doExist) {
            if (self->_getPeersDelay == 0) {
                self->_getPeersDelay = BASE_INTERVAL;
            } else {
                self->_getPeersDelay *= FACTOR;
            }
            CBInfo(@"get more peers, delay %f", self->_getPeersDelay);
            //            dispatch_main_async_safe(^{
            //                self->_getPeersTimer = [NSTimer timerWithTimeInterval:self->_getPeersDelay target:self selector:@selector(peersRequest) userInfo:nil repeats:NO];
            //                [[NSRunLoop currentRunLoop] addTimer:self->_getPeersTimer forMode:NSRunLoopCommonModes];
            //                //        CBInfo(@"peersRequest");
            //            })
            
            [[CBTimerManager sharedInstance] scheduledDispatchTimerWithName:TRACKER_GET_PEERS
                                                               timeInterval:self->_getPeersDelay
                                                                      queue:nil
                                                                    repeats:NO
                                                              fireInstantly:NO
                                                                     action:^{
                                                                         [weakSelf peersRequest];
                                                                     }];
            
        }
    }];
    
}

- (void)destroyGetPeersInterval {
//    dispatch_main_async_safe(^{
//        [CBUtils destroyTimer:self->_getPeersTimer];
//    })
    [[CBTimerManager sharedInstance] cancelTimerWithName:TRACKER_GET_PEERS];
}

- (void)handleSignal:(NSDictionary *)data fromPeerId:(NSString *)peerId intermediator:(NSString *)intermediator {
    SWCDataChannel *dc = [_datachannelDic objectForKey:peerId];
    if (dc && dc.connected) {
        CBInfo(@"datachannel had connected, signal ignored");
        return;
    }
    if (!dc) {
//        if ([_failedDCSet containsObject:peerId]) {
//            return;
//        }
        CBInfo(@"receive node %@ connection request", peerId);
        
        // 限制最大连接数
        if (self.scheduler && self.scheduler.peersNum > _p2pConfig.maxPeerConnections) {
            CBInfo(@"p2p connections reach MAX_CONNS, signal rejected");
            // 拒绝对方连接请求
            [_signaler sendRejectToRemotePeerId:peerId reason:[NSString stringWithFormat:@"p2p connections reach %@", @(_p2pConfig.maxPeerConnections)]];
            return;
        }
        
        // 不能超过12个，否则卡住 TODO 验证
        if (_datachannelDic.count >= 12) {
            // 拒绝对方连接请求
            [_signaler sendRejectToRemotePeerId:peerId reason:@"p2p connections reach 12"];
            return;
        }
        dc = [self createDatachannelWithRemoteId:peerId isInitiator:NO intermediator:intermediator];
        // 设置代理
        dc.delegate = self;
        [_datachannelDic setObject:dc forKey:peerId];
        CBInfo(@"_datachannelDic setObject forKey %@ remain %@", peerId, @(_datachannelDic.count));
    }
    if (dc) {
        [dc receiveSignal:data];
    } else {
        CBWarn(@"dc is nil!");
    }
}

- (SWCDataChannel *)createDatachannelWithRemoteId:(NSString *)remoteId isInitiator:(BOOL)isInitiator intermediator:(NSString *)intermediator {
    SWCDataChannel *dc;
    if (_scheduler.isSequential) {
        dc = [[SWCDataChannel alloc] initWithPeerId:self.peerId remotePeerId:remoteId isInitiator:isInitiator factory:_factory andConfig:_p2pConfig isLive:_isLive sequential:YES channal:_channel intermediator:intermediator];
    } else {
        dc = [[SWCDataChannel alloc] initWithPeerId:self.peerId remotePeerId:remoteId isInitiator:isInitiator factory:_factory andConfig:_p2pConfig isLive:_isLive sequential:NO channal:_channel intermediator:intermediator];
    }
    [_datachannelDic setObject:dc forKey:remoteId];
    return dc;
}

- (void)onSignalMessage:(NSDictionary *)msg {
    NSString *action = [msg objectForKey:@"action"];
    NSString *fromPeerId = [msg objectForKey:@"from_peer_id"];
    if (!fromPeerId) return;
    if ([action isEqualToString:@"signal"]) {
        [self handleSignalMsg:[msg objectForKey:@"data"] fromPeerId:fromPeerId intermediator:nil];
    } else if ([action isEqualToString:@"reject"]) {
        CBInfo(@"peer %@ signal rejected", fromPeerId);
        [self handSignalRejectedFromPeerId:fromPeerId reason:[msg objectForKey:@"reason"]];
    }
}

- (void)handleSignalMsg:(NSDictionary *)data fromPeerId:(NSString *)fromPeerId intermediator:(NSString *)intermediator {
    CBVerbose(@"signal from peer id %@", fromPeerId);
    if (data == nil) {
        if ([self destroyAndDeletePeer:fromPeerId] == nil) return;
        CBInfo(@"peer %@ not found", fromPeerId);
        [self getMorePeers];
    } else {
        if ([_failedDCSet containsObject:fromPeerId]) {
            // 拒绝对方连接请求
            [self sendSignalRejectWithRemoteId:fromPeerId reason:@"peer in blocked list" intermediator:intermediator];
            return;
        }
        [self handleSignal:data fromPeerId:fromPeerId intermediator:intermediator];
    }
}

- (SWCDataChannel *)destroyAndDeletePeer:(NSString *)remotePeerId {
    SWCDataChannel *dc = [_datachannelDic objectForKey:remotePeerId];
    if (dc) {
        dc.delegate = nil;
        [dc close];
        [_datachannelDic removeObjectForKey:remotePeerId];
    }
    return dc;
}

- (void)handSignalRejectedFromPeerId:(NSString *)fromPeerId reason:(NSString *)reason {
    CBWarn(@"peer %@ signal rejected", fromPeerId);
    SWCDataChannel *dc = [_datachannelDic objectForKey:fromPeerId];
    if (dc && !dc.connected) {
        [dc close];
        [_datachannelDic removeObjectForKey:fromPeerId];
    }
    [self getMorePeers];
}

- (NSMutableArray<SWCPeer *> *)filterPeers:(NSArray<SWCPeer *> *)peers {
    NSMutableArray<SWCPeer *> *ret = [NSMutableArray array];
    for (SWCPeer *peer in peers) {
        NSString *remotePeerId = peer.peerId;
        if ([_datachannelDic objectForKey:remotePeerId] || [_failedDCSet containsObject:remotePeerId] || [remotePeerId isEqualToString:_peerId]) {
            CBDebug(@"peer %@ ignored", remotePeerId);
            continue;
        }
        [ret addObject:peer];
    }
    return ret;
}

- (void)sendSignalRejectWithRemoteId:(NSString *)remoteId reason:(NSString *)reason intermediator:(NSString *)intermediator {
    if (intermediator) {
        SWCDataChannel *interPeer = [_datachannelDic objectForKey:intermediator];
        if (interPeer) {
            // 通过中间peer中转
            if ([interPeer sendMsgSignalRejectToPeerId:remoteId fromPeerId:_peerId reason:reason]) return;
        }
    }
    [_signaler sendRejectToRemotePeerId:remoteId reason:reason];
}

#pragma mark - **************** CBDataChannelDelegate

/** 产生了信令信息，通过ws发送出去 */
- (void)dataChannel:(SWCDataChannel *)peer didHaveSignal:(NSDictionary *)dict {
    
    if (_signaler) {
//        CBDebug(@"signaler send %@ to %@", dict, remotePeerId);
         [_signaler sendSignal:dict remotePeerId:peer.remotePeerId];
    }
}

/** datachannel开启 */
- (void)dataChannelDidOpen:(SWCDataChannel *)peer {
    CBDebug(@"datachannel open %@", peer.remotePeerId);
    
    // 发送bitfield
    [self.scheduler handshakePeer:peer];
    self.scheduler.conns ++;
    [self getMorePeers];
    [self doSignalFusing:self.scheduler.conns];
}

/** datachannel关闭 */
- (void)dataChannelDidClose:(SWCDataChannel *)peer {
    CBInfo(@"datachannel close %@", peer.remotePeerId);
    [_failedDCSet addObject:peer.remotePeerId];
    [self.scheduler breakOffPeer:peer];
    [self destroyAndDeletePeer:peer.remotePeerId];
    CBInfo(@"_datachannelDic removeObjectForKey %@ remain %@", peer.remotePeerId, @(_datachannelDic.count));
    self.scheduler.conns --;
    [self getMorePeers];
    [self doSignalFusing:self.scheduler.conns];
    [_scheduler clearDisconnectedPeers];
}

/** datachannel连接失败 */
- (void)dataChannelDidFail:(SWCDataChannel *)peer fatal:(BOOL)fatal {
    CBInfo(@"datachannel failed %@", peer.remotePeerId);
    [self.scheduler breakOffPeer:peer];
    [peer close];
    peer.delegate = nil;
    if (peer.connected) {
        //            CBInfo(@"opened dc failed %@", remotePeerId);
        self.scheduler.conns --;
    } else {
        if (_failedDCSet && fatal) [_failedDCSet addObject:peer.remotePeerId];
        self.scheduler.failConns ++;
    }
    peer.connected = NO;
    [_datachannelDic removeObjectForKey:peer.remotePeerId];
    CBInfo(@"_datachannelDic removeObjectForKey %@ remain %@", peer.remotePeerId, @(_datachannelDic.count));
    [self getMorePeers];
    [self doSignalFusing:self.scheduler.conns];
    [_scheduler clearDisconnectedPeers];
}

/** bitfield 用于加入peer */
- (void)dataChannel:(SWCDataChannel *)peer didReceiveBitField:(NSArray *)field {
//    CBInfo(@"didReceiveBitField %@ from %@", field, remotePeerId);
    [peer initBitField:field];
    [self.scheduler addPeer:peer andBitfield:field];
    
    if (_downloadOnly) {
        [peer sendMsgChoke];           // 不分享
    }
}

// TODO
- (void)dataChannelDidReceiveGetPeersRequest:(SWCDataChannel *)peer {
    
}

// TODO
- (void)dataChannel:(SWCDataChannel *)peer didReceivePeers:(NSArray *)peers {
    
}

#pragma mark - **************** SRWebSocket

- (void)SRWebSocketDidOpen {
    CBInfo(@"ws connection opened");
    self.connected = YES;
    NSDictionary *message = @{@"serverConnected": @(YES)};
    [[NSNotificationCenter defaultCenter] postNotificationName:kP2pEngineDidReceiveStatistics object:message];
  
    // 针对每个peer初始化datachannel
    [self tryConnectToAllPeers];
}

- (void)SRWebSocketDidClose {
    CBInfo(@"ws connection closed");
    //在成功后需要做的操作。。。
//    self.connected = NO;
}

- (void)SRWebSocketDidFail {
    CBWarn(@"ws connection failed");
//    self.connected = NO;
    //在成功后需要做的操作。。。
    
}

- (void)SRWebSocketDidReceiveMsg:(NSNotification *)note {
    //收到服务端发送过来的消息
    NSDictionary * dict = note.object;
    [self onSignalMessage:dict];
}



- (void)dealloc {
//    [self stopP2p];
    CBInfo(@"tracker dealloc");
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}
@end
