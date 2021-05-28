//
//  SWCProxy.m
//  SwarmCloudSDK
//
//  Created by Timmy on 2021/5/6.
//  Copyright © 2021 cdnbye. All rights reserved.
//

#import "SWCProxy.h"
#import "CBLogger.h"

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
    CBInfo(@"requestFromNetworkWithUrl %@", [url absoluteString]);
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
        CBInfo(@"range %@", rangeHeader);
        
        [req addValue:rangeHeader  forHTTPHeaderField:@"Range"];
    }
    __block NSData *respData;
    __block NSString *mime = @"";
    __block NSURL *responseUrl;
    __block NSInteger statusCode;
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    NSURLSessionDataTask *dataTask = [self->_httpSession dataTaskWithRequest:req completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        
        if (data && (error == nil)) {
            // 网络访问成功
            NSHTTPURLResponse *httpResp = (NSHTTPURLResponse *)response;
            respData = data;
            mime = response.MIMEType;
            responseUrl = response.URL;
            statusCode = httpResp.statusCode;
            statusCode = 200;
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
        *err = [NSError errorWithDomain:@"NetworkResponse" code:-908 userInfo:@{NSLocalizedDescriptionKey:errMsg}];
    }
    return [SWCNetworkResponse.alloc initWithData:respData contentType:mime responseUrl:responseUrl statusCode:statusCode];
}

@end
