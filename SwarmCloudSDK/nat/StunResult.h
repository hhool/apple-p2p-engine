//
//  StunResult.h
//  CDNByeKit
//
//  Created by Timmy on 2020/1/15.
//  Copyright © 2020 cdnbye. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SocketAddress.h"
#import "NATUtils.h"

NS_ASSUME_NONNULL_BEGIN

@interface StunResult : NSObject

@property(nonatomic, strong, readonly) SocketAddress *addr;

@property(nonatomic, assign, readonly) NatType natType;

- (instancetype)initWithAddress:(nullable SocketAddress *)addr andNatType:(NatType)type;

@end

NS_ASSUME_NONNULL_END
