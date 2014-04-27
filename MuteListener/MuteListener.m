//
//  MuteListener.m
//  MuteListener
//
//  Created by Glenn Nagel on 4/27/14.
//  Copyright (c) 2014 gnagel. All rights reserved.
//

#import "MuteListener.h"
#import <AudioToolbox/AudioToolbox.h>



/**
 Sound completion proc - this is the real magic, we simply calculate how long it took for the sound to finish playing
 In silent mode, playback will end very fast (but not in zero time)
 */
void MuteListenerBlockProc(SystemSoundID  ssID,void* clientData);

@interface MuteListener()

// Find out how fast the completion call is called
@property (nonatomic,assign) NSTimeInterval startedPlayingSilentSound;

// Our silent sound (0.5 sec)
@property (nonatomic,assign) SystemSoundID soundId;

// Have we completed the first "slient" test yet?
@property (nonatomic,assign) BOOL firstRun;


// ===== ===== ===== ===== =====
// Mute switch helpers:
// ===== ===== ===== ===== =====


// Ping the mute switch to see if it is disabled
-(void)pingMuteSwitch;

// How long did we play the silent sound for?
-(NSTimeInterval)silentSoundDuration;

// Callback after we play the silent sound
-(void)silentSoundFinished;

// Enqueue a listener to ping the mute switch
-(void)enqueuePingMuteSwitch;

// Are we currently playing a sound?
@property (nonatomic,assign) BOOL isPlayingSilentSound;

@end



void MuteListenerBlockProc(SystemSoundID  ssID,void* clientData){
    MuteListener* m = (__bridge MuteListener*)clientData;
    [m silentSoundFinished];
}


@implementation MuteListener


// ===== ===== ===== ===== =====
// Singleton instance of MuteListener
// ===== ===== ===== ===== =====
+(MuteListener*)singleton{
    static MuteListener* globalMuteListener = nil;
    if (globalMuteListener) {
        return globalMuteListener;
    }
    
    globalMuteListener = [MuteListener new];
    return globalMuteListener;
}


-(id)init{
    self = [super init];
    if (!self) {
        return self;
    }

    self.soundId = -1;
    self.firstRun = NO;
    self.isPlayingSilentSound = NO;
    
    // URL for our silent_killer file
    NSURL* url = [[NSBundle mainBundle] URLForResource:@"silent_killer" withExtension:@"caf"];
    
    if (AudioServicesCreateSystemSoundID((__bridge CFURLRef)url, &_soundId) == kAudioServicesNoError){
        // Vodo setting up audio services:
        AudioServicesAddSystemSoundCompletion(self.soundId, CFRunLoopGetMain(), kCFRunLoopDefaultMode, MuteListenerBlockProc,(__bridge void *)(self));
        UInt32 yes = 1;
        AudioServicesSetProperty(kAudioServicesPropertyIsUISound, sizeof(_soundId), &_soundId, sizeof(yes), &yes);

        // Enqueue first run!
        self.firstRun = YES;
        [self performSelector:@selector(pingMuteSwitch) withObject:nil afterDelay:1];
    }

    return self;
}

// ===== ===== ===== ===== =====
// Release the notification listener and cleanup the completion callbacks
// ===== ===== ===== ===== =====
-(void)dealloc{
    // Detach the backtround notifications, sound notifications, etc
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
    // Detach the audio services sound
    if (self.soundId != -1) {
        AudioServicesRemoveSystemSoundCompletion(self.soundId);
        AudioServicesDisposeSystemSoundID(self.soundId);
    }
}


// ===== ===== ===== ===== ===== ===== ===== ===== ===== =====
// ===== ===== ===== ===== ===== ===== ===== ===== ===== =====
// ===== ===== ===== ===== ===== ===== ===== ===== ===== =====


// ===== ===== ===== ===== =====
// Set the callback and reset the firstRun flag
// ===== ===== ===== ===== =====
-(void)setMuteListenerBlock:(MuteListenerBlock)blockCallback{
    _blockCallback = [blockCallback copy];
    self.firstRun = YES;
}


// ===== ===== ===== ===== =====
// Enable background pooling for the mute switch
// ===== ===== ===== ===== =====
-(void)enablePolling{
    _isPollingEnabled = YES;
    [self enqueuePingMuteSwitch];
}


// ===== ===== ===== ===== =====
// Disable background pooling for the mute switch
// ===== ===== ===== ===== =====
-(void)disablePolling{
    _isPollingEnabled = NO;
    [self enqueuePingMuteSwitch];
}


// ===== ===== ===== ===== =====
// How long did we play the silent sound for?
// ===== ===== ===== ===== =====
-(NSTimeInterval)silentSoundDuration {
    return ([NSDate timeIntervalSinceReferenceDate] - self.startedPlayingSilentSound);
}


// ===== ===== ===== ===== ===== ===== ===== ===== ===== =====
// ===== ===== ===== ===== ===== ===== ===== ===== ===== =====
// ===== ===== ===== ===== ===== ===== ===== ===== ===== =====


// ===== ===== ===== ===== =====
// Enqueue a listener to ping the mute switch
// ===== ===== ===== ===== =====
-(void)enqueuePingMuteSwitch {
    // Cancel the previous callback
    [[self class] cancelPreviousPerformRequestsWithTarget:self selector:@selector(pingMuteSwitch) object:nil];
    
    // Schedule a new callback
    if (self.isPollingEnabled && !self.isPlayingSilentSound){
        [self performSelector:@selector(pingMuteSwitch) withObject:nil afterDelay:1];
    }
}


// ===== ===== ===== ===== =====
// Ping the mute switch to see if it is disabled
// ===== ===== ===== ===== =====
-(void)pingMuteSwitch{
    if (!self.isPollingEnabled){
        return;
    }

    self.isPlayingSilentSound = YES;
    self.startedPlayingSilentSound = [NSDate timeIntervalSinceReferenceDate];
    AudioServicesPlaySystemSound(self.soundId);
}


// ===== ===== ===== ===== =====
// Callback after we play the silent sound
// ===== ===== ===== ===== =====
-(void)silentSoundFinished{
    self.isPlayingSilentSound = NO;
    
    // How long did it take to play the "silent" sound?
    BOOL isVeryShort = [self silentSoundDuration] < 0.1;
    
    // If the mute state has changed or this was the first run, then call the callback
    if (self.firstRun || self.isMuted != isVeryShort) {
        // Save the muted state
        _isMuted = isVeryShort;
        
        // Fire the callback if we have one
        if (self.blockCallback) {
            self.blockCallback(_isMuted);
        }
    }
    
    // Clear the first run flag
    self.firstRun = NO;
    
    // Poll the mute switch!
    [self enqueuePingMuteSwitch];
}


@end
