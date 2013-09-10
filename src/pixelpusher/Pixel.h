//
//  Pixel.h
//  pixelpusher
//
//  Created by Andrew Kimpton on 9/8/13.
//  Copyright (c) 2013 Andrew Kimpton. All rights reserved.
//

#import <Foundation/Foundation.h>
#if __IPHONE_OS_VERSION_MIN_REQUIRED
#import <UIKit/UIKit.h>
#endif

@interface Pixel : NSObject

@property uint8_t red;
@property uint8_t green;
@property uint8_t blue;
@property uint8_t orange;
@property uint8_t white;

#ifdef __MAC_OS_X_VERSION_MAX_ALLOWED
- (void) setColor:(NSColor *) color useAntiLog:(BOOL) useAntiLog;
#else
- (void) setColor:(UIColor *) color useAntiLog:(BOOL) useAntiLog;
#endif
- (void) setPixel:(Pixel *) pixel useAntiLog:(BOOL) useAntiLog;

@end
