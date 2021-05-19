//
//  SWCPlaylistInfo.h
//  SwarmCloudSDK
//
//  Created by Timmy on 2021/5/13.
//  Copyright © 2021 cdnbye. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface SWCPlaylistInfo : NSObject

@property (nonatomic, copy, readonly) NSString *data;

@property (nonatomic, copy, readonly) NSString *md5;

@property (nonatomic, copy, readonly) NSNumber *ts;

- (instancetype)initWithTs:(NSNumber *)ts data:(NSString *)data;

- (instancetype)initWithMd5:(NSString *)md5 ts:(NSNumber *)ts;

@end

NS_ASSUME_NONNULL_END
