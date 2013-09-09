//
//  Strip.h
//  pixelpusher
//
//  Created by Andrew Kimpton on 9/8/13.
//  Copyright (c) 2013 Andrew Kimpton. All rights reserved.
//

#import <Foundation/Foundation.h>

@class PixelPusher;

@interface Strip : NSObject

- (id) initWithPusher:(PixelPusher *)device stripNumber:(NSUInteger)stripNumber length:(NSUInteger)length;

@property BOOL useAntiLog;
@property NSUInteger stripNumber;
@property (nonatomic) BOOL RGBOW;
@end
