//
//  SWCM3u8Proxy.m
//  SwarmCloudSDK
//
//  Created by Timmy on 2021/5/6.
//  Copyright © 2021 cdnbye. All rights reserved.
//

#import "SWCM3u8Proxy.h"
#import "SWCP2pConfig.h"
#import "GCDWebServer.h"
#import "GCDWebServerDataResponse.h"
#import "CBLogger.h"
#import "SWCUtils.h"
#import "SWCPlaylistUtils.h"
#import "SWCNetworkResponse.h"
#import "SWCByteRange.h"
#import "SWCHlsPredictor.h"
#import "SWCDataChannel.h"
#import "SWCPlaylistInfo.h"
#import "SWCHlsSegment.h"
#import "SWCPlaylistParser.h"

static SWCM3u8Proxy *_instance = nil;

@interface SWCM3u8Proxy()<NSURLSessionTaskDelegate, SWCSchedulerDelegate, GCDWebServerDelegate>
{
    BOOL _isLive;
    BOOL _rangeTested;
    BOOL _m3u8Redirected;
    NSUInteger _endSN;
    NSMutableSet<NSString *> *_mediaListUrls;
    BOOL _scheduledBySegId;
    NSDictionary<NSString *, SWCHlsSegment *> *_segmentMapVod;
    NSCache<NSString *, SWCHlsSegment *> *_segmentMapLive;
    NSLock *_locker;
}
@end

@implementation SWCM3u8Proxy

- (void)initWithTkoen:(NSString *)token config:(SWCP2pConfig *)config
{
    [super initWithTkoen:token config:config];
    [self initVariable];
}

- (void)initVariable {
    _segmentMapVod = [NSDictionary dictionary];
    _segmentMapLive = [NSCache.alloc init];
    _segmentMapLive.countLimit = 60;
    _mediaListUrls = [NSMutableSet set];
    self->_locker = [[NSLock alloc] init];
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
    _currentPort = _config.localPortHls;
    if (_currentPort < 0) return;
    _webServer = [[GCDWebServer alloc] init];
    _webServer.delegate = self;
    [GCDWebServer setLogLevel:3];   // WARN
    
    __weak typeof(self) weakSelf = self;
    
    // .m3u8 handler
    [_webServer addHandlerForMethod:@"GET" pathRegex:@"^/.*\\.m3u8$" requestClass:[GCDWebServerRequest class] processBlock:^GCDWebServerResponse * _Nullable(__kindof GCDWebServerRequest * _Nonnull request) {
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
        if (strongSelf->_m3u8Redirected) {
            url = strongSelf->_originalLocation;
        }
        NSDictionary *headers = strongSelf->_config.httpHeadersForHls;
        SWCNetworkResponse *netResp;
        NSError *error;
        if (strongSelf->_config.sharePlaylist && strongSelf->_tracker) {
            NSString *netUrlString = [url.absoluteString componentsSeparatedByString:@"?"][0];
            SWCPlaylistInfo *playlist = [strongSelf requestPlaylistFromPeerWithUrl:netUrlString];
            if (!playlist) {
                netResp = [strongSelf requestFromNetworkWithUrl:url req:request headers:headers error:&error];
                [strongSelf->_tracker.scheduler broadcastPlaylist:netUrlString data:[NSString.alloc initWithData:netResp.data encoding:NSUTF8StringEncoding]];
            } else {
                netResp = [SWCNetworkResponse.alloc initWithData:[playlist.data dataUsingEncoding:NSUTF8StringEncoding] contentType:@"application/x-mpeg"];
            }
        } else {
            netResp = [strongSelf requestFromNetworkWithUrl:url req:request headers:headers error:&error];
        }
        // 重定向导致url变化
        if (netResp.responseUrl && ![netResp.responseUrl.absoluteString isEqualToString:url.absoluteString]) {
            CBInfo(@"m3u8 request redirected to %@", netResp.responseUrl);
            strongSelf->_originalLocation = netResp.responseUrl;
            url = netResp.responseUrl;
            strongSelf->_m3u8Redirected = YES;
        }
        GCDWebServerResponse *resp;
        if (error) {
            CBWarn(@"request m3u8 failed, error %@ redirect to %@", error, url);
            resp = [GCDWebServerResponse responseWithRedirect:strongSelf->_originalURL permanent:NO];
            return resp;
        }
        NSString *m3u8Text = [[NSString alloc] initWithData:netResp.data encoding:NSUTF8StringEncoding];
        SWCHlsPlaylist *playlist = [SWCPlaylistParser.alloc parseWithUri:url m3u8:m3u8Text error:&error];
        if (error) {
            CBWarn(@"parse m3u8 failed, error %@ redirect to %@", error.userInfo, url);
            resp = [GCDWebServerResponse responseWithRedirect:strongSelf->_originalURL permanent:NO];
            return resp;
        }
        if ([playlist isMemberOfClass:[SWCHlsMasterPlaylist class]]) {
            SWCHlsMasterPlaylist *masterPlaylist = (SWCHlsMasterPlaylist *)playlist;
            for (NSURL *mediaPlaylistUrl in masterPlaylist.mediaPlaylistUrls) {
//                    CBDebug(@"mediaPlaylistUrl %@", [mediaPlaylistUrl absoluteString]);
                [strongSelf->_mediaListUrls addObject:[mediaPlaylistUrl absoluteString]];
            }
            strongSelf->_scheduledBySegId = masterPlaylist.isMultiPlaylisy;
            CBDebug(@"isMultiPlaylisy %@", @(masterPlaylist.isMultiPlaylisy));
            
        } else if ([playlist isMemberOfClass:[SWCHlsMediaPlaylist class]]) {
            SWCHlsMediaPlaylist *mediaPlaylist = (SWCHlsMediaPlaylist *)playlist;
            strongSelf->_isLive = !mediaPlaylist.hasEndTag;
//                CBDebug(@"mediaPlaylist endSN %@", @(mediaPlaylist.endSN));
            if (strongSelf->_isLive) {
                [mediaPlaylist.uriToSegments enumerateKeysAndObjectsUsingBlock:^(NSString * _Nonnull key, SWCHlsSegment * _Nonnull obj, BOOL * _Nonnull stop) {
                    [strongSelf->_segmentMapLive setObject:obj forKey:key];
                }];
                m3u8Text = [SWCPlaylistUtils insertTimeOffsetTag:m3u8Text];
            } else {
                strongSelf->_endSN = mediaPlaylist.endSN;
                strongSelf->_segmentMapVod = mediaPlaylist.uriToSegments;
            }
        }
//            CBInfo(@"original m3u8Text %@", m3u8Text);
        if (strongSelf->_m3u8Redirected) {
//                CBDebug(@"redirectedRewritePlaylist");
            m3u8Text = [SWCPlaylistUtils redirectedRewritePlaylist:m3u8Text baseUri:strongSelf->_originalLocation];
        } else {
//                CBDebug(@"checkAndRewritePlaylist");
            m3u8Text = [SWCPlaylistUtils checkAndRewritePlaylist:m3u8Text];
        }
        resp = [GCDWebServerDataResponse responseWithData:[m3u8Text dataUsingEncoding:NSUTF8StringEncoding] contentType:netResp.contentType];
        return resp;
    }];
    
    // .ts handler
    [_webServer addHandlerForMethod:@"GET" pathRegex:@"^/.*\\.(ts|mp4|m4s)$" requestClass:[GCDWebServerRequest class] asyncProcessBlock:^(__kindof GCDWebServerRequest * _Nonnull request, GCDWebServerCompletionBlock  _Nonnull completionBlock) {

//        CBDebug(@"ts url %@", request.URL.absoluteString);
        __strong typeof(weakSelf) strongSelf = weakSelf;
        CBDebug(@"request ts path %@ query %@", request.path, request.URL.query);
        NSString *uri = request.path;
        NSString *proxyOrigin = [request.query objectForKey:@"_ProxyOrigin_"];
        NSString *proxyTarget = [request.query objectForKey:@"_ProxyTarget_"];
        if (proxyOrigin) {
            uri = [NSString stringWithFormat:@"%@%@", proxyOrigin, uri];
            CBInfo(@"reset uri %@", uri);
        } else if (proxyTarget) {
            uri = proxyTarget;
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
        NSURL *url = [NSURL URLWithString:uri relativeToURL:strongSelf->_originalLocation];
        // 去掉查询参数
        NSString *segmentKey = [url.absoluteString componentsSeparatedByString:@"?"][0];
        if (request.hasByteRange) {
            CBDebug(@"setByteRangeFromNSRange location %@ length %@", @(request.byteRange.location), @(request.byteRange.length));
            segmentKey = [segmentKey stringByAppendingFormat:@"|%@", SWCRangeGetHeaderStringFromNSRange(request.byteRange)];
        }
        SWCHlsSegment *playlistSeg;
        if (strongSelf->_isLive) {
            playlistSeg = [strongSelf->_segmentMapLive objectForKey:segmentKey];
        } else {
            playlistSeg = [strongSelf->_segmentMapVod objectForKey:segmentKey];
        }
        if (!playlistSeg) {
            CBWarn(@"playlistSeg %@ not found fallback", segmentKey);
            completionBlock([GCDWebServerResponse responseWithRedirect:url permanent:NO]);
            return;
        }
        CBDebug(@"segmentKey %@ playlistSeg segId %@", segmentKey, playlistSeg.segId);
        
        NSDictionary *headers = strongSelf->_config.httpHeadersForHls;
        NSError *error;
        if (strongSelf.isConnected && strongSelf->_config.p2pEnabled) {
            [strongSelf->_tracker.scheduler loadSegment:playlistSeg withBlock:^(NSHTTPURLResponse * _Nonnull response, NSData * _Nullable data) {
                GCDWebServerResponse *resp = [GCDWebServerDataResponse responseWithData:data contentType:[SWCHlsSegment getDefaultContentType]];
                [[SWCHlsPredictor sharedInstance] addDuration:playlistSeg.duration];
                completionBlock(resp);
            }];
        } else{
            SWCNetworkResponse *netResp = [strongSelf requestFromNetworkWithUrl:url req:request headers:headers error:&error];
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
                NSLog(@"setDefaultContentType %@", resp.contentType);
                [strongSelf performRangeRequestWithUrl:url];
                CBInfo(@"engine reset HlsPredictor");
                [SWCHlsPredictor.sharedInstance reset];
            }
            [[SWCHlsPredictor sharedInstance] addDuration:playlistSeg.duration];
            completionBlock(resp);
            if (!strongSelf->_tracker && strongSelf->_config.p2pEnabled) {
                if (strongSelf->_config.scheduledBySegId) strongSelf->_scheduledBySegId = YES;
                [strongSelf->_locker lock];
                @try {
                    [strongSelf initTrackerClient:strongSelf->_isLive endSN:strongSelf->_endSN scheduledBySegId:strongSelf->_scheduledBySegId];
                } @catch (NSException *exception) {
                    CBError(@"NSException caught, reason: %@", exception.reason);
                    strongSelf->_config.p2pEnabled = NO;
                }
               [strongSelf->_locker unlock];
            }
        }
    }];

    // other file handler
    [_webServer addHandlerForMethod:@"GET" pathRegex:@"^/.*(?<!(.ts|.m3u8|.mp4|.m4s))$" requestClass:[GCDWebServerRequest class]  processBlock:^GCDWebServerResponse * _Nullable(__kindof GCDWebServerRequest * _Nonnull request) {
        
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
        NSDictionary *headers = strongSelf->_config.httpHeadersForHls;
        SWCNetworkResponse *netResp = [strongSelf requestFromNetworkWithUrl:url req:request headers:headers error:&error];
        GCDWebServerResponse *resp;
        if (error) {
            CBWarn(@"request m3u8 failed, error %@ redirect to %@", error, url);
            resp = [GCDWebServerResponse responseWithRedirect:url permanent:NO];
        } else {
            resp = [GCDWebServerDataResponse responseWithData:netResp.data contentType:netResp.contentType];
            resp.statusCode = netResp.statusCode;
        }
        return resp;
    }];
    
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
}

- (void)restartP2p {
    CBInfo(@"m3u8 proxy restart p2p");
    if (_tracker) [self stopP2p];
     _tracker = nil;
    _rangeTested = NO;
    _isLive = NO;
    [_mediaListUrls removeAllObjects];
    if (_segmentMapVod) _segmentMapVod = nil;
    _scheduledBySegId = NO;
    _m3u8Redirected = NO;
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

#pragma mark - **************** GCDWebServerDelegate

/**
 *  This method is called after the server has successfully started.
 */
- (void)webServerDidStart:(GCDWebServer*)server {
    CBDebug(@"!-> webServerDidStart isRunning %@", @(_webServer.isRunning));
}

/**
 *  This method is called when the first GCDWebServerConnection is opened by the
 *  server to serve a series of HTTP requests.
 *
 *  A series of HTTP requests is considered ongoing as long as new HTTP requests
 *  keep coming (and new GCDWebServerConnection instances keep being opened),
 *  until before the last HTTP request has been responded to (and the
 *  corresponding last GCDWebServerConnection closed).
 */
- (void)webServerDidConnect:(GCDWebServer*)server {
    CBDebug(@"!-> webServerDidConnect isRunning %@", @(_webServer.isRunning));
    // 发起请求时调用
}

/**
 *  This method is called when the last GCDWebServerConnection is closed after
 *  the server has served a series of HTTP requests.
 *
 *  The GCDWebServerOption_ConnectedStateCoalescingInterval option can be used
 *  to have the server wait some extra delay before considering that the series
 *  of HTTP requests has ended (in case there some latency between consecutive
 *  requests). This effectively coalesces the calls to -webServerDidConnect:
 *  and -webServerDidDisconnect:.
 */
- (void)webServerDidDisconnect:(GCDWebServer*)server {
    CBDebug(@"!-> webServerDidDisconnect isRunning %@", @(_webServer.isRunning));
    // 结束请求时调用
}

/**
 *  This method is called after the server has stopped.
 */
- (void)webServerDidStop:(GCDWebServer*)server {
    CBDebug(@"!-> webServerDidStop isRunning %@", @(_webServer.isRunning));
}

@end
