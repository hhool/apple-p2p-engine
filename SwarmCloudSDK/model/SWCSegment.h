//
//  SWCSegment.h
//  SwarmCloudSDK
//
//  Created by Timmy on 2021/5/8.
//  Copyright © 2021 cdnbye. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SWCByteRange.h"

NS_ASSUME_NONNULL_BEGIN

@interface SWCSegment : NSObject <NSCoding>

@property (nonatomic, strong) NSData *buffer;

@property (nonatomic, copy, readonly) NSString *segId;

@property (nonatomic, copy, readonly) NSString *urlString;

@property (nonatomic, assign, readonly) SWCRange byteRange;

@property (nonatomic, assign, readonly) BOOL hasByteRange;

- (instancetype)initWithBuffer:(NSData *)buf segId:(NSString *)segId url:(NSString *)urlString;

- (instancetype)initWithBuffer:(NSData *)buf segId:(NSString *)segId url:(NSString *)urlString byteRange:(SWCRange)range;

- (instancetype)initWithSegId:(NSString *)segId url:(NSString *)urlString;

- (instancetype)initWithSegId:(NSString *)segId url:(NSString *)urlString byteRange:(SWCRange)range;

- (NSString *)rangeStringForHeader;

- (void)setByteRangeFromNSRange:(NSRange)range;

@end

NS_ASSUME_NONNULL_END
