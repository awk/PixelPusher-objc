//
//  Pixel.m
//  pixelpusher
//
//  Created by Andrew Kimpton on 9/8/13.
//  Copyright (c) 2013 Andrew Kimpton. All rights reserved.
//

#import "Pixel.h"

static uint8_t sLinearExp[] =
{ 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 1,
    1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
    1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
    1, 1, 1, 2, 2, 2, 2, 2, 2, 2,
    2, 2, 2, 2, 2, 2, 2, 2, 3, 3,
    3, 3, 3, 3, 3, 3, 3, 3, 3, 3,
    4, 4, 4, 4, 4, 4, 4, 4, 4, 5,
    5, 5, 5, 5, 5, 5, 5, 6, 6, 6,
    6, 6, 6, 7, 7, 7, 7, 7, 7, 8,
    8, 8, 8, 8, 9, 9, 9, 9, 9, 10,
    10, 10, 10, 11, 11, 11, 11, 12, 12, 12,
    13, 13, 13, 14, 14, 14, 14, 15, 15, 16,
    16, 16, 17, 17, 17, 18, 18, 19, 19, 20,
    20, 20, 21, 21, 22, 22, 23, 23, 24, 25,
    25, 26, 26, 27, 27, 28, 29, 29, 30, 31,
    31, 32, 33, 34, 34, 35, 36, 37, 38, 38,
    39, 40, 41, 42, 43, 44, 45, 46, 47, 48,
    49, 50, 51, 52, 54, 55, 56, 57, 59, 60,
    61, 63, 64, 65, 67, 68, 70, 72, 73, 75,
    76, 78, 80, 82, 83, 85, 87, 89, 91, 93,
    95, 97, 99, 102, 104, 106, 109, 111, 114, 116,
    119, 121, 124, 127, 129, 132, 135, 138, 141, 144,
    148, 151, 154, 158, 161, 165, 168, 172, 176, 180,
    184, 188, 192, 196, 201, 205, 209, 214, 219, 224,
    229, 234, 239, 244, 249, 255 };

@implementation Pixel

- (id)init
{
    self = [super init];
    if (self) {
        _red = _green = _blue = _orange = _white = 0;
    }
    return self;
}

#ifdef __IPHONE_OS_VERSION_MIN_REQUIRED
- (id) initWithColor:(UIColor *) color useAntiLog:(BOOL) useAntiLog
#else
- (id) initWithColor:(NSColor *) color useAntiLog:(BOOL) useAntiLog
#endif
{
    self = [super init];
    if (self) {
        [self setColor:color useAntiLog:useAntiLog];
    }
    return self;
}

// Processing "color" objects only support the axes of red, green and blue.
#ifdef __IPHONE_OS_VERSION_MIN_REQUIRED
- (void) setColor:(UIColor *) color useAntiLog:(BOOL)useAntiLog
#else
- (void) setColor:(NSColor *) color useAntiLog:(BOOL)useAntiLog
#endif
{
    CGFloat red, green, blue, alpha;
    [color getRed:&red green:&green blue:&blue alpha:&alpha];
    
    if (useAntiLog) {
        self.blue = sLinearExp[(uint8_t)(blue * 255.0f) & 0xff];
        self.green = sLinearExp[(uint8_t)(green * 255.0f) & 0xff];
        self.red = sLinearExp[(uint8_t)(red * 255.0f) & 0xff];
    } else {
        self.blue = (uint8_t)(blue * 255.0f) & 0xff;
        self.green = (uint8_t)(green * 255.0f) & 0xff;
        self.red = (uint8_t)(red * 255.0f) & 0xff;
    }
    self.orange = 0;
    self.white = 0;
}

- (void) setPixel:(Pixel *)pixel useAntiLog:(BOOL) useAntiLog
{
    if (useAntiLog) {
        self.red = sLinearExp[pixel.red];
        self.blue = sLinearExp[pixel.blue];
        self.green = sLinearExp[pixel.green];
        self.orange = sLinearExp[pixel.orange];
        self.white = sLinearExp[pixel.white];
    } else {
        self.red = pixel.red;
        self.blue = pixel.blue;
        self.green = pixel.green;
        self.orange = pixel.orange;
        self.white = pixel.white;
    }
}

@end
