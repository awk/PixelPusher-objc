//
//  DeviceHeader.h
//  pixelpusher
//
//  Created by Andrew Kimpton on 9/7/13.
//  Copyright (c) 2013 Andrew Kimpton. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef enum {
    ETHERDREAM = 0,
    LUMIABRIDGE = 1,
    PIXELPUSHER = 2
} DeviceType;

@interface DeviceHeader : NSObject

- (id) initWithData:(NSData *)data;

- (NSString *) macAddressAsString;
- (NSString *) deviceTypeAsName;
- (NSString *) ipAddressAsString;

@property (nonatomic, retain) NSData *macAddress;
@property uint32_t ipAddress;
@property DeviceType deviceType;
@property NSInteger protocolVersion;
@property NSInteger vendorId;
@property NSInteger productId;
@property NSInteger hardwareRevision;
@property NSInteger softwareRevision;
@property NSInteger linkSpeed;
@property (nonatomic, retain) NSData *packetRemainder;

@end
