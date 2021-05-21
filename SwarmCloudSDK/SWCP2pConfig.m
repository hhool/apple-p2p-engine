//
//  SWCP2pConfig.m
//  SwarmCloudSDK
//
//  Created by Timmy on 2021/5/5.
//  Copyright © 2021 cdnbye. All rights reserved.
//

#import "SWCP2pConfig.h"
#import <WebRTC/RTCIceServer.h>

static NSString *const RTCSTUNServerURL1 = @"stun:stun.l.google.com:19302";
static NSString *const RTCSTUNServerURL2 = @"stun:global.stun.twilio.com:3478?transport=udp";

static NSString *const ANNOUNCE = @"https://tracker.cdnbye.com/v1";

@interface SWCP2pConfig()
{
//    @package
}
@end

@implementation SWCP2pConfig

+ (instancetype)defaultConfiguration {
    return [[SWCP2pConfig alloc] init];
}

- (instancetype)init {
    if(self = [super init])
    {
        [self initDefaultConfig];
    }
    return self;
}

- (void)initDefaultConfig {

    self.webRTCConfig = [[RTCConfiguration alloc] init];
    
    self.trickleICE = YES;
    
    self.webRTCConfig.iceServers = [self defaultSTUNServer];
        
    self.announce = ANNOUNCE;
    
    self.p2pEnabled = YES;
    
    self.wifiOnly = NO;
    
    self.localPortHls = 0;
    
    self.localPortMp4 = 0;
    
    self.dcDownloadTimeout = 15.0;
    
    self.diskCacheLimit = 1024*1024*1024;
    
    self.memoryCacheLimit = 100*1024*1024;
    
    self.downloadTimeout = 10.0;
        
    self.logLevel = SWCLogLevelWarn;
    
    self.maxPeerConnections = 12;
    
    self.useHttpRange = YES;
    
    self.signalCompressed = NO;
    
    self.httpLoadTime = 2.0;
    
    self.pieceLengthForMp4 = 512*1024;
    
    self.maxSubscribeLevel = 3;
    
}

// 初始化STUN Server （ICE Server）
- (NSMutableArray *)defaultSTUNServer{
    NSMutableArray *ICEServers = [NSMutableArray array];
    RTCIceServer *servers = [[RTCIceServer alloc] initWithURLStrings:@[RTCSTUNServerURL1, RTCSTUNServerURL2]];
     [ICEServers addObject:servers];
    return ICEServers;
    
}

@end
