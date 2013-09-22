//
//  pixelpusher_osxTests.m
//  pixelpusher-osxTests
//
//  Created by Andrew Kimpton on 9/7/13.
//  Copyright (c) 2013 Andrew Kimpton. All rights reserved.
//

#import "pixelpusher_osxTests.h"

#import "DeviceHeader.h"
#import "PixelPusher.h"
#import "DeviceRegistry.h"

@interface pixelpusher_osxTests () {
    NSInteger _notificationCount;
}

@end
@implementation pixelpusher_osxTests

NSData *sampleData;

- (void)setUp
{
    [super setUp];
    
    unsigned char announcePacket[] =
    { 0x00, 0x02, 0xf7, 0xf1, 0x75, 0x89, 0xc0, 0xa8, 0x14, 0xdc, 0x02, 0x01, 0x02, 0x00, 0x01, 0x00,
        0x02, 0x00, 0x6e, 0x00, 0x00, 0xe1, 0xf5, 0x05, 0x04, 0x01, 0x34, 0x01, 0xa0, 0x86, 0x01, 0x00,
        0x60, 0x7d, 0x0a, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0xa9, 0x26, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00 };
    
    sampleData = [NSData dataWithBytes:announcePacket length:sizeof announcePacket];
}

- (void)tearDown
{
    // Tear-down code here.
    
    [super tearDown];
}

- (void) testDeviceHeader
{
    unsigned char headerPacket[] = { 0x00, 0x02, 0xf7, 0xf0,
        0xc0, 0x99, 0x0a, 0x49, 0x26,
        0xa6, 0x02, 0x01, 0x02, 0x00,
        0x01, 0x00, 0x02, 0x00, 0x03,
        0x00, 0x00, 0xe1, 0xf5, 0x05,
        0x08, 0x01, 0x32, 0x00, 0xff,
        0xff, 0xff, 0xff };
    NSData *headerData = [NSData dataWithBytes:headerPacket length:sizeof headerPacket];
    DeviceHeader *deviceHeader = [[DeviceHeader alloc] initWithData:headerData];
    STAssertTrue([deviceHeader.description isEqualToString:@"PIXELPUSHER: MAC(00:02:f7:f0:c0:99), IP(10.73.38.166), Protocol Ver(1), Vendor ID(2), Product ID(1), HW Rev(2), SW Rev(3), Link Spd(100000000)"], @"Device Header parsed correctly");
}

- (void)testDeviceCreation
{
    DeviceHeader *header = [[DeviceHeader alloc] initWithData:sampleData];
    NSString *macAddr = [header macAddressAsString];
    STAssertTrue([macAddr isEqualToString:@"00:02:f7:f1:75:89"], @"MAC Address parsed correctly");
    STAssertEquals(header.deviceType, PIXELPUSHER, @"Device is pixel pusher");
    PixelPusher *device = [[PixelPusher alloc] initWithHeader:header andRemainingData:header.packetRemainder];
    STAssertEquals(device.numberOfStrips, (NSUInteger) 4, @"4 Strips");
    STAssertEquals(device.pixelsPerStrip, 308 , @"308 Pixels Per Strip");
}

- (void) testDeviceRegistry {
    DeviceRegistry *aDeviceRegistry = [[DeviceRegistry alloc] init];
    
    NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
    NSOperationQueue *mainQueue = [NSOperationQueue mainQueue];
    [center addObserverForName:REGISTRY_PUSHERS_ADDED object:aDeviceRegistry
                         queue:mainQueue
                    usingBlock:^(NSNotification *note)
     {
         _notificationCount++;
     }];
    
    [aDeviceRegistry receive:sampleData];
    STAssertEquals([aDeviceRegistry.pusherMap count], (NSUInteger) 1, @"One PixelPusher Detected");

    [aDeviceRegistry receive:sampleData];
    STAssertEquals([aDeviceRegistry.pusherMap count], (NSUInteger) 1, @"Still One PixelPusher Detected");
    
    STAssertEquals(_notificationCount, (NSInteger) 1, @"Single notification of new pusher");
}

@end
