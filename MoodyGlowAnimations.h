// Moody Glow - Animations Manager Header
// Developer: Moody

#import <UIKit/UIKit.h>

@interface MoodyGlowAnimations : NSObject

// Plays the animation at the given index (0-6)
// 0=Contrary, 1=Light Bar, 2=Outline, 3=Particles, 4=Pendulum, 5=Pulse, 6=Symmetric
+ (void)playAnimationWithIndex:(NSInteger)index
                         color:(UIColor *)color
                        inView:(UIView *)view
                   repeatCount:(NSInteger)repeatCount
                         speed:(CGFloat)speed;

// Finds the best window to attach animations to
+ (UIWindow *)findBestWindow;

@end
