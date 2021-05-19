//
//  CBPeerManager.m
//  SwarmCloudSDK
//
//  Created by Timmy on 2021/5/9.
//  Copyright © 2021 cdnbye. All rights reserved.
//

#import "CBPeerManager.h"
#import "CBQueue.h"

@interface CBPeerManager()

@property (nonatomic, strong) NSMutableDictionary<NSString*, SWCDataChannel*> *peerMap;

@end

@implementation CBPeerManager

- (instancetype)initManager {
    if(self = [super init]) {
        self.peerMap = [NSMutableDictionary dictionary];
    }
    return self;
}

- (BOOL)isEmpty {
    return self.peerMap.count == 0;
}

- (NSUInteger)size {
    return self.peerMap.count;
}

- (void)clear {
    [self.peerMap removeAllObjects];
}

- (SWCDataChannel *)getPeerWithId:(NSString *)peerId {
    return [self.peerMap objectForKey:peerId];
}

- (void)addPeer:(SWCDataChannel *)peer withId:(NSString *)peerId {
    [self.peerMap setObject:peer forKey:peerId];
}

- (void)removePeerWithId:(NSString *)peerId {
    [self.peerMap removeObjectForKey:peerId];
}

- (void)removePeersWithIds:(NSArray *)peerIds {
     [self.peerMap removeObjectsForKeys:peerIds];
}

- (BOOL)hasIdlePeers {
    if ([self isEmpty]) {
        return NO;
    }
    for (NSString *peerId in self.peerMap) {
        SWCDataChannel *peer = [self.peerMap objectForKey:peerId];
        if (peer.isAvailable) {
            return YES;
        }
    }
    return NO;
}

- (NSArray<SWCDataChannel *> *)getAvailablePeers {
    NSMutableArray<SWCDataChannel *> *arr = [NSMutableArray array];
    for (NSString *peerId in self.peerMap) {
        SWCDataChannel *peer = [self.peerMap objectForKey:peerId];
        if (peer.isAvailable) {
            [arr addObject:peer];
        }
    }
    return arr;
}

- (NSMutableDictionary *)getPeerMap {
    return self.peerMap;
}

- (NSArray<SWCDataChannel *> *)getPeersOrderByWeight {
    NSArray *peers = [[self getAvailablePeers] sortedArrayUsingSelector:@selector(compareByWeight:)];
    CBQueue *queue = [CBQueue queue];
    for (SWCDataChannel *peer in peers) {
        if (peer.weight == 0) {
            [queue unshift:peer];
        } else {
            [queue push:peer];
        }
    }
//    NSLog(@"sorted peers");
//    for (CBDataChannel *peer in [queue getArray]) {
//        NSLog(@"weight %@", @(peer.weight));
//    }
    return peers;
}

@end
