//
//  MuteListener.h
//  MuteListener
//
//  Created by Glenn Nagel on 4/27/14.
//  Copyright (c) 2014 gnagel. All rights reserved.
//

#import <Foundation/Foundation.h>

// Closure we will call when muted state is updated:
typedef void(^MuteListenerBlock)(BOOL isSilent);

// ===== ===== ===== ===== =====
// Mute Listener
// - Fires a "slient" sound in the background to detect the device's mute state
// ===== ===== ===== ===== =====
@interface MuteListener : NSObject

// Static instance
+(MuteListenerBlock*)singleton;

// Are we currently muted?
@property (nonatomic,readonly) BOOL isMuted;

// Should we schedule mute listeners in the background?
@property (nonatomic,readonly) BOOL isPollingEnabled;

// Enable/Disable background pooling for the mute switch
-(void)enablePolling;
-(void)disablePolling;

// Callback we will fire
@property (nonatomic,copy) MuteListenerBlock blockCallback;

@end



