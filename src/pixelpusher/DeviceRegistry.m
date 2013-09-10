//
//  DeviceRegistry.m
//  pixelpusher
//
//  Created by Andrew Kimpton on 9/6/13.
//   (c) 2013 Andrew Kimpton. All rights reserved.
//

#import "DeviceRegistry.h"
#import "AsyncUdpSocket.h"
#import "DeviceHeader.h"
#import "PixelPusher.h"
#import "PusherGroup.h"

#import <pthread.h>

const NSInteger DISCOVERY_PORT = 7331;
const NSInteger SOCKET_RECV_TIMEOUT = -1;
const NSInteger DISCOVERT_SOCKET_TAG = 0x01;

NSString *REGISTRY_PUSHERS_VALUE_KEY = @"pushers";

@interface DiscoveryListenerThread : NSThread {
    DeviceRegistry *_deviceRegistry;
    AsyncUdpSocket *_discoverySocket;
    NSInteger _portNum;
}

- (id) initWithPort:(NSInteger) portNum andDeviceRegistry:(DeviceRegistry *) deviceRegistry;

@end

@interface DeviceRegistry () {
    DiscoveryListenerThread *_discoveryThread;
    NSLock *_updateLock;
    NSMutableDictionary *_pusherLastSeenMap;
    NSMutableDictionary *_pusherMap;
    NSMutableDictionary *_groupMap;
    
    BOOL _useAntiLog;
    BOOL _autoThrottle;
    BOOL _logEnabled;
}

- (void) addNewPusherWithMacAddr:(NSString *)macAddr andDevice:(PixelPusher*)pusher;

@end


@implementation DeviceRegistry

- (id) init
{
    if (self = [super init]) {
        _logEnabled = YES;
        _updateLock = [[NSLock alloc] init];
        _pusherLastSeenMap = [NSMutableDictionary dictionaryWithCapacity:5];
        _pusherMap = [NSMutableDictionary dictionaryWithCapacity:5];
        _groupMap = [NSMutableDictionary dictionaryWithCapacity:5];
        _discoveryThread = [[DiscoveryListenerThread alloc] initWithPort:DISCOVERY_PORT andDeviceRegistry:self];
    }
    return self;
}

- (void) startListening
{
    if (_discoveryThread) {
        [_discoveryThread start];
    }
}

- (void) expireDeviceWithMacAddr:(NSString *) macAddr
{

}

- (NSArray *) getStrips
{
    return nil;
}

- (void) receive:(NSData *) data
{
    // This is for the UDP callback, this should not be called directly
    [_updateLock lock];
    DeviceHeader *header = [[DeviceHeader alloc] initWithData:data];
    NSString *macAddr = [header macAddressAsString];
    if (header.deviceType != PIXELPUSHER) {
        NSLog(@"Ignoring non-PixelPusher discovery packet from %@", header);
        return;
    }
    PixelPusher *device = [[PixelPusher alloc] initWithHeader:header andRemainingData:header.packetRemainder];
    device.useAntiLog = _useAntiLog;
    
    // Set the timestamp for the last time this device checked in
    [_pusherLastSeenMap setValue:[NSDate date] forKey:macAddr];
    
    PixelPusher *anExistingDevice = [_pusherMap valueForKey:macAddr];
    if (!anExistingDevice) {
        // We haven't seen this device before
        [self addNewPusherWithMacAddr:macAddr andDevice:device];
    } else {
        if (![anExistingDevice equals:device]) { // we already saw it but it's changed.
            while ([anExistingDevice isBusy]) {
                pthread_yield_np();
            }
            [self updatePusherWithMacAddr:macAddr andDevice:device];
        } else {
            // The device is identical, nothing important has changed
            NSLog(@"Updating pusher from bcast.");
            [anExistingDevice updateVariablesWithDevice:device];
            // if we dropped more than occasional packets, slow down a little
            if (device.deltaSequence > 3) {
                [anExistingDevice increaseExtraDelay:5];
            }
            if (device.deltaSequence < 1) {
                [anExistingDevice decreaseExtraDelay:1];
            }
            NSLog(@"%@", device);
        }
    }
    
#if 0
    // update the power limit variables
    if (totalPowerLimit > 0) {
        totalPower = 0;
        for (Iterator<PixelPusher> iterator = sortedPushers.iterator(); iterator
             .hasNext();) {
            PixelPusher pusher = iterator.next();
            totalPower += pusher.getPowerTotal();
        }
        if (totalPower > totalPowerLimit) {
            powerScale = totalPowerLimit / totalPower;
        } else {
            powerScale = 1.0;
        }
    }
#endif
    [_updateLock unlock];
}

- (void) updatePusherWithMacAddr:(NSString *) macAddr andDevice:(PixelPusher*) device
{
    // We already knew about this device at the given MAC, but its details
    // have changed
    [self willChangeValueForKey:REGISTRY_PUSHERS_VALUE_KEY];
    if (_logEnabled) {
        NSLog(@"Device changed: %@", macAddr);
    }
    [[_pusherMap valueForKey:macAddr] copyHeader:device];
    
    [self didChangeValueForKey:REGISTRY_PUSHERS_VALUE_KEY];
}

- (void) setStripValuesWithMacAddr:(NSString *) macAddress stripNumber:(NSInteger) stripNumber pixels:(Pixel*) pixels
{
    
}

- (void) startPushing
{
    
}

- (void) stopPushing
{
}

- (void) addNewPusherWithMacAddr:(NSString *)macAddr andDevice:(PixelPusher*)pusher
{
    [self willChangeValueForKey:REGISTRY_PUSHERS_VALUE_KEY];
    
    if (_logEnabled) {
        NSLog(@"New device: %@ has group ordinal %d", macAddr, pusher.groupOrdinal);
    }
    [_pusherMap setValue:pusher forKey:macAddr];
    if (_logEnabled) {
        NSLog(@"Adding to sorted list");
    }
//    sortedPushers.add(pusher);
    if (_logEnabled) {
        NSLog(@"Adding to group map");
    }
    NSString *groupOrdinalKey = [[NSNumber numberWithInt:pusher.groupOrdinal] stringValue];
    PusherGroup *pg = [_groupMap valueForKey:groupOrdinalKey];
    if (pg != nil) {
        if (_logEnabled) {
            NSLog(@"Adding pusher to group %d", pusher.groupOrdinal);
        }
        [pg addPusher:pusher];
    } else {
        // we need to create a PusherGroup since it doesn't exist yet.
        pg = [[PusherGroup alloc] init];
        if (_logEnabled) {
            NSLog(@"Creating group and adding pusher to group %d", pusher.groupOrdinal);
        }
        [pg addPusher:pusher];
        [_groupMap setValue:pg forKey:groupOrdinalKey];
    }
    [pusher setAutoThrottle:_autoThrottle];
    if (_logEnabled) {
        NSLog(@"Notifying observers");
    }
    [self didChangeValueForKey:REGISTRY_PUSHERS_VALUE_KEY];
}

+ (BOOL)automaticallyNotifiesObserversForKey:(NSString *)theKey {
    
    BOOL automatic = NO;
    if ([theKey isEqualToString:REGISTRY_PUSHERS_VALUE_KEY]) {
        automatic = NO;
    }
    else {
        automatic = [super automaticallyNotifiesObserversForKey:theKey];
    }
    return automatic;
}

@end

@implementation DiscoveryListenerThread

- (id) initWithPort:(NSInteger)portNum andDeviceRegistry:(DeviceRegistry *)deviceRegistry
{
    if (self = [super init]) {
        _deviceRegistry = deviceRegistry;
        _portNum = portNum;
    }
    return self;
}

- (void) main
{
    // Sample data buffer:
    //      0002f7f1 7589c0a8 14dc0201 02000100 02006e00 00e1f505 04013401 a0860100
    //      607d0a00 00000000 00000000 00000000 00000000 a9260000 00000000 00000000
    @autoreleasepool {
        NSError *error = nil;
        NSRunLoop *theRL = [NSRunLoop currentRunLoop];

        [NSTimer scheduledTimerWithTimeInterval:DBL_MAX target:self selector:@selector(ignore:) userInfo:nil repeats:NO];

        _discoverySocket = [[AsyncUdpSocket alloc] initWithDelegate:self];
        if (![_discoverySocket bindToPort:_portNum error:&error]) {
            NSLog(@"Failed to bind to port %ld - error = %@\n", (long) _portNum, error);
            return;
        }
        NSLog(@"Listening for PixelPusher announcements on %@ port %d",
              [_discoverySocket localHost],
              [_discoverySocket localPort]);

        [_discoverySocket receiveWithTimeout:SOCKET_RECV_TIMEOUT tag:DISCOVERT_SOCKET_TAG];
        while (![self isCancelled]) {
            BOOL rlStatus = [theRL runMode:NSDefaultRunLoopMode beforeDate:[NSDate distantFuture]];
            if (!rlStatus) {
                NSLog(@"Runloop returned NO!");
            }
        }
    }
}

- (BOOL)onUdpSocket:(AsyncUdpSocket *)sock
     didReceiveData:(NSData *)data
            withTag:(long)tag
           fromHost:(NSString *)host
               port:(UInt16)port
{
    if (tag == DISCOVERT_SOCKET_TAG) {
        [_deviceRegistry receive:data];
        [_discoverySocket receiveWithTimeout:SOCKET_RECV_TIMEOUT tag:DISCOVERT_SOCKET_TAG];
    }
    return YES;
}

@end