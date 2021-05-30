//
//  SWCPlaylistParser.m
//  SwarmCloudSDK
//
//  Created by Timmy on 2021/5/21.
//  Copyright © 2021 cdnbye. All rights reserved.
//

#import "SWCPlaylistParser.h"
#import "SWCError.h"
#import "LineReader.h"
#import "CBLogger.h"

#define HLS_PREFIX_TAG @"#"
#define HLS_SUFFIX_CONTINUE @"\\"
#define HLS_PREFIX_FILE_FIRST_LINE @"#EXTM3U"
#define HLS_TAG_STREAM_INF @"#EXT-X-STREAM-INF"
#define HLS_TAG_TARGET_DURATION @"#EXT-X-TARGETDURATION"
#define HLS_TAG_MEDIA_SEQUENCE @"#EXT-X-MEDIA-SEQUENCE"
#define HLS_TAG_MEDIA_DURATION @"#EXTINF"
#define HLS_TAG_KEY @"#EXT-X-KEY"
#define HLS_TAG_SESSION_KEY @"#EXT-X-SESSION-KEY"
#define HLS_TAG_BYTERANGE @"#EXT-X-BYTERANGE"
#define HLS_TAG_DISCONTINUITY @"#EXT-X-DISCONTINUITY"
#define HLS_TAG_DISCONTINUITY_SEQUENCE @"#EXT-X-DISCONTINUITY-SEQUENCE"
#define HLS_TAG_ENDLIST @"#EXT-X-ENDLIST"

@implementation SWCPlaylistParser

- (SWCHlsPlaylist *)parseWithUri:(NSURL *)uri m3u8:(NSString *)m3u8 error:(NSError **)err {
    LineReader* reader = [[LineReader alloc] initWithText:m3u8];
    NSString* line = [reader next];
    if (![line hasPrefix:HLS_PREFIX_FILE_FIRST_LINE]) {
        if (err) {
            *err = [SWCError errorForExceptionWithReason:@"Input does not start with the #EXTM3U header."];
        }
        return nil;
    }
    while ([reader hasNext]) {
        line = [reader next];
        if ([line isEqualToString:@""]) {
            // Do nothing
        } else if ([line hasPrefix:HLS_TAG_STREAM_INF]) {
            return [self parseMasterPlaylistWithUri:uri reader:reader.reset];
        } else if ([line hasPrefix:HLS_TAG_TARGET_DURATION] ||
                   [line hasPrefix:HLS_TAG_MEDIA_SEQUENCE] ||
                   [line hasPrefix:HLS_TAG_KEY] ||
                   [line hasPrefix:HLS_TAG_BYTERANGE] ||
                   [line isEqualToString:HLS_TAG_DISCONTINUITY] ||
                   [line isEqualToString:HLS_TAG_DISCONTINUITY_SEQUENCE] ||
                   [line isEqualToString:HLS_TAG_ENDLIST]) {
            return [self parseMediaPlaylistWithUri:uri reader:reader.reset];
        }
    }
    if (err) {
        *err = [SWCError errorForExceptionWithReason:@"Failed to parse the playlist, could not identify any tags."];
    }
    return nil;
}

- (SWCHlsMasterPlaylist *)parseMasterPlaylistWithUri:(NSURL *)uri reader:(LineReader *)reader {
    SWCHlsMasterPlaylist *playlist = [SWCHlsMasterPlaylist.alloc initWithBaseUri:uri];
    NSString* line;
    while ([reader hasNext]) {
        line = [reader next];
        if ([line hasPrefix:HLS_TAG_STREAM_INF]) {
            line = [reader next];
            if (![line hasPrefix:HLS_PREFIX_TAG] && ![line hasSuffix:HLS_SUFFIX_CONTINUE]) {
                // URI
                NSURL *streamUrl = [NSURL URLWithString:line relativeToURL:playlist.baseUri];
                [playlist addMediaPlaylistUrl:streamUrl];
            }
        }
    }
    return playlist;
}

- (SWCHlsMediaPlaylist *)parseMediaPlaylistWithUri:(NSURL *)uri reader:(LineReader *)reader {
    SWCHlsMediaPlaylist *playlist = [SWCHlsMediaPlaylist.alloc initWithBaseUri:uri];
    NSTimeInterval segmentDuration = 0.0;;
    NSUInteger mediaSequence = 0;
    NSUInteger segmentMediaSequence = 0;
    NSInteger segmentByteRangeLength = NSNotFound;
    NSInteger segmentByteRangeOffset = 0;
    NSString * line;
    while ([reader hasNext]) {
        line = [reader next];
        if ([line hasPrefix:HLS_TAG_MEDIA_SEQUENCE]) {
            NSRange range = [line rangeOfString:@"#EXT-X-MEDIA-SEQUENCE:"];
            mediaSequence = [[line substringFromIndex:range.location + range.length] integerValue];
            playlist.mediaSequence = mediaSequence;
            segmentMediaSequence = mediaSequence;
        }
        else if ([line hasPrefix:HLS_TAG_TARGET_DURATION]) {
            NSRange range = [line rangeOfString:@"#EXT-X-TARGETDURATION:"];
            playlist.targetDuration = [[line substringFromIndex:range.location + range.length] doubleValue];
//            CBDebug(@"targetDuration %@", @(playlist.targetDuration));
        }
        else if ([line hasPrefix:HLS_TAG_MEDIA_DURATION]) {
            line = [line stringByReplacingOccurrencesOfString:@"#EXTINF:" withString:@""];
            line = [line stringByReplacingOccurrencesOfString:@"," withString:@""];
            segmentDuration = [line doubleValue];
        }
        else if ([line hasPrefix:HLS_TAG_BYTERANGE]) {
            line = [line stringByReplacingOccurrencesOfString:@"#EXT-X-BYTERANGE:" withString:@""];
            NSArray<NSString *> *splitByteRange = [line componentsSeparatedByString:@"@"];
            segmentByteRangeLength = [splitByteRange[0] integerValue];
            if (splitByteRange.count > 1) {
                segmentByteRangeOffset = [splitByteRange[1] integerValue];
            }
        }
        else if ([line hasPrefix:HLS_TAG_ENDLIST]) {
            playlist.hasEndTag = YES;
        }
        else if (line && ![line hasPrefix:HLS_PREFIX_TAG]) {
            // uri
//            CBDebug(@"line %@ playlist.baseUri %@ ", line, playlist.baseUri);
            NSURL *segmentUrl = [NSURL URLWithString:line relativeToURL:playlist.baseUri];
            NSString *urlString = segmentUrl.absoluteString;
            SWCRange range = SWCRangeInvaild();
            if (segmentByteRangeLength == NSNotFound) {
                // The segment is not byte range defined.
                segmentByteRangeOffset = 0;
            } else {
                range = SWCMakeRange(segmentByteRangeOffset, segmentByteRangeOffset+segmentByteRangeLength-1);
            }
//            CBDebug(@"SWCHlsSegment sn %@ duration %@ urlString %@ range %@", @(segmentMediaSequence), @(segmentDuration), urlString, SWCStringFromRange(range));
            SWCHlsSegment *segment = [SWCHlsSegment.alloc initWithSN:@(segmentMediaSequence) url:urlString andDuration:segmentDuration byteRange:range streamId:uri.absoluteString];  // TODO
            urlString = [urlString componentsSeparatedByString:@"?"][0];
            if (SWCRangeIsVaild(range)) {
                urlString = [urlString stringByAppendingFormat:@"|%@", SWCRangeGetHeaderString(range)];
            }
            [playlist addSegment:segment forUri:urlString];
            segmentMediaSequence ++;
            if (segmentByteRangeLength != NSNotFound) {
                segmentByteRangeOffset += segmentByteRangeLength;
            }
            segmentByteRangeLength = NSNotFound;
        }
    }
    playlist.endSN = segmentMediaSequence;
    return playlist;
}

@end
