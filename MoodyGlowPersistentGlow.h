// Moody Glow - Persistent Glow Engine Header
// Developer: Moody
// Purpose: A glow that stays on screen as long as notifications exist

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface MoodyGlowPersistentGlow : NSObject

+ (instancetype)sharedInstance;

// Show or update the persistent glow.
// Style: 0=Contrary, 1=LightBar, 2=Outline, 3=Particles,
//        4=Pendulum, 5=Pulse, 6=Symmetric
- (void)showWithColor:(UIColor *)color
                style:(NSInteger)style
             animated:(BOOL)animated;

// Stop and hide the glow.
- (void)stopAnimated:(BOOL)animated;

// Update speed (0.5x = slow, 2.0x = fast).
- (void)setBreathingSpeed:(CGFloat)speed;

// YES if the glow is currently visible.
- (BOOL)isActive;

@end
