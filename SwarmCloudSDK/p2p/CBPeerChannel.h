//
//  CBSimpleChannel.h
//  WebRTC
//
//  Created by Timmy on 2019/5/7.
//  Copyright © 2019 cdnbye. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <WebRTC/RTCSessionDescription.h>
#import <WebRTC/RTCDataChannel.h>
#import <WebRTC/RTCDataChannelConfiguration.h>
#import <WebRTC/RTCPeerConnection.h>
#import <WebRTC/RTCIceCandidate.h>
#import <WebRTC/RTCPeerConnectionFactory.h>
#import <WebRTC/RTCMediaConstraints.h>
#import "SWCP2pConfig.h"

//NS_ASSUME_NONNULL_BEGIN

@class CBPeerChannel;

@protocol CBSimpleChannelDelegate <NSObject>

/** 产生了信令信息，通过ws发送出去 */
- (void)simpleChannel:(CBPeerChannel *)simpleChannel didHaveSignal:(NSDictionary *)dict;

/** datachannel开启 */
- (void)simpleChannelDidOpen:(CBPeerChannel *)simpleChannel;

/** datachannelf关闭 */
- (void)simpleChannelDidClose:(CBPeerChannel *)simpleChannel;

/** datachannelf连接失败 */
- (void)simpleChannelDidFail:(CBPeerChannel *)simpleChannel;

@optional
/** The simple channel successfully received a binary buffer. */
- (void)simpleChannel:(CBPeerChannel *)simpleChannel
didReceiveBinaryMessage:(NSData *)data;

/** The simple channel successfully received a JSON. */
- (void)simpleChannel:(CBPeerChannel *)simpleChannel
didReceiveJSONMessage:(NSDictionary *)dict;

@end

@interface CBPeerChannel : NSObject

@property (assign, nonatomic) BOOL isInitiator;

@property (assign, nonatomic) BOOL connected;

@property (copy, nonatomic) NSString *channelId;

@property (nonatomic,weak) id<CBSimpleChannelDelegate> delegate;

// 实例化方法
- (instancetype)initWithIsInitiator:(BOOL)isInitiator channelId:(NSString *)channelId factory:(RTCPeerConnectionFactory *)factory andConfiguration:(SWCP2pConfig *)configuration;

// 关闭
- (void)close;

// 接收远端节点的信令信息
- (void)receiveSignal:(NSDictionary *)dataDic;

// 接收远端节点发了ICE候选，（即经过ICEServer而获取到的地址）
- (void)receiveICECandidate:(NSDictionary *)dataDic;

// 接收远端节点发了Offer
- (void)receiveRemoteOffer:(NSString *)sdp;

// 接收远端节点发了Offer
- (void)receiveRemoteAnswer:(NSString *)sdp;

// 发送JSON数据
- (BOOL)sendJSONMessage:(NSDictionary *)dict;

// 发送w二进制数据
- (BOOL)sendBinaryMessage:(NSData *)data;

// 获取统计信息



@end

//NS_ASSUME_NONNULL_END
