//
//  NetworkResponse.m
//  SwarmCloudSDK
//
//  Created by Timmy on 2021/5/7.
//  Copyright © 2021 cdnbye. All rights reserved.
//

#import "SWCNetworkResponse.h"

@implementation SWCNetworkResponse

- (instancetype)initWithData:(NSData *_Nullable)data contentType:(NSString *)type responseUrl:(NSURL *)responseUrl statusCode:(NSInteger)code {
    self = [super init];
    if (self) {
        _data = data;
        _contentType = type;
        _responseUrl = responseUrl;
        _statusCode = code;
    }
    return self;
}

- (instancetype)initWithData:(NSData *_Nullable)data contentType:(NSString *)type responseUrl:(NSURL *)responseUrl
{
    return [self initWithData:data contentType:type responseUrl:responseUrl statusCode:200];
}

- (instancetype)initWithData:(NSData *_Nullable)data contentType:(NSString *)type {
    self = [super init];
    if (self) {
        _data = data;
        _contentType = type;
        _statusCode = 200;
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
