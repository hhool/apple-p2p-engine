//
//  SWCUtils.h
//  SwarmCloudSDK
//
//  Created by Timmy on 2021/5/5.
//  Copyright © 2021 cdnbye. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SWCSegment.h"
#import "GCDWebServer/GCDWebServerRequest.h"

NS_ASSUME_NONNULL_BEGIN

@interface SWCUtils : NSObject

+ (NSString*)convertToJSONData:(id)infoDict;

+ (NSNumber *)getTimestamp;

+ (NSString *)getNetconnType;

+ (NSString *)MD5:(NSString *)raw;

//+ (NSData *)zlibInflate:(NSData *)compressedData;

+ (BOOL)isVideoContentType:(NSString *) contentType length:(NSUInteger)length;

+ (BOOL)isVideoContentLength:(NSUInteger)length;

+ (NSURL *)getLocationFromURL:(NSURL *)url;

+ (NSString *)removeProxyQuery:(NSDictionary *)query;

+ (NSURLSessionDataTask *)httpLoadSegment:(SWCSegment *)segment timeout:(NSTimeInterval)timeout headers:(NSDictionary *)httpHeaders withBlock:(void(^)(NSHTTPURLResponse *response, NSData *_Nullable data))block;

+ (NSURLSessionDataTask *)httpLoadSegment:(SWCSegment *)segment rangeFrom:(NSUInteger)offset timeout:(NSTimeInterval)timeout headers:(NSDictionary *)httpHeaders withBlock:(void(^)(NSHTTPURLResponse *response, NSData *_Nullable data))block;

@end

NS_ASSUME_NONNULL_END
