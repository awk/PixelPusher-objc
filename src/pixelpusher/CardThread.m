//
//  CardThread.m
//  pixelpusher
//
//  Created by Andrew Kimpton on 9/14/13.
//  Copyright (c) 2013 Andrew Kimpton. All rights reserved.
//

#import "CardThread.h"
#import "PixelPusher.h"
#import "DeviceRegistry.h"
#import "AsyncUdpSocket.h"
#import "Strip.h"

const NSInteger maxPacketSize = 1460;

@interface CardThread() {
    PixelPusher *_pusher;
    NSInteger _pusherPort;
    NSTimeInterval _lastSendTime;
    DeviceRegistry *_registry;
    uint8_t *_packet;
    NSString *_cardAddress;
    uint32_t _packetNumber;
    BOOL _cancel;
    BOOL _fileIsOpen;
    NSInteger _threadSleepMsec;
    AsyncUdpSocket *_udpSocket;
    NSTimer *_stripCheckTimer;
}

@end

@implementation CardThread

- (id)initWithPusher:(PixelPusher *)thePusher andDeviceRegistry:(DeviceRegistry *)aDeviceRegistry
{
    self = [super init];
    if (self) {
        _pusher = thePusher;
        _pusherPort = thePusher.port;
        _lastSendTime = 0;
        
        _registry = aDeviceRegistry;
        _packet = malloc(maxPacketSize);
        _cardAddress = [thePusher getIp];
        _packetNumber = 0;
        _cancel = NO;
        _fileIsOpen = NO;
        if (thePusher.updatePeriod > 100 && thePusher.updatePeriod < 1000000)
            _threadSleepMsec = (thePusher.updatePeriod / 1000) + 1;
    }
    return self;
}

- (BOOL) controls:(PixelPusher *)pusher
{
    return [_pusher equals:pusher];
}

- (void) shutdown
{
//    if (fileIsOpen) {
//        try {
//            pusher.setAmRecording(false);
//            fileIsOpen = false;
//            recordFile.close();
//        } catch (IOException e) {
//            // TODO Auto-generated catch block
//            e.printStackTrace();
//        }
//    }
}

- (BOOL) hasTouchedStrips
{
    NSArray *allStrips = _pusher.strips;
    for (Strip *strip in allStrips) {
        if (strip.touched) {
            return true;
        }
    }
    return false;
}

- (void) setUseAntiLog:(BOOL) antiLog
{
    _useAntiLog = antiLog;
    for (Strip *strip in _pusher.strips) {
        strip.useAntiLog = antiLog;
    }
}

- (void) main
{
    _udpSocket = [[AsyncUdpSocket alloc] initWithDelegate:self];
    NSRunLoop *theRL = [NSRunLoop currentRunLoop];

    _stripCheckTimer = [NSTimer scheduledTimerWithTimeInterval:(1.0 / self->_registry.frameLimit)
                                                        target:self
                                                      selector:@selector(checkStrips:)
                                                      userInfo:nil
                                                       repeats:NO];
    
    while (!self.isCancelled) {
        
        // check to see if we're supposed to be recording.
        if (_pusher.amRecording) {
            if (!_fileIsOpen) {
//                try {
//                    recordFile = new FileOutputStream(new File(pusher.getFilename()));
//                    fileIsOpen = true;
//                } catch (Exception e) {
//                    System.err.println("Failed to open recording file "+pusher.getFilename());
//                    pusher.setAmRecording(false);
//                }
            }
        }

        BOOL rlStatus = [theRL runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:1.0]];
        if (!rlStatus) {
            NSLog(@"Runloop returned NO!");
        }
    }
}

- (void) checkStrips:(NSTimer *)aTimer {
    NSInteger bytesSent;
    NSTimeInterval startTime = [NSDate timeIntervalSinceReferenceDate];
    NSTimeInterval nextInterval = (1.0 / self->_registry.frameLimit);
    
    if (_pusher.touchedStrips) {
        bytesSent = [self sendPacketToPusher:_pusher];
    }

    NSTimeInterval endTime = [NSDate timeIntervalSinceReferenceDate];
    NSTimeInterval duration = (endTime - startTime);
    if (duration > 0) {
        _bandwidthEstimate = bytesSent / duration;
    }

    if (duration > nextInterval) {
        nextInterval = 0;
    }
    if (!self.isCancelled) {
        _stripCheckTimer = [NSTimer scheduledTimerWithTimeInterval:nextInterval
                                                            target:self
                                                          selector:@selector(checkStrips:)
                                                          userInfo:nil
                                                           repeats:NO];
    }
}

- (NSInteger) sendPacketToPusher:(PixelPusher*)aPusher
{
    NSInteger packetLength;
    NSInteger totalLength = 0;
    NSInteger totalDelay;
    BOOL payload;
    double powerScale;
    NSMutableData *packetData;
    
    if (!_pusher.touchedStrips) {
        return 0;
    }
    
    powerScale = _registry.powerScale;
    
    [aPusher makeBusy];
    NSMutableArray *remainingStrips;
    
    remainingStrips = [aPusher.strips mutableCopy];
    
    int requestedStripsPerPacket = aPusher.maxStripsPerPacket;
    int supportedStripsPerPacket = (maxPacketSize - 4) / (1 + 3 * aPusher.pixelsPerStrip);
    int stripPerPacket = MIN(MIN(requestedStripsPerPacket, supportedStripsPerPacket), aPusher.stripsAttached);
    //if (supportedStripsPerPacket > 2)
    //  stripPerPacket = 7;
    
    while ([remainingStrips count] > 0) {
        packetLength = 0;
        payload = false;
        if (aPusher.updatePeriod > 1000) {
            _threadSleepMsec = (aPusher.updatePeriod / 1000) + 1;
        } else {
            // Shoot for 60 Hz.
            _threadSleepMsec = (16 / (aPusher.stripsAttached / stripPerPacket));
        }
        totalDelay = _threadSleepMsec + _extraDelay + aPusher.extraDelayMsec;
        
        memcpy(_packet + packetLength, &_packetNumber, sizeof _packetNumber);
        packetLength += sizeof _packetNumber;
        
        int i;
        // Now loop over remaining strips.
        for (i = 0; i < stripPerPacket; i++) {
            if (remainingStrips.count == 0) {
                break;
            }
            Strip *strip = [remainingStrips objectAtIndex:0];
            [remainingStrips removeObjectAtIndex:0];
            if (!strip.touched) {
                continue;
            }
            
            strip.powerScale = powerScale;
            NSData *stripPacket = [strip serialize];
            [strip markClean];
            _packet[packetLength++] = (uint8_t) strip.stripNumber;
            if (_fileIsOpen) {
//                try {
//                    // we need to make the pusher wait on playback the same length of time between strips as we wait between packets
//                    // this number is in microseconds.
//                    if (i > 0 || lastSendTime == 0 )  // only write the delay in the first strip in a datagram.
//                        recordFile.write(ByteUtils.unsignedIntToByteArray((int)0, true));
//                    else
//                        recordFile.write(ByteUtils.unsignedIntToByteArray((int)((System.nanoTime() - lastSendTime) / 1000), true));
//                    
//                    recordFile.write(this.packet, packetLength-1, 1);
//                    recordFile.write(stripPacket);
//                } catch (IOException e) {
//                    // TODO Auto-generated catch block
//                    e.printStackTrace();
//                }
            }
            packetData = [[NSMutableData alloc] initWithBytes:_packet length:packetLength];
            [packetData appendData:stripPacket];

            packetLength += stripPacket.length;
            payload = YES;
        }
        if (payload) {
            /* System.err.println(" Packet number array = length "+ packetLength +
             *      " seq "+ packetNumber +" data " + String.format("%02x, %02x, %02x, %02x",
             *          packetNumberArray[0], packetNumberArray[1], packetNumberArray[2], packetNumberArray[3]));
             */
            BOOL success = [_udpSocket sendData:packetData toHost:_cardAddress port:_pusherPort withTimeout:5 tag:_packetNumber];
            if (!success) {
                NSLog(@"Failed to send data!");
            }
            _packetNumber++;
            _lastSendTime = [NSDate timeIntervalSinceReferenceDate];

            totalLength += packetLength;
        }
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:((NSTimeInterval)totalDelay/1000)]];
        packetLength = 0;
    }
    [_pusher clearBusy];
    return totalLength;
}

- (void)onUdpSocket:(AsyncUdpSocket *)sock didSendDataWithTag:(long)tag
{
//    NSLog(@"Send Completed - tag = %ld", tag);
}

/**
 * Called if an error occurs while trying to send a datagram.
 * This could be due to a timeout, or something more serious such as the data being too large to fit in a sigle packet.
 **/
- (void)onUdpSocket:(AsyncUdpSocket *)sock didNotSendDataWithTag:(long)tag dueToError:(NSError *)error
{
    NSLog(@"Failed to send - tag = %ld error = %@", tag, error);
}
@end
