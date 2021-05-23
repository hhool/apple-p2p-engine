//
//  SWCSignalClient.m
//  SwarmCloudSDK
//
//  Created by Timmy on 2021/5/8.
//  Copyright © 2021 cdnbye. All rights reserved.
//

#import "SWCSignalClient.h"
#import "SWCUtils.h"
#import "CBLogger.h"
#import "CBTimerManager.h"

#define dispatch_main_async_safe(block)\
if ([NSThread isMainThread]) {\
block();\
} else {\
dispatch_async(dispatch_get_main_queue(), block);\
}

NSString * const kWebSocketDidOpenNote           = @"kWebSocketDidOpenNote";
NSString * const kWebSocketDidCloseNote          = @"kWebSocketDidCloseNote";
NSString * const kWebSocketDidFailNote           = @"kWebSocketDidFailNote";
NSString * const kWebSocketdidReceiveMessageNote = @"kWebSocketdidReceiveMessageNote";

static NSString * const SIGNAL_HEARTBEAT = @"SIGNAL_HEARTBEAT";
static NSString * const SIGNAL_RECONNECT = @"SIGNAL_RECONNECT";

@interface SWCSignalClient()<SRWebSocketDelegate>
{
    NSTimeInterval _reConnectTime;
//    dispatch_queue_t _concurrentQueue;
}

@property (nonatomic,strong) SRWebSocket *socket;

@property (nonatomic,copy) NSString *urlString;

@property (nonatomic,strong) NSNumber *serverVersion;


@end


@implementation SWCSignalClient

+ (SWCSignalClient *)sharedInstance{
    static SWCSignalClient *Instance = nil;
    static dispatch_once_t predicate;
    dispatch_once(&predicate, ^{
        Instance = [[SWCSignalClient alloc] init];
    });
    return Instance;
}

#pragma mark - **************** public methods
- (void)openWithUrl:(NSString *)urlString reset:(BOOL)reset{
    
    //如果是同一个url return
    if (self.socket) {
        return;
    }
    
    if (reset) {
        _reConnectTime = 0;
        [self destoryReconnect];
    }
    
//    _concurrentQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0);
    self.urlString = urlString;
    
    self.socket = [[SRWebSocket alloc] initWithURLRequest:
                   [NSURLRequest requestWithURL:[NSURL URLWithString:self.urlString]]];
    
    CBInfo(@"open websocket url：%@",self.socket.url.absoluteString);
    
    //SRWebSocketDelegate 协议
    self.socket.delegate = self;
    
    //开始连接
    [self.socket open];
}

- (void)reconnectImmediately {
    if (!self.urlString || self.socketReadyState == SR_OPEN) return;
    CBInfo(@"reconnect websocket");
    [self openWithUrl:self.urlString reset:NO];
}

// 关闭
- (void)close {
    if (self.socket){
        CBInfo(@"close websocket");
        [self.socket close];
//        CBInfo(@"close signaler");
        self.socket = nil;
        //断开连接时销毁心跳
        [self destoryHeartBeat];
        [self destoryReconnect];
    }
}

#define WeakSelf(ws) __weak __typeof(&*self)weakSelf = self
- (void)sendData:(id)data {
//    NSLog(@"socketSendData --------------- %@",data);
    
    WeakSelf(ws);
    dispatch_queue_t queue =  dispatch_queue_create("cb", NULL);      // 串行
    
    dispatch_async(queue, ^{
        if (weakSelf.socket != nil) {
            // 只有 SR_OPEN 开启状态才能调 send 方法啊，不然要崩
            if (weakSelf.socket.readyState == SR_OPEN) {
                [weakSelf.socket send:data];    // 发送数据
                
            } else if (weakSelf.socket.readyState == SR_CONNECTING) {
//                NSLog(@"正在连接中，重连后其他方法会去自动同步数据");
                // 每隔2秒检测一次 socket.readyState 状态，检测 10 次左右
                // 只要有一次状态是 SR_OPEN 的就调用 [ws.socket send:data] 发送数据
                // 如果 10 次都还是没连上的，那这个发送请求就丢失了，这种情况是服务器的问题了，小概率的
                // 代码有点长，我就写个逻辑在这里好了
                [self reConnect];
                
            } else if (weakSelf.socket.readyState == SR_CLOSING || weakSelf.socket.readyState == SR_CLOSED) {
                // websocket 断开了，调用 reConnect 方法重连
                [self reConnect];
            }
        } else {
            CBWarn(@"no network，ws send failed");
        }
    });
}

// 发送信令
- (void)sendSignal:(NSDictionary*)signalData remotePeerId:(NSString*)_id {
    
    NSDictionary *dict = @{@"action": @"signal", @"to_peer_id": _id, @"data": signalData};
    NSString *jsonString = [SWCUtils convertToJSONData:dict];
//    NSLog(@"socketSendSignal --------------- %@",jsonString);
    [self sendData:jsonString];
}

// 拒绝信令
- (void)sendRejectToRemotePeerId:(NSString*)_id reason:(NSString *)reason {
    
    NSDictionary *dict = @{@"action": @"signal", @"to_peer_id": _id};
    NSString *jsonString = [SWCUtils convertToJSONData:dict];
    if (reason) {
        [dict setValue:reason forKey:@"reason"];
    }
//    NSLog(@"socketSendRejected --------------- %@",jsonString);
    [self sendData:jsonString];
}

#pragma mark - **************** private mothodes
//重连机制
- (void)reConnect {
    [self close];
    
    //超过5分钟就不再重连
    if (_reConnectTime > 300) {
        //您的网络状况不是很好，请检查网络后重试
        return;
    }
    
    CBInfo(@"_reConnectTime %@", @(_reConnectTime));
    if (_reConnectTime == 0) {
        int max = 45, min = 15;
        _reConnectTime = arc4random()%max + min;
    } else {
        _reConnectTime *= 1.3;
    }
    
    CBInfo(@"signaler will reconnect after %@", @(_reConnectTime));
//    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(_reConnectTime * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
//        self.socket = nil;
//        [self openWithPeerId:self.peerId andConfig:self->_p2pConfig reset:NO];
//        CBInfo(@"signaler reconnect");
//    });
    
    [[CBTimerManager sharedInstance] scheduledDispatchTimerWithName:SIGNAL_RECONNECT
     timeInterval:_reConnectTime
            queue:nil
            repeats:NO
            fireInstantly:NO
            action:^{
               self.socket = nil;
               CBInfo(@"signaler reconnect");
        [self openWithUrl:self.urlString reset:NO];
            }];
    
}


// 取消心跳
- (void)destoryHeartBeat {
    [[CBTimerManager sharedInstance] cancelTimerWithName:SIGNAL_HEARTBEAT];
}

// 取消重连
- (void)destoryReconnect {
    [[CBTimerManager sharedInstance] cancelTimerWithName:SIGNAL_RECONNECT];
}

//初始化心跳
- (void)initHeartBeat {
    dispatch_main_async_safe(^{
        [self destoryHeartBeat];
        //心跳设置为1分钟，NAT超时一般为5分钟
//        self->_heartBeat = [NSTimer timerWithTimeInterval:1*60 target:self selector:@selector(ping) userInfo:nil repeats:YES];
        //和服务端约定好发送什么作为心跳标识，尽可能的减小心跳包大小
//        [[NSRunLoop currentRunLoop] addTimer:self->_heartBeat forMode:NSRunLoopCommonModes];
        
        __weak typeof(self) weakSelf = self;
        [[CBTimerManager sharedInstance] scheduledDispatchTimerWithName:SIGNAL_HEARTBEAT
                                                           timeInterval:1*270
                                                                  queue:nil
                                                                repeats:YES
                                                          fireInstantly:NO
                                                                 action:^{
                                                                     [weakSelf ping];
                                                                 }];
    })
}

//pingPong
- (void)ping {
    if (self.socket.readyState == SR_OPEN) {
        CBInfo(@"signal ping");
        [self.socket sendPing:nil];
    }
}

#pragma mark - **************** SRWebSocketDelegate
- (void)webSocketDidOpen:(SRWebSocket *)webSocket {
    //每次正常连接的时候清零重连时间
    _reConnectTime = 0;
    //开启心跳
    [self initHeartBeat];
    if (webSocket == self.socket) {
        CBInfo(@"signaler connection open");
        [[NSNotificationCenter defaultCenter] postNotificationName:kWebSocketDidOpenNote object:nil];
    }
}

- (void)webSocket:(SRWebSocket *)webSocket didFailWithError:(NSError *)error {
    if (webSocket == self.socket) {
        CBWarn(@"signaler connection failed");
        _socket = nil;
        //连接失败就重连
        [self reConnect];
        [[NSNotificationCenter defaultCenter] postNotificationName:kWebSocketDidFailNote object:nil];
    }
}

- (void)webSocket:(SRWebSocket *)webSocket didCloseWithCode:(NSInteger)code reason:(NSString *)reason wasClean:(BOOL)wasClean {
    if (webSocket == self.socket) {
        CBWarn(@"signaler connection closed，code:%ld,reason:%@,wasClean:%d",(long)code,reason,wasClean);
        [self close];
        [[NSNotificationCenter defaultCenter] postNotificationName:kWebSocketDidCloseNote object:nil];
        
        if (code != 1000) {
            [self reConnect];
        }
    }
}

/*
 该函数是接收服务器发送的pong消息，其中最后一个是接受pong消息的，
 在这里就要提一下心跳包，一般情况下建立长连接都会建立一个心跳包，
 用于每隔一段时间通知一次服务端，客户端还是在线，这个心跳包其实就是一个ping消息，
 我的理解就是建立一个定时器，每隔十秒或者十五秒向服务端发送一个ping消息，这个消息可是是空的
 */
- (void)webSocket:(SRWebSocket *)webSocket didReceivePong:(NSData *)pongPayload {
//    NSString *reply = [[NSString alloc] initWithData:pongPayload encoding:NSUTF8StringEncoding];
//    CBVerbose(@"signal server reply%@",reply);
}

- (void)webSocket:(SRWebSocket *)webSocket didReceiveMessage:(id)message  {
    
    if (webSocket != self.socket) return;
//        CBDebug(@"************************** socket收到数据了************************** ");
//        CBVerbose(@"message:%@", message);
    NSString *jsonStr;
    if ([message respondsToSelector: @selector(bytes)]) {       // 如果是二进制数据
        
    } else{
        jsonStr = message;
        CBDebug(@"signaler received string %@", jsonStr);
    }
    
    NSData *jsonData = [jsonStr dataUsingEncoding:NSUTF8StringEncoding];
    NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:jsonData options:NSJSONReadingAllowFragments error:nil];
    NSString *action = [dict objectForKey:@"action"];
    if (!action) return;
    if ([action isEqualToString:@"ver"]) {
        self.serverVersion = (NSNumber *)[dict objectForKey:@"ver"];
        return;
    }
    if ([action isEqualToString:@"close"]) {
        CBWarn(@"server close signaler reason %@", [dict objectForKey:@"reason"]);
        [self close];
        return;
    }
    [[NSNotificationCenter defaultCenter] postNotificationName:kWebSocketdidReceiveMessageNote object:dict];
}

#pragma mark - **************** setter getter
- (SRReadyState)socketReadyState {
    return self.socket.readyState;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end
