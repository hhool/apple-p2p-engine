//
//  SWCPeer.m
//  SwarmCloudSDK
//
//  Created by Timmy on 2021/5/8.
//  Copyright © 2021 cdnbye. All rights reserved.
//

#import "SWCPeer.h"

@implementation SWCPeer

- (instancetype)initWithId:(NSString *)peerId intermediator:(NSString *)intermediator {
    if(self = [super init])
    {
        _peerId = peerId;
        _intermediator = intermediator;
    }
    return self;
}

- (instancetype)initWithId:(NSString *)peerId{
    if(self = [super init])
    {
        _peerId = peerId;
    }
    return self;
}

@end
