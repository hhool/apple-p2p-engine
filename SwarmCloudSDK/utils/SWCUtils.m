//
//  SWCUtils.m
//  SwarmCloudSDK
//
//  Created by Timmy on 2021/5/5.
//  Copyright © 2021 cdnbye. All rights reserved.
//

#import "SWCUtils.h"
#import <CommonCrypto/CommonCrypto.h>
#import <zlib.h>
#import "CBLogger.h"
#import "SWCP2pEngine.h"
#if !TARGET_OS_OSX
#import "CBReachability.h"
# endif
#import "SWCSegment.h"


@implementation SWCUtils

+ (NSString*)convertToJSONData:(id)infoDict
{
    NSError *error;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:infoDict
                                                       options:NSJSONWritingPrettyPrinted // Pass 0 if you don't care about the readability of the generated string
                                                         error:&error];
    
    NSString *jsonString = @"";
    
    if (!jsonData)
    {
        NSLog(@"Got an error: %@", error);
    }else
    {
        jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
    }
    
    jsonString = [jsonString stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];  //去除掉首尾的空白字符和换行字符
    
    [jsonString stringByReplacingOccurrencesOfString:@"\n" withString:@""];
    
    return jsonString;
}

+ (NSNumber *)getTimestamp {
    NSTimeInterval interval = [[NSDate date] timeIntervalSince1970];
    NSString *strVal = [NSString stringWithFormat:@"%.0f", interval];
    return @([strVal integerValue]);
}

+ (NSString *)getNetconnType{
    
    NSString *netconnType = @"wifi";
    
# if !TARGET_OS_OSX
    CBReachability *reach = [CBReachability reachabilityWithHostName:@"www.apple.com"];

    switch ([reach currentReachabilityStatus]) {
        case NotReachable:// 没有网络
        {
            
            netconnType = @"non_network";
        }
            break;
            
        case ReachableViaWiFi:// Wifi
        {
            netconnType = @"wifi";
        }
            break;
            
        case ReachableViaWWAN:// 手机自带网络
        {
            netconnType = @"cellular";
        }
            break;
            
        default:
            break;
    }
# endif
    return netconnType;
}

+ (NSString *)MD5:(NSString *)raw
{
    const char *cStr = [raw UTF8String];
    unsigned char digest[16];
    unsigned int x=(int)strlen(cStr) ;
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    CC_MD5( cStr, x, digest );
#pragma clang diagnostic pop
    // This is the md5 call
    NSMutableString *output = [NSMutableString stringWithCapacity:CC_MD5_DIGEST_LENGTH * 2];

    for(int i = 0; i < CC_MD5_DIGEST_LENGTH; i++)
        [output appendFormat:@"%02x", digest[i]];

    return  output;
}

// 检查是否video的contentType
+ (BOOL)isVideoContentType:(NSString *) contentType length:(NSUInteger)length {
    if (contentType == nil || [contentType isEqualToString:@""]) return NO;
    if (length <= 10000) return NO;
    return ![contentType containsString:@"text"] && ![contentType containsString:@"xml"] && ![contentType containsString:@"json"];
}

// 检查二进制长度
+ (BOOL)isVideoContentLength:(NSUInteger)length {
    return length > 10000;
}

// 获取 http://host:port
+ (NSURL *)getLocationFromURL:(NSURL *)url {
    NSString *scheme = url.scheme;
    NSString *host = url.host;
    NSString *location = [NSString stringWithFormat:@"%@://%@", scheme, host];
    if (url.port) {
        location = [NSString stringWithFormat:@"%@:%@", location, url.port];
    }
    return [NSURL URLWithString:location];
}

+ (NSString *)removeProxyQuery:(NSDictionary *)queryD {
    if (queryD.count == 0) return nil;
    NSString *query = @"?";
    for (NSString *key in queryD) {
        if ([key hasPrefix:@"_Proxy"]) {
            continue;
        }
        query = [NSString stringWithFormat:@"%@&%@=%@", query, key, [queryD objectForKey:key]];
    }
    return [query isEqualToString:@"?"] ? nil : query;
}

+ (NSURLSessionDataTask *)httpLoadSegment:(SWCSegment *)segment timeout:(NSTimeInterval)timeout headers:(NSDictionary *)httpHeaders withBlock:(void(^)(NSHTTPURLResponse *response, NSData *_Nullable data))block {
    
    NSString *segId = segment.segId;
    NSString *url = segment.urlString;
    CBInfo(@"request ts from http %@ segId %@", url, segId);
    
    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:url] cachePolicy:NSURLRequestUseProtocolCachePolicy timeoutInterval:timeout];
    
    // 处理range请求
    if (segment.hasByteRange) {
        [req setValue:[segment rangeStringForHeader]  forHTTPHeaderField:@"Range"];
    }
    // 处理headers
//    NSLog(@"test %@", [CBGlobal sharedInstance].p2pConfig.httpHeaders);
    if (httpHeaders) {
        for (NSString *key in httpHeaders) {
            [req addValue:[httpHeaders objectForKey:key]  forHTTPHeaderField:key];
        }
        
    }
    
    return [SWCUtils requestDataWithRequest:req block:^(NSHTTPURLResponse *response, NSData * _Nullable data) {
        if (data) {
            CBInfo(@"receive ts from http size %@ segId %@", @(data.length), segId);
            
            // 更新时间
//            [[CBTimer sharedInstance] updateAvailableSpanWithSegmentDuration:segment.duration];
//            [[CBHlsPredictor sharedInstance] addDuration:segment.duration];
        }
        block(response, data);
    }];
    
    // test 下载超时测试
//    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
//        [dataTask resume];
//    });
}

+ (NSURLSessionDataTask *)httpLoadSegment:(SWCSegment *)segment rangeFrom:(NSUInteger)offset timeout:(NSTimeInterval)timeout headers:(NSDictionary *)httpHeaders withBlock:(void(^)(NSHTTPURLResponse *response, NSData *_Nullable data))block {
    
    NSString *segId = segment.segId;
    NSString *url = segment.urlString;
    
    
    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:url] cachePolicy:NSURLRequestUseProtocolCachePolicy timeoutInterval:timeout];
    
    // 处理range请求
    NSString *range;
    if (segment.hasByteRange) {
        range = [NSString stringWithFormat:@"bytes=%@-%@", @(offset), @(segment.byteRange.end)];
    } else {
        range = [NSString stringWithFormat:@"bytes=%@-", @(offset)];
    }
    CBInfo(@"request ts from http %@ segId %@ range: %@", url, segId, range);
    
    [req setValue:range  forHTTPHeaderField:@"Range"];
    
    if (httpHeaders) {
        for (NSString *key in httpHeaders) {
            [req addValue:[httpHeaders objectForKey:key]  forHTTPHeaderField:key];
        }
        
    }
    
    return [SWCUtils requestDataWithRequest:req block:^(NSHTTPURLResponse *response, NSData * _Nullable data) {
        if (data) {
            CBInfo(@"receive ts from http size %@ segId %@", @(data.length), segId);
           
            // 更新时间
//            [[CBTimer sharedInstance] updateAvailableSpanWithSegmentDuration:segment.duration];
//             [[CBHlsPredictor sharedInstance] addDuration:segment.duration];
        }
        block((NSHTTPURLResponse *)response, data);
    }];
}

+ (NSURLSessionDataTask *)requestDataWithRequest:(NSMutableURLRequest *)req block:(void(^)(NSHTTPURLResponse *response, NSData *_Nullable data))block {
    NSURLSession *sharedSession = [NSURLSession sharedSession];
    NSURLSessionDataTask *dataTask = [sharedSession dataTaskWithRequest:req completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        if (data && (error == nil)) {
            // 网络访问成功
            block((NSHTTPURLResponse *)response, data);
            
            // 上报http流量
            NSUInteger size = data.length/1024;
            NSDictionary *message = @{@"httpDownloaded": @(size)};
            // TODO
            [[NSNotificationCenter defaultCenter] postNotificationName:kP2pEngineDidReceiveStatistics object:message];
        } else {
            // 网络访问失败
            CBWarn(@"failed to request ts from %@ %@", req.URL.absoluteString, error.userInfo);
            if (error.code == -1001) {
                CBWarn(@"请求ts超时");
            }
            block((NSHTTPURLResponse *)response, nil);
        }
    }];
    [dataTask resume];
    return dataTask;
}

@end
