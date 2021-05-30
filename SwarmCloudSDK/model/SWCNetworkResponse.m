//
//  NetworkResponse.m
//  SwarmCloudSDK
//
//  Created by Timmy on 2021/5/7.
//  Copyright © 2021 cdnbye. All rights reserved.
//

#import "SWCNetworkResponse.h"

@implementation SWCNetworkResponse

- (instancetype)initWithData:(NSData *_Nullable)data contentType:(NSString *)type responseUrl:(NSURL *_Nullable)responseUrl statusCode:(NSInteger)code fileSize:(NSUInteger)size {
    self = [super init];
    if (self) {
        _data = data;
        _contentType = type;
        _responseUrl = responseUrl;
        _statusCode = code;
        _fizeSize = size;
    }
    return self;
}

- (instancetype)initWithData:(NSData *_Nullable)data contentType:(NSString *)type responseUrl:(NSURL *_Nullable)responseUrl
{
    return [self initWithData:data contentType:type responseUrl:responseUrl statusCode:200 fileSize:data.length];
}

- (instancetype)initWithData:(NSData *_Nullable)data contentType:(NSString *)type {
    return [self initWithData:data contentType:type responseUrl:nil statusCode:200 fileSize:data.length];
}

- (instancetype)initWithNoResponse
{
    self = [super init];
    if (self) {
        
    }
    return self;
}

@end
