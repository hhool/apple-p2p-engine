//
//  SWCPeer.h
//  SwarmCloudSDK
//
//  Created by Timmy on 2021/5/8.
//  Copyright © 2021 cdnbye. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface SWCPeer : NSObject

@property (nonatomic, copy, readonly) NSString *peerId;

@property (nonatomic, copy, readonly) NSString *intermediator;

- (instancetype)initWithId:(NSString *)peerId intermediator:(NSString *)intermediator;

- (instancetype)initWithId:(NSString *)peerId;

- (instancetype)init NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END
