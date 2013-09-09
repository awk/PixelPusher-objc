//
//  Pixel.h
//  pixelpusher
//
//  Created by Andrew Kimpton on 9/8/13.
//  Copyright (c) 2013 Andrew Kimpton. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface Pixel : NSObject

@property uint8 red;
@property uint8 green;
@property uint8 blue;
@property uint8 orange;
@property uint8 white;

- (void) setColor:(NSColor *) color useAntiLog:(BOOL) useAntiLog;
- (void) setPixel:(Pixel *) pixel useAntiLog:(BOOL) useAntiLog;

@end
