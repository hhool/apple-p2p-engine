//
//  SWCMp4Proxy.h
//  SwarmCloudSDK
//
//  Created by Timmy on 2021/5/6.
//  Copyright © 2021 cdnbye. All rights reserved.
//

#import "SWCProxy.h"
#import "SWCP2pConfig.h"

NS_ASSUME_NONNULL_BEGIN

@interface SWCMp4Proxy : SWCProxy


- (void)initWithTkoen:(NSString *)token config:(SWCP2pConfig *)config;

+ (instancetype)sharedInstance;

@end

NS_ASSUME_NONNULL_END
