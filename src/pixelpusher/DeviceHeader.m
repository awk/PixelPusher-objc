//
//  DeviceHeader.m
//  pixelpusher
//
//  Created by Andrew Kimpton on 9/7/13.
//  Copyright (c) 2013 Andrew Kimpton. All rights reserved.
//

#import "DeviceHeader.h"

@implementation DeviceHeader

/**
 * Device Header format:
 * uint8_t mac_address[6];
 * uint8_t ip_address[4];
 * uint8_t device_type;
 * uint8_t protocol_version; // for the device, not the discovery
 * uint16_t vendor_id;
 * uint16_t product_id;
 * uint16_t hw_revision;
 * uint16_t sw_revision;
 * uint32_t link_speed; // in bits per second
 */

const NSInteger headerLength = 24;

@synthesize macAddress;

- (NSString *) description {
    NSString *outBuf = [NSString stringWithFormat:@"%@: MAC(%@), IP(%@), Protocol Ver(%ld), Vendor ID(%ld), Product ID(%ld), HW Rev(%ld), SW Rev(%ld), Link Spd(%ld)",
                        [self deviceTypeAsName], [self macAddressAsString], [self ipAddressAsString], (long)self.protocolVersion, (long)self.vendorId, (long)self.productId, (long)self.hardwareRevision, (long)self.softwareRevision, (long)self.linkSpeed];
    return outBuf;
}

- (NSString *) macAddressAsString {
    const unsigned char *macAddressBytes = [macAddress bytes];
    NSString *macAddrString = [NSString stringWithFormat:@"%02x:%02x:%02x:%02x:%02x:%02x",
                               macAddressBytes[0], macAddressBytes[1], macAddressBytes[2], macAddressBytes[3], macAddressBytes[4], macAddressBytes[5]];
    return macAddrString;
}

- (id) initWithData:(NSData *) packet
{
    if (self = [super init]) {
        if ([packet length] < headerLength) {
            NSLog(@"Short (%ld) packet!", (long) [packet length]);
            return nil;
        }
        unsigned char headerPkt[headerLength];
        memcpy(headerPkt, [packet bytes], headerLength);

        self.macAddress = [NSData dataWithBytes:headerPkt length:6];
//        try {
//            this.IpAddress = InetAddress.getByAddress(Arrays.copyOfRange(headerPkt,
//                                                                         6, 10));
//        } catch (UnknownHostException e) {
//            throw new IllegalArgumentException();
//        }
        self.deviceType = headerPkt[10];
        self.protocolVersion = headerPkt[11];
        self.vendorId = *((uint16_t*) &headerPkt[12]);
        self.productId = *((uint16_t*) &headerPkt[14]);
        self.hardwareRevision = *((uint16_t*) &headerPkt[16]);
        self.softwareRevision = *((uint16_t*) &headerPkt[18]);
        self.linkSpeed = *((uint32_t*) &headerPkt[20]);
        self.packetRemainder = [NSData dataWithBytes:([packet bytes] + headerLength) length:[packet length] - headerLength];
    }
    return self;
}

- (NSString *) deviceTypeAsName
{
    switch (self.deviceType) {
        case ETHERDREAM:
            return @"ETHERDREAM";
            break;
        case LUMIABRIDGE:
            return @"LUMIABRIDGE";
            break;
        case PIXELPUSHER:
            return @"PIXELPUSHER";
            break;
            
        default:
            return @"UNKNOWN";
            break;
    }
    
}

- (NSString *) ipAddressAsString
{
    return @"Unset IP Address";
}
@end
