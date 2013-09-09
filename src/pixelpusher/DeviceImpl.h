//
//  DeviceImpl.h
//  pixelpusher
//
//  Created by Andrew Kimpton on 9/7/13.
//  Copyright (c) 2013 Andrew Kimpton. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "Device.h"

@interface DeviceImpl : NSObject<Device>

- (id) initWithHeader:(DeviceHeader *)aHeader;

@end
