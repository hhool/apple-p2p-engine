//
//  SWCError.h
//  SwarmCloudSDK
//
//  Created by Timmy on 2021/5/10.
//  Copyright © 2021 cdnbye. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef NS_ENUM(NSInteger, SWCErrorCode) {
    SWCErrorCodeResponseUnavailable  = -192700,
    SWCErrorCodeUnsupportContentType = -192701,
    SWCErrorCodeNotEnoughDiskSpace   = -192702,
    SWCErrorCodeException            = -192703,
};

@interface SWCError : NSObject

+ (NSError *)errorForResponseUnavailable:(NSURL *)URL
                                 request:(NSURLRequest *)request
                                response:(NSURLResponse *)response;

+ (NSError *)errorForUnsupportContentType:(NSURL *)URL
                                  request:(NSURLRequest *)request
                                 response:(NSURLResponse *)response;

+ (NSError *)errorForException:(NSException *)exception;

@end


