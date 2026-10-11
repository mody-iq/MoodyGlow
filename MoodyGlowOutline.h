// Moody Glow - Outline Animation Header
// Developer: Moody
// Purpose: Draw and animate a glowing outline around the screen edges

#import <UIKit/UIKit.h>

@interface MoodyGlowOutline : NSObject

// Main method to show the outline animation
+ (void)showOutlineWithColor:(UIColor *)color
                       inView:(UIView *)view
                  repeatCount:(NSInteger)repeatCount
                        speed:(CGFloat)speed;

// Finds the best window to attach the outline layer to (lock screen priority)
+ (UIWindow *)findBestWindow;

@end
