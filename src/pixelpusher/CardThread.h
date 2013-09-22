//
//  CardThread.h
//  pixelpusher
//
//  Created by Andrew Kimpton on 9/14/13.
//  Copyright (c) 2013 Andrew Kimpton. All rights reserved.
//

#import <Foundation/Foundation.h>

@class PixelPusher;
@class DeviceRegistry;

@interface CardThread : NSThread

-(id) initWithPusher:(PixelPusher*)thePusher andDeviceRegistry:(DeviceRegistry*)aDeviceRegistry;
-(BOOL) controls:(PixelPusher*) pusher;
-(void) shutdown;

@property (nonatomic, readonly) long bandwidthEstimate;
@property (nonatomic) NSInteger extraDelay;
@property (nonatomic, readonly) BOOL hasTouchedStrips;
@property (nonatomic) BOOL useAntiLog;

@end
