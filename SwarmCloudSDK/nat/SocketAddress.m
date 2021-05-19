//
//  SocketAddress.m
//  CDNByeKit
//
//  Created by Timmy on 2020/1/16.
//  Copyright © 2020 cdnbye. All rights reserved.
//

#import "SocketAddress.h"
#include <sys/socket.h>
#include <netinet/in.h>
#include<arpa/inet.h>
#import <netdb.h>

@implementation SocketAddress

- (instancetype)initWithIp:(NSString *)ip andPort:(int)port {
    if(self = [super init]) {
        _ip = ip;
        _port = port;
    }
    return self;
}

- (instancetype)initWithHost:(NSString *)host andPort:(int)port {
    if(self = [super init]) {
        _host = host;
        _port = port;
    }
    return self;
}

- (char *)ip2Bytes {
    struct addrinfo hints, *res;
    memset(&hints, 0, sizeof(hints));
    hints.ai_family   = AF_INET;
    hints.ai_socktype = SOCK_DGRAM;
    hints.ai_protocol = IPPROTO_UDP;
    int gai_error = getaddrinfo([self.ip UTF8String], [[NSString stringWithFormat:@"%d", self.port] UTF8String], &hints, &res);
    
    NSLog(@"gai_error %d", gai_error);
    
    return res->ai_addr->sa_data;
}

@end
