//
//  LineReader.h
//  CDNByeKit
//
//  Created by Timmy on 2021/1/11.
//  Copyright © 2021 cdnbye. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface LineReader : NSObject

@property (nonatomic, readonly, strong) NSArray<NSString*>* lines;
@property (atomic, readonly, assign) NSUInteger index;
    
- (instancetype)initWithText:(NSString*)text;
- (NSString*)next;
- (BOOL)hasNext;
- (instancetype)reset;

@end

NS_ASSUME_NONNULL_END
