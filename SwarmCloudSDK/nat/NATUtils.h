//
//  NATUtils.h
//  CDNByeKit
//
//  Created by Timmy on 2020/1/14.
//  Copyright © 2020 cdnbye. All rights reserved.
//

#import <Foundation/Foundation.h>
//#import "GCDAsyncUdpSocket.h"


typedef enum {
    NatTypeUdpBlocked,
    NatTypeOpenInternet,
    NatTypeSymmetricUdpFirewall,
    NatTypeFullCone,
    NatTypeRestrictedCone,
    NatTypePortRestrictedCone,
    NatTypeSymmetric,
    NatTypeUnknown,
} NatType;

extern NSString * _Nonnull const NatTypeDescription[];

typedef NS_OPTIONS(NSUInteger, StunMessageType) {
    
    StunMessageTypeBindingRequest = 0x0001,
    StunMessageTypeBindingResponse = 0x0101,
    StunMessageTypeBindingErrorResponse = 0x0111,
    StunMessageTypeSharedSecretRequest = 0x0002,
    StunMessageTypeSharedSecretResponse = 0x0102,
    StunMessageTypeSharedSecretErrorResponse = 0x0112,
};

NS_ASSUME_NONNULL_BEGIN

@interface NATUtils : NSObject

+ (NSString *)getIPAddress:(BOOL)preferIPv4;     

@end

NS_ASSUME_NONNULL_END
