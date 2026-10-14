// Moody Glow - System State Header
// Developer: Moody

#import <Foundation/Foundation.h>

@interface MoodyGlowSystemState : NSObject

// Returns YES if the device is currently locked
+ (BOOL)isDeviceLocked;

// Returns YES if Do Not Disturb is currently active
+ (BOOL)isDNDActive;

// Cache the lock state (called from Tweak.x hook on _setUILocked:)
+ (void)setCachedLocked:(BOOL)locked;

// Query the system for the current lock state (called once at tweak load)
+ (void)refreshFromSystem;

@end
