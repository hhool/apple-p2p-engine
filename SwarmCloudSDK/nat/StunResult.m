//
//  StunResult.m
//  CDNByeKit
//
//  Created by Timmy on 2020/1/15.
//  Copyright © 2020 cdnbye. All rights reserved.
//

#import "StunResult.h"

@implementation StunResult

- (instancetype)initWithAddress:(nullable SocketAddress *)addr andNatType:(NatType)type {
    if(self = [super init]) {
        _addr = addr;
        _natType = type;
    }
    return self;
}

@end
