//
//  Device.h
//  pixelpusher
//
//  Created by Andrew Kimpton on 9/7/13.
//  Copyright (c) 2013 Andrew Kimpton. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "DeviceHeader.h"

@protocol Device <NSObject>

- (NSString *) getMacAddress;

- (NSString *) getIp;

- (DeviceType) getDeviceType;

- (NSInteger) getProtocolVersion;
- (NSInteger) getVendorId;
- (NSInteger) getProductId;
- (NSInteger) getHardwareRevision;
- (NSInteger) getSoftwareRevision;
- (NSInteger) getLinkSpeed;

@end
