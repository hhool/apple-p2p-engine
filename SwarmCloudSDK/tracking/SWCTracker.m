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
#import "WebRTC/RTCPeerConnectionFactory.h"
#import "CBTimerManager.h"
#import "WebRTC/RTCIceServer.h"
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
const NSUInteger IOS_MAX_PEERS_LIMIT = 11;

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
    
    BOOL _gotPeersFromTracker;
    NSUInteger _peersIncrement;                 // 每个getPeers周期获取的可连接节点数量
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
    NSString *mediaTypeString;
    switch (_mediaType) {
        case SWCMediaTypeHls:
            mediaTypeString = @"hls";
            break;
        case SWCMediaTypeMp4:
            mediaTypeString = @"mp4";
            break;
        case SWCMediaTypeFile:
            mediaTypeString = @"file";
            break;
        default:
            break;
    }
    NSDictionary *dict = @{
                           @"device": @"ios-native",
                           @"tag": tag,
                           @"type": mediaTypeString,
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
    if (_datachannelDic.count >= _minConns) return;   // 连接达到上限
    if (_scheduler.peersNum == 0 || (_peersIncrement <= 3 && !_gotPeersFromTracker)) {
        // 如果上次获取的节点过少并且不是向tracker请求，则这次向tracker请求
        [self sendPeersReqToServer];
        _gotPeersFromTracker = YES;
    } else {
        // 从邻居获取节点 留一部分空间给tracker调度给其他节点
        if (_scheduler.peersNum < _p2pConfig.maxPeerConnections - MIN_PEERS_FOR_TRACKER) {
            [_scheduler requestPeers];
            _gotPeersFromTracker = NO;
        }
    }
}

- (void)sendPeersReqToServer {
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
        
        _peerId = (NSString *)data[@"id"];
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
            _peersReceived = [self makePeersFromArray:peers];
            // test
//            _peersReceived = [NSMutableArray arrayWithArray:@[_peersReceived[1]]];
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
        
        // 优先使用下发的stun
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

- (NSMutableArray<SWCPeer *> *)makePeersFromArray:(NSArray *)peerIds {
    NSMutableArray<SWCPeer *> *peers = [NSMutableArray array];
    for(NSDictionary *dict in peerIds) {
        NSString *_id = dict[@"id"];
        SWCPeer *peer = [[SWCPeer alloc] initWithId:_id];
        [peers addObject:peer];
    }
    return [self filterPeers:peers];
}

- (void)handlePeersMsg:(NSDictionary *)dict {
    NSNumber *ret = dict[@"ret"];
    NSDictionary *data =dict[@"data"];
    if ([ret intValue] == 0) {
        // 正常响应 开始连接
        [_peersReceived removeAllObjects];
//        [_peers addObjectsFromArray:(NSArray *)data[@"peers"]];
        _peersReceived = [self makePeersFromArray:(NSArray *)data[@"peers"]];
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
#if TARGET_OS_IOS
    // 防止ios主线程卡死
    if (copyArr.count > 6) copyArr = [copyArr subarrayWithRange:NSMakeRange(0, 6)];
#endif
    for (SWCPeer *peer in copyArr) {
        NSString *peerId = peer.peerId;
        
        // 限制最大连接数
        if (self.scheduler && self.scheduler.peersNum > _p2pConfig.maxPeerConnections) {
            CBInfo(@"p2p connections reach MAX_CONNS");
            break;
        }
        
#if TARGET_OS_IOS
        // ios不能超过11个，否则卡住
        if (_datachannelDic.count >= IOS_MAX_PEERS_LIMIT) {
            break;
        }
#endif
        [self createDatachannelWithRemoteId:peerId isInitiator:YES intermediator:peer.intermediator];
//        CBInfo(@"_datachannelDic setObject forKey %@ remain %@", peerId, @(_datachannelDic.count));
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
    [[CBTimerManager sharedInstance] cancelTimerWithName:TRACKER_HEARTBEAT];
}

- (void)doSignalFusing:(NSInteger)conns {
    if (_fuseRate <= 0 || _signaler == nil) return;
    // test
//    _fuseRate = 2;
//    CBDebug(@"_signaler.socketReadyState %@ conns %@", @(_signaler.socketReadyState), @(conns));
    if (_signaler.socketReadyState == SR_OPEN && conns >= _fuseRate+2) {
        // 上报stats
        CBInfo(@"reach fuseRate, report stats close signaler");
        if (self.scheduler.conns > 0) [self report];
        // 断开信令
        [_signaler close];
    } else if (_signaler.socketReadyState != SR_OPEN && conns < _fuseRate) {
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
        // 如果没有存在定时器
        if (!doExist) {
            if (self->_getPeersDelay == 0) {
                self->_getPeersDelay = BASE_INTERVAL;
            } else {
                self->_getPeersDelay *= FACTOR;
            }
            CBInfo(@"get more peers, delay %f", self->_getPeersDelay);
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

- (void)realHandleSignal:(NSDictionary *)data fromPeerId:(NSString *)remoteId intermediator:(NSString *)intermediator {
    SWCDataChannel *dc = [_datachannelDic objectForKey:remoteId];
    NSString *sdpType = (NSString *)data[@"type"];
    if (dc) {
        if (dc.connected) {
            CBInfo(@"datachannel had connected, signal ignored");
            return;
        }
        if (sdpType && [sdpType isEqualToString:@"offer"]) {
            // 收到的一定是answer或candidate  可能产生碰撞
            if ([self.peerId compare:remoteId] == NSOrderedDescending) {
                // peerId大的转成被动方
                [self destroyAndDeletePeer:remoteId];
                CBWarn(@"signal type wrong %@ , convert to non initiator", sdpType);
                dc = [self createDatachannelWithRemoteId:remoteId isInitiator:NO intermediator:intermediator];
            } else {
                // peerId小的忽略信令
                CBWarn(@"signal type wrong %@ , ignored", sdpType);
                return;
            }
        }
    } else {
        // 收到的一定是offer
        if (sdpType && [sdpType isEqualToString:@"answer"]) {
            NSString *errMsg = [NSString stringWithFormat:@"signal type wrong %@", sdpType];
            CBWarn(@"signal type wrong %@", sdpType);
            // 拒绝对方连接请求
            [self sendSignalRejectWithRemoteId:remoteId reason:errMsg intermediator:intermediator];
            [self destroyAndDeletePeer:remoteId];
            return;
        }
        // 收到节点连接请求
        CBInfo(@"receive node %@ connection request", remoteId);
#if TARGET_OS_IOS
        // ios不能超过11个，否则卡住
        if (_datachannelDic.count >= IOS_MAX_PEERS_LIMIT) {
            // 拒绝对方连接请求
            [_signaler sendRejectToRemotePeerId:remoteId reason:@"peers reach limit"];
            return;
        }
#endif
        // 限制最大连接数
        if (self.scheduler && self.scheduler.peersNum >= _p2pConfig.maxPeerConnections) {
            NSArray<SWCDataChannel *> *candidates = [_scheduler getNonactivePeers];
            if (candidates.count > 0) {
                SWCDataChannel *peerToClose = [candidates firstObject];
                peerToClose.connected = NO;
                [peerToClose sendMsgClose];
            } else {
                CBInfo(@"p2p connections reach limit %@", @(_p2pConfig.maxPeerConnections));
                // 拒绝对方连接请求
                [_signaler sendRejectToRemotePeerId:remoteId reason:[NSString stringWithFormat:@"p2p connections reach %@", @(_p2pConfig.maxPeerConnections)]];
                return;
            }
        }
        // 留一部分空间给tracker调度给其他节点
        if (intermediator && (_p2pConfig.maxPeerConnections-[_scheduler peersNum] < MIN_PEERS_FOR_TRACKER)) {
            CBInfo(@"too many peers from peer");
            // 拒绝对方连接请求
            [_signaler sendRejectToRemotePeerId:remoteId reason:[NSString stringWithFormat:@"p2p connections reach %@", @(_p2pConfig.maxPeerConnections)]];
            return;
        }
        dc = [self createDatachannelWithRemoteId:remoteId isInitiator:NO intermediator:intermediator];
    }
    [dc receiveSignal:data];
}

- (SWCDataChannel *)createDatachannelWithRemoteId:(NSString *)remoteId isInitiator:(BOOL)isInitiator intermediator:(NSString *)intermediator {
    SWCDataChannel *dc;
    CBDebug(@"create datachannel remoteId %@ isSequential %@", remoteId, @(_scheduler.isSequential));
    if (_scheduler.isSequential) {
        dc = [[SWCDataChannel alloc] initWithPeerId:self.peerId remotePeerId:remoteId isInitiator:isInitiator factory:_factory andConfig:_p2pConfig isLive:_isLive sequential:YES channal:_channel intermediator:intermediator];
    } else {
        dc = [[SWCDataChannel alloc] initWithPeerId:self.peerId remotePeerId:remoteId isInitiator:isInitiator factory:_factory andConfig:_p2pConfig isLive:_isLive sequential:NO channal:_channel intermediator:intermediator];
    }
    // 设置代理
    dc.delegate = self;
    [_datachannelDic setObject:dc forKey:remoteId];
    CBInfo(@"create datachannel for %@", remoteId);
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
        [self realHandleSignal:data fromPeerId:fromPeerId intermediator:intermediator];
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
    CBWarn(@"peer %@ signal rejected reason %@", fromPeerId, reason);
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
        if ([_datachannelDic objectForKey:remotePeerId] || [_failedDCSet containsObject:remotePeerId] || [remotePeerId isEqualToString:self.peerId]) {
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
            if ([interPeer sendMsgSignalRejectToPeerId:remoteId fromPeerId:self.peerId reason:reason]) return;
        }
    }
    [_signaler sendRejectToRemotePeerId:remoteId reason:reason];
}

#pragma mark - **************** CBDataChannelDelegate

/** 产生了信令信息，通过ws或者peer发送出去 */
- (void)dataChannel:(SWCDataChannel *)dc didHaveSignal:(NSDictionary *)dict {
    // webrtc产生的sdp
    if (dc.intermediator) {
        // 通过中间peer中转
        SWCDataChannel *interPeer = [_datachannelDic objectForKey:dc.intermediator];
        if (interPeer) {
            // 通过中间peer中转
            if ([interPeer sendMsgSignalToPeerId:dc.remotePeerId fromPeerId:self.peerId data:dict]) return;
        }
    }
    if (_signaler) {
//        CBDebug(@"signaler send %@ to %@", dict, remotePeerId);
         [_signaler sendSignal:dict remotePeerId:dc.remotePeerId];
    }
}

/** datachannel开启 */
- (void)dataChannelDidOpen:(SWCDataChannel *)dc {
    CBDebug(@"datachannel open %@", dc.remotePeerId);
    
    // 发送bitfield
    [self.scheduler handshakePeer:dc];
    self.scheduler.conns ++;
    _peersIncrement ++;
    [self getMorePeers];
    [self doSignalFusing:self.scheduler.peersNum + 1];
}

/** datachannel关闭 */
- (void)dataChannelDidClose:(SWCDataChannel *)dc {
    CBInfo(@"datachannel close %@", dc.remotePeerId);
    [_failedDCSet addObject:dc.remotePeerId];
    [self.scheduler breakOffPeer:dc];
    [self destroyAndDeletePeer:dc.remotePeerId];
    CBInfo(@"_datachannelDic removeObjectForKey %@ remain %@", dc.remotePeerId, @(_datachannelDic.count));
    self.scheduler.conns --;
    [self getMorePeers];
    [self doSignalFusing:self.scheduler.peersNum];
    [_scheduler clearDisconnectedPeers];
}

/** datachannel连接失败 */
- (void)dataChannelDidFail:(SWCDataChannel *)dc fatal:(BOOL)fatal {
    CBInfo(@"datachannel failed %@", dc.remotePeerId);
    [self.scheduler breakOffPeer:dc];
    [dc close];
    dc.delegate = nil;
    if (dc.connected) {
        //            CBInfo(@"opened dc failed %@", remotePeerId);
        self.scheduler.conns --;
    } else {
        if (_failedDCSet && fatal) [_failedDCSet addObject:dc.remotePeerId];
        self.scheduler.failConns ++;
    }
    [_datachannelDic removeObjectForKey:dc.remotePeerId];
    CBInfo(@"_datachannelDic removeObjectForKey %@ remain %@", dc.remotePeerId, @(_datachannelDic.count));
    [self getMorePeers];
    [self doSignalFusing:self.scheduler.peersNum];
    [_scheduler clearDisconnectedPeers];
}

/** bitfield 用于加入peer */
- (void)dataChannel:(SWCDataChannel *)dc didReceiveBitField:(NSArray *)field {
//    CBInfo(@"didReceiveBitField %@ from %@", field, remotePeerId);
    [dc initBitField:field];
    [self.scheduler addPeer:dc andBitfield:field];
    
    if (_downloadOnly) {
        [dc sendMsgChoke];           // 不分享
    }
}

- (void)dataChannelDidReceiveGetPeersRequest:(SWCDataChannel *)dc {
    NSArray<SWCDataChannel *> *peers = _scheduler.getPeers;
    if (peers.count > 0) {
        NSMutableArray *peersToSent = [NSMutableArray array];
        for (SWCDataChannel *peer in peers) {
            if ([peer.remotePeerId isEqualToString:dc.remotePeerId]
                || [peer.remotePeerId isEqualToString:self.peerId]
                || peer.peersConnected >= (peer.mobile?15:25)-MIN_PEERS_FOR_TRACKER) continue;    // 排除连接满的节点
            NSDictionary *peerModel = @{@"id": peer.remotePeerId};
            [peersToSent addObject:peerModel];
        }
        CBInfo(@"send %@  peers to %@", @(peersToSent.count), dc.remotePeerId);
        [dc sendMsgPeers:peersToSent];
    }
}

- (void)dataChannel:(SWCDataChannel *)dc didReceivePeers:(NSArray *)peers {
    if (peers.count > 0) {
        CBInfo(@"receive %@ peers from %@", @(peers.count), dc.remotePeerId);
        NSArray<SWCPeer *> *peerArr = [self makePeersFromArray:peers];
        for (SWCPeer *peer in peerArr) {
            peer.intermediator = dc.remotePeerId;
        }
        if (peerArr.count > MAX_TRY_CONNS) {
            peerArr = [peerArr subarrayWithRange:NSMakeRange(0, MAX_TRY_CONNS)];
        }
        [_peersReceived addObjectsFromArray:peerArr];
        [self tryConnectToAllPeers];
    }
}

- (void)dataChannel:(SWCDataChannel *)dc didReceivePeerSignalWithAction:(NSString *)action toPeerId:(NSString *)toPeerId fromPeerId:(NSString *)fromPeerId data:(NSDictionary *)data reason:(NSString *)reason {
    // 接收到peer传来的信令
    if (![toPeerId isEqualToString:self.peerId]) {
        // 本节点是中转者
        CBInfo(@"relay signal for %@", fromPeerId);     
        SWCDataChannel *targetPeer = [_datachannelDic objectForKey:toPeerId];
        if (targetPeer) {
            if ([action isEqualToString:@"signal"]) {
                if ([targetPeer sendMsgSignalToPeerId:toPeerId fromPeerId:fromPeerId data:data]) return;
            } else if ([action isEqualToString:@"reject"]) {
                if ([targetPeer sendMsgSignalRejectToPeerId:toPeerId fromPeerId:fromPeerId reason:reason]) return;
            }
        }
        // peer not found
        [dc sendMsgSignalToPeerId:fromPeerId fromPeerId:toPeerId data:nil];
    } else {
        // 本节点是目标节点
        CBInfo(@"receive signal from %@", fromPeerId);
        if ([action isEqualToString:@"signal"]) {
            [self handleSignalMsg:data fromPeerId:fromPeerId intermediator:dc.remotePeerId];
        } else if ([action isEqualToString:@"reject"]) {
            [self handSignalRejectedFromPeerId:fromPeerId reason:reason];
        }
    }
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
    NSDictionary *message = @{@"serverConnected": @(NO)};
    [[NSNotificationCenter defaultCenter] postNotificationName:kP2pEngineDidReceiveStatistics object:message];
}

- (void)SRWebSocketDidFail {
    CBWarn(@"ws connection failed");
    NSDictionary *message = @{@"serverConnected": @(NO)};
    [[NSNotificationCenter defaultCenter] postNotificationName:kP2pEngineDidReceiveStatistics object:message];
    
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
