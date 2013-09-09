//
//  PusherGroup.h
//  pixelpusher
//
//  Created by Andrew Kimpton on 9/8/13.
//  Copyright (c) 2013 Andrew Kimpton. All rights reserved.
//

#import <Foundation/Foundation.h>

@class PixelPusher;

@interface PusherGroup : NSObject

- (void) addPusher:(PixelPusher *)pusher;
- (void) removePusher:(PixelPusher *)pusher;
- (NSUInteger) size;

@property (readonly) NSArray* strips;

@end
