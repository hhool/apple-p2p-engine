//
//  CBSocket.h
//  CDNByeKit
//
//  Created by Timmy on 2020/1/18.
//  Copyright © 2020 cdnbye. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "GCDAsyncUdpSocket.h"
#import "SocketAddress.h"

typedef void (^dataBlock)( NSData  *_Nullable response, SocketAddress *_Nullable addr);

NS_ASSUME_NONNULL_BEGIN

@interface CBSocket : NSObject<GCDAsyncUdpSocketDelegate>

@property (nonatomic, strong) dataBlock _Nullable receiveData;

//- (void)receiveData:(dataBlock)block;

+ (CBSocket *)sharedInstance;   // 单例

- (BOOL)startWithLocalPort:(int)lport;

- (void)sendData:(NSData *)data withTimeout:(NSTimeInterval)timeout remoteEndPoint:(SocketAddress *)remote andReceiveBlock:(dataBlock)block;

-(void)cutOffSocket;

@end

NS_ASSUME_NONNULL_END
