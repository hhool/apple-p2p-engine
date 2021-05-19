//
//  CBPeerManager.h
//  SwarmCloudSDK
//
//  Created by Timmy on 2021/5/9.
//  Copyright © 2021 cdnbye. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SWCDataChannel.h"

NS_ASSUME_NONNULL_BEGIN

@interface CBPeerManager : NSObject

- (instancetype)initManager;

- (BOOL)isEmpty;

- (NSUInteger)size;

- (void)clear;

- (SWCDataChannel *)getPeerWithId:(NSString *)peerId;

- (void)addPeer:(SWCDataChannel *)peer withId:(NSString *)peerId;

- (void)removePeerWithId:(NSString *)peerId;

- (void)removePeersWithIds:(NSArray *)peerIds;

- (BOOL)hasIdlePeers;

- (NSArray<SWCDataChannel *> *)getAvailablePeers;

- (NSMutableDictionary *)getPeerMap;

- (NSArray<SWCDataChannel *> *)getPeersOrderByWeight;

@end

NS_ASSUME_NONNULL_END
