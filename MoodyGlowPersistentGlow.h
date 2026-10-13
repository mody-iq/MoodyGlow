// Moody Glow - Persistent Glow Engine Header
// Developer: Moody

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface MoodyGlowPersistentGlow : NSObject

+ (instancetype)sharedInstance;

// Style: 0=Contrary, 1=LightBar, 2=Outline, 3=Particles,
//        4=Pendulum, 5=Pulse, 6=Symmetric

// Single color (kept for backward compatibility, forwards to showWithColors)
- (void)showWithColor:(UIColor *)color
                style:(NSInteger)style
             animated:(BOOL)animated;

// Multiple colors: cycles through them every 3s with a 0.4s cross-fade.
// One color = static glow. Empty array = does nothing.
- (void)showWithColors:(NSArray<UIColor *> *)colors
                 style:(NSInteger)style
              animated:(BOOL)animated;

- (void)stopAnimated:(BOOL)animated;

- (void)setBreathingSpeed:(CGFloat)speed;
- (void)setDrawSpeed:(CGFloat)speed;

- (BOOL)isActive;

@end
