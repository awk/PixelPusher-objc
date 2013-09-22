//
//  pixelpusher.h
//  pixelpusher
//
//  Created by Andrew Kimpton on 9/6/13.
//  Copyright (c) 2013 Andrew Kimpton. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "DeviceImpl.h"

@interface PixelPusher : DeviceImpl

- (id) initWithHeader:(DeviceHeader *)aHeader andRemainingData:(NSData*)packet;

- (void) updateVariablesWithDevice:(PixelPusher *)device;
- (void) copyHeader:(PixelPusher *)device;

- (void) increaseExtraDelay:(long)delta;
- (void) decreaseExtraDelay:(long)delta;

- (void) markTouched;
- (void) markUntouched;
- (void) makeBusy;
- (void) clearBusy;

- (BOOL) equals:(PixelPusher*) otherPusher;

@property BOOL stripsCreated;
@property long updatePeriod;
@property BOOL hasRGBOW;
@property (readonly) int pixelsPerStrip;
@property int artnet_channel;
@property int artnet_universe;
@property (readonly) NSInteger port;
@property long deltaSequence;
@property (readonly) int groupOrdinal;
@property (readonly) int controllerOrdinal;
@property BOOL isBusy;
@property BOOL autoThrottle;
@property int maxStripsPerPacket;
@property long powerTotal;
@property (readonly) int stripsAttached;
@property NSString *filename;
@property BOOL amRecording;
@property BOOL useAntiLog;
@property (readonly) NSUInteger numberOfStrips;
@property (readonly) NSArray *strips;
@property (nonatomic, readonly) BOOL touchedStrips;
@property (nonatomic, readonly) NSInteger extraDelayMsec;

@end
