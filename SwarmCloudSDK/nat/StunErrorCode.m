//
//  StunErrorCode.m
//  CDNByeKit
//
//  Created by Timmy on 2020/1/15.
//  Copyright © 2020 cdnbye. All rights reserved.
//

#import "StunErrorCode.h"

@implementation StunErrorCode

- (instancetype)initWithCode:(NSInteger)code reasonText:(NSString*)text {
    if(self = [super init]) {
        _code = code;
        _reasonText = text;
    }
    return self;
}

@end
