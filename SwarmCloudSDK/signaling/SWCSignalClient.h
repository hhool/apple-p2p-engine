//
//  SWCSignalClient.h
//  SwarmCloudSDK
//
//  Created by Timmy on 2021/5/8.
//  Copyright © 2021 cdnbye. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <SocketRocket.h>
#import "SWCP2pConfig.h"

NS_ASSUME_NONNULL_BEGIN

extern NSString * const kWebSocketDidFailNote;
extern NSString * const kWebSocketDidOpenNote;
extern NSString * const kWebSocketDidCloseNote;
extern NSString * const kWebSocketdidReceiveMessageNote;

@interface SWCSignalClient : NSObject

/** 获取连接状态 */
@property (nonatomic,assign,readonly) SRReadyState socketReadyState;

/** 开始连接 */
- (void)openWithUrl:(NSString *)urlString reset:(BOOL)reset;

/** 关闭连接 */
- (void)close;

/** 发送信令 */
- (void)sendSignal:(NSDictionary*)signalData remotePeerId:(NSString*)_id;

/** 拒绝信令 */
- (void)sendRejectToRemotePeerId:(NSString*)_id reason:(NSString *)reason;

- (void)reconnectImmediately;

+ (SWCSignalClient *)sharedInstance;

@end

NS_ASSUME_NONNULL_END
