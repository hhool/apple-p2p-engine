//
//  SWCWebServerConnection.m
//  SwarmCloudSDK
//
//  Created by Timmy on 2021/5/30.
//  Copyright © 2021 cdnbye. All rights reserved.
//

#import "SWCWebServerConnection.h"

@implementation SWCWebServerConnection

-(GCDWebServerResponse *)preflightRequest:(GCDWebServerRequest *)request {
    NSLog(@"preflightRequest %@", request);
    return [super preflightRequest:request];
}

-(void)abortRequest:(GCDWebServerRequest *)request withStatusCode:(NSInteger)statusCode {
    NSLog(@"abortRequest %@ StatusCode %@", request, @(statusCode));
    [super abortRequest:request withStatusCode:statusCode];
}

-(void)processRequest:(GCDWebServerRequest *)request completion:(GCDWebServerCompletionBlock)completion {
    NSLog(@"processRequest %@", request);
    [super processRequest:request completion:completion];
}

-(BOOL)open {
    NSLog(@"connection open");
    return [super open];
}

-(void)close {
    NSLog(@"connection close");
    [super close];
}

@end
