//
//  SWCM3u8Proxy.h
//  SwarmCloudSDK
//
//  Created by Timmy on 2021/5/6.
//  Copyright © 2021 cdnbye. All rights reserved.
//

#import "SWCProxy.h"

NS_ASSUME_NONNULL_BEGIN

@interface SWCM3u8Proxy : SWCProxy

- (void)initWithTkoen:(NSString *)token config:(SWCP2pConfig *)config;

+ (instancetype)sharedInstance;



@end

NS_ASSUME_NONNULL_END
