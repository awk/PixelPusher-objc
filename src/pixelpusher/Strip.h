//
//  Strip.h
//  pixelpusher
//
//  Created by Andrew Kimpton on 9/8/13.
//  Copyright (c) 2013 Andrew Kimpton. All rights reserved.
//

#import <Foundation/Foundation.h>
#if __IPHONE_OS_VERSION_MIN_REQUIRED
#import <UIKit/UIKit.h>
#endif

@class PixelPusher;

@interface Strip : NSObject

- (id) initWithPusher:(PixelPusher *)device stripNumber:(NSUInteger)stripNumber length:(NSUInteger)length;

#ifdef __IPHONE_OS_VERSION_MIN_REQUIRED
- /*synchronized*/ (void) setPixelColor:(UIColor *) color atPosition:(int) position;
#else
- /*synchronized*/ (void) setPixelColor:(NSColor *) color atPosition:(int) position;
#endif

- (NSData*) serialize;
- (void) markClean;

@property BOOL useAntiLog;
@property NSUInteger stripNumber;
@property (nonatomic) BOOL RGBOW;
@property (nonatomic, readonly) NSUInteger length;
@property BOOL touched;
@property double powerScale;

@end
