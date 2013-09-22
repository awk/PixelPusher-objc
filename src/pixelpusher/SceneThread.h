//
//  SceneThread.h
//  pixelpusher
//
//  Created by Andrew Kimpton on 9/14/13.
//  Copyright (c) 2013 Andrew Kimpton. All rights reserved.
//

#import <Foundation/Foundation.h>

@class DeviceRegistry;
@class PixelPusher;

@interface SceneThread : NSThread

- (id)initWithDeviceRegistry:(DeviceRegistry *)aDeviceRegistry;
- (void) removePusherThread:(PixelPusher*) card;

@property (nonatomic) BOOL autoThrottle;
@property (nonatomic) NSInteger extraDelay;

@end
