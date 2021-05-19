//
//  NetworkResponse.m
//  SwarmCloudSDK
//
//  Created by Timmy on 2021/5/7.
//  Copyright © 2021 cdnbye. All rights reserved.
//

#import "SWCNetworkResponse.h"

@implementation SWCNetworkResponse

- (instancetype)initWithData:(NSData *_Nullable)data contentType:(NSString *)type
{
    self = [super init];
    if (self) {
        self->_data = data;
        self->_contentType = type;
    }
    return self;
}

- (instancetype)initWithNoResponse
{
    self = [super init];
    if (self) {
        
    }
    return self;
}

@end
