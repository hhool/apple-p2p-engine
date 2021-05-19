//
//  StunClient.h
//  CDNByeKit
//
//  Created by Timmy on 2020/1/15.
//  Copyright © 2020 cdnbye. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "StunResult.h"
#import "CBSocket.h"

NS_ASSUME_NONNULL_BEGIN

@interface StunClient : NSObject

- (StunResult *)queryWithLocalIp:(NSString *)localIp;

- (StunResult *)queryWithLocalIp:(NSString *)localIp stunHost:(NSString *)host stunPort:(int)port;

- (StunResult *)queryWithLocalIp:(NSString *)localIp stunHost:(NSString *)host stunPort:(int)port socket:(CBSocket *)socket;

- (instancetype)initWithLocalPort:(int)port;

@end

NS_ASSUME_NONNULL_END
