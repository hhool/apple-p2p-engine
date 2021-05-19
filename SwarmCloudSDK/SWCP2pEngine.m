//
//  SWCP2pEngine.m
//  SwarmCloudSDK
//
//  Created by Timmy on 2021/5/5.
//  Copyright © 2021 cdnbye. All rights reserved.
//

#import "SWCP2pEngine.h"
#import <GCDWebServer.h>
#import "CBLogger.h"
#import "NATUtils.h"
#import "StunMessage.h"
#import "StunClient.h"
#import "CBTimerManager.h"
#import "SWCProxy.h"
#import "SWCM3u8Proxy.h"
#import "SWCMp4Proxy.h"
#import "SWCDataChannel.h"
#import "SWCHlsSegment.h"

NSString *const VERSION = @"2.0.0";                 // SDK版本号

const NSUInteger UDP_SEND_PORT = 50899;              // 发送udp包的端口                     // TODO 测试 0
NSString *const kP2pEngineDidReceiveStatistics  = @"kP2pEngineDidReceiveStatistics";

static NSString * const ENGINE_NAT_QUERY = @"ENGINE_NAT_QUERY";

@interface SWCP2pEngine()<SWCProxyDelegate>

{
    @package
    
    
@private
    SWCProxy *_currentProxy;
    NSURL *_originalURL;
    NSString *_videoId;
    NSString *_token;
//    CBTrackerClient *_tracker;
    BOOL _isvalid;
//    GCDWebServer* _webServer;
    
    BOOL _isLive;
    NSUInteger _endSN;
//    NSUInteger _prefetchSegs; // 目前通过http预加载的ts数量
    NSLock *_locker;
//    Boolean _httpRequesting;         // 是否正在http下载  防止崩溃
    NSUInteger _currentPort;
    
    NSString *_currPlaylist;
    NSURL *_lastRequestUrl;
    
    StunClient *_stunClient;
    NatType _natType;
}

@end

static SWCP2pEngine *_instance = nil;

@implementation SWCP2pEngine

#pragma mark - **************** public methods

+ (instancetype)sharedInstance {
    
    static dispatch_once_t onceToken = 0;
    dispatch_once(&onceToken, ^{
        _instance = [[self alloc] init];
    });
    return _instance;
    
}

- (void)startWithToken:(NSString *)token andP2pConfig:(nullable SWCP2pConfig *)config {
    self->_isvalid = YES;
    if (!config) {
        self.p2pConfig = [SWCP2pConfig defaultConfiguration];
    } else {
        self.p2pConfig = config;
    }
    
    [self p_initLogLevel];
    
    self->_token = token;
    if (!self->_token || token.length == 0) {
        CBError(@"Token is invalid");
        self->_isvalid = NO;
    } else if (self->_token.length > 20) {
        CBError(@"Token length is too long");
        self->_isvalid = NO;
    }
    if (self->_p2pConfig.tag.length > 20) {
        CBError(@"Tag length is too long");
        self->_isvalid = NO;
    }
    if (self->_p2pConfig.localPortHls > 65535 || self->_p2pConfig.localPortMp4 > 65535) {
        CBError(@"Port is invalid");
        self->_isvalid = NO;
    }

    
    self->_locker = [[NSLock alloc] init];
    
    
    self->_stunClient = [[StunClient alloc] initWithLocalPort:UDP_SEND_PORT];
    self->_natType = NatTypeUnknown;
    
    [self p_initInternal];
    
    
}

+ (id)allocWithZone:(struct _NSZone *)zone{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
//        NSLog(@"allocWithZone");
        _instance = [super allocWithZone:zone];
    });
    return _instance;
}

- (nonnull id)copyWithZone:(nullable NSZone *)zone {
    return _instance;
}

- (nonnull id)mutableCopyWithZone:(nullable NSZone *)zone {
    return _instance;
}

- (NSURL *)parseStreamURL:(NSURL *)url {
    return [self parseStreamURL:url withVideoId:url.absoluteString];
}

- (NSURL *)parseStreamURL:(NSURL *)url withVideoId:(NSString *)videoId {
    _originalURL = url;
    [self restartP2p];
    if (!_isvalid) return url;
    if (url.isFileURL || url.absoluteString.length == 0) return url;               // Whether the scheme is file:
    // 如果p2p关闭，返回原始url
    if (!_p2pConfig.p2pEnabled) {
        CBWarn(@"p2p is disabled");
        return url;
    }
    NSString *contentId = url.absoluteString;
    if (videoId) {
        contentId = videoId;
    }
    NSString *relativePath = url.relativePath;
    NSString *localUrlStr = url.absoluteString;
    if ([relativePath hasSuffix:@".m3u8"]) {
        localUrlStr = [SWCM3u8Proxy.sharedInstance getProxyUrl:url withVideoId:contentId];
        _currentProxy = SWCM3u8Proxy.sharedInstance;
    } else if ([relativePath hasSuffix:@".mp4"]) {
        localUrlStr = [SWCMp4Proxy.sharedInstance getProxyUrl:url withVideoId:contentId];
        _currentProxy = SWCMp4Proxy.sharedInstance;
    }
    // 设置代理
    _currentProxy.delegate = self;
    CBDebug(@"local url: %@ videoId: %@", localUrlStr, _videoId);
    NSURL *localUrl = [NSURL URLWithString:localUrlStr];
    return localUrl;
}

- (void)restartP2p {
    if (!_currentProxy) return;
    [_currentProxy restartP2p];
}

+ (NSString *)dcVersion {
    return [SWCDataChannel dcVersion];
}

+ (NSString *)engineVersion {
    return VERSION;
}

- (void)shutdown {
    [self stopP2p];
    [SWCM3u8Proxy.sharedInstance shutdown];
    [SWCMp4Proxy.sharedInstance shutdown];
}

- (void)stopP2p {
    if (!_currentProxy) return;
    CBInfo(@"engine stop p2p");
    [_currentProxy stopP2p];
}

- (void)setSegmentIdForHls:(SegmentId)segmentIdForHls {
    [SWCHlsSegment setSegmentId:segmentIdForHls];
}

- (NSString *)peerId {
    if (!_currentProxy) return nil;
    return _currentProxy.getPeerId;
}

- (BOOL)isConnected {
    if (!_currentProxy) return NO;
    return _currentProxy.isConnected;
}


#pragma mark - **************** private methods

- (void)p_initInternal {
    [SWCM3u8Proxy.sharedInstance initWithTkoen:_token config:_p2pConfig];
    [SWCMp4Proxy.sharedInstance initWithTkoen:_token config:_p2pConfig];
    
    NSLog(@"start Local Server");
    [self p_startLocalServer];
    
    // 启动3秒后开始NAT探测
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3 * NSEC_PER_SEC)), dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
        if (!self) return;
        [self p_queryNatRepeatly];
    });
}

- (void)p_startLocalServer {
    [SWCM3u8Proxy.sharedInstance startLocalServer];
    [SWCMp4Proxy.sharedInstance startLocalServer];
}

- (void)p_initLogLevel {
    DDLogLevel level;
    switch (_p2pConfig.logLevel) {
        case SWCLogLevelNone:
            level = DDLogLevelOff;
            break;
        case SWCLogLevelDebug:
            level = DDLogLevelAll;
            break;
        case SWCLogLevelInfo:
            level = DDLogLevelInfo;
            break;
        case SWCLogLevelWarn:
            level = DDLogLevelWarning;
            break;
        case SWCLogLevelError:
            level = DDLogLevelError;
            break;
        default:
            level = DDLogLevelWarning;
            break;
    }
    [CBLogger ddSetLogLevel:level];
    [[CBLogger shareManager] start];
}

// NAT探测
- (void)p_queryNatRepeatly {
    //    CBInfo(@"_correntLoadedSN %ld _endSN %ld", _correntLoadedSN, _endSN);
//    __weak typeof(self) _self = self;
    double checkDelay = 20*60;             // 每20分钟探测一次
    
//    CBInfo(@"Nat type: %@ Public IP: %@", NatTypeDescription[_natType], result.addr.ip);
//    CBInfo(@"Nat type: %@", NatTypeDescription[_natType]);
    
    [[CBTimerManager sharedInstance] scheduledDispatchTimerWithName:ENGINE_NAT_QUERY
           timeInterval:checkDelay
           queue:nil
           repeats:YES
           fireInstantly:YES
           action:^{
              NSString *localIp = [NATUtils getIPAddress:YES];
              CBInfo(@"local ip: %@", localIp);
              StunResult *result = [self->_stunClient queryWithLocalIp:localIp];
              self->_natType = result.natType;
              SWCM3u8Proxy.sharedInstance.natTypeString = NatTypeDescription[result.natType];
              SWCMp4Proxy.sharedInstance.natTypeString = NatTypeDescription[result.natType];
           }];
}

#pragma mark - **************** SWCProxyDelegate

- (NSTimeInterval)bufferedDuration {
    if ([self->_delegate respondsToSelector:@selector(bufferedDuration)]) {
        return [self->_delegate bufferedDuration];
    }
    return -1;
}

@end
