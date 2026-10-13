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

// Breathing pulse speed (used by Outline style). Default: 1.0
- (void)setBreathingSpeed:(CGFloat)speed;

// Drawing animation speed (used by Symmetric and future styles). Default: 1.0
- (void)setDrawSpeed:(CGFloat)speed;

// YES if the glow is currently visible.
- (BOOL)isActive;

@end
