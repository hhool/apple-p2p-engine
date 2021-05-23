//
//  SWCHlsMediaPlaylist.h
//  SwarmCloudSDK
//
//  Created by Timmy on 2021/5/22.
//  Copyright © 2021 cdnbye. All rights reserved.
//

#import "SWCHlsPlaylist.h"
#import "SWCHlsSegment.h"

NS_ASSUME_NONNULL_BEGIN

@interface SWCHlsMediaPlaylist : SWCHlsPlaylist

@property (nonatomic, readonly, copy) NSURL *URI;

/**
 * The target duration in seconds, as defined by #EXT-X-TARGETDURATION.
 */
@property (nonatomic, assign) NSTimeInterval targetDuration;

/**
 * Whether the playlist contains the #EXT-X-ENDLIST tag.
 */
@property (nonatomic, assign) BOOL hasEndTag;

@property (nonatomic, assign) NSUInteger endSN;

/**
 * The media sequence number of the first media segment in the playlist, as defined by
 * #EXT-X-MEDIA-SEQUENCE.
 */
@property (nonatomic, assign) NSUInteger mediaSequence;

@property (nonatomic, readonly, strong) NSDictionary<NSString *, SWCHlsSegment *> *uriToSegments;

- (void)addSegment:(SWCHlsSegment *)segment forUri:(NSString *)uri;

@end

NS_ASSUME_NONNULL_END
