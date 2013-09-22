//
//  FWAppDelegate.m
//  pixelscene
//
//  Created by Andrew Kimpton on 9/7/13.
//  Copyright (c) 2013 Andrew Kimpton. All rights reserved.
//

#import "FWAppDelegate.h"

#import "DeviceRegistry.h"
#import "Strip.h"

@interface FWAppDelegate() {
    DeviceRegistry *_deviceRegistry;
    float _brightness;
}

@end

@implementation FWAppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    _deviceRegistry = [[DeviceRegistry alloc] init];
    if (!_deviceRegistry) {
        NSLog(@"Failed to create Device Registry");
    }
    [[NSNotificationCenter defaultCenter] addObserverForName:REGISTRY_PUSHERS_ADDED object:_deviceRegistry
                         queue:[NSOperationQueue mainQueue]
                    usingBlock:^(NSNotification *note)
     {
         NSLog(@"Pusher Detected!");
         _brightness = 0.0;
         NSTimer *updateTimer = [NSTimer timerWithTimeInterval:1.0/50.0 target:self selector:@selector(updateStrips:) userInfo:nil repeats:YES];
         [[NSRunLoop currentRunLoop] addTimer:updateTimer forMode:NSDefaultRunLoopMode];
     }];
    
    
    [_deviceRegistry startListening];
}

-(void) updateStrips:(NSTimer*)timer
{
    [_deviceRegistry startPushing];
    [_deviceRegistry setExtraDelay:0];
    [_deviceRegistry setAutoThrottle:YES];
    int stripy = 0;
    
    NSArray *strips = [_deviceRegistry getStrips];
    
    NSUInteger numStrips = [strips count];
    //println("Strips total = "+numStrips);
    if (numStrips == 0) {
        return;
    }
    
//    for (int stripNo = 0; stripNo < numStrips; stripNo++) {
//        fill(c+(stripNo*2), 100, 100);
//        rect(0, stripNo * (height/numStrips), width/2, (stripNo+1) * (height/numStrips));
//        fill(c+((numStrips - stripNo)*2), 100, 100);
//        rect(width/2, stripNo * (height/numStrips), width, (stripNo+1) * (height/numStrips));
//    }
    
    
//    int yscale = height / strips.size();
    for(Strip *strip in strips) {
//        int xscale = width / strip.length;
        for (int stripx = 0; stripx < strip.length; stripx++) {
//            x = stripx*xscale + 1;
//            y = stripy*yscale + 1;
//            color c = get(x, y);
            NSColor *aColor = [NSColor colorWithCalibratedRed:1.0 * _brightness green:0.0 blue:0.0 alpha:0.0];
            [strip setPixelColor:aColor atPosition:stripx];
        }
        stripy++;
    }

    _brightness += 0.001;
    if (_brightness > 1.0) {
        _brightness = 0;
    }
}
@end
