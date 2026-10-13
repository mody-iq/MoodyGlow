// Moody Glow - Persistent Glow Engine Header
// Developer: Moody
// Purpose: A glow that stays on screen as long as notifications exist

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface MoodyGlowPersistentGlow : NSObject

+ (instancetype)sharedInstance;

// Show or update the persistent glow.
// - If glow is inactive: creates it with the given color.
// - If glow is active: only updates the color (smooth crossfade).
- (void)showWithColor:(UIColor *)color animated:(BOOL)animated;

// Stop and hide the glow.
- (void)stopAnimated:(BOOL)animated;

// Update breathing speed (0.5x = slow, 2.0x = fast).
// If the glow is currently active, the animation restarts immediately.
- (void)setBreathingSpeed:(CGFloat)speed;

// YES if the glow is currently visible.
- (BOOL)isActive;

@end
