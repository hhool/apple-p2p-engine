//
//  LineReader.m
//  CDNByeKit
//
//  Created by Timmy on 2021/1/11.
//  Copyright © 2021 cdnbye. All rights reserved.
//

#import "LineReader.h"

@implementation LineReader
- (instancetype)initWithText:(NSString*)text
{
    self = [super init];
    if (self) {
        _lines = [text componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];
    }
    return self;
}

- (NSString*)next {
    while (_index < _lines.count) {
        NSString* line = [_lines[_index] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        _index++;
        
        if (line.length > 0) {
            return line;
        }
    }
    return nil;
}

- (BOOL)hasNext {
    return _index < _lines.count;
}

- (instancetype)reset {
    _index = 0;
    return self;
}

@end
