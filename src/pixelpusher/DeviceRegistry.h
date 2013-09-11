//
//  DeviceRegistry.h
//  pixelpusher
//
//  Created by Andrew Kimpton on 9/6/13.
//  Copyright (c) 2013 Andrew Kimpton. All rights reserved.
//

#import <Foundation/Foundation.h>

@class Pixel;

extern NSString *REGISTRY_PUSHERS_CHANGED;

@interface DeviceRegistry : NSObject

- (void) startListening;
- (void) expireDeviceWithMacAddr:(NSString *) macAddr;
- (NSArray *) getStrips;
- (void) setStripValuesWithMacAddr:(NSString *) macAddress stripNumber:(NSInteger) stripNumber pixels:(Pixel*) pixels;
- (void) startPushing;
- (void) stopPushing;

- (void) receive:(NSData *) data;

@property (nonatomic, readonly) NSDictionary* pusherMap;

@end
