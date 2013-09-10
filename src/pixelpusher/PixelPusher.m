//
//  PixelPusher.m
//  PixelPusher
//
//  Created by Andrew Kimpton on 9/6/13.
//  Copyright (c) 2013 Andrew Kimpton. All rights reserved.
//

#import "PixelPusher.h"
#import "Strip.h"

@interface PixelPusher () {
//    BOOL mStripsCreated;
//    int mMaxStripsPerPacket;
//    long mUpdatePeriod;
//    long mPowerTotal;
//    long mDeltaSequence;
//    int mControllerOrdinal;
//    int mGroupOrdinal;
//    NSString *mFilename;
//    BOOL mAmRecording;
//    BOOL mIsBusy;
//    int mArtnet_universe;
//    int mArtnet_channel;
//    int mMyPort;
//    int mStripsAttached;
//    int mPixelsPerStrip;
    long _extraDelayMsec;
    BOOL _autothrottle;
    NSArray *_strips;
    NSLock *_stripLock;
    BOOL _touchedStrips;
    unsigned char _stripFlags[8];
    BOOL _useAntiLog;
}

- /*synchronized*/ (void) doDeferredStripCreation;
@end

const int SFLAG_RGBOW = 1;

@implementation PixelPusher

- (id) initWithHeader:(DeviceHeader *)aHeader andRemainingData:(NSData *)remainingData
{
    /**
     * uint8_t strips_attached;
     * uint8_t max_strips_per_packet;
     * uint16_t pixels_per_strip; // uint16_t used to make alignment work
     * uint32_t update_period; // in microseconds
     * uint32_t power_total; // in PWM units
     * uint32_t delta_sequence; // difference between received and expected
     * sequence numbers
     * int32_t controller_ordinal;  // configured order number for controller
     * int32_t group_ordinal;  // configured group number for this controller
     * int16_t artnet_universe;
     * int16_t artnet_channel;
     * int16_t my_port;
     */
    
    self = [super initWithHeader:aHeader];
    if (self) {
        if (remainingData.length < 28) {
            NSLog(@"Short remaining data!");
            return nil;
        }
        const unsigned char *packet = [remainingData bytes];
        _stripLock = [[NSLock alloc] init];
        
        _stripsAttached = packet[0];
        _pixelsPerStrip = *((uint16_t *) &packet[2]);
        _maxStripsPerPacket = packet[1];
        
        _updatePeriod = *((uint32_t *) &packet[4]);
        _powerTotal = *((uint32_t *) &packet[8]);
        _deltaSequence = *((uint32_t *) &packet[12]);
        _controllerOrdinal = *((int32_t *) &packet[16]);
        _groupOrdinal = *((int32_t *) &packet[20]);
        
        _artnet_universe = *((int16_t *) &packet[24]);
        _artnet_channel = *((int16_t *) &packet[26]);
        _amRecording = false;
        
        if (remainingData.length > 28) {
            _my_port = *((int16_t *) &packet[28]);
        } else {
            _my_port = 9798;
        }
        if (remainingData.length > 30) {
            memcpy(_stripFlags, &packet[30], 8);
        } else {
            memset(_stripFlags, 0, 8);
        }
        self.stripsCreated = false;
    }
    return self;
}

- (void) updateVariablesWithDevice:(PixelPusher *)device
{
    self.deltaSequence = device.deltaSequence;
    self.maxStripsPerPacket = device.maxStripsPerPacket;
    self.powerTotal = device.powerTotal;
    self.updatePeriod = device.updatePeriod;
}

- (void) copyHeader:(PixelPusher *) device
{
    self->_controllerOrdinal = device.controllerOrdinal;
    self.deltaSequence = device.deltaSequence;
    self->_groupOrdinal = device.groupOrdinal;
    self.maxStripsPerPacket = device.maxStripsPerPacket;
    
    // if the number of strips we have doesn't match,
    // we'll need to make a fresh set.
    if (self.stripsAttached != device.stripsAttached) {
        self.stripsCreated = false;
        self->_stripsAttached = device.stripsAttached;
    }
    // likewise, if the length of each strip differs,
    // we will need to make a new set.
    if (self.pixelsPerStrip != device.pixelsPerStrip) {
        self->_pixelsPerStrip = device.pixelsPerStrip;
        self.stripsCreated = false;
    }
    
    self.powerTotal = device.powerTotal;
    self.updatePeriod = device.updatePeriod;
    self.artnet_channel = device.artnet_channel;
    self.artnet_universe = device.artnet_universe;
    self->_my_port = device.my_port;
    self.filename = device.filename;
    self.amRecording = device.amRecording;
    
    // if it already has strips, just use those
    if (device.stripsCreated) {
        self.isBusy = YES;
        self->_strips = device->_strips;
        self.stripsCreated = device.stripsCreated;
        self.isBusy = NO;
    }
}

- (BOOL) useAntiLog
{
    return _useAntiLog;
}

- (void) setUseAntiLog:(BOOL) antiLog
{
    _useAntiLog = antiLog;
    if (_stripsCreated) {
        for (Strip *strip in _strips) {
            strip.useAntiLog = _useAntiLog;
        }
    }
}

- (void) increaseExtraDelay:(long) i
{
    if (_autothrottle) {
        _extraDelayMsec += i;
        NSLog(@"Group %d card %d extra delay now %ld", self.groupOrdinal, self.controllerOrdinal, _extraDelayMsec);
    } else {
        NSLog(@"Group %d card %d would increase delay, but autothrottle is disabled", self.groupOrdinal, self.controllerOrdinal);
    }
}

- (void) decreaseExtraDelay:(long) i {
    _extraDelayMsec -= i;
    if (_extraDelayMsec < 0) {
        _extraDelayMsec = 0;
    }
}

- (BOOL) equals:(PixelPusher *)obj
{
    
    // quick checks first.
    
    // object handle identity
    if (self == obj) {
        return true;
    }
    
    // if it's null, it's not the same as anything
    // (and we can't compare its fields without a null pointer exception)
    if (obj == nil) {
        return false;
    }
    
    // if it's some different class, well then something is bad.
    if ([self class] != [obj class]) {
        return false;
    }
    
    // if it differs by less than half a msec, it has no effect on our timing
    if (labs(self.updatePeriod - obj.updatePeriod) > 500) {
        return false;
    }
    
    // some fudging to cope with the fact that pushers don't know they have RGBOW
    if (self.hasRGBOW & !obj.hasRGBOW) {
        if (self.pixelsPerStrip != obj.pixelsPerStrip / 3) {
            return false;
        }
    }
    if (!self.hasRGBOW & obj.hasRGBOW) {
        if (self.pixelsPerStrip / 3 != obj.pixelsPerStrip) {
            return false;
        }
    }
    if (! (self.hasRGBOW || obj.hasRGBOW)) {
        if (self.pixelsPerStrip != obj.pixelsPerStrip) {
            return false;
        }
    }
    if (self.numberOfStrips != obj.numberOfStrips) {
        return false;
    }
    
    // handle the case where someone changed the config during library runtime
    if (self.artnet_channel != self.artnet_channel ||
        self.artnet_universe != obj.artnet_universe) {
        return false;
    }
    
    // if the port's been changed, we need to update
    if (self.my_port != obj.my_port) {
        return false;
    }
    
    // we should update every time the power total changes
    //if (this.powerTotal != obj.powerTotal)
    //  return false;
    
    // if all those other things are the same, then we call it good.
    return true;
}

- (void) doDeferredStripCreation
{
    [_stripLock lock];
    NSMutableArray *mutableStrips = [[NSMutableArray alloc] initWithCapacity:self.stripsAttached];
    for (int stripNo = 0; stripNo < self.stripsAttached; stripNo++) {
        [mutableStrips addObject:[[Strip alloc] initWithPusher:self stripNumber:stripNo length:_pixelsPerStrip]];
    }
    _strips = mutableStrips;
    for (Strip *strip in _strips) {
        strip.useAntiLog = _useAntiLog;
        strip.RGBOW = ((_stripFlags[strip.stripNumber] & SFLAG_RGBOW) == 1);
    }
    [_stripLock unlock];
    _stripsCreated = true;
    _touchedStrips = false;
}


- (NSUInteger) numberOfStrips
{
    if (_stripsCreated)
        return [_strips count];
    else {
        [self doDeferredStripCreation];
        return [_strips count];
    }
}

- (NSArray *) strips
{
    if (_stripsCreated)
        return _strips;
    else {
        [self doDeferredStripCreation];
        return _strips;
    }
}

- (void) markTouched
{
    _touchedStrips = YES;
}

- (void) markUntouched
{
    _touchedStrips = NO;
}

- (NSString *) formattedStripFlags
{
return [NSString stringWithFormat:@"[%d][%d][%d][%d][%d][%d][%d][%d]", _stripFlags[0], _stripFlags[1], _stripFlags[2], _stripFlags[3], _stripFlags[4], _stripFlags[5], _stripFlags[6], _stripFlags[7]];
}

- (NSString *) description
{
    return [NSString stringWithFormat:@"%@ # Strips(%ld) Max Strips Per Packet(%d) PixelsPerStrip (%d) Update Period (%ld) Power Total (%ld) Delta Sequence (%ld) Group (%d) Controller (%d) Port (%d) Art-Net Universe (%d) Art-Net Channel (%d) Strip flags %@", [super description], (unsigned long) self.numberOfStrips, self.maxStripsPerPacket, self.pixelsPerStrip, self.updatePeriod, self.powerTotal, self.deltaSequence, self.groupOrdinal, self.controllerOrdinal, self.my_port, self.artnet_universe, self.artnet_channel, [self formattedStripFlags]];
}
@end
