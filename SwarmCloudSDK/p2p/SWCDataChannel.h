//
//  SWCDataChannel.h
//  SwarmCloudSDK
//
//  Created by Timmy on 2021/5/9.
//  Copyright © 2021 cdnbye. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <WebRTC/RTCPeerConnectionFactory.h>
#import "SWCP2pConfig.h"
#import "SWCNetworkResponse.h"
#import "SWCPlaylistInfo.h"

@class SWCDataChannel;

NS_ASSUME_NONNULL_BEGIN

@protocol SWCDataChannelDelegate <NSObject>

@optional
/** 产生了信令信息，通过ws发送出去 */
- (void)dataChannel:(SWCDataChannel *)peer didHaveSignal:(NSDictionary *)dict;

/** datachannel开启 */
- (void)dataChannelDidOpen:(SWCDataChannel *)peer;

/** datachannelf关闭 */
- (void)dataChannelDidClose:(SWCDataChannel *)peer;

/** datachannelf连接失败 */
- (void)dataChannelDidFail:(SWCDataChannel *)peer fatal:(BOOL)fatal;

/** bitfield */
- (void)dataChannel:(SWCDataChannel *)peer didReceiveBitField:(NSArray *)field;

/** request */
- (void)dataChannel:(SWCDataChannel *)peer didReceiveRequestWithSegId:(nullable NSString *)segId SN:(nullable NSNumber *)sn andUrgent:(BOOL)urgent;

/** have */
- (void)dataChannel:(SWCDataChannel *)peer didReceiveHaveSN:(NSNumber *)sn andSegId:(NSString *)segId;

/** lost */
- (void)dataChannel:(SWCDataChannel *)peer didReceiveLostSN:(NSNumber *)sn andSegId:(NSString *)segId;

/** piece_ack */
- (void)dataChannel:(SWCDataChannel *)peer didReceivePieceAckWithSegId:(NSString *)segId SN:(NSNumber *)sn andSize:(NSNumber *)size;

/** piece_not_found  接收到critical未找到的响应 */
- (void)dataChannel:(SWCDataChannel *)peer didReceivePieceNotFoundWithSegId:(NSString *)segId SN:(NSNumber *)sn;

/** response 接收到piece头信息 */
- (void)dataChannel:(SWCDataChannel *)peer didReceivePieceWithSegId:(NSString *)segId SN:(NSNumber *)sn;

/** response 接收到完整二进制数据 */
- (void)dataChannel:(SWCDataChannel *)peer didReceiveResponseWithSN:(NSNumber *)sn segId:(NSString *)segId andData:(NSData *)data;

/** response 下载二进制数据发生错误 */
- (void)dataChannel:(SWCDataChannel *)peer didDownloadPieceErrorWithSN:(NSNumber *)sn segId:(NSString *)segId;

/** 接受节点请求 */
- (void)dataChannelDidReceiveGetPeersRequest:(SWCDataChannel *)peer;

/** 收到节点 */
- (void)dataChannel:(SWCDataChannel *)peer didReceivePeers:(NSArray *)peers;

/** 收到信令 */
- (void)dataChannel:(SWCDataChannel *)peer didReceivePeerSignalWithAction:(NSString *)action toPeerId:(NSString *)toPeerId fromPeerId:(NSString *)fromPeerId data:(NSDictionary *)data reason:(NSString *)reason;

@end

@interface SWCDataChannel : NSObject

@property(nonatomic, copy, readonly, class) NSString *dcVersion;

@property (nonatomic,weak) id<SWCDataChannelDelegate> delegate;           // 打开、关闭、失败、peer_signal、peers、getpeers的代理

@property (nonatomic,weak) id<SWCDataChannelDelegate> msgDelegate;        // 接收消息的代理

@property (assign, nonatomic) BOOL connected;

@property (copy, nonatomic, readonly) NSString *channelId;

@property (copy, nonatomic, readonly) NSString *remotePeerId;

@property (assign, nonatomic) BOOL isInitiator;

@property (copy, nonatomic, readonly) NSString *platform;

@property (assign, nonatomic, readonly) BOOL mobile;

@property (assign, nonatomic, readonly) BOOL uploading;

@property (assign, nonatomic, readonly) BOOL downloading;

@property (assign, nonatomic, readonly) BOOL choked;

@property(nonatomic, assign, readonly) int peersConnected;

@property (nonatomic, assign, readonly) NSUInteger currentBufSN;

@property (nonatomic, copy, readonly) NSString *currentBufSegId;

@property (nonatomic, assign, readonly) NSUInteger currentBufArrSize;

@property (nonatomic, assign, readonly) long weight;

@property (nonatomic, assign, readonly) CFAbsoluteTime dataExchangeTs;

@property(nonatomic, assign, readonly) NSUInteger liveEdgeSN;

@property(nonatomic, assign, readonly) NSUInteger continuousHits;

@property (copy, nonatomic, readonly) NSString *intermediator;

- (instancetype)initWithPeerId:(NSString *)peerId remotePeerId:(NSString *)remotePeerId isInitiator:(BOOL)isInitiator factory:(RTCPeerConnectionFactory *)factory andConfig:(SWCP2pConfig *)config isLive:(BOOL)live sequential:(BOOL)sequential channal:(NSString *)channel;

- (instancetype)initWithPeerId:(NSString *)peerId remotePeerId:(NSString *)remotePeerId isInitiator:(BOOL)isInitiator factory:(RTCPeerConnectionFactory *)factory andConfig:(SWCP2pConfig *)config isLive:(BOOL)live sequential:(BOOL)sequential channal:(NSString *)channel intermediator:(NSString *_Nullable)intermediator;

- (BOOL)isAvailable;

//- (void)sendJSON:(NSDictionary *)dict;
//
//- (void)sendBinaryData:(NSData *)data;

- (void)close;

- (NSComparisonResult)compareByWeight:(SWCDataChannel *)peer;

// 接收远端节点的信令信息
- (void)receiveSignal:(NSDictionary *)dataDic;

// 初始化bitfield
- (void)initBitField:(NSArray *)field;

// add sn
- (void)bitFieldAddSN:(NSNumber *)sn;

- (void)bitFieldAddSegId:(NSString *)segId;

- (BOOL)bitFieldHasSegId:(NSString *)segId;

// remove sn
- (void)bitFieldRemoveSN:(NSNumber *)sn;

- (void)bitFieldRemoveSegId:(NSString *)segId;

// has sn
- (BOOL)bitFieldHasSN:(NSNumber *)sn;

- (SWCPlaylistInfo *)getLatestPlaylistWithUrl:(NSString *)url lastTs:(NSNumber *)lastTs;

// 发送bitfield
- (void)sendMetaData:(NSMutableSet *)field sequential:(BOOL)sequential peersNum:(NSUInteger)num;

// 发送GetPeers请求
- (void)sendMsgGetPeers;

// 发送Peers
- (void)sendMsgPeers:(NSArray *)peers;

// 发送have
- (void)sendMsgHave:(NSNumber *)sn segId:(NSString *)segId;

// 发送lost
- (void)sendMsgLost:(NSNumber *)sn segId:(NSString *)segId;

// 发送DC_PIECE_NOT_FOUND
- (void)sendPieceNotFound:(NSNumber *)sn andSegId:(NSString *)segId;

// 发送buffer
- (void)sendBuffer:(NSData *)buffer segId:(NSString *)segId SN:(NSNumber *)sn;

// 发送request
- (void)sendRequestSegmentById:(NSString *)segId SN:(NSNumber *)sn isUrgent:(BOOL)urgent;

// 发送request
- (void)sendRequestSegmentBySN:(NSNumber *)sn isUrgent:(BOOL)urgent;

// 发送close
- (void)sendMsgClose;

// 发送choke
- (void)sendMsgChoke;

// 发送unchoke
- (void)sendMsgUnchoke;

// 发送订阅请求
- (void)sendMsgSubscribe;

// 发送取消订阅请求
- (void)sendMsgUnsubscribe;

// 发送拒绝订阅
- (void)sendMsgSubscribeReject:(NSString *)reason;

// 发送允许订阅
- (void)sendMsgSubscribeAccept:(int)level;

// 发送订阅层级
- (void)sendMsgSubscribeLevel:(int)level;

// 发送信令信息
- (BOOL)sendMsgSignalToPeerId:(NSString *)toPeerId fromPeerId:(NSString *)fromPeerId data:(NSDictionary *_Nullable)data;

// 发送拒绝信令
- (BOOL)sendMsgSignalRejectToPeerId:(NSString *)toPeerId fromPeerId:(NSString *)fromPeerId reason:(NSString *)reason;

// 发送playlist
- (void)sendMsgPlaylistWithUrl:(NSString *)url text:(NSString *)text;

// sync方式请求segment
- (SWCNetworkResponse *)loadSegmentSyncFromPeerById:(NSString *)segId SN:(NSNumber *)sn timeout:(NSTimeInterval)timeout;

// 检查是否需要阻塞节点
- (void)checkIfNeedChoke;

// 发送统计信息
- (void)sendMsgStats:(NSNumber *)totalConns;

// 获取p2p下载部分的二进制数据
- (NSData *)getLoadedBuffer;

- (void)shareOnly;

- (NSMutableSet *)getBitMap;

@end

NS_ASSUME_NONNULL_END
