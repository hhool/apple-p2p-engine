//
//  StunErrorCode.h
//  CDNByeKit
//
//  Created by Timmy on 2020/1/15.
//  Copyright © 2020 cdnbye. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface StunErrorCode : NSObject

@property(nonatomic, assign, readonly) NSInteger code;

@property(nonatomic, copy, readonly) NSString* reasonText;

- (instancetype)initWithCode:(NSInteger)code reasonText:(NSString*)text;

@end

NS_ASSUME_NONNULL_END
