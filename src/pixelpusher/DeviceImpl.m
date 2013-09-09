//
//  DeviceImpl.m
//  pixelpusher
//
//  Created by Andrew Kimpton on 9/7/13.
//  Copyright (c) 2013 Andrew Kimpton. All rights reserved.
//

#import "DeviceImpl.h"

@interface DeviceImpl () {
    DeviceHeader *mDeviceHeader;
}
@end

@implementation DeviceImpl

- (id)initWithHeader:(DeviceHeader *)aHeader
{
    self = [super init];
    if (self) {
        mDeviceHeader = aHeader;
    }
    return self;
}

- (NSString *) getMacAddress
{
    return [mDeviceHeader macAddressAsString];
}

//InetAddress getIp();

- (DeviceType) getDeviceType
{
    return mDeviceHeader.deviceType;
}

- (NSInteger) getProtocolVersion
{
    return mDeviceHeader.protocolVersion;
}

- (NSInteger) getVendorId
{
    return mDeviceHeader.vendorId;
}

- (NSInteger) getProductId
{
    return mDeviceHeader.productId;
}

- (NSInteger) getHardwareRevision
{
    return mDeviceHeader.hardwareRevision;
}

- (NSInteger) getSoftwareRevision
{
    return mDeviceHeader.softwareRevision;
}

- (NSInteger) getLinkSpeed
{
    return mDeviceHeader.linkSpeed;
}

@end
