//
//  SWCSegment.m
//  SwarmCloudSDK
//
//  Created by Timmy on 2021/5/8.
//  Copyright © 2021 cdnbye. All rights reserved.
//

#import "SWCSegment.h"
#import "SWCByteRange.h"

@implementation SWCSegment

- (instancetype)initWithSegId:(NSString *)segId url:(NSString *)urlString {
    return [self initWithSegId:segId url:urlString byteRange:SWCRangeInvaild()];
}

- (instancetype)initWithSegId:(NSString *)segId url:(NSString *)urlString byteRange:(SWCRange)range {
    self = [super init];
    if (self) {
        self->_segId = segId;
        self->_urlString = urlString;
        if (range.end != SWCNotFound) {
            self->_hasByteRange = YES;
            self->_byteRange = range;
        } else {
            self->_hasByteRange = NO;
        }
    }
    return self;
}

- (instancetype)initWithBuffer:(NSData *)buf segId:(NSString *)segId url:(NSString *)urlString {
    return [self initWithBuffer:buf segId:segId url:urlString byteRange:SWCRangeInvaild()];
}

- (instancetype)initWithBuffer:(NSData *)buf segId:(NSString *)segId url:(NSString *)urlString byteRange:(SWCRange)range
{
    self = [super init];
    if (self) {
        self->_segId = segId;
        self->_buffer = buf;
        self->_urlString = urlString;
        if (range.end != SWCNotFound) {
            self->_hasByteRange = YES;
            self->_byteRange = range;
        } else {
            self->_hasByteRange = NO;
        }
    }
    return self;
}

- (void)encodeWithCoder:(nonnull NSCoder *)aCoder {
    [aCoder encodeObject:self.segId forKey:@"segId"];
    [aCoder encodeDataObject:self.buffer];
}

- (nullable instancetype)initWithCoder:(nonnull NSCoder *)aDecoder {
    if (self = [super init]) {
        _segId = [aDecoder decodeObjectForKey:@"segId"];
        _buffer = [aDecoder decodeDataObject];
    }
    return self;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<%@: %p, %@>",
            [self class],
            self,
            @{
                @"_segId": _segId,
                @"range": SWCStringFromRange(_byteRange),
                @"urlString": _urlString,
            }
            ];
}

- (NSString *)rangeStringForHeader {
    return SWCRangeGetHeaderString(_byteRange);
}

- (void)setByteRangeFromNSRange:(NSRange)range {
    self->_byteRange = SWCMakeRange(range.location, range.location + range.length - 1);
    self->_hasByteRange = YES;
}

@end
