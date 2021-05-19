//
//  StunChangeRequest.m
//  CDNByeKit
//
//  Created by Timmy on 2020/1/15.
//  Copyright © 2020 cdnbye. All rights reserved.
//

#import "StunChangeRequest.h"

@implementation StunChangeRequest

- (instancetype)initWithChangeIp:(BOOL)changeIp changePort:(BOOL)changePort {
    if(self = [super init]) {
        _changeIp = changeIp;
        _changePort = changePort;
    }
    
    return self;
}

@end
