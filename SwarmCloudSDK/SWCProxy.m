//
//  SWCProxy.m
//  SwarmCloudSDK
//
//  Created by Timmy on 2021/5/6.
//  Copyright © 2021 cdnbye. All rights reserved.
//

#import "SWCProxy.h"
#import "CBLogger.h"
#import "SWCError.h"

#define SWCProxyThrowException @throw [NSException exceptionWithName:NSInternalInconsistencyException reason:[NSString stringWithFormat:@"%@ must be overriden", NSStringFromSelector(_cmd)] userInfo:nil];

NSString *const LOCAL_IP = @"http://127.0.0.1";

@interface SWCProxy()<NSURLSessionTaskDelegate, SWCSchedulerDelegate>
{
    

}
@end

@implementation SWCProxy

- (void)initWithTkoen:(NSString *)token config:(SWCP2pConfig *)config {
    _config = config;
    _token = token;
    [self initVariable];
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        
    }
    return self;
}

- (void)initVariable {
    
}

- (NSString *)localIp {
    return LOCAL_IP;
}


- (void)startLocalServer:(NSError **)error {
    SWCProxyThrowException
}

- (void)shutdown {
    CBError(@"Not implemented");
}

- (void)stopP2p {
    CBError(@"Not implemented");
}

- (void)restartP2p {
    CBError(@"Not implemented");
}

- (NSString *)getMediaType {
    SWCProxyThrowException
}

- (BOOL)isConnected {
    SWCProxyThrowException
}

- (NSString *)getPeerId {
    SWCProxyThrowException
}

- (NSString *)getProxyUrl:(NSURL *)url withVideoId:(NSString *)videoId {
    if (_currentPort < 0) {
        CBWarn(@"Port < 0, fallback to original url");
        return [url absoluteString];
    }
    _videoId = videoId;
    _originalURL = url;
    _originalLocation = [SWCUtils getLocationFromURL:url];
    NSString *path = url.relativePath;
    NSString *query = url.query;
    NSString *localUrlStr = [NSString stringWithFormat:@"%@:%@%@", self.localIp, @(_currentPort), path];
    if (query) {
        localUrlStr = [NSString stringWithFormat:@"%@?%@", localUrlStr, query];
    }
    return localUrlStr;
}

- (SWCNetworkResponse *)requestFromNetworkWithUrl:(NSURL *)url req:(GCDWebServerRequest *)request headers:(NSDictionary *)headers error:(NSError **)err {
    
    NSTimeInterval timeout = 10.0f;
    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:url];
    
    // 处理headers
    if (headers) {
        for (NSString *key in headers) {
            [req addValue:[headers objectForKey:key]  forHTTPHeaderField:key];
        }
    }
    
    // 处理range
    if (request.hasByteRange) {
        NSString *rangeHeader = SWCRangeGetHeaderStringFromNSRange(request.byteRange);
        CBInfo(@"requestFromNetworkWithUrl %@ range %@", [url absoluteString], rangeHeader);
        [req addValue:rangeHeader  forHTTPHeaderField:@"Range"];
    } else {
        CBInfo(@"requestFromNetworkWithUrl %@", [url absoluteString]);
    }
    __block NSData *respData;
    __block NSString *mime = @"";
    __block NSURL *responseUrl;
    __block NSInteger statusCode;
    __block NSDictionary *httpHeaders;
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    NSURLSessionDataTask *dataTask = [self->_httpSession dataTaskWithRequest:req completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        
        if (data && (error == nil)) {
            // 网络访问成功
            NSHTTPURLResponse *httpResp = (NSHTTPURLResponse *)response;
            respData = data;
            mime = response.MIMEType;
            responseUrl = response.URL;
            statusCode = httpResp.statusCode;
            httpHeaders = httpResp.allHeaderFields;
        } else {
            // 网络访问失败
            CBWarn(@"failed to request m3u8 from %@ %@", req.URL.absoluteString, error.userInfo);
            
            
        }
        dispatch_semaphore_signal(semaphore);
    }];
    [dataTask resume];
    dispatch_semaphore_wait(semaphore, dispatch_time(DISPATCH_TIME_NOW, timeout * NSEC_PER_SEC));
    if (!respData && err) {
        NSString *errMsg = [NSString stringWithFormat:@"request %@ timeout", url];
        *err = [SWCError errorForNetworkWithReason:errMsg];
        return [SWCNetworkResponse.alloc initWithNoResponse];
    }
//    CBDebug(@"SWCNetworkResponse statusCode %@ data %@ contentType %@", @(statusCode), @(respData.length), mime);
    if (statusCode == 206) {
        NSString *contentRange = [httpHeaders objectForKey:@"Content-Range"];
        if (!contentRange) contentRange = [httpHeaders objectForKey:@"content-range"];
        if ((!contentRange || ![contentRange hasPrefix:@"bytes "]) && err) {
            NSString *errMsg = [NSString stringWithFormat:@"request %@ do not contain Content-Range", url];
            *err = [SWCError errorForNetworkWithReason:errMsg];
            return [SWCNetworkResponse.alloc initWithNoResponse];
        }
        contentRange = [contentRange stringByReplacingOccurrencesOfString:@"bytes " withString:@""];
        NSRange range = [contentRange rangeOfString:@"/"];
        if (range.location == NSNotFound) {
            NSString *errMsg = [NSString stringWithFormat:@"parse %@ Content-Range error", url];
            *err = [SWCError errorForNetworkWithReason:errMsg];
            return [SWCNetworkResponse.alloc initWithNoResponse];
        }
        NSString *totalLengthString = [contentRange substringFromIndex:range.location + range.length];
        NSUInteger totalLength = totalLengthString.longLongValue;
        return [SWCNetworkResponse.alloc initWithData:respData contentType:mime responseUrl:responseUrl statusCode:statusCode fileSize:totalLength];
    }
    return [SWCNetworkResponse.alloc initWithData:respData contentType:mime responseUrl:responseUrl];
    
}

#pragma mark - **************** SWCSchedulerDelegate
- (NSTimeInterval)bufferedDuration {
    if ([self->_delegate respondsToSelector:@selector(bufferedDuration)]) {
        return [self->_delegate bufferedDuration];
    }
    return -1;
}

@end
