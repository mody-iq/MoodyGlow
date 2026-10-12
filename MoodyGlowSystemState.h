// Moody Glow - System State Header
// Developer: Moody
// Purpose: Detect device lock state and DND status

#import <Foundation/Foundation.h>

@interface MoodyGlowSystemState : NSObject

// Returns YES if the device is currently locked
+ (BOOL)isDeviceLocked;

// Returns YES if Do Not Disturb is currently active
+ (BOOL)isDNDActive;

@end
