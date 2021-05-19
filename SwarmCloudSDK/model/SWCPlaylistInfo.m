//
//  SWCPlaylistInfo.m
//  SwarmCloudSDK
//
//  Created by Timmy on 2021/5/13.
//  Copyright © 2021 cdnbye. All rights reserved.
//

#import "SWCPlaylistInfo.h"

@implementation SWCPlaylistInfo

- (instancetype)initWithTs:(NSNumber *)ts data:(NSString *)data
{
    self = [super init];
    if (self) {
        _ts = ts;
        _data = data;
    }
    return self;
}

- (instancetype)initWithMd5:(NSString *)md5 ts:(NSNumber *)ts
{
    self = [super init];
    if (self) {
        _ts = ts;
        _md5 = md5;
    }
    return self;
}

@end
