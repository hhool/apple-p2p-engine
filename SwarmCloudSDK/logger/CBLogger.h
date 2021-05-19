//
//  CBLogger.h
//  WebRTC
//
//  Created by Timmy on 2019/5/13.
//  Copyright © 2019 cdnbye. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CocoaLumberjack/CocoaLumberjack.h>

#define CBError(frmt, ...) DDLogError(frmt, ##__VA_ARGS__)
#define CBWarn(frmt, ...) DDLogWarn(frmt, ##__VA_ARGS__)
#define CBInfo(frmt, ...) DDLogInfo(frmt, ##__VA_ARGS__)

#define CBDebug(frmt, ...) DDLogDebug(frmt, ##__VA_ARGS__)
#define CBVerbose(frmt, ...) DDLogVerbose(frmt, ##__VA_ARGS__)

//#define CBDebug(frmt, ...)
//#define CBVerbose(frmt, ...)


//#if DEBUG
//static const DDLogLevel ddLogLevel = DDLogLevelVerbose;   // DDLogLevelOff
////[[CBWindowPrinter sharedInstance] setHidden:NO];
//#else
//static const DDLogLevel ddLogLevel = DDLogLevelWarning;
//#endif

#ifdef LOG_LEVEL_DEF
#   undef LOG_LEVEL_DEF
#endif
#define LOG_LEVEL_DEF [CBLogger ddLogLevel]

NS_ASSUME_NONNULL_BEGIN

@interface CBLogger : NSObject <DDRegisteredDynamicLogging>
@property(nonatomic, strong)DDFileLogger *fileLogger;

+ (CBLogger *)shareManager;
- (void)start;                              // 配置日志信息
//- (NSArray *)getAllLogFilePath;             // 获取日志路径
//- (NSArray *)getAllLogFileContent;          // 获取日志内容

@end

NS_ASSUME_NONNULL_END
