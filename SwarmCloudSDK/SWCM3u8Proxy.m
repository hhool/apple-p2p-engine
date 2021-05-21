//
//  SWCM3u8Proxy.m
//  SwarmCloudSDK
//
//  Created by Timmy on 2021/5/6.
//  Copyright © 2021 cdnbye. All rights reserved.
//

#import "SWCM3u8Proxy.h"
#import "SWCP2pConfig.h"
#import <GCDWebServer.h>
#import <GCDWebServerDataResponse.h>
#import "CBLogger.h"
#import "SWCUtils.h"
#import "SWCPlaylistUtils.h"
#import "SWCNetworkResponse.h"
#import "SWCByteRange.h"
#import "SWCHlsPredictor.h"
#import "SWCDataChannel.h"
#import "SWCPlaylistInfo.h"
#import "SWCHlsSegment.h"

static SWCM3u8Proxy *_instance = nil;

@interface SWCM3u8Proxy()<NSURLSessionTaskDelegate, SWCSchedulerDelegate>
{
    NSURLSession *_httpSession;
    BOOL _isLive;
    BOOL _rangeTested;
}
@end

@implementation SWCM3u8Proxy

- (void)initWithTkoen:(NSString *)token config:(SWCP2pConfig *)config
{
    _config = config;
    _token = token;
    self->_locker = [[NSLock alloc] init];
    NSURLSessionConfiguration *httpConfig = [NSURLSessionConfiguration defaultSessionConfiguration];
    httpConfig.allowsCellularAccess = YES;
    self->_httpSession = [NSURLSession sessionWithConfiguration:httpConfig delegate:self delegateQueue:[NSOperationQueue mainQueue]];
}

+ (instancetype)sharedInstance {
    
    static dispatch_once_t onceToken = 0;
    dispatch_once(&onceToken, ^{
        _instance = [[self alloc] init];
    });
    return _instance;
    
}

- (void)startLocalServer {
    // 启动本地服务器
    if (_webServer && _webServer.isRunning) return;
    
    _webServer = [[GCDWebServer alloc] init];
    [GCDWebServer setLogLevel:3];   // WARN
    
    __weak typeof(self) weakSelf = self;
    
    // .m3u8 handler
    [_webServer addHandlerForMethod:@"GET" pathRegex:@"^/.*\\.m3u8$" requestClass:[GCDWebServerRequest class] asyncProcessBlock:^(__kindof GCDWebServerRequest * _Nonnull request, GCDWebServerCompletionBlock  _Nonnull completionBlock) {
            
        __strong typeof(weakSelf) strongSelf = weakSelf;
        CBDebug(@"request m3u8 path %@ query %@", request.path, request.URL.query);
        NSString *uri = request.path;
        if (request.URL.query) {
            uri = [NSString stringWithFormat:@"%@?%@", uri, request.URL.query];
        }
        if (!strongSelf) {
            CBError(@"Engine is released");
        }
        NSURL *url = [NSURL URLWithString:uri relativeToURL:strongSelf->_originalLocation];
        SWCNetworkResponse *netResp;
        NSError *error;
        if (strongSelf->_config.isSharePlaylist && strongSelf->_tracker) {
            NSString *netUrlString = [url.absoluteString componentsSeparatedByString:@"?"][0];
            SWCPlaylistInfo *playlist = [strongSelf requestPlaylistFromPeerWithUrl:netUrlString];
            if (!playlist) {
                netResp = [strongSelf requestFromNetworkWithUrl:url req:request error:&error];
                [strongSelf->_tracker.scheduler broadcastPlaylist:netUrlString data:[NSString.alloc initWithData:netResp.data encoding:NSUTF8StringEncoding]];
            } else {
                netResp = [SWCNetworkResponse.alloc initWithData:[playlist.data dataUsingEncoding:NSUTF8StringEncoding] contentType:@"application/x-mpeg"];
            }
        } else {
            netResp = [strongSelf requestFromNetworkWithUrl:url req:request error:&error];
        }
        
        GCDWebServerResponse *resp;
        if (error) {
            CBWarn(@"request m3u8 failed, error %@ redirect to %@", error, url);
            resp = [GCDWebServerResponse responseWithRedirect:strongSelf->_originalURL permanent:NO];
        } else {
            NSString *m3u8Text = [[NSString alloc] initWithData:netResp.data encoding:NSUTF8StringEncoding];
            strongSelf->_isLive = [SWCPlaylistUtils isLivePlaylist:m3u8Text];
            m3u8Text = [SWCPlaylistUtils checkAndRewritePlaylist:m3u8Text isLive:YES];    // TODO
//            CBInfo(@"m3u8Text %@ isLive %@", m3u8Text, @(strongSelf->_isLive));
            if (strongSelf->_isLive) {
                NSString *insertededM3u8 = [SWCPlaylistUtils insertTimeOffsetTag:m3u8Text];
                resp = [GCDWebServerDataResponse responseWithData:[insertededM3u8 dataUsingEncoding:NSUTF8StringEncoding] contentType:netResp.contentType];
            } else {
                resp = [GCDWebServerDataResponse responseWithData:[m3u8Text dataUsingEncoding:NSUTF8StringEncoding] contentType:netResp.contentType];
            }
            
            if (!strongSelf->_tracker && strongSelf->_config.p2pEnabled) {
                [strongSelf->_locker lock];
                @try {
                    [strongSelf initTrackerClient:strongSelf->_isLive endSN:100 scheduledBySegId:YES];    // TODO
                } @catch (NSException *exception) {
                    CBError(@"NSException caught, reason: %@", exception.reason);
                    strongSelf->_config.p2pEnabled = NO;
                }
               [strongSelf->_locker unlock];
            }
            
        }
        completionBlock(resp);
    }];
    
    // .ts handler
    [_webServer addHandlerForMethod:@"GET" pathRegex:@"^/.*\\.(ts|jpg|mp4|m4s)$" requestClass:[GCDWebServerRequest class] asyncProcessBlock:^(__kindof GCDWebServerRequest * _Nonnull request, GCDWebServerCompletionBlock  _Nonnull completionBlock) {

        CBDebug(@"ts url %@", request.URL.absoluteString);
        __strong typeof(weakSelf) strongSelf = weakSelf;
        CBDebug(@"request ts path %@ query %@", request.path, request.URL.query);
        NSString *uri = request.path;
        NSString *proxyOrigin = [request.query objectForKey:@"_ProxyOrigin_"];
        CBInfo(@"");
        if (proxyOrigin) {
            uri = [NSString stringWithFormat:@"%@%@", proxyOrigin, uri];         // TODO
            CBInfo(@"reset uri %@", uri);
        }
        
        if (request.URL.query) {
            NSString *queryStr = [SWCUtils removeProxyQuery:request.query];
            if (queryStr) {
                uri = [NSString stringWithFormat:@"%@?%@", uri, request.URL.query];
            }
        }
        if (!strongSelf) {
            CBError(@"Engine is released");
        }
//        CBInfo(@"proxy load %@", request.query);
        NSNumber *SN = @([[request.query objectForKey:@"_ProxySn_"] integerValue]);
        NSTimeInterval duration = [[request.query objectForKey:@"_ProxyDuration_"] doubleValue];
        NSURL *url = [NSURL URLWithString:uri relativeToURL:strongSelf->_originalLocation];
        NSError *error;
        if (strongSelf.isConnected && strongSelf->_config.p2pEnabled) {
            SWCHlsSegment *segment = [SWCHlsSegment.alloc initWithSN:SN url:url.absoluteString andDuration:duration];
            
            [strongSelf->_tracker.scheduler loadSegment:segment withBlock:^(NSHTTPURLResponse * _Nonnull response, NSData * _Nullable data) {
                GCDWebServerResponse *resp = [GCDWebServerDataResponse responseWithData:data contentType:[SWCHlsSegment getDefaultContentType]];
                [[SWCHlsPredictor sharedInstance] addDuration:duration];
                completionBlock(resp);
            }];
        } else{
            SWCNetworkResponse *netResp = [strongSelf requestFromNetworkWithUrl:url req:request error:&error];
            GCDWebServerResponse *resp;
            if (error) {
                CBWarn(@"request m3u8 failed, error %@ redirect to %@", error, url);
                resp = [GCDWebServerResponse responseWithRedirect:url permanent:NO];
            } else {
                resp = [GCDWebServerDataResponse responseWithData:netResp.data contentType:netResp.contentType];
            }
            if (!strongSelf->_rangeTested) {
                strongSelf->_rangeTested = true;
                [SWCHlsSegment setDefaultContentType:resp.contentType];
//                NSLog(@"setDefaultContentType %@", resp.contentType);
                [strongSelf performRangeRequestWithUrl:url];
                CBInfo(@"engine reset HlsPredictor");
                [SWCHlsPredictor.sharedInstance reset];
            }
            [[SWCHlsPredictor sharedInstance] addDuration:duration];
            completionBlock(resp);
        }
    }];

    // other file handler
    [_webServer addHandlerForMethod:@"GET" pathRegex:@"^/.*(?<!(.ts|.m3u8|.jpg|.mp4|.m4s))$" requestClass:[GCDWebServerRequest class] asyncProcessBlock:^(__kindof GCDWebServerRequest * _Nonnull request, GCDWebServerCompletionBlock  _Nonnull completionBlock) {

        __strong typeof(weakSelf) strongSelf = weakSelf;
        CBDebug(@"request other file path %@ query %@", request.path, request.URL.query);
        NSString *uri = request.path;
        if (request.URL.query) {
            uri = [NSString stringWithFormat:@"%@?%@", uri, request.URL.query];
        }
        if (!strongSelf) {
            CBError(@"Engine is released");
        }
        NSURL *url = [NSURL URLWithString:uri relativeToURL:strongSelf->_originalLocation];
        NSError *error;
        SWCNetworkResponse *netResp = [strongSelf requestFromNetworkWithUrl:url req:request error:&error];
        GCDWebServerResponse *resp;
        if (error) {
            CBWarn(@"request m3u8 failed, error %@ redirect to %@", error, url);
            resp = [GCDWebServerResponse responseWithRedirect:url permanent:NO];
        } else {
            resp = [GCDWebServerDataResponse responseWithData:netResp.data contentType:netResp.contentType];
        }
        completionBlock(resp);
    }];
    
    _currentPort = _config.localPortHls;
    [_webServer startWithPort:_currentPort bonjourName:nil];
    _currentPort = _webServer.port;
    CBInfo(@"Hls listening Port: %@", @(_currentPort));
}

- (void)shutdown {
    [self stopP2p];
    if (_webServer && _webServer.isRunning) {
        [_webServer stop];
    }
}

- (void)stopP2p {
    CBInfo(@"m3u8 proxy stop p2p");
    if (_tracker) {
        [_tracker stopP2p];
    }
    _rangeTested = NO;
    _isLive = NO;
}

- (void)restartP2p {
    CBInfo(@"m3u8 proxy restart p2p");
    if (_tracker) [self stopP2p];
     _tracker = nil;
}

- (NSString *) getMediaType {
    return @"hls";
}

- (BOOL)isConnected {
    return _tracker && _tracker.connected;
}

- (NSString *)getPeerId {
    if (_tracker && _tracker.peerId) {
        return _tracker.peerId;
    }
    return nil;
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

- (SWCNetworkResponse *)requestFromNetworkWithUrl:(NSURL *)url req:(GCDWebServerRequest *)request error:(NSError **)err{
    CBInfo(@"requestFromNetworkWithUrl %@", [url absoluteString]);
    NSTimeInterval timeout = 10.0f;
    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:url];
    
    // 处理headers
    NSDictionary *headers = _config.httpHeadersForHls;
    if (headers) {
        for (NSString *key in headers) {
            [req addValue:[headers objectForKey:key]  forHTTPHeaderField:key];
        }
    }
    
    // 处理range
    if (request.hasByteRange) {
//        NSString *range = [NSString stringWithFormat:@"bytes=%@-%@", @(request.byteRange.location), @(request.byteRange.location + request.byteRange.length-1)];
        NSString *rangeHeader = SWCRangeGetHeaderStringFromNSRange(request.byteRange);
        CBInfo(@"range %@", rangeHeader);
        
        [req addValue:rangeHeader  forHTTPHeaderField:@"Range"];
    }
    
    __block NSData *respData;
    __block NSString *mime = @"";
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    NSURLSessionDataTask *dataTask = [self->_httpSession dataTaskWithRequest:req completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        if (data && (error == nil)) {
            // 网络访问成功
            respData = data;
            mime = response.MIMEType;
            
        } else {
            // 网络访问失败
            NSLog(@"failed to request m3u8 from %@ %@", req.URL.absoluteString, error.userInfo);
            
            
        }
        dispatch_semaphore_signal(semaphore);
    }];
    [dataTask resume];
    dispatch_semaphore_wait(semaphore, dispatch_time(DISPATCH_TIME_NOW, timeout * NSEC_PER_SEC));
    if (!respData && err) {
        NSString *errMsg = [NSString stringWithFormat:@"failed to request %@", url];
        *err = [NSError errorWithDomain:@"NetworkResponse" code:-908 userInfo:@{NSLocalizedDescriptionKey:errMsg}];
    }
    return [SWCNetworkResponse.alloc initWithData:respData contentType:mime];
}

- (SWCPlaylistInfo *)requestPlaylistFromPeerWithUrl:(NSString *)urlString {
    // 首先从peers中寻找请求的m3u8，如果找不到则用http请求。
    if ([_tracker.scheduler isPlayListMapContainsUrl:urlString]) {
        SWCPlaylistInfo *playlistInfo = [_tracker.scheduler getPlaylistFromPeerWithUrl:urlString];
        if (playlistInfo) {
            CBInfo(@"got playlist from peer size %@", @(playlistInfo.data.length));
            return playlistInfo;
        }
    }
    return nil;
}

- (void)initTrackerClient:(BOOL)isLive endSN:(NSUInteger)sn scheduledBySegId:(BOOL)scheduledBySegId {
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
    _tracker = [SWCTracker.alloc initWithToken:_token BaseUrl:_config.announce channel:base64EncodeString isLive:isLive endSN:sn nat:self.natTypeString mediaType:SWCMediaTypeHls multiBitrate:scheduledBySegId andConfig:_config];
    
    // TODO
    if ([self.delegate respondsToSelector:@selector(bufferedDuration)]) {
        _tracker.scheduler.delegate = self;    // 设置代理
    }
    
    CBInfo(@"tracker do channelRequest");
    [_tracker channelRequest];
}

// 发起Range测试请求
- (void)performRangeRequestWithUrl:(NSURL *)url {
    if (!_config.useHttpRange) return;

    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:url cachePolicy:NSURLRequestUseProtocolCachePolicy timeoutInterval:5.0];
    [req setValue:@"bytes=0-1"  forHTTPHeaderField:@"Range"];

    // 处理headers
    NSDictionary *headers = _config.httpHeadersForHls;
    if (headers) {
        for (NSString *key in headers) {
            [req addValue:[headers objectForKey:key]  forHTTPHeaderField:key];
        }
    }
    NSURLSession *sharedSession = [NSURLSession sharedSession];
    __weak typeof(self) weakSelf = self;
    NSURLSessionDataTask *dataTask = [sharedSession dataTaskWithRequest:req completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (data && (error == nil)) {
            // 网络访问成功
            if (((NSHTTPURLResponse *)response).statusCode == 206) {
                strongSelf->_tracker.scheduler.isHttpRangeSupported = YES;
                CBInfo(@"http range request is supported");
            } else {
                CBInfo(@"http range request is not supported");
            }
        } else {
            // 网络访问失败
            CBWarn(@"http range request failed");
        }
    }];
    [dataTask resume];
}

@end
