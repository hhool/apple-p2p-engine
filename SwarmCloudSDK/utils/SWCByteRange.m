//
//  SWCByteRange.m
//  SwarmCloudSDK
//
//  Created by Timmy on 2021/5/10.
//  Copyright © 2021 cdnbye. All rights reserved.
//

#import "SWCByteRange.h"

BOOL SWCRangeIsFull(SWCRange range)
{
    return SWCEqualRanges(range, SWCRangeFull());
}

BOOL SWCRangeIsVaild(SWCRange range)
{
    return !SWCRangeIsInvaild(range);
}

BOOL SWCRangeIsInvaild(SWCRange range)
{
    return SWCEqualRanges(range, SWCRangeInvaild());
}

BOOL SWCEqualRanges(SWCRange range1, SWCRange range2)
{
    return range1.start == range2.start && range1.end == range2.end;
}

long long SWCRangeGetLength(SWCRange range)
{
    if (range.start == SWCNotFound || range.end == SWCNotFound) {
        return SWCNotFound;
    }
    return range.end - range.start + 1;
}

NSString *SWCStringFromRange(SWCRange range)
{
    return [NSString stringWithFormat:@"Range : {%lld, %lld}", range.start, range.end];
}

NSString *SWCRangeGetHeaderString(SWCRange range)
{
    NSMutableString *string = [NSMutableString stringWithFormat:@"bytes="];
    if (range.start != SWCNotFound) {
        [string appendFormat:@"%lld", range.start];
    }
    [string appendFormat:@"-"];
    if (range.end != SWCNotFound) {
        [string appendFormat:@"%lld", range.end];
    }
    return [string copy];
}

NSString *SWCRangeGetHeaderStringFromNSRange(NSRange range) {
    return SWCRangeGetHeaderString(SWCMakeRange(range.location, range.location + range.length - 1));
}

NSDictionary *SWCRangeFillToRequestHeaders(SWCRange range, NSDictionary *headers)
{
    NSMutableDictionary *ret = [NSMutableDictionary dictionaryWithDictionary:headers];
    [ret setObject:SWCRangeGetHeaderString(range) forKey:@"Range"];
    return ret;
}

NSDictionary *SWCRangeFillToRequestHeadersIfNeeded(SWCRange range, NSDictionary *headers)
{
    if ([headers objectForKey:@"Range"]) {
        return headers;
    }
    return SWCRangeFillToRequestHeaders(range, headers);
}

NSDictionary *SWCRangeFillToResponseHeaders(SWCRange range, NSDictionary *headers, long long totalLength)
{
    NSMutableDictionary *ret = [NSMutableDictionary dictionaryWithDictionary:headers];
    long long currentLength = SWCRangeGetLength(range);
    [ret setObject:[NSString stringWithFormat:@"%lld", currentLength] forKey:@"Content-Length"];
    [ret setObject:[NSString stringWithFormat:@"bytes %lld-%lld/%lld", range.start, range.end, totalLength] forKey:@"Content-Range"];
    return ret;
}

SWCRange SWCMakeRange(long long start, long long end)
{
    SWCRange range = {start, end};
    return range;
}

SWCRange SWCRangeZero(void)
{
    return SWCMakeRange(0, 0);
}

SWCRange SWCRangeFull(void)
{
    return SWCMakeRange(0, SWCNotFound);
}

SWCRange SWCRangeInvaild()
{
    return SWCMakeRange(SWCNotFound, SWCNotFound);
}

SWCRange SWCRangeWithSeparateValue(NSString *value)
{
    SWCRange range = SWCRangeInvaild();
    if (value.length > 0) {
        NSArray *components = [value componentsSeparatedByString:@","];
        if (components.count == 1) {
            components = [components.firstObject componentsSeparatedByString:@"-"];
            if (components.count == 2) {
                NSString *startString = [components objectAtIndex:0];
                NSInteger startValue = [startString integerValue];
                NSString *endString = [components objectAtIndex:1];
                NSInteger endValue = [endString integerValue];
                if (startString.length && (startValue >= 0) && endString.length && (endValue >= startValue)) {
                    // The second 500 bytes: "500-999"
                    range.start = startValue;
                    range.end = endValue;
                } else if (startString.length && (startValue >= 0)) {
                    // The bytes after 9500 bytes: "9500-"
                    range.start = startValue;
                    range.end = SWCNotFound;
                } else if (endString.length && (endValue > 0)) {
                    // The final 500 bytes: "-500"
                    range.start = SWCNotFound;
                    range.end = endValue;
                }
            }
        }
    }
    return range;
}

SWCRange SWCRangeWithRequestHeaderValue(NSString *value)
{
    if ([value hasPrefix:@"bytes="]) {
        NSString *rangeString = [value substringFromIndex:6];
        return SWCRangeWithSeparateValue(rangeString);
    }
    return SWCRangeInvaild();
}

SWCRange SWCRangeWithResponseHeaderValue(NSString *value, long long *totalLength)
{
    if ([value hasPrefix:@"bytes "]) {
        value = [value stringByReplacingOccurrencesOfString:@"bytes " withString:@""];
        NSRange range = [value rangeOfString:@"/"];
        if (range.location != NSNotFound) {
            NSString *rangeString = [value substringToIndex:range.location];
            NSString *totalLengthString = [value substringFromIndex:range.location + range.length];
            *totalLength = totalLengthString.longLongValue;
            return SWCRangeWithSeparateValue(rangeString);
        }
    }
    return SWCRangeInvaild();
}

SWCRange SWCRangeWithEnsureLength(SWCRange range, long long ensureLength)
{
    if (range.end == SWCNotFound && ensureLength > 0) {
        return SWCMakeRange(range.start, ensureLength - 1);
    }
    return range;
}
