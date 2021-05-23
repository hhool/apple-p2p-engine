//
//  SWCHlsSegment.h
//  SwarmCloudSDK
//
//  Created by Timmy on 2021/5/8.
//  Copyright © 2021 cdnbye. All rights reserved.
//

#import "SWCSegment.h"
#import "SWCP2pEngine.h"

NS_ASSUME_NONNULL_BEGIN

@interface SWCHlsSegment : SWCSegment

@property (nonatomic, copy, readonly) NSString *baseUri;           // m3u8

@property (nonatomic, assign, readonly) NSNumber *SN;

@property (nonatomic, assign) NSTimeInterval duration;

+ (void)setSegmentId:(SegmentId) segmentId;

+ (void)setDefaultContentType:(NSString *)contentType;

+ (NSString *)getDefaultContentType;

- (instancetype)initWithBuffer:(NSData *)buf url:(NSString *)urlString sn:(NSNumber *)SN duration:(NSTimeInterval)duration streamId:(NSString *)streamId;

- (instancetype)initWithSN:(NSNumber *)SN url:(NSString *)urlString andDuration:(NSTimeInterval)duration streamId:(NSString *)streamId;

- (instancetype)initWithSN:(NSNumber *)SN url:(NSString *)urlString andDuration:(NSTimeInterval)duration byteRange:(SWCRange)range streamId:(NSString *)streamId;

- (instancetype)initWithBuffer:(NSData *)buf sn:(NSNumber *)SN segId:(NSString *)segId;

@end

NS_ASSUME_NONNULL_END
