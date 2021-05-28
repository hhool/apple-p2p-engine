//
//  SWCMp4Proxy.m
//  SwarmCloudSDK
//
//  Created by Timmy on 2021/5/6.
//  Copyright © 2021 cdnbye. All rights reserved.
//

#import "SWCMp4Proxy.h"
#import "SWCP2pConfig.h"
#import "GCDWebServer.h"
#import "CBLogger.h"
#import "GCDWebServerDataResponse.h"
#import "SWCByteRange.h"

static SWCMp4Proxy *_instance = nil;

@interface SWCMp4Proxy()<NSURLSessionTaskDelegate, SWCSchedulerDelegate, GCDWebServerDelegate>
{
    BOOL _isFirstRequest;
}
@end

@implementation SWCMp4Proxy

- (void)initWithTkoen:(NSString *)token config:(SWCP2pConfig *)config
{
    [super initWithTkoen:token config:config];
    [self initVariable];
}

- (void)initVariable {
    _isFirstRequest = YES;
    NSURLSessionConfiguration *httpConfig = [NSURLSessionConfiguration defaultSessionConfiguration];
    httpConfig.allowsCellularAccess = YES;
    _httpSession = [NSURLSession sessionWithConfiguration:httpConfig delegate:self delegateQueue:[NSOperationQueue mainQueue]];
}

+ (instancetype)sharedInstance {
    
    static dispatch_once_t onceToken = 0;
    dispatch_once(&onceToken, ^{
        _instance = [[self alloc] init];
    });
    return _instance;
    
}

- (void)startLocalServer:(NSError **)error {
    // 启动本地服务器
    if (_webServer && _webServer.isRunning) return;
    _currentPort = _config.localPortMp4;
    if (_currentPort < 0) return;
    
    _webServer = [[GCDWebServer alloc] init];
    _webServer.delegate = self;
    [GCDWebServer setLogLevel:3];   // WARN
    __weak typeof(self) weakSelf = self;
    
    [_webServer addDefaultHandlerForMethod:@"GET" requestClass:[GCDWebServerRequest class] asyncProcessBlock:^(__kindof GCDWebServerRequest * _Nonnull request, GCDWebServerCompletionBlock  _Nonnull completionBlock) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (request.hasByteRange) {
            CBDebug(@"request ts path %@ query %@ range %@", request.path, request.URL.query, SWCRangeGetHeaderStringFromNSRange(request.byteRange));
        } else {
            CBDebug(@"request ts path %@ query %@", request.path, request.URL.query);
        }
        NSString *uri = request.path;
        if (request.URL.query) {
            uri = [NSString stringWithFormat:@"%@?%@", uri, request.URL.query];
        }
        if (!strongSelf) {
            CBError(@"Engine is released");
        }
        NSURL *url = [NSURL URLWithString:uri relativeToURL:strongSelf->_originalLocation];
        NSError *error;
        NSDictionary *headers = strongSelf->_config.httpHeadersForMp4;
        SWCNetworkResponse *netResp = [strongSelf requestFromNetworkWithUrl:url req:request headers:headers error:&error];
        GCDWebServerResponse *resp;
        if (error) {
            CBWarn(@"request mp4 failed, error %@ redirect to %@", error, url);
            resp = [GCDWebServerResponse responseWithRedirect:url permanent:NO];
        } else {
            if (strongSelf->_isFirstRequest) {
                CBDebug(@"mp4 first request");
                strongSelf->_isFirstRequest = NO;
            }
            resp = [GCDWebServerDataResponse responseWithData:netResp.data contentType:netResp.contentType];
            resp.statusCode = netResp.statusCode;                             // TODO 验证
        }
        completionBlock(resp);
    }];
    
    /*
     kGCDWebServerHTTPStatusCode_OK = 200,
     kGCDWebServerHTTPStatusCode_Created = 201,
     kGCDWebServerHTTPStatusCode_Accepted = 202,
     kGCDWebServerHTTPStatusCode_NonAuthoritativeInformation = 203,
     kGCDWebServerHTTPStatusCode_NoContent = 204,
     kGCDWebServerHTTPStatusCode_ResetContent = 205,
     kGCDWebServerHTTPStatusCode_PartialContent = 206,
     kGCDWebServerHTTPStatusCode_MultiStatus = 207,
     kGCDWebServerHTTPStatusCode_AlreadyReported = 208
     */
    
#if TARGET_OS_OSX
    [_webServer startWithPort:_currentPort bonjourName:nil];
#else
    [_webServer startWithOptions:@{
        GCDWebServerOption_AutomaticallySuspendInBackground : @(NO),
        GCDWebServerOption_Port: @(_currentPort),
        GCDWebServerOption_ConnectedStateCoalescingInterval: @3.0,
    } error:error];
#endif
    _currentPort = _webServer.port;
    CBInfo(@"Mp4 listening Port: %@", @(_currentPort));
}

- (void)shutdown {
    [self stopP2p];
    if (_webServer && _webServer.isRunning) {
        [_webServer stop];
    }
}

- (void)stopP2p {
    CBInfo(@"mp4 proxy stop p2p");
}

- (void)restartP2p {
    CBInfo(@"mp4 proxy restart p2p");
    _isFirstRequest = YES;
}

- (NSString *)getMediaType {
    return @"mp4";
}

- (BOOL)isConnected {
    return NO;
}

- (NSString *)getPeerId {
    return nil;
}


@end
