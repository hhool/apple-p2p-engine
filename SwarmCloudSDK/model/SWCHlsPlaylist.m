//
//  SWCHlsPlaylist.m
//  SwarmCloudSDK
//
//  Created by Timmy on 2021/5/22.
//  Copyright © 2021 cdnbye. All rights reserved.
//

#import "SWCHlsPlaylist.h"

@implementation SWCHlsPlaylist

- (instancetype)initWithBaseUri:(NSURL *)uri
{
    self = [super init];
    if (self) {
        _baseUri = uri;
    }
    return self;
}

@end
