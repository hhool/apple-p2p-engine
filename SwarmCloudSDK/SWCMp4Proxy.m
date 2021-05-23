//
//  SWCMp4Proxy.m
//  SwarmCloudSDK
//
//  Created by Timmy on 2021/5/6.
//  Copyright © 2021 cdnbye. All rights reserved.
//

#import "SWCMp4Proxy.h"
#import "SWCP2pConfig.h"
#import <GCDWebServer.h>
#import "CBLogger.h"

static SWCMp4Proxy *_instance = nil;

@interface SWCMp4Proxy()
{
    
}
@end

@implementation SWCMp4Proxy

- (void)initWithTkoen:(NSString *)token config:(SWCP2pConfig *)config
{
    _config = config;
    _token = token;
    self->_locker = [[NSLock alloc] init];
}

+ (instancetype)sharedInstance {
    
    static dispatch_once_t onceToken = 0;
    dispatch_once(&onceToken, ^{
        _instance = [[self alloc] init];
    });
    return _instance;
    
}

- (void)startLocalServer {
    // 启动本地服务器
    if (_webServer && _webServer.isRunning) return;
    _currentPort = _config.localPortMp4;
    if (_currentPort < 0) return;
    
    _webServer = [[GCDWebServer alloc] init];
    [GCDWebServer setLogLevel:3];   // WARN
    
    
    [_webServer startWithPort:_currentPort bonjourName:nil];
    _currentPort = _webServer.port;
    CBInfo(@"Mp4 listening Port: %@", @(_currentPort));
}

- (void)shutdown {
    [self stopP2p];
    if (_webServer && _webServer.isRunning) {
        [_webServer stop];
    }
}

- (void)stopP2p {
    CBInfo(@"mp4 proxy stop p2p");
}

- (void)restartP2p {
    CBInfo(@"mp4 proxy restart p2p");
}

- (NSString *)getMediaType {
    return @"mp4";
}

- (BOOL)isConnected {
    return NO;
}

- (NSString *)getPeerId {
    return nil;
}

- (NSString *)getProxyUrl:(NSURL *)url withVideoId:(NSString *)videoId {
    if (_currentPort < 0) {
        CBWarn(@"Port < 0, fallback to original url");
        return [url absoluteString];
    }
    return nil;
}

@end
