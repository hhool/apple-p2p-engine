//
//  SWCPlaylistUtils.m
//  SwarmCloudSDK
//
//  Created by Timmy on 2021/5/7.
//  Copyright © 2021 cdnbye. All rights reserved.
//

#import "SWCPlaylistUtils.h"
#import "LineReader.h"
#import "SWCUtils.h"

static NSString *const TAG_INIT_SEGMENT = @"#EXT-X-MAP";
static NSString *const TAG_STREAM_INF = @"#EXT-X-STREAM-INF";
static NSString *const TAG_MEDIA_SEQUENCE = @"#EXT-X-MEDIA-SEQUENCE";
static NSString *const TAG_M3U8_EXTINF = @"#EXTINF";
static NSString *const M3U8_EXT_X_ENDLIST = @"#EXT-X-ENDLIST";
@implementation SWCPlaylistUtils

+ (NSString *)checkAndRewritePlaylist:(NSString *)m3u8 isLive:(BOOL)isLive {
    BOOL isAbsoluteUrl = NO;
    NSUInteger snCount = 0;
    float duration = 0.0;
    NSString *m3u8Builder = @"";
    LineReader* lines = [[LineReader alloc] initWithText:m3u8];
    NSString* line = [lines next];
    do {
        if ([line hasPrefix:TAG_STREAM_INF]) {
            return m3u8;
        } else if (isLive && [line hasPrefix:TAG_MEDIA_SEQUENCE]) {
            NSRange range = [line rangeOfString:@"#EXT-X-MEDIA-SEQUENCE:"];
            snCount = [[line substringFromIndex:range.location + range.length] integerValue];
        } else if (isLive && [line hasPrefix:TAG_M3U8_EXTINF]) {
            NSString *str = [line stringByReplacingOccurrencesOfString:@"#EXTINF:" withString:@""];
            duration = [[str stringByReplacingOccurrencesOfString:@"," withString:@""] floatValue];
//            NSLog(@"duration %@", @(duration));
        } else if (![line hasPrefix:@"#"]) {
            // segment uri
            if ([line hasPrefix:@"http"]) {
                isAbsoluteUrl = YES;
                NSURL *url = [NSURL URLWithString:line];
                NSURL *originalLocation = [SWCUtils getLocationFromURL:url];
                // URL编码
                NSString *encodedLocation = [originalLocation.absoluteString stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLHostAllowedCharacterSet]];
                line = url.path;
                NSString *query = url.query;
                if (query) {
                    line = [NSString stringWithFormat:@"%@?%@&_ProxyOrigin_=%@", line, query, encodedLocation];
                } else {
                    line = [NSString stringWithFormat:@"%@?_ProxyOrigin_=%@", line, encodedLocation];
                }
                if (isLive) {
                    line = [NSString stringWithFormat:@"%@&_ProxySn_=%@&_ProxyDuration_=%@", line, @(snCount), @(duration)];
                    snCount ++;
                }
            } else {
                if (!isAbsoluteUrl && !isLive) {
                    return m3u8;
                }
                if ([line containsString:@"?"]) {
                    line = [NSString stringWithFormat:@"%@&_ProxySn_=%@&_ProxyDuration_=%@", line, @(snCount), @(duration)];
                } else {
                    line = [NSString stringWithFormat:@"%@?_ProxySn_=%@&_ProxyDuration_=%@", line, @(snCount), @(duration)];
                }
                snCount ++;
            }
        }
        m3u8Builder = [m3u8Builder stringByAppendingFormat:@"%@\n", line];
        line = [lines next];
    } while(line);
    return m3u8Builder;
}

+ (NSString *)insertTimeOffsetTag:(NSString *)m3u8 {
    NSString *m3u8Builder = @"";
    LineReader* lines = [[LineReader alloc] initWithText:m3u8];
    NSString* line = [lines next];
    do {
        if ([line hasPrefix:TAG_MEDIA_SEQUENCE]) {
            m3u8Builder = [m3u8Builder stringByAppendingString:@"#EXT-X-START:TIME-OFFSET=-30\n"];
        }
        m3u8Builder = [m3u8Builder stringByAppendingFormat:@"%@\n", line];
        line = [lines next];
    } while(line);
    return m3u8Builder;
}

+ (BOOL)isLivePlaylist:(NSString *)m3u8 {
    if ([m3u8 rangeOfString:TAG_STREAM_INF].location != NSNotFound) {
        return NO;
    }
    BOOL isLive = [m3u8 rangeOfString:M3U8_EXT_X_ENDLIST].location == NSNotFound;
    return isLive;;
}

@end
