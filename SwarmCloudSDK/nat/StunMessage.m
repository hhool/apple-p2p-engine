//
//  StunMessage.m
//  CDNByeKit
//
//  Created by Timmy on 2020/1/15.
//  Copyright © 2020 cdnbye. All rights reserved.
//

#import "StunMessage.h"
#import <CommonCrypto/CommonRandom.h>

@implementation StunMessage

- (instancetype)init {
    if(self = [super init]) {
        
        // 初始化transactionId
        int length = 12;
        unsigned char digest[length];
//        CCRNGStatus status = CCRandomGenerateBytes(digest, length);
        CCRandomGenerateBytes(digest, length);
//        if (status == kCCSuccess) {
//            _transactionId = [NSData dataWithBytes:digest length:length];
//        }
        _transactionId = [NSData dataWithBytes:digest length:length];
        
        // 初始化StunMessageType
        _type = StunMessageTypeBindingRequest;
    }
    return self;
}

- (instancetype)initWithStunMessageType:(StunMessageType)type {
    if(self = [self init]) {
        _type = type;
    }
    return self;
}

- (instancetype)initWithStunMessageType:(StunMessageType)type andStunChangeRequest:(StunChangeRequest *)changeRequest {
    if(self = [self init]) {
        _type = type;
        _changeRequest = changeRequest;
    }
    return self;
}

#pragma mark - **************** public methods

- (AttributeType) getAttributeTypeByValue:(int)value {
    AttributeType type;
    switch (value) {
        case AttributeTypeMappedAddress:
            type = AttributeTypeMappedAddress;
            break;
        case AttributeTypeResponseAddress:
            type = AttributeTypeResponseAddress;
            break;
        case AttributeTypeChangeRequest:
            type = AttributeTypeChangeRequest;
            break;
        case AttributeTypeSourceAddress:
            type = AttributeTypeSourceAddress;
            break;
        case AttributeTypeChangedAddress:
            type = AttributeTypeChangedAddress;
            break;
        case AttributeTypeMessageIntegrity:
            type = AttributeTypeMessageIntegrity;
            break;
        case AttributeTypeErrorCode:
            type = AttributeTypeErrorCode;
            break;
        case AttributeTypeUnknownAttribute:
            type = AttributeTypeUnknownAttribute;
            break;
        default:
            type = AttributeTypeMappedAddress;
            break;
    }
    return type;
}

- (NSData *)toByteData {
    
    /* RFC 5389 6.
     All STUN messages MUST start with a 20-byte header followed by zero
     or more Attributes.  The STUN header contains a STUN message type,
     magic cookie, transaction ID, and message length.
     
     0                   1                   2                   3
     0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
     +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
     |0 0|     STUN Message Type     |         Message Length        |
     +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
     |                         Magic Cookie                          |
     +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
     |                                                               |
     |                     Transaction ID (96 bits)                  |
     |                                                               |
     +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
     
     The message length is the count, in bytes, of the size of the
     message, not including the 20 byte header.
     */
    
    // We allocate 512 for header, that should be more than enough.
    Byte msg[512] = {0};
    
    int offset = 0;
    
    //--- message header -------------------------------------
    
    // STUN Message Type (2 bytes)
    msg[offset++] = (Byte)((self.type >> 8) & 0x3F);
    msg[offset++] = (Byte)(self.type & 0xFF);
    
    // Message Length (2 bytes) will be assigned at last.
    msg[offset++] = 0;
    msg[offset++] = 0;
    
    // Magic Cookie
    msg[offset++] = (Byte)((self.magicCookie >> 24) & 0xFF);
    msg[offset++] = (Byte)((self.magicCookie >> 16) & 0xFF);
    msg[offset++] = (Byte)((self.magicCookie >> 8) & 0xFF);
    msg[offset++] = (Byte)(self.magicCookie & 0xFF);
    
    // Transaction ID (16 bytes)
    arraycopy((Byte *)[self.transactionId bytes], 0, msg, offset, 12);
    offset += 12;
    
    //--- Message attributes ------------------------------------
    
    /* RFC 3489 11.2.
     After the header are 0 or more attributes.  Each attribute is TLV
     encoded, with a 16 bit type, 16 bit length, and variable value:
     
     0                   1                   2                   3
     0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
     +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
     |         Type                  |            Length             |
     +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
     |                             Value                             ....
     +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
     */
    
    if (self.mappedAddress)
    {
        storeEndPoint(AttributeTypeMappedAddress, self.mappedAddress, msg, &offset);  
    } else if (self.responseAddress) {
        storeEndPoint(AttributeTypeResponseAddress, self.responseAddress, msg, &offset);
    } else if (self.changeRequest) {
        /*
         The CHANGE-REQUEST attribute is used by the client to request that
         the server use a different address and/or port when sending the
         response.  The attribute is 32 bits long, although only two bits (A
         and B) are used:
         
         0                   1                   2                   3
         0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
         +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
         |0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 A B 0|
         +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
         
         The meaning of the flags is:
         
         A: This is the "change IP" flag.  If true, it requests the server
         to send the Binding Response with a different IP address than the
         one the Binding Request was received on.
         
         B: This is the "change port" flag.  If true, it requests the
         server to send the Binding Response with a different port than the
         one the Binding Request was received on.
         */
        
        // Attribute header
        msg[offset++] = (Byte)(AttributeTypeChangeRequest >> 8);
        msg[offset++] = (Byte)(AttributeTypeChangeRequest & 0xFF);
        msg[offset++] = 0;
        msg[offset++] = 4;
        
        msg[offset++] = 0;
        msg[offset++] = 0;
        msg[offset++] = 0;
        msg[offset++] = (Byte)((self.changeRequest.changeIp ? 1 : 0) << 2 | (self.changeRequest.changePort ? 1 : 0) << 1);
    } else if (self.sourceAddress) {
        storeEndPoint(AttributeTypeSourceAddress, self.sourceAddress, msg, &offset);
    } else if (self.errorCode) {
        /* 3489 11.2.9.
         0                   1                   2                   3
         0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
         +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
         |                   0                     |Class|     Number    |
         +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
         |      Reason Phrase (variable)                                ..
         +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
         */
        
        NSData *reasonData = [[self.errorCode reasonText] dataUsingEncoding:NSUTF8StringEncoding];
        
        Byte *reasonBytes =  (Byte*)[reasonData bytes];
        
        NSUInteger byteLength = reasonData.length;
        
        // Header
        msg[offset++] = 0;
        msg[offset++] = (Byte)AttributeTypeErrorCode;
        msg[offset++] = 0;
        msg[offset++] = (Byte)(4 + byteLength);
        
        // Empty
        msg[offset++] = 0;
        msg[offset++] = 0;
        // Class
        msg[offset++] = (Byte)floor(self.errorCode.code / 100.0);
        // Number
        msg[offset++] = (Byte)(self.errorCode.code & 0xFF);
        // ReasonPhrase
        arraycopy(reasonBytes, 0, msg, offset, (int)byteLength);
        offset += byteLength;
    }
    
    // Update Message Length. NOTE: 20 bytes header not included.
    msg[2] = (Byte)((offset - 20) >> 8);
    msg[3] = (Byte)((offset - 20) & 0xFF);
    
    // Make retVal with actual size.
    Byte retVal[offset];
    memset(retVal, 0, offset);
    arraycopy(msg, 0, retVal, 0, offset);
    
    return [NSData dataWithBytes:retVal length:offset];
}

- (void)parseData:(NSData *)udpData {
    if (!udpData) {
        NSLog(@"udp data is null!");
        return;
    }
    
    /* RFC 5389 6.
     All STUN messages MUST start with a 20-byte header followed by zero
     or more Attributes.  The STUN header contains a STUN message type,
     magic cookie, transaction ID, and message length.
     
     0                   1                   2                   3
     0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
     +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
     |0 0|     STUN Message Type     |         Message Length        |
     +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
     |                         Magic Cookie                          |
     +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
     |                                                               |
     |                     Transaction ID (96 bits)                  |
     |                                                               |
     +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
     
     The message length is the count, in bytes, of the size of the
     message, not including the 20 byte header.
     */
    
    if (udpData.length < 20) {
        NSLog(@"Invalid STUN message value!");
        return;
    }
    
    Byte *data = (Byte *)[udpData bytes];
    
    int offset = 0;
    
    //--- message header --------------------------------------------------
    
    // STUN Message Type
    int offset1 = offset++;
    int messageType = data[offset1] << 8 | data[offset++];
    
    if (messageType == StunMessageTypeBindingErrorResponse) {
        _type = StunMessageTypeBindingErrorResponse;
    }
    else if (messageType == StunMessageTypeBindingRequest) {
        _type = StunMessageTypeBindingRequest;
    }
    else if (messageType == StunMessageTypeBindingResponse) {
        _type = StunMessageTypeBindingResponse;
    }
    else if (messageType == StunMessageTypeSharedSecretErrorResponse) {
        _type = StunMessageTypeSharedSecretErrorResponse;
    }
    else if (messageType == StunMessageTypeSharedSecretRequest) {
        _type = StunMessageTypeSharedSecretRequest;
    }
    else if (messageType == StunMessageTypeSharedSecretResponse) {
        _type = StunMessageTypeSharedSecretResponse;
    }
    else {
        NSLog(@"Invalid STUN message type value!");
        return;
    }
    
    // Message Length
    offset1 = offset++;
    int messageLength = data[offset1] << 8 | data[offset++];
    
    // Magic Cookie
    offset1 = offset++;
    int offset2 = offset++;
    int offset3 = offset++;
    _magicCookie = data[offset1] << 24 | data[offset2] << 16 | data[offset3] << 8 | data[offset++];
    
    // Transaction ID
    Byte temp[12] = {0};
    arraycopy(data, offset, temp, 0, 12);
    _transactionId = [NSData dataWithBytes:temp length:12];
    offset += 12;
    
    //--- Message attributes ---------------------------------------------
    while (offset - 20 < messageLength)
    {
        [self parseAttributeWithData:data offset:&offset];
//        NSLog(@"while offset %d messageLength %d", offset, messageLength);
    }
    
}

#pragma mark - **************** private methods

- (void)parseAttributeWithData:(Byte *)data offset:(int *)offset {
    
    /* RFC 3489 11.2.
     Each attribute is TLV encoded, with a 16 bit type, 16 bit length, and variable value:
     
     0                   1                   2                   3
     0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
     +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
     |         Type                  |            Length             |
     +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
     |                             Value                             ....
     +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
     */
    
    // Type
    int offset1 = (*offset)++;
//    NSLog(@"offset1 %d offset %d", offset1, (*offset));
//    NSLog(@"%d", data[offset1]);
//    NSLog(@" %d", data[(*offset)++]);
    AttributeType type = (AttributeType)((data[offset1] << 8) | data[(*offset)++]);
    
//    NSLog(@"AttributeType type %d", type);
    
    // Length
    offset1 = (*offset)++;
    int length = data[offset1] << 8 | data[(*offset)++];
    
    // MAPPED-ADDRESS
    if (type == AttributeTypeMappedAddress)
    {
        _mappedAddress = [self parseEndPointWithData:data offset:offset];
    }
    // RESPONSE-ADDRESS
    else if (type == AttributeTypeResponseAddress)
    {
        _responseAddress = [self parseEndPointWithData:data offset:offset];
    }
    // CHANGE-REQUEST
    else if (type == AttributeTypeChangeRequest)
    {
        /*
         The CHANGE-REQUEST attribute is used by the client to request that
         the server use a different address and/or port when sending the
         response.  The attribute is 32 bits long, although only two bits (A
         and B) are used:
         
         0                   1                   2                   3
         0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
         +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
         |0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 A B 0|
         +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
         
         The meaning of the flags is:
         
         A: This is the "change IP" flag.  If true, it requests the server
         to send the Binding Response with a different IP address than the
         one the Binding Request was received on.
         
         B: This is the "change port" flag.  If true, it requests the
         server to send the Binding Response with a different port than the
         one the Binding Request was received on.
         */
        
        // Skip 3 bytes
        (*offset) += 3;
        _changeRequest = [[StunChangeRequest alloc] initWithChangeIp:(data[(*offset)] & 4) != 0 changePort:(data[(*offset)] & 2) != 0];
        (*offset)++;
    }
    // SOURCE-ADDRESS
    else if (type == AttributeTypeSourceAddress)
    {
        _sourceAddress = [self parseEndPointWithData:data offset:offset];
    }
    // CHANGED-ADDRESS
    else if (type == AttributeTypeChangedAddress)
    {
        _changedAddress = [self parseEndPointWithData:data offset:offset];
    }
    // MESSAGE-INTEGRITY
    else if (type == AttributeTypeMessageIntegrity)
    {
        (*offset) += length;
    }
    // ERROR-CODE
    else if (type == AttributeTypeErrorCode)
    {
        /* 3489 11.2.9.
         0                   1                   2                   3
         0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
         +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
         |                   0                     |Class|     Number    |
         +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
         |      Reason Phrase (variable)                                ..
         +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
         */
        
        int code = (data[(*offset) + 2] & 0x7) * 100 + (data[(*offset) + 3] & 0xFF);
        
        Byte textBytes[length - 4];
        memset(textBytes, 0, length - 4);
        arraycopy(data, (*offset) + 4, textBytes, 0, length - 4);
        NSData *adata = [[NSData alloc]initWithBytes:textBytes length:length - 4];
        NSString *result =[[ NSString alloc] initWithData:adata encoding:NSUTF8StringEncoding];
        _errorCode = [[StunErrorCode alloc] initWithCode:code reasonText:result];
        
        (*offset) += length;
    }
    // UNKNOWN-ATTRIBUTES
    else if (type == AttributeTypeUnknownAttribute)
    {
        (*offset) += length;
    }
    // Unknown
    else
    {
        (*offset) += length;
    }
}

void arraycopy(Byte *p_src, int srcPos, Byte *p_dest, int destPos, int length){
    for(int num = 0;num <= length - 1;num++){
        p_dest[destPos + num] = p_src[srcPos + num];
    }
}

- (SocketAddress *)parseEndPointWithData:(Byte *)data offset:(int *)offset {
    /*
     It consists of an eight bit address family, and a sixteen bit
     port, followed by a fixed length value representing the IP address.
     
     0                   1                   2                   3
     0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
     +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
     |x x x x x x x x|    Family     |           Port                |
     +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
     |                             Address                           |
     +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
     */
    
    // Skip family
    (*offset)++;
    (*offset)++;
    
    // Port
    int offset1 = (*offset)++;
    int port = data[offset1] << 8 | data[(*offset)++];
    
    // Address
    Byte ip[4] = {0};
    ip[0] = data[(*offset)++];
    ip[1] = data[(*offset)++];
    ip[2] = data[(*offset)++];
    ip[3] = data[(*offset)++];
    
//    NSLog(@"ip[0] %d", ip[0]);
//    NSLog(@"%d", ip[1]);
//    NSLog(@"%d", ip[2]);
//    NSLog(@"%d", ip[3]);
//    NSLog(@"port %d", port);
    
    NSString *ipStr = [NSString stringWithFormat:@"%d.%d.%d.%d", ip[0], ip[1], ip[2], ip[3]];
    
    return [[SocketAddress alloc] initWithIp:ipStr andPort:port];
}

void storeEndPoint(AttributeType type, SocketAddress *endPoint, Byte *message, int *offset) {
    /*
     It consists of an eight bit address family, and a sixteen bit
     port, followed by a fixed length value representing the IP address.
     
     0                   1                   2                   3
     0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
     +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
     |x x x x x x x x|    Family     |           Port                |
     +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
     |                             Address                           |
     +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
     */
    
    // Header
    message[(*offset)++] = (type >> 8);
    message[(*offset)++] = (type & 0xFF);
    message[(*offset)++] = 0;
    message[(*offset)++] = 8;
    
    // Unused
    message[(*offset)++] = 0;
    // Family
    message[(*offset)++] = 0x01;
    // Port
    message[(*offset)++] = (endPoint.port >> 8);
    message[(*offset)++] = (endPoint.port & 0xFF);
    // Address
    char *ipBytes = [endPoint ip2Bytes];      // 前两位是端口
    message[(*offset)++] = ipBytes[2];
    message[(*offset)++] = ipBytes[3];
    message[(*offset)++] = ipBytes[4];
    message[(*offset)++] = ipBytes[5];
}

@end
