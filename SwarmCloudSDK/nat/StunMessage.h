//
//  StunMessage.h
//  CDNByeKit
//
//  Created by Timmy on 2020/1/15.
//  Copyright © 2020 cdnbye. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "NATUtils.h"
#import "SocketAddress.h"
#import "StunChangeRequest.h"
#import "StunErrorCode.h"

/*
 MappedAddress(0x0001),
 ResponseAddress(0x0002),
 ChangeRequest(0x0003),
 SourceAddress(0x0004),
 ChangedAddress(0x0005),
 Username(0x0006),
 Password(0x0007),
 MessageIntegrity(0x0008),
 ErrorCode(0x0009),
 UnknownAttribute(0x000A),
 ReflectedFrom(0x000B),
 XorMappedAddress(0x8020),
 XorOnly(0x0021),
 ServerName(0x8022);
 */
typedef NS_OPTIONS(NSUInteger, AttributeType) {
    AttributeTypeMappedAddress = 0x0001,
    AttributeTypeResponseAddress = 0x0002,
    AttributeTypeChangeRequest = 0x0003,
    AttributeTypeSourceAddress = 0x0004,
    AttributeTypeChangedAddress = 0x0005,
    AttributeTypeMessageIntegrity = 0x0008,
    AttributeTypeErrorCode = 0x0009,
    AttributeTypeUnknownAttribute = 0x000A,
};

NS_ASSUME_NONNULL_BEGIN

@interface StunMessage : NSObject

@property(nonatomic, strong, readonly) NSData *transactionId;

@property(nonatomic, assign, readonly) StunMessageType type;

@property(nonatomic, assign, readonly) int magicCookie;

@property(nonatomic, strong, readonly) SocketAddress *mappedAddress;

@property(nonatomic, strong, readonly) SocketAddress *responseAddress;

@property(nonatomic, strong, readonly) SocketAddress *sourceAddress;

@property(nonatomic, strong, readonly) SocketAddress *changedAddress;

@property(nonatomic, strong, readonly) StunChangeRequest *changeRequest;

@property(nonatomic, strong, readonly) StunErrorCode *errorCode;

- (instancetype)initWithStunMessageType:(StunMessageType)type;

- (instancetype)initWithStunMessageType:(StunMessageType)type andStunChangeRequest:(StunChangeRequest *)changeRequest;

- (AttributeType) getAttributeTypeByValue:(int)value;

- (NSData *)toByteData;

- (void)parseData:(NSData *)udpData;



@end

NS_ASSUME_NONNULL_END
