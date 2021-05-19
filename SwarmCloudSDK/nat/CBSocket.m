//
//  CBSocket.m
//  CDNByeKit
//
//  Created by Timmy on 2020/1/18.
//  Copyright © 2020 cdnbye. All rights reserved.
//

#import "CBSocket.h"

static CBSocket *sharedInstance = nil;

@interface CBSocket()<GCDAsyncUdpSocketDelegate>
{
    GCDAsyncUdpSocket *_socket;
}
@end

@implementation CBSocket

+ (CBSocket *)sharedInstance {
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        
        sharedInstance = [[self alloc] init];
    });
    
    return sharedInstance;
    
}

- (BOOL)startWithLocalPort:(int)lport {
    
    dispatch_queue_t qQueue = dispatch_queue_create("Stun client queue", NULL);
    _socket = [[GCDAsyncUdpSocket alloc] initWithDelegate:self delegateQueue:qQueue];
    
    NSError *error = nil;
    [_socket bindToPort:lport error:&error];
    if (error) {
        NSLog(@"socket bind to port %d error %@", lport, error);
        return NO;
    }
    
    if (![_socket beginReceiving:&error]) {
        NSLog(@"socket failed to beginReceiving %@", error);
        return NO;
    }
    
    return YES;
}

#pragma mark - **************** public method

- (void)sendData:(NSData *)data withTimeout:(NSTimeInterval)timeout remoteEndPoint:(SocketAddress *)remote andReceiveBlock:(dataBlock)block {
    
    if (!_socket) {
        block(nil, nil);
    }
    
    self.receiveData = block;
    NSString *target;
    if (remote.host) {
        target = remote.host;
    } else {
        target = remote.ip;
    }
//    NSLog(@"socket send data length %@ to %@:%d", @(data.length), target, remote.port);
    [_socket sendData:data toHost:target port:remote.port withTimeout:-1 tag:1];
    
}

#pragma mark - **************** private method


#pragma mark - 接收到数据进行回调
//- (void)receiveData:(dataBlock)block {
//    
//    self.receiveData = block;
//}

// 关闭套接字，并销毁
-(void)cutOffSocket {
    [_socket close];
    _socket = nil;
}

#pragma mark - **************** GCDAsyncUdpSocketDelegate
// socket未连接
- (void)udpSocket:(GCDAsyncUdpSocket *)sock didNotConnect:(NSError *)error {
    NSLog(@"socket didNotConnect");
}

// socket关闭
- (void)udpSocketDidClose:(GCDAsyncUdpSocket *)sock withError:(NSError *)error {
    NSLog(@"socket DidClose");
}

// 发送消息失败回调
- (void)udpSocket:(GCDAsyncUdpSocket *)sock didNotSendDataWithTag:(long)tag dueToError:(NSError *)error {
    NSLog(@"socket didNotSendData");
}

// 收到消息回调
- (void)udpSocket:(GCDAsyncUdpSocket *)sock didReceiveData:(NSData *)data fromAddress:(NSData *)address withFilterContext:(id)filterContext {
    
    NSString *host = nil;
    uint16_t port = 0;
    [GCDAsyncUdpSocket getHost:&host port:&port fromAddress:address];
//    NSLog(@"socket didReceiveData %@ %hu", host, port);
    
    SocketAddress *addr = [[SocketAddress alloc] initWithHost:host andPort:port];
    
    if (self.receiveData != nil) {
        self.receiveData(data, addr);
        self.receiveData = nil;
    }
}

- (void)udpSocket:(GCDAsyncUdpSocket *)sock didSendDataWithTag:(long)tag {
//    NSLog(@"socket didSendData");
}

@end
