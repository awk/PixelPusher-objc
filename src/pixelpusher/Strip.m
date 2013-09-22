//
//  Strip.m
//  pixelpusher
//
//  Created by Andrew Kimpton on 9/8/13.
//  Copyright (c) 2013 Andrew Kimpton. All rights reserved.
//

#import "Strip.h"
#import "Pixel.h"
#import "PixelPusher.h"

@interface Strip()

@property (nonatomic, retain) NSMutableArray *pixels;
@property (nonatomic, retain) PixelPusher *pusher;
@property NSData *msg;
@end

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

@implementation Strip

- (id) initWithPusher:(PixelPusher *)device stripNumber:(NSUInteger)stripNumber length:(NSUInteger)length
{
    if (self = [super init]) {
        _stripNumber = stripNumber;

        _pixels = [[NSMutableArray alloc] initWithCapacity:length * 3];
        for (int i = 0; i < length; i++) {
            [self.pixels addObject:[[Pixel alloc] init]];
        }
        _pusher = device;
        _stripNumber = stripNumber;
        _touched = false;
        _powerScale = 1.0;
        _RGBOW = false;
        _useAntiLog = false;
        _msg = nil;
    }
    return self;
}


- (NSUInteger) length
{
    return [_pixels count];
}

- (NSString *) getMacAddress
{
    return [self.pusher getMacAddress];
}

- /*synchronized*/ (void) markClean
{
    _touched = false;
    [_pusher markUntouched];
}

- (long) getStripIdentifier
{
    // Return a compact reversible identifier
    return -1;
}

// set the RGBOW state of the strip;  this function is idempotent.
- (void) setRGBOW:(BOOL) state
{
    if (state == _RGBOW) {
        return;
    }
    self.touched = true;
    [_pusher markTouched];
    NSUInteger length = [self.pixels count];
    if (_RGBOW) {  // if we're already set to RGBOW mode
        self.pixels = [[NSMutableArray alloc] initWithCapacity:length * 3];   // else go back to RGB mode - length is shorter in RGBOW mode so multiply it here
        for (int i = 0; i < [self.pixels count]; i++) {
            [self.pixels addObject:[[Pixel alloc] init]];
        }
        _msg = nil;
        _RGBOW = NO;
        return;
    }
    // otherwise, we were in RGB mode.
    if (state) { // if we are going to RGBOW mode
        self.pixels = [[NSMutableArray alloc] initWithCapacity:length / 3];   // shorten the pixel array
        for (int i = 0; i < [self.pixels count]; i++) {
            [self.pixels addObject:[[Pixel alloc] init]];
        }
        _msg = nil;
        _RGBOW = state;
        return;
    }
    // otherwise, do nothing.
    
}

- /*synchronized*/ (void) setPixels:(NSArray *) pixels
{
    self.pixels = [NSMutableArray arrayWithArray:[pixels objectsAtIndexes:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, [self.pixels count])]]];
    self.touched = YES;
    [_pusher markTouched];
}

- /*synchronized*/ (void) setPixelRed:(uint8_t) intensity atPosition:(int) position
{
    if (position >= [self.pixels count]) {
        return;
    }
    Pixel *aPixel = [self.pixels objectAtIndex:position];
    if (_useAntiLog) {
        aPixel.red = sLinearExp[(int)intensity];
    } else {
        aPixel.red = intensity;
    }
    self.touched = YES;
    [_pusher markTouched];
}

- /*synchronized*/ (void) setPixelBlue:(uint8_t) intensity atPosition:(int) position
{
    if (position >= [self.pixels count]) {
        return;
    }
    
    Pixel *aPixel = [self.pixels objectAtIndex:position];
    if (_useAntiLog) {
        aPixel.blue = sLinearExp[(int)intensity];
    } else {
        aPixel.blue = intensity;
    }
    self.touched = YES;
    [_pusher markTouched];
}

- /*synchronized*/ (void) setPixelGreen:(uint8_t) intensity atPosition:(int) position
{
    if (position >= [self.pixels count]) {
        return;
    }
    
    Pixel *aPixel = [self.pixels objectAtIndex:position];
    if (_useAntiLog) {
        aPixel.green = sLinearExp[(int)intensity];
    } else {
        aPixel.green = intensity;
    }
    self.touched = YES;
    [_pusher markTouched];
}

- /*synchronized*/ (void) setPixelOrange:(uint8_t) intensity atPosition:(int) position
{
    if (position >= [self.pixels count]) {
        return;
    }
    
    Pixel *aPixel = [self.pixels objectAtIndex:position];
    if (_useAntiLog) {
        aPixel.orange = sLinearExp[(int)intensity];
    } else {
        aPixel.orange = intensity;
    }
    self.touched = YES;
    [_pusher markTouched];
}

- /*synchronized*/ (void) setPixelWhite:(uint8_t) intensity atPosition:(int) position
{
    if (position >= [self.pixels count]) {
        return;
    }
    
    Pixel *aPixel = [self.pixels objectAtIndex:position];
    if (_useAntiLog) {
        aPixel.white = sLinearExp[(int)intensity];
    } else {
        aPixel.white = intensity;
    }
    self.touched = YES;
    [_pusher markTouched];
}

#ifdef __IPHONE_OS_VERSION_MIN_REQUIRED
- /*synchronized*/ (void) setPixelColor:(UIColor *) color atPosition:(int) position
#else
- /*synchronized*/ (void) setPixelColor:(NSColor *) color atPosition:(int) position
#endif
{
    if (position >= [self.pixels count]) {
        return;
    }
    
    Pixel *aPixel = [self.pixels objectAtIndex:position];
    [aPixel setColor:color useAntiLog:_useAntiLog];
    self.touched = YES;
    [_pusher markTouched];
}

- /*synchronized*/ (void) setPixel:(Pixel *) pixel atPosition:(int) position
{
    if (position >= [self.pixels count]) {
        return;
    }
    
    Pixel *aPixel = [self.pixels objectAtIndex:position];
    [aPixel setPixel:pixel useAntiLog:_useAntiLog];
    self.touched = YES;
    [_pusher markTouched];
}

- (NSData*) serialize
{
    int i = 0;
    BOOL phase = YES;
    unsigned char *serializedMsg;
    if (_RGBOW) {
        Pixel *pixel;
        NSUInteger pixelIdx;
        serializedMsg = malloc([self.pixels count] * 9);
        for (pixelIdx = 0; pixelIdx < [self.pixels count]; pixelIdx++) {
            pixel = [self.pixels objectAtIndex:pixelIdx];
            if (pixel == nil)
                pixel = [[Pixel alloc] init];
            
            if (phase) {
                serializedMsg[i++] = (uint8_t) (((double)pixel.red)   * self.powerScale);    // C
                serializedMsg[i++] = (uint8_t) (((double)pixel.green) * self.powerScale);
                serializedMsg[i++] = (uint8_t) (((double)pixel.blue)  * self.powerScale);
                
                serializedMsg[i++] = (uint8_t) (((double)pixel.orange) * self.powerScale);   // O
                serializedMsg[i++] = (uint8_t) (((double)pixel.orange) * self.powerScale);
                serializedMsg[i++] = (uint8_t) (((double)pixel.orange) * self.powerScale);
                
                serializedMsg[i++] = (uint8_t) (((double)pixel.white) * self.powerScale);    // W
                serializedMsg[i++] = (uint8_t) (((double)pixel.white) * self.powerScale);
                serializedMsg[i++] = (uint8_t) (((double)pixel.white) * self.powerScale);
            } else {
                serializedMsg[i++] = (uint8_t) (((double)pixel.red)   * self.powerScale);    // C
                serializedMsg[i++] = (uint8_t) (((double)pixel.green) * self.powerScale);
                serializedMsg[i++] = (uint8_t) (((double)pixel.blue)  * self.powerScale);
                
                serializedMsg[i++] = (uint8_t) (((double)pixel.white) * self.powerScale);    // W
                serializedMsg[i++] = (uint8_t) (((double)pixel.white) * self.powerScale);
                serializedMsg[i++] = (uint8_t) (((double)pixel.white) * self.powerScale);
                
                serializedMsg[i++] = (uint8_t) (((double)pixel.orange) * self.powerScale);   // O
                serializedMsg[i++] = (uint8_t) (((double)pixel.orange) * self.powerScale);
                serializedMsg[i++] = (uint8_t) (((double)pixel.orange) * self.powerScale);
            }
            phase = !phase;
        }
    } else {
        Pixel *pixel;
        NSUInteger pixelIdx;

        serializedMsg = malloc([self.pixels count] * 3);
        for (pixelIdx = 0; pixelIdx < [self.pixels count]; pixelIdx++) {
            pixel = [self.pixels objectAtIndex:pixelIdx];
            if (pixel == nil)
                pixel = [[Pixel alloc] init];

            serializedMsg[i++] = (uint8_t) (((double)pixel.red) * self.powerScale);
            serializedMsg[i++] = (uint8_t) (((double)pixel.green) * self.powerScale);
            serializedMsg[i++] = (uint8_t) (((double)pixel.blue) * self.powerScale);
        }
    }
    _msg = [[NSData alloc] initWithBytes:serializedMsg length:[self.pixels count] * 3];
    free(serializedMsg);
    return _msg;
}

@end

