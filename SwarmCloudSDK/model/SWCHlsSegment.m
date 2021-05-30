//
//  SWCHlsSegment.m
//  SwarmCloudSDK
//
//  Created by Timmy on 2021/5/8.
//  Copyright © 2021 cdnbye. All rights reserved.
//

#import "SWCHlsSegment.h"

static NSString *CONTENT_TYPE = @"video/mp2t";

@implementation SWCHlsSegment

static SegmentId segmengId = ^NSString * _Nonnull(NSString * _Nonnull streamId, NSNumber *sn, NSString * _Nonnull segmentUrl, SWCRange byteRange) {
//    NSLog(@"streamId %@", streamId);
    NSString *segId = segmentUrl;
    segId = [segmentUrl componentsSeparatedByString:@"?"][0];
    if ([segId hasPrefix:@"http://"]) {
        segId = [segId stringByReplacingOccurrencesOfString:@"http://" withString:@""];
    } else if ([segId hasPrefix:@"https://"]) {
        segId = [segId stringByReplacingOccurrencesOfString:@"https://" withString:@""];
    }
    if (byteRange.start != SWCNotFound) {
        segId = [NSString stringWithFormat:@"%@|%@", segId, SWCRangeGetHeaderString(byteRange)];
    }
    return segId;
};;

+ (void)setSegmentId:(SegmentId)segId {
    segmengId = segId;
}

+ (void)setDefaultContentType:(NSString *)contentType {
    CONTENT_TYPE = contentType;
}

+ (NSString *)getDefaultContentType {
    return CONTENT_TYPE;
}

- (instancetype)initWithBuffer:(NSData * _Nonnull)buf sn:(NSNumber *)SN segId:(NSString *)segId
{
    self = [super initWithBuffer:buf segId:segId url:@""];
    if (self) {
        _SN = SN;
    }
    return self;
}

- (instancetype)initWithBuffer:(NSData *)buf url:(NSString *)urlString sn:(NSNumber *)SN duration:(NSTimeInterval)duration streamId:(NSString *)streamId
{
    self = [super initWithBuffer:buf segId:segmengId(streamId, SN, urlString, SWCRangeInvaild()) url:urlString];
    if (self) {
        _SN = SN;
        _duration = duration;
    }
    return self;
}

- (instancetype)initWithBuffer:(NSData *)buf url:(NSString *)urlString sn:(NSNumber *)SN duration:(NSTimeInterval)duration byteRange:(SWCRange)range streamId:(NSString *)streamId {
    self = [super initWithBuffer:buf segId:segmengId(streamId, SN, urlString, SWCRangeInvaild()) url:urlString byteRange:range];
    if (self) {
        _SN = SN;
        _duration = duration;
    }
    return self;
}

- (instancetype)initWithSN:(NSNumber *)SN url:(NSString *)urlString andDuration:(NSTimeInterval)duration streamId:(NSString *)streamId {
    self = [super initWithSegId:segmengId(streamId, SN, urlString, SWCRangeInvaild()) url:urlString];
    if (self) {
        _SN = SN;
        _duration = duration;
        _baseUri = streamId;
    }
    return self;
}

- (instancetype)initWithSN:(NSNumber *)SN url:(NSString *)urlString andDuration:(NSTimeInterval)duration byteRange:(SWCRange)range streamId:(NSString *)streamId {
    self = [super initWithSegId:segmengId(streamId, SN, urlString, range) url:urlString byteRange:range];
    if (self) {
        _SN = SN;
        _duration = duration;
        _baseUri = streamId;
    }
    return self;
}

- (void)encodeWithCoder:(nonnull NSCoder *)aCoder {
    [aCoder encodeObject:self.SN forKey:@"SN"];
    [aCoder encodeDouble:self.duration forKey:@"duration"];
    [super encodeWithCoder:aCoder];
}

- (nullable instancetype)initWithCoder:(nonnull NSCoder *)aDecoder {
    if (self = [super initWithCoder:aDecoder]) {
        _SN = [aDecoder decodeObjectForKey:@"SN"];
        _duration = [aDecoder decodeDoubleForKey:@"duration"];
    }
    return self;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<%@: %p, %@>",
            [self class],
            self,
            @{
                @"SN": _SN,
                @"duration": @(_duration),
                @"segId": self.segId,
                @"range": SWCStringFromRange(self.byteRange),
            }
            ];
}

@end
