// Moody Glow - Persistent Glow Engine Header
// Developer: Moody

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface MoodyGlowPersistentGlow : NSObject

+ (instancetype)sharedInstance;

// Style: 0=Contrary, 1=LightBar, 2=Outline, 3=Particles,
//        4=Pendulum, 5=Pulse, 6=Symmetric
- (void)showWithColors:(NSArray<UIColor *> *)colors
                 style:(NSInteger)style
              animated:(BOOL)animated;

// Backward-compatible single-color API
- (void)showWithColor:(UIColor *)color
                style:(NSInteger)style
             animated:(BOOL)animated;

- (void)stopAnimated:(BOOL)animated;

- (void)setBreathingSpeed:(CGFloat)speed;
- (void)setDrawSpeed:(CGFloat)speed;

// NEW: glow line thickness in pixels (1.0 - 12.0, default 6.0)
- (void)setGlowThickness:(CGFloat)thickness;

- (BOOL)isActive;

@end
