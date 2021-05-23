//
//  SWCError.m
//  SwarmCloudSDK
//
//  Created by Timmy on 2021/5/10.
//  Copyright © 2021 cdnbye. All rights reserved.
//

#import "SWCError.h"

NSString * const SWCErrorUserInfoKeyURL      = @"SWCErrorUserInfoKeyURL";
NSString * const SWCErrorUserInfoKeyRequest  = @"SWCErrorUserInfoKeyRequest";
NSString * const SWCErrorUserInfoKeyResponse = @"SWCErrorUserInfoKeyResponse";

@implementation SWCError

+ (NSError *)errorForResponseUnavailable:(NSURL *)URL
                                 request:(NSURLRequest *)request
                                response:(NSURLResponse *)response
{
    NSMutableDictionary *userInfo = [NSMutableDictionary dictionary];
    if (URL) {
        [userInfo setObject:URL forKey:SWCErrorUserInfoKeyURL];
    }
    if (request) {
        [userInfo setObject:request forKey:SWCErrorUserInfoKeyRequest];
    }
    if (response) {
        [userInfo setObject:response forKey:SWCErrorUserInfoKeyResponse];
    }
    NSError *error = [NSError errorWithDomain:@"SwarmCloudSDK error"
                                         code:SWCErrorCodeResponseUnavailable
                                     userInfo:userInfo];
    return error;
}

+ (NSError *)errorForUnsupportContentType:(NSURL *)URL
                                  request:(NSURLRequest *)request
                                 response:(NSURLResponse *)response
{
    NSMutableDictionary *userInfo = [NSMutableDictionary dictionary];
    if (URL) {
        [userInfo setObject:URL forKey:SWCErrorUserInfoKeyURL];
    }
    if (request) {
        [userInfo setObject:request forKey:SWCErrorUserInfoKeyRequest];
    }
    if (response) {
        [userInfo setObject:response forKey:SWCErrorUserInfoKeyResponse];
    }
    NSError *error = [NSError errorWithDomain:@"SwarmCloudSDK error"
                                         code:SWCErrorCodeUnsupportContentType
                                     userInfo:userInfo];
    return error;
}

+ (NSError *)errorForException:(NSException *)exception
{
    NSError *error = [NSError errorWithDomain:@"SwarmCloudSDK error"
                                        code:SWCErrorCodeException
                                    userInfo:exception.userInfo];
    return error;
}

+ (NSError *)errorWithReason:(NSString *)reason {
    return [NSError errorWithDomain:@"SwarmCloudSDK error" code:SWCErrorCodeException userInfo:@{@"reason": reason}];
}

@end
