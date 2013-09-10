//
//  FWAppDelegate.m
//  pixelscene
//
//  Created by Andrew Kimpton on 9/7/13.
//  Copyright (c) 2013 Andrew Kimpton. All rights reserved.
//

#import "FWAppDelegate.h"

#import "DeviceRegistry.h"

@implementation FWAppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    DeviceRegistry *aDeviceRegistry = [[DeviceRegistry alloc] init];
    if (!aDeviceRegistry) {
        NSLog(@"Failed to create Device Registry");
    }
    [aDeviceRegistry startListening];
}

@end
