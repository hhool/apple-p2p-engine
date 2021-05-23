//
//  CBLogFormatter.m
//  WebRTC
//
//  Created by Timmy on 2019/5/13.
//  Copyright © 2019 cdnbye. All rights reserved.
//

#import "CBLogFormatter.h"
//#import "DDLog.h"

/*
 DDLogMessage中返回信息
 
 NSString *_message;             // 具体logger内容
 DDLogLevel _level;              // 全局lever等级
 DDLogFlag _flag;                // log的flag等级
 NSInteger _context;             //
 NSString *_file;                // 文件
 NSString *_fileName;            // 文件名称
 NSString *_function;            // 函数名
 NSUInteger _line;               // 行号
 id _tag;                        //
 DDLogMessageOptions _options;   //
 NSDate *_timestamp;             // 时间
 NSString *_threadID;            // 线程id
 NSString *_threadName;          // 线程名称
 NSString *_queueLabel;          // gcd线程名称
 */

@implementation CBLogFormatter

- (NSString *)formatLogMessage:(DDLogMessage *)logMessage{
    NSString *loglevel = @"[P2P Log]";
    switch (logMessage.flag){
        case LOG_FLAG_ERROR:
            loglevel = @"[CDNBye ERROR]-->";
            break;
        case LOG_FLAG_WARN:
            loglevel = @"[CDNBye WARN]-->";
            break;
        case LOG_FLAG_INFO:
            loglevel = @"[CDNBye INFO]-->";
            break;
        case LOG_FLAG_DEBUG:
            loglevel = @"[CDNBye DEBUG]-->";
            break;
        case LOG_FLAG_VERBOSE:
            loglevel = @"[CDNBye VBOSE]-->";
            break;
        default:
            break;
    }
    NSString *resultString = [NSString stringWithFormat:@"%@ %@_line[%@]  %@", loglevel, logMessage->_function, @(logMessage->_line), logMessage->_message];
    return resultString;
}

@end
