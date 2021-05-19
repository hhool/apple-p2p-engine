//
//  SWCProxy.m
//  SwarmCloudSDK
//
//  Created by Timmy on 2021/5/6.
//  Copyright © 2021 cdnbye. All rights reserved.
//

#import "SWCProxy.h"
#import "CBLogger.h"

#define SWCProxyThrowException @throw [NSException exceptionWithName:NSInternalInconsistencyException reason:[NSString stringWithFormat:@"%@ must be overriden", NSStringFromSelector(_cmd)] userInfo:nil];

NSString *const LOCAL_IP = @"http://127.0.0.1";

@interface SWCProxy()
{
    

}
@end

@implementation SWCProxy

- (instancetype)init
{
    self = [super init];
    if (self) {
        
    }
    return self;
}

- (NSString *)localIp {
    return LOCAL_IP;
}


- (void)startLocalServer {
    SWCProxyThrowException
}

- (void)shutdown {
    CBError(@"Not implemented");
}

- (void)stopP2p {
    CBError(@"Not implemented");
}

- (void)restartP2p {
    CBError(@"Not implemented");
}

- (NSString *)getMediaType {
    SWCProxyThrowException
}

- (BOOL)isConnected {
    SWCProxyThrowException
}

- (NSString *)getPeerId {
    SWCProxyThrowException
}

- (NSString *) getProxyUrl:(NSURL *)url withVideoId:(NSString *)videoId {
    SWCProxyThrowException
}

@end
