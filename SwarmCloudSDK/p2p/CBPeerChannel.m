//
//  CBSimpleChannel.m
//  WebRTC
//
//  Created by Timmy on 2019/5/7.
//  Copyright © 2019 cdnbye. All rights reserved.
//

#import "CBPeerChannel.h"
#import "CBLogger.h"
#import "CBTimerManager.h"
#import "LineReader.h"


static NSString * const PEERCHANNEL_ICE_TIMMER = @"PEERCHANNEL_ICE_TIMMER";

@interface CBPeerChannel()<RTCPeerConnectionDelegate, RTCDataChannelDelegate>
{
    RTCPeerConnectionFactory *_factory;
    RTCPeerConnection *_peerConnection;
    SWCP2pConfig *_configuration;
    RTCDataChannel *_dataChannel;
    BOOL _iceComplete;

}
@end

@implementation CBPeerChannel

#pragma mark - **************** setter getter




#pragma mark - **************** public methods

- (instancetype)initWithIsInitiator:(BOOL)isInitiator channelId:(NSString *)channelId factory:(RTCPeerConnectionFactory *)factory andConfiguration:(SWCP2pConfig *)configuration {
    if(self = [super init])
    {
        _configuration = configuration;
        _factory = factory;
        self.channelId = channelId;
        
        if (isInitiator) {
            self.isInitiator = isInitiator;
            
            // 主动创建offer
            [self createOffer];
        }
    }
    return self;
}

// 关闭
- (void)close {
    [[CBTimerManager sharedInstance] cancelTimerWithName:PEERCHANNEL_ICE_TIMMER];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
        [self->_peerConnection close];
        self->_peerConnection = nil;
//        CBInfo(@"test after closePeerConnection %@",  @([NSThread isMainThread]));
        if (self->_dataChannel) {
            [self->_dataChannel close];
            self->_dataChannel = nil;
//            CBInfo(@"test after _dataChannel close");
        }
    });
//    CBInfo(@"test after closePeerConnection %@",  @([NSThread isMainThread]));
//    if (_dataChannel) {
//        [_dataChannel close];
//        _dataChannel = nil;
//        CBInfo(@"test after _dataChannel close");
//    }
    self.connected = NO;
}

- (void)receiveSignal:(NSDictionary *)dict {
    NSDictionary *candidate = [dict objectForKey:@"candidate"];
    if (candidate) {
//        CBDebug(@"receive candidate %@", candidate);
        [self receiveICECandidate:candidate];
    }
    
    else {
        NSString *type = [dict objectForKey:@"type"];
        if ([type isEqualToString: @"offer"]) {
//            CBDebug(@"receive offer %@", [dict objectForKey:@"sdp"]);
            [self receiveRemoteOffer:[dict objectForKey:@"sdp"]];
        }
        
        else if ([type isEqualToString: @"answer"]) {
//            CBDebug(@"receive answer %@", [dict objectForKey:@"sdp"]);
            [self receiveRemoteAnswer:[dict objectForKey:@"sdp"]];
        }
    }
}

// 接收远端节点发了ICE候选，（即经过ICEServer而获取到的地址）
- (void)receiveICECandidate:(NSDictionary *)dataDic {
    NSString *sdpMid = dataDic[@"sdpMid"];
    int sdpMLineIndex = [dataDic[@"sdpMLineIndex"] intValue];
    NSString *sdp = dataDic[@"candidate"];
    //生成远端网络地址对象
    RTCIceCandidate *candidate = [[RTCIceCandidate alloc] initWithSdp:sdp sdpMLineIndex:sdpMLineIndex sdpMid:sdpMid];;
    //添加到点对点连接中
    [_peerConnection addIceCandidate:candidate];
}

// 接收远端节点发了Offer
- (void)receiveRemoteOffer:(NSString *)sdp {
    //根据类型和SDP 生成SDP描述对象
    RTCSessionDescription *remoteSdp = [[RTCSessionDescription alloc] initWithType:RTCSdpTypeOffer sdp:sdp];
    
    if (_peerConnection == nil) {
        _peerConnection = [self createPeerConnection];
    }
    
    //设置给这个点对点连接
    __weak RTCPeerConnection *weakPeerConnection = _peerConnection;
    [weakPeerConnection setRemoteDescription:remoteSdp completionHandler:^(NSError * _Nullable error) {
        [self setSessionDescriptionWithPeerConnection:weakPeerConnection];
    }];
}

// 接收远端节点发了Answer
- (void)receiveRemoteAnswer:(NSString *)sdp {
    //根据类型和SDP 生成SDP描述对象
    RTCSessionDescription *remoteSdp = [[RTCSessionDescription alloc] initWithType:RTCSdpTypeAnswer sdp:sdp];
    
    if (_peerConnection == nil) {
        CBWarn(@"No _peerConnection!");
        return;
    }
    
    //设置给这个点对点连接
    __weak RTCPeerConnection * weakPeerConnection = _peerConnection;
    [weakPeerConnection setRemoteDescription:remoteSdp completionHandler:^(NSError * _Nullable error) {
        [self setSessionDescriptionWithPeerConnection:weakPeerConnection];
    }];
}

- (BOOL)sendJSONMessage:(NSDictionary *)dict {
    if (!self.connected) return NO;
    NSData* messageData = [NSJSONSerialization dataWithJSONObject:dict options:NSJSONWritingPrettyPrinted error:nil];
    
    RTCDataBuffer *buffer = [[RTCDataBuffer alloc] initWithData:messageData isBinary:NO];
//    CBInfo(@"_dataChannel sendData");
    bool success = [_dataChannel sendData:buffer];
    if (success){
//        CBInfo(@"sendmessageSuccess = %@",dict);
    }else{
        CBError(@"SendMessageFailed = %@", dict);
    }
    return success;
}

- (BOOL)sendBinaryMessage:(NSData *)data {
    if (!self.connected) return NO;
    RTCDataBuffer *buffer = [[RTCDataBuffer alloc] initWithData:data isBinary:YES];
    
    bool success = [_dataChannel sendData:buffer];
    if (success){
//        DDLogInfo(@"send binary message Success");
    }else{
        CBError(@"Send binary Message Failed");
    }
    return success;
}

#pragma mark - **************** private mothodes

- (RTCPeerConnection *)createPeerConnection {
//    CBDebug(@"webRTCConfig %@", _configuration.webRTCConfig);
    RTCPeerConnection *connection = [_factory peerConnectionWithConfiguration:_configuration.webRTCConfig constraints:[self creatPeerConnectionConstraint] delegate:self];
    
//    RTCPeerConnection *connection = [[[RTCPeerConnectionFactory alloc] init] peerConnectionWithConfiguration:_configuration.webRTCConfig constraints:[self creatPeerConnectionConstraint] delegate:self];
    
    return connection;
}

- (RTCMediaConstraints *)creatPeerConnectionConstraint
{
    RTCMediaConstraints *constraints = [[RTCMediaConstraints alloc] initWithMandatoryConstraints:@{kRTCMediaConstraintsOfferToReceiveAudio:kRTCMediaConstraintsValueFalse,kRTCMediaConstraintsOfferToReceiveVideo:kRTCMediaConstraintsValueFalse} optionalConstraints:nil];
    return constraints;
}

/**
 * 创建offer
 */
-(void)createOffer{
    CBVerbose(@"createOffer");
    if (_peerConnection == nil) {
        _peerConnection = [self createPeerConnection];
    }
//    CBInfo(@"test after self createPeerConnection");
    // DataChannel的创建是在生成本地offer之前，这样才能在生成offer后，使offer中包含DataChannel的信息。
    [self createDataChannelWithPeerConnection:_peerConnection];
//    CBInfo(@"test after createDataChannelWithPeerConnection");
    [_peerConnection offerForConstraints:[self offerOranswerConstraint] completionHandler:^(RTCSessionDescription * _Nullable sdp, NSError * _Nullable error) {
        if (error == nil) {
            
            RTCSessionDescription *filteredSdp;
            if (self->_configuration.trickleICE) {
                filteredSdp = sdp;
            } else {
                NSString *filteredDesc = [self filterSdp:sdp.sdp];
                filteredSdp = [[RTCSessionDescription alloc] initWithType:sdp.type sdp:filteredDesc];
            }
//            CBDebug(@"create sdp success type %@ \n %@", @(filteredSdp.type), filteredSdp.sdp);
            __weak RTCPeerConnection * weakPeerConnction = self->_peerConnection;
            [weakPeerConnction setLocalDescription:filteredSdp completionHandler:^(NSError * _Nullable error) {
                if (error == nil) {
                    [self setSessionDescriptionWithPeerConnection:weakPeerConnction];
                }
            }];
        }
    }];
//    CBInfo(@"test after offerForConstraints");
}

/**
 *  设置offer/answer的约束
    kRTCMediaConstraintsIceRestart  网络改变重新收集ICE
 */
- (RTCMediaConstraints *)offerOranswerConstraint
{
    NSMutableDictionary * dic = [@{kRTCMediaConstraintsOfferToReceiveAudio:kRTCMediaConstraintsValueFalse,kRTCMediaConstraintsOfferToReceiveVideo:kRTCMediaConstraintsValueFalse} mutableCopy];
    [dic setObject:kRTCMediaConstraintsValueFalse forKey:kRTCMediaConstraintsOfferToReceiveVideo];
    RTCMediaConstraints *constraints = [[RTCMediaConstraints alloc] initWithMandatoryConstraints:dic optionalConstraints:nil];
    return constraints;
}

// Called when setting a local or remote description.
//当一个远程或者本地的SDP被设置就会调用
- (void)setSessionDescriptionWithPeerConnection:(RTCPeerConnection *)peerConnection
{
//    NSLog(@"%s",__func__);
    
    //判断，当前连接状态为，收到了远程点发来的offer
    if (peerConnection.signalingState == RTCSignalingStateHaveRemoteOffer)
    {
        //创建一个answer,会把自己的SDP信息返回出去
        [peerConnection answerForConstraints:[self offerOranswerConstraint] completionHandler:^(RTCSessionDescription * _Nullable sdp, NSError * _Nullable error) {
            __weak RTCPeerConnection *obj = peerConnection;
            [peerConnection setLocalDescription:sdp completionHandler:^(NSError * _Nullable error) {
                [self setSessionDescriptionWithPeerConnection:obj];
            }];
        }];
    }
    //判断连接状态为本地发送offer
    else if (peerConnection.signalingState == RTCSignalingStateHaveLocalOffer)
    {
        if (peerConnection.localDescription.type == RTCSdpTypeAnswer)
        {
            NSDictionary *dict = @{@"type": @"answer", @"sdp": peerConnection.localDescription.sdp};
            
            if (!_configuration.trickleICE) {
                // 不现在发送
                return;
            }
            
            // 发送信令
            if ([self->_delegate respondsToSelector:@selector(simpleChannel:didHaveSignal:)])
            {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self->_delegate simpleChannel:self didHaveSignal:dict];
                });
            }
        }
        //发送者,发送自己的offer
        else if(peerConnection.localDescription.type == RTCSdpTypeOffer)
        {
            NSDictionary *dict = @{@"type": @"offer", @"sdp": peerConnection.localDescription.sdp};
            
            if (!_configuration.trickleICE) {
                // 不现在发送
                return;
            }
            
            // 发送信令
            if ([self->_delegate respondsToSelector:@selector(simpleChannel:didHaveSignal:)])
            {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self->_delegate simpleChannel:self didHaveSignal:dict];
                });
            }
        }
    }
    else if (peerConnection.signalingState == RTCSignalingStateStable)
    {
        if (peerConnection.localDescription.type == RTCSdpTypeAnswer)
        {
            NSDictionary *dict = @{@"type": @"answer", @"sdp": peerConnection.localDescription.sdp};
//            NSData *data = [NSJSONSerialization dataWithJSONObject:dict options:NSJSONWritingPrettyPrinted error:nil];
//            [_socket send:data];
            // 发送信令
            if ([self->_delegate respondsToSelector:@selector(simpleChannel:didHaveSignal:)])
            {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self->_delegate simpleChannel:self didHaveSignal:dict];
                });
            }
        }
    }
}

/**
 *  关闭peerConnection
 *
 *
 */
- (void)closePeerConnection
{
    if (_peerConnection && _peerConnection.connectionState == RTCPeerConnectionStateConnected)
    {
        [_peerConnection close];
        _peerConnection = nil;
    }
}

// 创建datachannel
- (void)createDataChannelWithPeerConnection:(RTCPeerConnection*)peerConnection {
    //给p2p连接创建dataChannel
    RTCDataChannelConfiguration *dataChannelConfiguration = [[RTCDataChannelConfiguration alloc] init];
    dataChannelConfiguration.isNegotiated = NO;
    dataChannelConfiguration.isOrdered = YES;
    dataChannelConfiguration.maxRetransmits = 30;
    _dataChannel = [peerConnection dataChannelForLabel:self.channelId configuration:dataChannelConfiguration];
    _dataChannel.delegate = self;
//    CBDebug(@"create datachannel");
}

// ICE超时后直接发生offer或者answer
- (void)startIceCompleteTimeout {
    [[CBTimerManager sharedInstance] checkExistTimer:PEERCHANNEL_ICE_TIMMER completion:^(BOOL doExist) {
        if (!doExist) {
            CBDebug(@"startIceCompleteTimeout for %@", self->_channelId);
            [[CBTimerManager sharedInstance] scheduledDispatchTimerWithName:PEERCHANNEL_ICE_TIMMER
                                                               timeInterval:7.0
            queue:nil
            repeats:NO
            fireInstantly:YES
            action:^{
                [self handleIceComplete];
            }];
        }
    }];
    
}

- (void)handleIceComplete {
    if (!_peerConnection) return;
    if (!_iceComplete && !_configuration.trickleICE) {
        _iceComplete = YES;
        // 发送给对等端
        RTCSessionDescription *sdp = _peerConnection.localDescription;
        NSString *type = [RTCSessionDescription stringForType:sdp.type];
        NSString *desc = sdp.sdp;
        NSDictionary *dict = @{@"type": type, @"sdp": desc};
        if ([self->_delegate respondsToSelector:@selector(simpleChannel:didHaveSignal:)])
        {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self->_delegate simpleChannel:self didHaveSignal:dict];
            });
        }
    }
}

// 去掉 a=ice-options:trickle
- (NSString *)filterSdp:(NSString *)sdp {
    NSString *sdpBuilder = @"";
    LineReader* lines = [[LineReader alloc] initWithText:sdp];
    NSString* line = [lines next];
    do {
        if ([line hasPrefix:@"a=ice-options:trickle"]) {
            line = [lines next];
            continue;
        }
        sdpBuilder = [sdpBuilder stringByAppendingFormat:@"%@\n", line];
        line = [lines next];
    } while(line);
    return sdpBuilder;
}

#pragma mark - **************** RTCPeerConnectionDelegate

/**
 RTCIceConnectionState 状态变化
 */
- (void)peerConnection:(nonnull RTCPeerConnection *)peerConnection didChangeIceConnectionState:(RTCIceConnectionState)newState {
    CBDebug(@"RTCIceConnectionState %@", @(newState));
    
    switch (newState) {
        case RTCIceConnectionStateDisconnected:           // 测试不再活跃，这可能是一个暂时的状态，可以自我恢复。
        {
            // disconnected可以自动重连
            self.connected = NO;
            CBInfo(@"peerConnection disconnected");
            break;
        }
        case RTCIceConnectionStateClosed:                 // ICE代理关闭，不再应答任何请求。 
        {
            CBInfo(@"peerConnection closed");
            //断开connection的连接
            if ([self->_delegate respondsToSelector:@selector(simpleChannelDidClose:)])
            {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self->_delegate simpleChannelDidClose:self];
                });
            }
            self.connected = NO;
            
            _dataChannel.delegate = nil;
//            dispatch_async(dispatch_get_main_queue(), ^{
//                // 代理方法
//                if ([self->_delegate respondsToSelector:@selector(simpleChannelDidClose:)])
//                {
//                    [self->_delegate simpleChannelDidClose:self];
//                }
//                self.connected = NO;
//                [self closePeerConnection];
//            });
            break;
        }
        case RTCIceConnectionStateConnected:
        {
            CBDebug(@"peerConnection connected");
            self.connected = YES;
            break;
        }
        case RTCIceConnectionStateFailed:
        {
            CBInfo(@"peerConnection failed");
            //断开connection的连接
            // 代理方法
            if ([self->_delegate respondsToSelector:@selector(simpleChannelDidFail:)])
            {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self->_delegate simpleChannelDidFail:self];
                });
            }
            self.connected = NO;
//            dispatch_async(dispatch_get_main_queue(), ^{
//                // 代理方法
//                if ([self->_delegate respondsToSelector:@selector(simpleChannelDidFail:)])
//                {
//                    [self->_delegate simpleChannelDidFail:self];
//                }
//                self.connected = NO;
//                [self closePeerConnection];
//            });
            break;
        }
        default:
            break;
    }
    
}

/**获取到新的candidate*/
- (void)peerConnection:(RTCPeerConnection *)peerConnection didGenerateIceCandidate:(RTCIceCandidate *)candidate{
//    NSLog(@"%s",__func__);
    
    NSDictionary *dict = @{@"candidate": @{@"sdpMid":candidate.sdpMid, @"sdpMLineIndex": [NSNumber numberWithInteger:candidate.sdpMLineIndex], @"candidate": candidate.sdp}};
    // 发送candidate
    if (_configuration.trickleICE) {
        // 如果是trickle
        if ([self->_delegate respondsToSelector:@selector(simpleChannel:didHaveSignal:)])
        {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self->_delegate simpleChannel:self didHaveSignal:dict];
            });
        }
    } else {
        [self startIceCompleteTimeout];
    }
    
}

- (void)peerConnectionShouldNegotiate:(RTCPeerConnection *)peerConnection{
//    NSLog(@"%s,line = %d object = %@",__FUNCTION__,__LINE__,peerConnection);
}

- (void)peerConnection:(nonnull RTCPeerConnection *)peerConnection didRemoveIceCandidates:(nonnull NSArray<RTCIceCandidate *> *)candidates {
//    NSLog(@"%s,line = %d object = %@",__FUNCTION__,__LINE__,candidates);
}

- (void)peerConnection:(RTCPeerConnection *)peerConnection didChangeSignalingState:(RTCSignalingState)stateChanged{
//    NSLog(@"stateChanged = %ld",(long)stateChanged);
}
- (void)peerConnection:(RTCPeerConnection *)peerConnection didChangeIceGatheringState:(RTCIceGatheringState)newState{
//    NSLog(@"newState = %@", @(newState));
    if (newState == RTCIceGatheringStateComplete) {
        // ICE搜集完成
        CBDebug(@"%@ RTCIceGatheringStateComplete", _channelId);
        [self handleIceComplete];
    }
}

// 只在对方主动连接时回调 p2p重连不会回调此函数  在此回调设置代理
-(void)peerConnection:(RTCPeerConnection *)peerConnection didOpenDataChannel:(RTCDataChannel *)dataChannel{
    
    CBDebug(@"didOpenDataChannel");
//    self.connected = YES;
    dataChannel.delegate = self;      // 设置代理
    _dataChannel = dataChannel;
}

- (void)peerConnection:(RTCPeerConnection *)peerConnection didAddStream:(RTCMediaStream *)stream {
    
//    NSLog(@"didAddStream");
}

- (void)peerConnection:(RTCPeerConnection *)peerConnection didRemoveStream:(RTCMediaStream *)stream {
    
//    NSLog(@"didRemoveStream");
}



#pragma mark - **************** RTCDataChannelDelegate

// p2p重连不会回调此函数
- (void)dataChannelDidChangeState:(RTCDataChannel *)dataChannel {
    CBInfo(@"dataChannelDidChangeState %@", @(dataChannel.readyState));

    switch (dataChannel.readyState) {

        case RTCDataChannelStateOpen:
        {
//            if (self.connected) return;
            self.connected = YES;
            dataChannel.delegate = self;      // 设置代理
            _dataChannel = dataChannel;
            if ([self->_delegate respondsToSelector:@selector(simpleChannelDidOpen:)])
            {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self->_delegate simpleChannelDidOpen:self];
                });
            }
            CBDebug(@"DataChannel opened");
            break;
        }
        case RTCDataChannelStateClosing:
            break;
        case RTCDataChannelStateClosed:
            CBDebug(@"DataChannel closed");
            break;
        case RTCDataChannelStateConnecting:
             CBDebug(@"DataChannel connecting");
            break;
        default:
            break;
    }
}

- (void)dataChannel:(RTCDataChannel *)dataChannel didReceiveMessageWithBuffer:(RTCDataBuffer *)buffer {
//    CBInfo(@"dataChannel didReceiveMessageWithBuffer");
    
    // 二进制数据
    if (buffer.isBinary) {
        // TODO 优化
//        if ([self->_delegate respondsToSelector:@selector(simpleChannel:didReceiveBinaryMessage:)])
//        {
//            dispatch_async(dispatch_get_main_queue(), ^{
//                [self->_delegate simpleChannel:self didReceiveBinaryMessage:buffer.data];
//            });
//        }
        dispatch_async(dispatch_get_main_queue(), ^{
            [self->_delegate simpleChannel:self didReceiveBinaryMessage:buffer.data];
        });
    }
    // JSON数据
    else {
        NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:buffer.data options:NSJSONReadingAllowFragments error:nil];
        // TODO 优化
//        if ([self->_delegate respondsToSelector:@selector(simpleChannel:didReceiveJSONMessage:)])
//        {
//            dispatch_async(dispatch_get_main_queue(), ^{
//                [self->_delegate simpleChannel:self didReceiveJSONMessage:dict];
//            });
//        }
        dispatch_async(dispatch_get_main_queue(), ^{
            [self->_delegate simpleChannel:self didReceiveJSONMessage:dict];
        });
    }
}

@end
