//
//  pixelpusherTests.m
//  pixelpusherTests
//
//  Created by Andrew Kimpton on 9/6/13.
//  Copyright (c) 2013 Andrew Kimpton. All rights reserved.
//

#import "pixelpusherTests.h"
#import "DeviceRegistry.h"

@implementation pixelpusherTests

- (void)setUp
{
    [super setUp];
    
    // Set-up code here.
}

- (void)tearDown
{
    // Tear-down code here.
    
    [super tearDown];
}

- (void)testExample
{
    DeviceRegistry *deviceRegistry = [[DeviceRegistry alloc] init];
    STAssertNotNil(deviceRegistry, @"Failed to alloc and init DeviceRegistry");
}

@end
