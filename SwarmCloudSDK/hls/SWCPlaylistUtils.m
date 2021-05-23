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

#define TAG_INIT_SEGMENT @"#EXT-X-MAP"
#define TAG_STREAM_INF @"#EXT-X-STREAM-INF"
#define TAG_MEDIA_SEQUENCE @"#EXT-X-MEDIA-SEQUENCE"
#define TAG_M3U8_EXTINF @"#EXTINF"
#define M3U8_EXT_X_ENDLIST @"#EXT-X-ENDLIST"

@implementation SWCPlaylistUtils

+ (NSString *)checkAndRewritePlaylist:(NSString *)m3u8 {
    BOOL isAbsoluteUrl = NO;
    NSString *m3u8Builder = @"";
    LineReader* lines = [[LineReader alloc] initWithText:m3u8];
    NSString* line = [lines next];
    do {
        if ([line hasPrefix:TAG_STREAM_INF]) {
            return m3u8;
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
            } else {
                if (!isAbsoluteUrl) {
                    return m3u8;
                }
            }
        }
        if (line) m3u8Builder = [m3u8Builder stringByAppendingFormat:@"%@\n", line];
        line = [lines next];
    } while(line);
    return m3u8Builder;
}

+ (NSString *)redirectedRewritePlaylist:(NSString *)m3u8 baseUri:(NSURL *)baseUri {
    NSString *m3u8Builder = @"";
    LineReader* lines = [[LineReader alloc] initWithText:m3u8];
    NSString* line;
    while ([lines hasNext]) {
        line = [lines next];
        if ([line hasPrefix:TAG_STREAM_INF]) {
            return m3u8;
        } else if (line && ![line hasPrefix:@"#"]) {
            // segment uri
            if ([line hasPrefix:@"http"]) {
                // 绝对地址
                NSURL *url = [NSURL URLWithString:line];
                // URL编码
                NSString *encodedLocation = [line stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLHostAllowedCharacterSet]];
                line = url.path;
                NSString *query = url.query;
                if (query) {
                    line = [NSString stringWithFormat:@"%@?%@&_ProxyTarget_=%@", line, query, encodedLocation];
                } else {
                    line = [NSString stringWithFormat:@"%@?_ProxyTarget_=%@", line, encodedLocation];
                }
            } else {
                // 相对地址
                NSURL *url = [NSURL URLWithString:line relativeToURL:baseUri];
//                NSLog(@"line %@ baseUri %@ url %@", line, baseUri, url);
                // URL编码
                NSString *encodedLocation = [url.absoluteString stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLHostAllowedCharacterSet]];
                line = url.path;
                NSString *query = url.query;
                if (query) {
                    line = [NSString stringWithFormat:@"%@?%@&_ProxyTarget_=%@", line, query, encodedLocation];
                } else {
                    line = [NSString stringWithFormat:@"%@?_ProxyTarget_=%@", line, encodedLocation];
                }
            }
        }
        if (line) m3u8Builder = [m3u8Builder stringByAppendingFormat:@"%@\n", line];
    }
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

@end
