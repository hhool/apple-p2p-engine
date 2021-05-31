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
#import "GCDWebServerStreamedResponse.h"
#import "SWCByteRange.h"
#import "SWCWebServerConnection.h"
#import "SWCTracker.h"

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
    
    [_webServer addDefaultHandlerForMethod:@"GET" requestClass:[GCDWebServerRequest class] processBlock:^GCDWebServerResponse * _Nullable(__kindof GCDWebServerRequest * _Nonnull request) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        CBDebug(@"local server receive request %@", request.path);
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
            return [GCDWebServerResponse responseWithRedirect:url permanent:NO];
        }
        if (strongSelf->_isFirstRequest) {
            CBDebug(@"mp4 first request");
            strongSelf->_isFirstRequest = NO;
            if (!strongSelf->_tracker && strongSelf->_config.p2pEnabled) {
                @try {
                    [strongSelf initTrackerClientWithEndSN:0];       // TODO
                } @catch (NSException *exception) {
                    CBError(@"NSException caught, reason: %@", exception.reason);
                    strongSelf->_config.p2pEnabled = NO;
                }
            }
        }
        
        resp = [GCDWebServerDataResponse responseWithData:netResp.data contentType:netResp.contentType];
        resp.statusCode = netResp.statusCode;                             // TODO 验证
        [resp setValue:@"bytes" forAdditionalHeader:@"Accept-Ranges"];
//        [resp setValue:@"video/mp4" forAdditionalHeader:@"Content-Type"];
        resp.contentLength = netResp.data.length;
        [resp setValue:[NSString stringWithFormat:@"bytes %lu-%lu/%lu", (unsigned long)request.byteRange.location, (unsigned long)(request.byteRange.location+request.byteRange.length-1), (unsigned long)netResp.fizeSize] forAdditionalHeader:@"Content-Range"];
        CBDebug(@"local server resp size %@", @(netResp.data.length));
        return resp;
    }];
    
//    [_webServer addDefaultHandlerForMethod:@"GET" requestClass:[GCDWebServerRequest class] asyncProcessBlock:^(__kindof GCDWebServerRequest * _Nonnull request, GCDWebServerCompletionBlock  _Nonnull completionBlock) {
//        __strong typeof(weakSelf) strongSelf = weakSelf;
//        CBDebug(@"local server receive request %@", request);
////        if (request.hasByteRange) {
////            CBDebug(@"request mp4 path %@ query %@ range %@", request.path, request.URL.query, SWCRangeGetHeaderStringFromNSRange(request.byteRange));
////        } else {
////            CBDebug(@"request mp4 path %@ query %@", request.path, request.URL.query);
////        }
//        NSString *uri = request.path;
//        if (request.URL.query) {
//            uri = [NSString stringWithFormat:@"%@?%@", uri, request.URL.query];
//        }
//        if (!strongSelf) {
//            CBError(@"Engine is released");
//        }
//        NSURL *url = [NSURL URLWithString:uri relativeToURL:strongSelf->_originalLocation];
//        NSError *error;
//        NSDictionary *headers = strongSelf->_config.httpHeadersForMp4;
//        SWCNetworkResponse *netResp = [strongSelf requestFromNetworkWithUrl:url req:request headers:headers error:&error];
//        GCDWebServerResponse *resp;
//        if (error) {
//            CBWarn(@"request mp4 failed, error %@ redirect to %@", error, url);
//            completionBlock([GCDWebServerResponse responseWithRedirect:url permanent:NO]);
//            return;
//        }
//        if (strongSelf->_isFirstRequest) {
//            CBDebug(@"mp4 first request");
//            strongSelf->_isFirstRequest = NO;
//        }
//        
////        resp = [GCDWebServerDataResponse responseWithData:netResp.data contentType:netResp.contentType];
//        
//        resp = [GCDWebServerStreamedResponse responseWithContentType:netResp.contentType streamBlock:^NSData * _Nullable(NSError *__autoreleasing  _Nullable * _Nullable error) {
//            return netResp.data;
//        }];
//        resp = [GCDWebServerStreamedResponse responseWithContentType:@"video/mp4" asyncStreamBlock:^(GCDWebServerBodyReaderCompletionBlock  _Nonnull completionBlock) {
//            completionBlock(netResp.data, nil);
//            completionBlock(nil, nil);
//        }];
//        
////            resp = [GCDWebServerResponse responseWithRedirect:strongSelf->_originalURL permanent:NO];
//        
////            for (NSString *field in netResp.headers) {
////                CBDebug(@"add http header %@ %@", field, netResp.headers[field]);
////                [resp setValue:netResp.headers[field] forAdditionalHeader:field];
////            }
//        resp.statusCode = netResp.statusCode;                             // TODO 验证
//        [resp setValue:@"bytes" forAdditionalHeader:@"Accept-Ranges"];
////        [resp setValue:@"0-1/80670065" forAdditionalHeader:@"Content-Range"];
//        [resp setValue:@"video/mp4" forAdditionalHeader:@"Content-Type"];
//        [resp setValue:@"keep-alive" forAdditionalHeader:@"Connection"];
//        resp.contentLength = netResp.data.length;
////        CBDebug(@"resp statusCode %@ data %@ contentType %@", @(resp.statusCode), @(netResp.data.length), netResp.contentType);
//        completionBlock(resp);
//    }];
    
#if TARGET_OS_OSX
    [_webServer startWithPort:_currentPort bonjourName:nil];
#else
    [_webServer startWithOptions:@{
        GCDWebServerOption_AutomaticallySuspendInBackground : @(NO),
        GCDWebServerOption_Port: @(_currentPort),
        GCDWebServerOption_ConnectedStateCoalescingInterval: @3.0,
        GCDWebServerOption_ConnectionClass: [SWCWebServerConnection class],
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
    [super stopP2p];
}

- (void)restartP2p {
    CBInfo(@"mp4 proxy restart p2p");
    [super restartP2p];
    _isFirstRequest = YES;
    
}

- (NSString *)getMediaType {
    return @"mp4";
}

- (void)initTrackerClientWithEndSN:(NSUInteger)sn {
    if (_tracker) return;
    CBInfo(@"Init tracker endSN %@", @(sn));
    // 拼接channelId，并进行url编码和base64编码
    NSString *firstPart;
    NSString *channelIdPrefix = _config.channelIdPrefix;
    if (![_videoId isEqualToString:_originalURL.absoluteString]) {
        if (!channelIdPrefix) {
            NSLog(@"P2P warning: channelIdPrefix is required while using customized channelId!");
            return;
        }
        if (channelIdPrefix.length < 5) {
            NSLog(@"P2P warning: channelIdPrefix length is too short!");
            return;
        } else if (channelIdPrefix.length > 15) {
            NSLog(@"P2P warning: channelIdPrefix length is too long!");
            return;
        }
        firstPart = [NSString stringWithFormat:@"%@%@", channelIdPrefix, _videoId];
    } else {
        NSString *host = _originalURL.host;
        if (_originalURL.port) {
            host = [NSString stringWithFormat:@"%@:%@", host, _originalURL.port];
        }
        firstPart = [NSString stringWithFormat:@"%@%@", host, [_originalURL.relativePath stringByDeletingPathExtension]];
        if (channelIdPrefix) firstPart = [NSString stringWithFormat:@"%@%@", channelIdPrefix, firstPart];
    }
    NSString *channelStr;
    if (_config.wsSignalerAddr) {
        //    CBInfo(@"wsSignalerAddr %@", _p2pConfig.wsSignalerAddr);
        NSURL *signalUrl = [NSURL URLWithString:_config.wsSignalerAddr];
        NSString *secondPart = signalUrl.host;
        if (signalUrl.port) {
            secondPart = [NSString stringWithFormat:@"%@:%@", secondPart, signalUrl.port];
        }
        channelStr = [NSString stringWithFormat:@"%@|%@[%@]", firstPart, secondPart, SWCDataChannel.dcVersion];
    } else {
        channelStr = [NSString stringWithFormat:@"%@|[%@]", firstPart, SWCDataChannel.dcVersion];
    }

    CBInfo(@"channelStr %@", channelStr);
    NSString *urlEncodedStr = [channelStr stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLHostAllowedCharacterSet]];
    NSData *base64Data = [urlEncodedStr dataUsingEncoding:NSUTF8StringEncoding];
    NSString *base64EncodeString = [base64Data base64EncodedStringWithOptions:0];           //base64编码
    CBInfo(@"channel id %@", base64EncodeString);
    _tracker = [SWCTracker.alloc initWithToken:_token BaseUrl:_config.announce channel:base64EncodeString isLive:NO endSN:sn nat:self.natTypeString mediaType:SWCMediaTypeMp4 multiBitrate:NO andConfig:_config];
    
    // TODO
    if ([self.delegate respondsToSelector:@selector(bufferedDuration)]) {
        _tracker.scheduler.delegate = self;    // 设置代理
    }
    
    CBInfo(@"tracker do channelRequest");
    [_tracker channelRequest];
}

@end
