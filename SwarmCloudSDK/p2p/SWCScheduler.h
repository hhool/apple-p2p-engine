//
//  SWCScheduler.h
//  SwarmCloudSDK
//
//  Created by Timmy on 2021/5/9.
//  Copyright © 2021 cdnbye. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SWCDataChannel.h"
#import "SWCP2pConfig.h"
#import "SWCSegment.h"
#import <GCDWebServerRequest.h>
#import "CBPeerManager.h"
#import "SWCPlaylistInfo.h"
#import "SWCSegmentManager.h"
#import "SWCUtils.h"

typedef NS_ENUM(NSInteger, SWCMediaType) {
    SWCMediaTypeHls,
    SWCMediaTypeMp4,
    SWCMediaTypeFile,
};

NS_ASSUME_NONNULL_BEGIN

@protocol SWCSchedulerDelegate <NSObject>
    
@optional

- (NSTimeInterval)bufferedDuration;

@end

@interface SWCScheduler : NSObject
{
    CBPeerManager *_peerManager;
    BOOL _isLive;              // 是否直播
    SWCSegmentManager *_cacheManager;
    SWCP2pConfig *_p2pConfig;
    NSURLSessionDataTask *_currentHttpTask;
}

@property (nonatomic, weak) id<SWCSchedulerDelegate> delegate;

// 单位 KB
@property (atomic, assign) NSUInteger p2pDownloaded;
@property (atomic, assign) NSUInteger p2pUploaded;
@property (atomic, assign) NSUInteger httpDownloaded;
@property (atomic, assign) NSInteger conns;                // 可能为负数
@property (atomic, assign) NSUInteger failConns;

@property (nonatomic, assign) BOOL isHttpRangeSupported;

@property (nonatomic, assign) BOOL shareOnly;                 // 是否只上传不下载

@property (atomic, assign, readonly) NSUInteger allowP2pLimit;

- (instancetype)initWithIsLive:(BOOL)live endSN:(NSUInteger)sn andConfig:(SWCP2pConfig *)config;

- (void)loadSegment:(SWCSegment *)segment withBlock:(void(^)(NSHTTPURLResponse *response, NSData *_Nullable data))block;

//- (void)deletePeer:(NSString *)peerId;


- (void)handshakePeer:(SWCDataChannel *)peer;

- (void)breakOffPeer:(SWCDataChannel *)peer;

- (void)addPeer:(SWCDataChannel *)peer andBitfield:(NSArray *)field;

- (BOOL)hasPeers;

- (BOOL)hasIdlePeers;

- (NSUInteger)peersNum;

- (void)evictSN:(SWCSegment *)seg;

- (BOOL)isSequential;

- (void)broadcastPlaylist;

- (NSArray<SWCDataChannel *> *)getPeers;

- (void)requestPeers;

- (void)notifyAllPeersWithSN:(NSNumber *)SN segId:(NSString *)segId;

- (void)notifyAllPeersWithSegId:(NSString *)segId;

- (void)postPeersStatistics;

- (BOOL)isPlayListMapContainsUrl:(NSString *)url;

- (void)broadcastPlaylist:(NSString *)url data:(NSString *)data;

- (SWCPlaylistInfo *)getPlaylistFromPeerWithUrl:(NSString *)url;

- (void)clearDisconnectedPeers;

- (void)closeAllPeers;

- (void)destroy;

- (NSArray<SWCDataChannel *> *)getNonactivePeers;

@end

NS_ASSUME_NONNULL_END
