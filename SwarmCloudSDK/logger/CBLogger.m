//
//  CBLogger.m
//  WebRTC
//
//  Created by Timmy on 2019/5/13.
//  Copyright © 2019 cdnbye. All rights reserved.
//

#import "CBLogger.h"
#import "CBLogFormatter.h"

static DDLogLevel s_ddLogLevel = DDLogLevelWarning;

@interface CBLogger() 

@end

@implementation CBLogger

+ (CBLogger *)shareManager{
    static CBLogger *manager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        manager = [[CBLogger alloc] init];
//        manager.fileLogger = [[DDFileLogger alloc] init];
//        manager.fileLogger.rollingFrequency = 60 * 60 * 24;                 // 刷新频率为24小时
//        manager.fileLogger.logFileManager.maximumNumberOfLogFiles = 7;      // 保存一周的日志，即7天
//        manager.fileLogger.maximumFileSize = 1024 * 1024 * 2;               // 最大文件大小
        
//        [[CBWindowLogger sharedInstance] setHidden:NO];
        
    });
    return manager;
}
/**
 配置日志信息
 */
- (void)start{
    // 1.自定义Log格式
    CBLogFormatter *logFormatter = [[CBLogFormatter alloc] init];
    // 2.DDASLLogger，日志语句发送到苹果文件系统、日志状态发送到Console.app
//    [[DDASLLogger sharedInstance] setLogFormatter:logFormatter];
//    [DDLog addLogger:[DDASLLogger sharedInstance]];
    // 3.DDFileLogger，日志语句写入到文件中（默认路径：Library/Caches/Logs/目录下，文件名为bundleid+空格+日期.log）
//    DDFileLogger *fileLogger = [CBLogger shareManager].fileLogger;
//    [fileLogger setLogFormatter:logFormatter];
//    [DDLog addLogger:fileLogger withLevel:DDLogLevelError];        // 错误日志，写到文件中
    // 4.DDTTYLogger，日志语句发送到Xcode
    [[DDTTYLogger sharedInstance] setLogFormatter:logFormatter];
    
//    [[DDTTYLogger sharedInstance] setColorsEnabled:YES];           // 启用颜色区分
//    [[DDTTYLogger sharedInstance] setForegroundColor:DDMakeColor(255, 0, 0) backgroundColor:nil forFlag:DDLogFlagError];
//    [[DDTTYLogger sharedInstance] setForegroundColor:DDMakeColor(105, 200, 80) backgroundColor:nil forFlag:DDLogFlagInfo];
//    [[DDTTYLogger sharedInstance] setForegroundColor:DDMakeColor(100, 100, 200) backgroundColor:nil forFlag:DDLogFlagDebug];
    [DDLog addLogger:[DDTTYLogger sharedInstance]];
    [DDLog setLevel:DDLogLevelInfo forClass:[DDTTYLogger class]];
}
/**
 获取日志路径(文件名bundleid+空格+日期)
 */
//- (NSArray *)getAllLogFilePath{
//    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
//    NSString *cachesPath = [paths objectAtIndex:0];
//    NSString *logPath = [cachesPath stringByAppendingPathComponent:@"Logs"];
//    NSFileManager *fileManger = [NSFileManager defaultManager];
//    NSError *error = nil;
//    NSArray *fileArray = [fileManger contentsOfDirectoryAtPath:logPath error:&error];
//    NSMutableArray *result = [NSMutableArray array];
//    [fileArray enumerateObjectsUsingBlock:^(NSString *filePath, NSUInteger idx, BOOL * _Nonnull stop) {
//        if([filePath hasPrefix:[NSBundle mainBundle].bundleIdentifier]){
//            NSString *logFilePath = [logPath stringByAppendingPathComponent:filePath];
//            [result addObject:logFilePath];
//        }
//    }];
//    return result;
//}
/**
 获取日志内容
 */
//- (NSArray *)getAllLogFileContent{
//    NSMutableArray *result = [NSMutableArray array];
//    NSArray *logfilePaths = [self getAllLogFilePath];
//    [logfilePaths enumerateObjectsUsingBlock:^(NSString *filePath, NSUInteger idx, BOOL * _Nonnull stop) {
//        NSData *data = [NSData dataWithContentsOfFile:filePath];
//        NSString *content = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
//        [result addObject:content];
//    }];
//    return result;
//}

+ (DDLogLevel)ddLogLevel {
    return s_ddLogLevel;
}

+ (void)ddSetLogLevel:(DDLogLevel)level {
    s_ddLogLevel = level;
}

@end
