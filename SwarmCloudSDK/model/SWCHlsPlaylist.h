//
//  SWCHlsPlaylist.h
//  SwarmCloudSDK
//
//  Created by Timmy on 2021/5/22.
//  Copyright © 2021 cdnbye. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface SWCHlsPlaylist : NSObject

@property (nonatomic, copy, readonly) NSURL *baseUri;

- (instancetype)initWithBaseUri:(NSURL *)uri;

@end

NS_ASSUME_NONNULL_END
