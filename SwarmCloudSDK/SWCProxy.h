//
//  SWCProxy.h
//  SwarmCloudSDK
//
//  Created by Timmy on 2021/5/6.
//  Copyright © 2021 cdnbye. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SWCP2pConfig.h"
#import "GCDWebServer.h"
#import "SWCTracker.h"

NS_ASSUME_NONNULL_BEGIN

@protocol SWCProxyDelegate <NSObject>
    
@optional

- (NSTimeInterval)bufferedDuration;

@end

@interface SWCProxy : NSObject
{
    SWCP2pConfig *_config;
    NSString *_token;
    GCDWebServer* _webServer;
    NSInteger _currentPort;
    NSURL *_originalURL;
    NSURL *_originalLocation;
    NSString *_videoId;
    SWCTracker *_tracker;
    NSURLSession *_httpSession;
}

@property(nonatomic, copy, readonly) NSString *localIp;

@property (nonatomic, copy) NSString *natTypeString;

@property (nonatomic, weak) id<SWCProxyDelegate> delegate;

- (void)initWithTkoen:(NSString *)token config:(SWCP2pConfig *)config;

- (void)startLocalServer:(NSError **)error;

- (void)shutdown;

- (void)stopP2p;

- (void)restartP2p;

- (NSString *)getMediaType;

- (BOOL)isConnected;

- (NSString *)getPeerId;

- (NSString *)getProxyUrl:(NSURL *)url withVideoId:(NSString *)videoId;

- (SWCNetworkResponse *)requestFromNetworkWithUrl:(NSURL *)url req:(GCDWebServerRequest *)request headers:(NSDictionary *)headers error:(NSError **)err;

@end

NS_ASSUME_NONNULL_END
