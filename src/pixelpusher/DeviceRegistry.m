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
#import "SceneThread.h"

const NSInteger DISCOVERY_PORT = 7331;
const NSInteger SOCKET_RECV_TIMEOUT = -1;
const NSInteger DISCOVERT_SOCKET_TAG = 0x01;
const NSTimeInterval MAX_DISCONNECT_SECONDS = 10.0;

NSString *REGISTRY_PUSHERS_ADDED = @"pushers_added";
NSString *REGISTRY_PUSHERS_REMOVED = @"pushers_removed";
NSString *REGISTRY_PUSHERS_CHANGED = @"pushers_changed";

@interface DiscoveryListenerThread : NSThread {
    DeviceRegistry *_deviceRegistry;
    AsyncUdpSocket *_discoverySocket;
    NSInteger _portNum;
}

- (id) initWithPort:(NSInteger) portNum andDeviceRegistry:(DeviceRegistry *) deviceRegistry;

@end

@interface DeviceRegistry () {
    DiscoveryListenerThread *_discoveryThread;
    SceneThread *_sceneThread;
    
    NSLock *_updateLock;
    NSMutableDictionary *_pusherLastSeenMap;
    NSMutableDictionary *_pusherMap;
    NSMutableDictionary *_groupMap;
    
    long _totalPower;
    long _totalPowerLimit;
    double _powerScale;

    BOOL _useAntiLog;
    BOOL _autoThrottle;
    BOOL _logEnabled;
}

- (void) addNewPusherWithMacAddr:(NSString *)macAddr andDevice:(PixelPusher*)pusher;

@property (nonatomic, readonly) NSArray *sortedPushers;
@property (nonatomic) long totalPower;
@property (nonatomic) long totalPowerLimit;

@end


@implementation DeviceRegistry

- (id) init
{
    if (self = [super init]) {
        _logEnabled = NO;
        _updateLock = [[NSLock alloc] init];
        _pusherLastSeenMap = [NSMutableDictionary dictionaryWithCapacity:5];
        _pusherMap = [NSMutableDictionary dictionaryWithCapacity:5];
        _groupMap = [NSMutableDictionary dictionaryWithCapacity:5];
        _discoveryThread = [[DiscoveryListenerThread alloc] initWithPort:DISCOVERY_PORT andDeviceRegistry:self];
        _sceneThread = [[SceneThread alloc] initWithDeviceRegistry:self];
        _totalPowerLimit = -1;
        _powerScale = 1.0;
        _frameLimit = 85;
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

- (NSArray *) sortedPushers {
    NSArray *sortedPushers = [[_pusherMap allValues] sortedArrayUsingComparator:^NSComparisonResult(PixelPusher *obj0, PixelPusher *obj1) {
        int group0 = obj0.groupOrdinal;
        int group1 = obj1.groupOrdinal;
        if (group0 != group1) {
            if (group0 < group1) {
                return NSOrderedAscending;
            }
            return NSOrderedDescending;
        }
        
        int ord0 = obj0.controllerOrdinal;
        int ord1 = obj1.controllerOrdinal;
        if (ord0 != ord1) {
            if (ord0 < ord1) {
                return NSOrderedAscending;
            }
            return NSOrderedDescending;
        }
        
        return [[obj0 getMacAddress] compare:[obj1 getMacAddress]];
    }];
    
    return sortedPushers;
}

- (NSArray *) getStrips
{
    NSMutableArray *strips = [[NSMutableArray alloc] initWithCapacity:self.sortedPushers.count * 8];
    [_updateLock lock];
    for (PixelPusher *p in self.sortedPushers) {
        [strips addObjectsFromArray:p.strips];
    }
    [_updateLock unlock];
    return strips;
}

- (void) receive:(NSData *) data
{
    // This is for the UDP callback, this should not be called directly
    DeviceHeader *header = [[DeviceHeader alloc] initWithData:data];
    NSString *macAddr = [header macAddressAsString];
    if (header.deviceType != PIXELPUSHER) {
        NSLog(@"Ignoring non-PixelPusher discovery packet from %@", header);
        return;
    }
    PixelPusher *device = [[PixelPusher alloc] initWithHeader:header andRemainingData:header.packetRemainder];
    device.useAntiLog = _useAntiLog;
    
    // Set the timestamp for the last time this device checked in
    [_updateLock lock];
    [_pusherLastSeenMap setValue:[NSDate date] forKey:macAddr];
    
    PixelPusher *anExistingDevice = [_pusherMap valueForKey:macAddr];
    [_updateLock unlock];
    if (!anExistingDevice) {
        // We haven't seen this device before
        [self addNewPusherWithMacAddr:macAddr andDevice:device];
    } else {
        if (![anExistingDevice equals:device]) { // we already saw it but it's changed.
            while ([anExistingDevice isBusy]) {
                [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.5]];
            }
            [self updatePusherWithMacAddr:macAddr andDevice:device];
        } else {
            // The device is identical, nothing important has changed
            if (_logEnabled) {
                NSLog(@"Updating pusher from bcast.");
            }
            [anExistingDevice updateVariablesWithDevice:device];
            // if we dropped more than occasional packets, slow down a little
            if (device.deltaSequence > 3) {
                [anExistingDevice increaseExtraDelay:5];
            }
            if (device.deltaSequence < 1) {
                [anExistingDevice decreaseExtraDelay:1];
            }
            if (_logEnabled) {
                NSLog(@"%@", device);
            }
        }
    }
    
    // update the power limit variables
    if (self.totalPowerLimit > 0) {
        self.totalPower = 0;
        for (PixelPusher *pusher in self.sortedPushers) {
            self.totalPower += pusher.powerTotal;
        }
        if (self.totalPower > self.totalPowerLimit) {
            self.powerScale = self.totalPowerLimit / self.totalPower;
        } else {
            self.powerScale = 1.0;
        }
    }
}

- (void) updatePusherWithMacAddr:(NSString *) macAddr andDevice:(PixelPusher*) device
{
    if (_logEnabled) {
        NSLog(@"Device changed: %@", macAddr);
    }
    [_updateLock lock];
    [[_pusherMap valueForKey:macAddr] copyHeader:device];
    [_updateLock unlock];

    // We already knew about this device at the given MAC, but its details have changed
    [[NSNotificationCenter defaultCenter] postNotificationName:REGISTRY_PUSHERS_CHANGED object:self];
}

- (void) setStripValuesWithMacAddr:(NSString *) macAddress stripNumber:(NSInteger) stripNumber pixels:(Pixel*) pixels
{
    
}

- (void) startPushing
{
    if (![_sceneThread isExecuting]) {
        [_sceneThread start];
    }
}

- (void) stopPushing
{
    if ([_sceneThread isExecuting]) {
        [_sceneThread cancel];
    }
}

- (void) addNewPusherWithMacAddr:(NSString *)macAddr andDevice:(PixelPusher*)pusher
{
    if (_logEnabled) {
        NSLog(@"New device: %@ has group ordinal %d", macAddr, pusher.groupOrdinal);
    }
    [_updateLock lock];
    [_pusherMap setValue:pusher forKey:macAddr];
    if (_logEnabled) {
        NSLog(@"Adding to sorted list");
    }
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
    [_updateLock unlock];

    [[NSNotificationCenter defaultCenter] postNotificationName:REGISTRY_PUSHERS_ADDED object:self];
}

- (void) setAutoThrottle:(BOOL)autoThrottle
{
    _autoThrottle = autoThrottle;
    [_sceneThread setAutoThrottle:autoThrottle];
}

- (void) setExtraDelay:(NSInteger)extraDelay
{
    [_sceneThread setExtraDelay:extraDelay];
}

- (void) deviceExpiry:(NSTimer*) aTimer
{
    if (self->_logEnabled) {
        NSLog(@"Expiry and preening task running");
    }
    
    // A little sleight of hand here.  We can't call registry.expireDevice()
    // directly from inside the loop, for the loop is an implicit iterator and
    // registry.expireDevice modifies the pusherMap.
    // Instead we create a list of the MAC addresses to kill, then loop over
    // them outside the iterator.  - jls
    [_updateLock lock];
    NSMutableArray *toKill = [[NSMutableArray alloc]initWithCapacity:[_pusherMap count]];
    for (NSString *deviceMac in [_pusherMap allKeys]) {
        NSTimeInterval lastSeenSeconds = [[NSDate date] timeIntervalSinceDate:[_pusherLastSeenMap objectForKey:deviceMac]];
        if (lastSeenSeconds > MAX_DISCONNECT_SECONDS) {
            [toKill addObject:deviceMac];
        }
    }
    [_updateLock unlock];
    for (NSString *doomedIndividual in toKill) {
        [self expireDevice:doomedIndividual];
    }
}

- (void) expireDevice:(NSString*) macAddr {
    if (_logEnabled) {
        NSLog(@"Device gone: %@", macAddr);
    }
    [_updateLock lock];
    PixelPusher *pusher = [_pusherMap objectForKey:macAddr];
    [_pusherMap removeObjectForKey:macAddr];
    [_pusherLastSeenMap removeObjectForKey:macAddr];

    NSString *groupOrdinalKey = [[NSNumber numberWithInt:pusher.groupOrdinal] stringValue];
    [[_groupMap objectForKey:groupOrdinalKey] removePusher:pusher];
    [_updateLock unlock];

    if ([_sceneThread isExecuting]) {
        [_sceneThread removePusherThread:pusher];
    }
    [[NSNotificationCenter defaultCenter] postNotificationName:REGISTRY_PUSHERS_REMOVED object:self];
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
        [NSTimer scheduledTimerWithTimeInterval:1.0 target:_deviceRegistry selector:@selector(deviceExpiry:) userInfo:nil repeats:YES];
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