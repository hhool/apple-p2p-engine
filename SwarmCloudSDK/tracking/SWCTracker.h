//
//  SWCTracker.h
//  SwarmCloudSDK
//
//  Created by Timmy on 2021/5/9.
//  Copyright © 2021 cdnbye. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SWCP2pConfig.h"
#import "SWCScheduler.h"

NS_ASSUME_NONNULL_BEGIN

@interface SWCTracker : NSObject

@property (nonatomic, copy) NSString *peerId;

@property (nonatomic, assign) NSTimeInterval reportInterval;

@property (nonatomic, copy) NSString *vcode;

@property (nonatomic, copy, readonly) NSString *token;

@property (assign, nonatomic) BOOL connected;   // 信令和tracker是否已连接

@property (nonatomic, strong) SWCScheduler *scheduler;

// 初始化方法
- (instancetype)initWithToken:(NSString *)token BaseUrl:(NSString *)url channel:(NSString *)channel isLive:(BOOL)live endSN:(NSUInteger)endSN nat:(NSString*)natType mediaType:(SWCMediaType)mediaType multiBitrate:(BOOL)multiBitrate andConfig:(SWCP2pConfig *)config;

- (void)channelRequest;

- (void)peersRequest;

- (void)stopP2p;                   // 停止P2P

- (void)resumeP2P;                 // 重启P2P

@end

NS_ASSUME_NONNULL_END
