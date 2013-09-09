//
//  PusherGroup.m
//  pixelpusher
//
//  Created by Andrew Kimpton on 9/8/13.
//  Copyright (c) 2013 Andrew Kimpton. All rights reserved.
//

#import "PusherGroup.h"
#import "PixelPusher.h"

@interface PusherGroup () {
    NSMutableSet *_pushers;
}

@end

@implementation PusherGroup

- (id)init
{
    self = [super init];
    if (self) {
        _pushers = [[NSMutableSet alloc] initWithCapacity:5];
    }
    return self;
}

- (NSArray *) getStrips
{
    NSMutableArray *strips = [[NSMutableArray alloc] initWithCapacity:5];
    for (PixelPusher *aPusher in _pushers) {
        [strips addObjectsFromArray:aPusher.strips];
    }
    return strips;
}
- (void) addPusher:(PixelPusher *)pusher
{
    [_pushers addObject:pusher];
}

- (void) removePusher:(PixelPusher *)pusher
{
    [_pushers removeObject:pusher];
}

- (NSUInteger) size
{
    return [_pushers count];
}

@end
