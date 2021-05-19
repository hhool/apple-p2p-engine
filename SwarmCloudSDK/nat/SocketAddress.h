//
//  SocketAddress.h
//  CDNByeKit
//
//  Created by Timmy on 2020/1/16.
//  Copyright © 2020 cdnbye. All rights reserved.
//

#import <Foundation/Foundation.h>



NS_ASSUME_NONNULL_BEGIN

@interface SocketAddress : NSObject

@property(nonatomic, copy, readonly) NSString *host;

@property(nonatomic, copy, readonly) NSString *ip;

@property(nonatomic, assign, readonly) int port;

- (instancetype)initWithHost:(NSString *)host andPort:(int)port;

- (instancetype)initWithIp:(NSString *)ip andPort:(int)port;

- (char *)ip2Bytes;

@end

NS_ASSUME_NONNULL_END
