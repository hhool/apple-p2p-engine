//
//  StunChangeRequest.h
//  CDNByeKit
//
//  Created by Timmy on 2020/1/15.
//  Copyright © 2020 cdnbye. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface StunChangeRequest : NSObject

@property(nonatomic, assign, readonly) BOOL changeIp;

@property(nonatomic, assign, readonly) BOOL changePort;

- (instancetype)initWithChangeIp:(BOOL)changeIp changePort:(BOOL)changePort;

@end

NS_ASSUME_NONNULL_END
