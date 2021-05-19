//
//  StunClient.m
//  CDNByeKit
//
//  Created by Timmy on 2020/1/15.
//  Copyright © 2020 cdnbye. All rights reserved.
//


#import "StunClient.h"
#import "StunMessage.h"
#import "NATUtils.h"

NSString *const DEFAULT_STUN_HOST = @"stun.cdnbye.com";
const NSUInteger DEFAULT_STUN_PORT = 3478;
const NSUInteger UDP_SEND_COUNT = 3;
const NSTimeInterval TRANSACTION_TIMEOUT = 1;
const NSUInteger SEND_PORT = 50899;

@interface StunClient()
{    
//    dispatch_queue_t _concurrentQueue;
}
@end

@implementation StunClient

- (instancetype)initWithLocalPort:(int)port {
    if(self = [self init]) {
        if (![[CBSocket sharedInstance] startWithLocalPort:port]) {
            return nil;
        }
//        _concurrentQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0);
    }
    return self;
}

#pragma mark - **************** public methods

- (StunResult *)queryWithLocalIp:(NSString *)localIp {
    return [self queryWithLocalIp:localIp stunHost:DEFAULT_STUN_HOST stunPort:DEFAULT_STUN_PORT];
}

- (StunResult *)queryWithLocalIp:(NSString *)localIp stunHost:(NSString *)host stunPort:(int)port {
//    [_socket sendData:nil toHost:@"" port:0 withTimeout:0 tag:0];
    if ([localIp isEqualToString:@""]) {
        return [[StunResult alloc] initWithAddress:nil andNatType:NatTypeUnknown];
    }
    
    return [self queryWithLocalIp:localIp stunHost:host stunPort:port socket:[CBSocket sharedInstance]];
    
}

- (StunResult *)queryWithLocalIp:(NSString *)localIp stunHost:(NSString *)host stunPort:(int)port socket:(CBSocket *)socket {
    if (!socket) {
        return [[StunResult alloc] initWithAddress:nil andNatType:NatTypeUnknown];
    }
    
    SocketAddress *remoteEndPoint = [[SocketAddress alloc] initWithHost:host andPort:port];
    
    /*
     In test I, the client sends a STUN Binding Request to a server, without any flags set in the
     CHANGE-REQUEST attribute, and without the RESPONSE-ADDRESS attribute. This causes the server
     to send the response back to the address and port that the request came from.
     
     In test II, the client sends a Binding Request with both the "change IP" and "change port" flags
     from the CHANGE-REQUEST attribute set.
     
     In test III, the client sends a Binding Request with only the "change port" flag set.
     
     +--------+
     |  Test  |
     |   I    |
     +--------+
     |
     |
     V
     /\              /\
     N /  \ Y          /  \ Y             +--------+
     UDP     <-------/Resp\--------->/ IP \------------->|  Test  |
     Blocked         \ ?  /          \Same/              |   II   |
     \  /            \? /               +--------+
     \/              \/                    |
     | N                  |
     |                    V
     V                    /\
     +--------+  Sym.      N /  \
     |  Test  |  UDP    <---/Resp\
     |   II   |  Firewall   \ ?  /
     +--------+              \  /
     |                    \/
     V                     |Y
     /\                         /\                    |
     Symmetric  N  /  \       +--------+   N  /  \                   V
     NAT  <--- / IP \<-----|  Test  |<--- /Resp\               Open
     \Same/      |   I    |     \ ?  /               Internet
     \? /       +--------+      \  /
     \/                         \/
     |                           |Y
     |                           |
     |                           V
     |                           Full
     |                           Cone
     V              /\
     +--------+        /  \ Y
     |  Test  |------>/Resp\---->Restricted
     |   III  |       \ ?  /
     +--------+        \  /
     \/
     |N
     |       Port
     +------>Restricted
     
     */
    
    // Test I
//    NSLog(@"begin Test I");
    StunMessage *test1 = [[StunMessage alloc] initWithStunMessageType:StunMessageTypeBindingRequest];
    //    StunMessage test1Response = [doTransaction(test1, socket, remoteEndPoint, TRANSACTION_TIMEOUT);
    
    StunMessage *test1Response = [self doTransactionWithStunMessage:test1 remoteEndPoint:remoteEndPoint timeout:TRANSACTION_TIMEOUT];
    // UDP blocked.
    if (test1Response == nil) {
        return [[StunResult alloc] initWithAddress:nil andNatType:NatTypeUdpBlocked];
    }
    else {
        // Test II
//        NSLog(@"begin Test II");
         StunMessage *test2 = [[StunMessage alloc] initWithStunMessageType:StunMessageTypeBindingRequest andStunChangeRequest:[[StunChangeRequest alloc] initWithChangeIp:YES changePort:YES]];
        
        // No NAT.
//        NSLog(@"test1Response ip: %@", test1Response.mappedAddress.ip);
        if ([test1Response.mappedAddress.ip isEqualToString:localIp]) {
            // IP相同
            StunMessage *test2Response = [self doTransactionWithStunMessage:test2 remoteEndPoint:remoteEndPoint timeout:TRANSACTION_TIMEOUT];
            // Open Internet.
            if (test2Response != nil)
            {
                 return [[StunResult alloc] initWithAddress:test1Response.mappedAddress andNatType:NatTypeOpenInternet];
            }
            // Symmetric UDP firewall.
            else
            {
                return [[StunResult alloc] initWithAddress:test1Response.mappedAddress andNatType:NatTypeSymmetricUdpFirewall];
            }
        }
        // NAT
        else {
            StunMessage *test2Response = [self doTransactionWithStunMessage:test2 remoteEndPoint:remoteEndPoint timeout:TRANSACTION_TIMEOUT];
            // Full cone NAT.
            if (test2Response != nil) {
                return [[StunResult alloc] initWithAddress:test1Response.mappedAddress andNatType:NatTypeFullCone];
            }
            else {
                /*
                 If no response is received, it performs test I again, but this time, does so to
                 the address and port from the CHANGED-ADDRESS attribute from the response to test I.
                 */
                
                // Test I(II)
//                NSLog(@"begin Test I(II) remote %@", test1Response.changedAddress.ip);
                StunMessage *test12 = [[StunMessage alloc] initWithStunMessageType:StunMessageTypeBindingRequest];
                StunMessage *test12Response =  [self doTransactionWithStunMessage:test12 remoteEndPoint:test1Response.changedAddress timeout:TRANSACTION_TIMEOUT];
                if (test12Response == nil) {
//                    NSLog(@"STUN Test I(II) didn't get response !");
                    return [[StunResult alloc] initWithAddress:nil andNatType:NatTypeUnknown];
                }
                else {
                    // Symmetric NAT
                    if (!([test12Response.mappedAddress.ip isEqualToString:test1Response.mappedAddress.ip] && (test12Response.mappedAddress.port == test1Response.mappedAddress.port))) {
                        return [[StunResult alloc] initWithAddress:test1Response.mappedAddress andNatType:NatTypeSymmetric];
                    }
                    else {
                        // Test III
                        StunMessage *test3 = [[StunMessage alloc] initWithStunMessageType:StunMessageTypeBindingRequest andStunChangeRequest:[[StunChangeRequest alloc] initWithChangeIp:NO changePort:YES]];
                        StunMessage *test3Response = [self doTransactionWithStunMessage:test3 remoteEndPoint:test1Response.changedAddress timeout:TRANSACTION_TIMEOUT];
                        // Restricted
                        if (test3Response != nil) {
                            return [[StunResult alloc] initWithAddress:test1Response.mappedAddress andNatType:NatTypeRestrictedCone];
                        }
                        // Port restricted
                        else {
                            return [[StunResult alloc] initWithAddress:test1Response.mappedAddress andNatType:NatTypePortRestrictedCone];
                        }
                    }
                }
            }
        }
    }
}

- (StunMessage *)doTransactionWithStunMessage:(StunMessage *)request remoteEndPoint:(SocketAddress *)remote timeout:(NSTimeInterval)timeout {
//    CFAbsoluteTime t1 = CFAbsoluteTimeGetCurrent();
    NSData *dataToSend = [request toByteData];
    
//    [_socket sendData:dataToSend toHost:remote.host port:remote.port withTimeout:3 tag:0];
//    NSLog(@"doTransaction %@", @([NSThread isMainThread]));
    BOOL revResponse = false;                   // 是否接收到数据的标志位
    int receiveCount = 0;
     __block StunMessage *message = [[StunMessage alloc] init];
    __block NSData *data = nil;
    while (!revResponse && receiveCount < UDP_SEND_COUNT) {
        // 回调转同步
        dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
        [[CBSocket sharedInstance] sendData:dataToSend withTimeout:timeout remoteEndPoint:remote andReceiveBlock:^(NSData * _Nullable response, SocketAddress * _Nullable addr) {
            data = response;
            dispatch_semaphore_signal(semaphore); //这句代码会使信号值增加1 并且会唤醒一个线程去开始继续工作,如果唤醒成功,那么返回一个非零的数,如果没有唤醒,那么返回 0
        }];
        dispatch_semaphore_wait(semaphore, dispatch_time(DISPATCH_TIME_NOW, timeout * NSEC_PER_SEC));
        if (data) {
            [message parseData:data];
            // 校验TransactionId
            if ([message.transactionId isEqualToData:request.transactionId]) {
                revResponse = true;
            } else {
                NSLog(@"TransactionId not match!");
            }
        }
        receiveCount ++;
    }
//    CFAbsoluteTime t2 = CFAbsoluteTimeGetCurrent();
//    NSLog(@"doTransaction 耗时 %f", (t2-t1)*1000.0);
    
    if (revResponse) {
        return message;
    } else {
        return nil;
    }
}

- (void)dealloc
{
    [[CBSocket sharedInstance] cutOffSocket];
}

@end
