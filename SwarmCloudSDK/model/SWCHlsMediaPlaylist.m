//
//  SWCHlsMediaPlaylist.m
//  SwarmCloudSDK
//
//  Created by Timmy on 2021/5/22.
//  Copyright © 2021 cdnbye. All rights reserved.
//

#import "SWCHlsMediaPlaylist.h"

@interface  SWCHlsMediaPlaylist()
{
    NSMutableDictionary<NSString *, SWCHlsSegment *> *_uriToSegmentDict;
}
@end

@implementation SWCHlsMediaPlaylist

- (instancetype)initWithBaseUri:(NSURL *)uri
{
    self = [super initWithBaseUri:uri];
    if (self) {
        _uriToSegmentDict = [NSMutableDictionary dictionary];
    }
    return self;
}

- (void)addSegment:(SWCHlsSegment *)segment forUri:(NSString *)uri {
    [_uriToSegmentDict setObject:segment forKey:uri];
}

- (NSDictionary<NSString *,SWCHlsSegment *> *)uriToSegments {
    return [NSDictionary dictionaryWithDictionary:_uriToSegmentDict];
}

@end
