// Moody Glow - Blackout Manager Header
// Developer: Moody

#import <UIKit/UIKit.h>

@interface MoodyGlowBlackout : NSObject

// Shows a solid black overlay on top of the window
+ (void)showOverlayInWindow:(UIWindow *)window;

// Removes the black overlay (optionally with a fade animation)
+ (void)removeOverlayAnimated:(BOOL)animated;

// Checks if the overlay is currently active
+ (BOOL)isOverlayActive;

// Turns off the device screen (backlight off)
+ (void)turnOffScreen;

@end
