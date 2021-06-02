//
//  CBLogFormatter.m
//  WebRTC
//
//  Created by Timmy on 2019/5/13.
//  Copyright © 2019 cdnbye. All rights reserved.
//

#import "CBLogFormatter.h"

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
    NSString *loglevel;
    switch (logMessage.flag){
        case DDLogFlagError:
            loglevel = @"[P2P ERROR]-->";
            break;
        case DDLogFlagWarning:
            loglevel = @"[P2P WARN]-->";
            break;
        case DDLogFlagInfo:
            loglevel = @"[P2P INFO]-->";
            break;
        case DDLogFlagDebug:
            loglevel = @"[P2P DEBUG]-->";
            break;
        case DDLogFlagVerbose:
            loglevel = @"[P2P VBOSE]-->";
            break;
        default:
            loglevel = @"[P2P Log]-->";
            break;
    }
    NSString *resultString = [NSString stringWithFormat:@"%@ %@_line[%@]  %@", loglevel, logMessage->_function, @(logMessage->_line), logMessage->_message];
    return resultString;
}

@end
