//
//  NetworkResponse.h
//  SwarmCloudSDK
//
//  Created by Timmy on 2021/5/7.
//  Copyright © 2021 cdnbye. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface SWCNetworkResponse : NSObject

@property(nonatomic, copy, readonly) NSString *contentType;
@property(nonatomic, strong, readonly) NSData *data;          // 如果没有数据为 nil

- (instancetype)initWithData:(NSData *_Nullable)data contentType:(NSString *)type;

- (instancetype)initWithNoResponse;

@end

NS_ASSUME_NONNULL_END
