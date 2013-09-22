//
//  SceneThread.m
//  pixelpusher
//
//  Created by Andrew Kimpton on 9/14/13.
//  Copyright (c) 2013 Andrew Kimpton. All rights reserved.
//

#import "SceneThread.h"
#import "PixelPusher.h"
#import "CardThread.h"
#import "DeviceRegistry.h"

#import <pthread.h>

@interface SceneThread() {
    NSMutableDictionary *_pusherMap;
    NSMutableDictionary *_cardThreadMap;
    NSLock *_listSemaphore;
    BOOL _drain;
    
    NSInteger _extraDelay;
    BOOL _autoThrottle;
    BOOL _frameCallback;
    BOOL _useAntiLog;
    
    id _frameCallbackObject;
    SEL _frameCallbackSelector;
}

-(void) updateFromRegistry:(DeviceRegistry*) aDeviceRegistry;

@property (nonatomic, readonly) long totalBandwidth;

@end

@implementation SceneThread

- (id)initWithDeviceRegistry:(DeviceRegistry *)aDeviceRegistry
{
    self = [super init];
    if (self) {
        _pusherMap = [[NSMutableDictionary alloc] init];
        _cardThreadMap = [[NSMutableDictionary alloc] init];
        _drain = NO;
        _listSemaphore = [[NSLock alloc] init];
        
        void (^registryChangedBlock)(NSNotification*) = ^(NSNotification *note) {
            [self updateFromRegistry:note.object];
        };
        [[NSNotificationCenter defaultCenter] addObserverForName:REGISTRY_PUSHERS_ADDED object:aDeviceRegistry queue:[NSOperationQueue mainQueue] usingBlock:registryChangedBlock];
        [[NSNotificationCenter defaultCenter] addObserverForName:REGISTRY_PUSHERS_REMOVED object:aDeviceRegistry queue:[NSOperationQueue mainQueue] usingBlock:registryChangedBlock];
        [[NSNotificationCenter defaultCenter] addObserverForName:REGISTRY_PUSHERS_CHANGED object:aDeviceRegistry queue:[NSOperationQueue mainQueue] usingBlock:registryChangedBlock];

    }
    return self;
}

- (void) setAutoThrottle:(BOOL) autothrottle {
    _autoThrottle = autothrottle;
    //System.err.println("Setting autothrottle in SceneThread.");
    for (PixelPusher *pusher in [_pusherMap allValues]) {
        //System.err.println("Setting card "+pusher.getControllerOrdinal()+" group "+pusher.getGroupOrdinal()+" to "+
        //      (autothrottle?"throttle":"not throttle"));
        pusher.autoThrottle = autothrottle;
    }
}

- (long) getTotalBandwidth {
    long totalBandwidth=0;
    for (CardThread *thread in [_cardThreadMap allValues]) {
        totalBandwidth += thread.bandwidthEstimate;
    }
    return totalBandwidth;
}

- (void) setExtraDelay:(NSInteger) msec {
    _extraDelay = msec;
    for (CardThread *thread in [_cardThreadMap allValues]) {
        thread.extraDelay = msec;
    }
}

- (void) removePusherThread:(PixelPusher*) card {
    for (CardThread *th in [_cardThreadMap allValues]) {
        if ([th controls:card]) {
            [th shutdown];
            [th cancel];
        }
    }
    [_cardThreadMap removeObjectForKey:[card getMacAddress]];
}

-(void) updateFromRegistry:(DeviceRegistry *)aDeviceRegistry
{
    if (!_drain) {
        [_listSemaphore lock];
        
        NSDictionary *incomingPusherMap = aDeviceRegistry.pusherMap; // all observed pushers
        NSMutableDictionary *newPusherMap = [incomingPusherMap mutableCopy];
        NSMutableDictionary *deadPusherMap = [_pusherMap mutableCopy];
        NSMutableDictionary *currentPusherMap = [_pusherMap mutableCopy];
        
            for (NSString *key in [incomingPusherMap allKeys]) {
                if ([currentPusherMap objectForKey:key]) { // if we already know about it
                    [newPusherMap removeObjectForKey:key]; // remove it from the new pusher map (is
                    // old)
                }
            }
            for (NSString *key in [currentPusherMap allKeys]) {
                if ([incomingPusherMap objectForKey:key]) { // if it's in the new pusher map
                    [deadPusherMap removeObjectForKey:key]; // it can't be dead
                }
            }
        
        for (NSString *key in [newPusherMap allKeys]) {
            PixelPusher *thePusher = [newPusherMap objectForKey:key];
            CardThread *newCardThread = [[CardThread alloc] initWithPusher:thePusher andDeviceRegistry:aDeviceRegistry];
            if (self.isExecuting) {
                [newCardThread start];
                newCardThread.extraDelay = _extraDelay;
                newCardThread.useAntiLog = _useAntiLog;
                thePusher.autoThrottle = _autoThrottle;
                thePusher.useAntiLog= _useAntiLog;
            }
            [_pusherMap setValue:[newPusherMap valueForKey:key] forKey:key];
            [_cardThreadMap setValue:newCardThread forKey:key];
        }
        for (NSString *key in [deadPusherMap allKeys]) {
            NSLog(@"Killing old CardThread %@", key);
            [[_cardThreadMap objectForKey:key] cancel];
            [_cardThreadMap removeObjectForKey:key];
            [_pusherMap removeObjectForKey:key];
        }
        [_listSemaphore unlock];
    }
}

- (void) main {
    _drain = NO;
    for (CardThread *thread in [_cardThreadMap allValues]) {
        [thread start];
    }
    
    while (!self.isCancelled) {
        if (_frameCallback) {
            BOOL frameDirty = NO;
            for (CardThread *thread  in [_cardThreadMap allValues]) {
                frameDirty |= thread.hasTouchedStrips;
            }
            if (!frameDirty) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
                [_frameCallbackObject performSelector:_frameCallbackSelector];
#pragma clang diagnostic pop
            }
                
        }
        if (_frameCallback) {
            pthread_yield_np();
        } else {
            [NSThread sleepForTimeInterval:0.032]; // two frames should be safe
        }
    }
}

- (void) cancel {
    _drain = YES;
    for (NSString *key in [_cardThreadMap allKeys]) {
        [[_cardThreadMap objectForKey:key] cancel];
        [_cardThreadMap removeObjectForKey:key];
    }
}

- (void) stopFrameCallback {
    _frameCallback = NO;
}

- (void) setFrameCallback:(id)obj selector:(SEL) selector {
    _frameCallbackObject = obj;
    _frameCallbackSelector = selector;
    _frameCallback = NO;
}

- (void) useAntiLog:(BOOL) antiLog {
    _useAntiLog = antiLog;
    for (PixelPusher *pusher in [_pusherMap allValues]) {
        //System.err.println("Setting card "+pusher.getControllerOrdinal()+" group "+pusher.getGroupOrdinal()+" to "+
        //      (autothrottle?"throttle":"not throttle"));
        pusher.useAntiLog = antiLog;
    }
}

@end
