// Moody Glow - Outline Animation Implementation
// Developer: Moody
// Purpose: Draw and animate a glowing outline around the screen edges

#import "MoodyGlowOutline.h"
#import <QuartzCore/QuartzCore.h>

@implementation MoodyGlowOutline

+ (UIWindow *)findBestWindow {
    UIApplication *app = [UIApplication sharedApplication];
    
    // Priority 1: Lock screen window (searched across all connected scenes)
    Class lockScreenWindowClass = NSClassFromString(@"SBLockScreenWindow");
    if (lockScreenWindowClass) {
        for (UIScene *scene in app.connectedScenes) {
            if ([scene isKindOfClass:[UIWindowScene class]]) {
                UIWindowScene *windowScene = (UIWindowScene *)scene;
                for (UIWindow *window in windowScene.windows) {
                    if ([window isKindOfClass:lockScreenWindowClass]) {
                        return window;
                    }
                }
            }
        }
    }
    
    // Priority 2: Key window (searched across all connected scenes)
    for (UIScene *scene in app.connectedScenes) {
        if ([scene isKindOfClass:[UIWindowScene class]]) {
            UIWindowScene *windowScene = (UIWindowScene *)scene;
            for (UIWindow *window in windowScene.windows) {
                if (window.isKeyWindow) {
                    return window;
                }
            }
        }
    }
    
    // Priority 3: First available window from any scene
    for (UIScene *scene in app.connectedScenes) {
        if ([scene isKindOfClass:[UIWindowScene class]]) {
            UIWindowScene *windowScene = (UIWindowScene *)scene;
            if (windowScene.windows.count > 0) {
                return windowScene.windows.firstObject;
            }
        }
    }
    
    // Fallback: No window found
    return nil;
}

// Build the outline path for iPhone XS Max (notch device)
+ (UIBezierPath *)outlinePathForBounds:(CGRect)bounds {
    CGFloat w = bounds.size.width;
    CGFloat h = bounds.size.height;
    
    // iPhone XS Max specific values
    CGFloat cornerRadius = 39.0;
    CGFloat notchWidth = 209.0;
    CGFloat notchHeight = 30.0;
    CGFloat notchCornerRadius = 15.0;
    
    CGFloat notchLeft = (w - notchWidth) / 2.0;
    CGFloat notchRight = notchLeft + notchWidth;
    
    UIBezierPath *path = [UIBezierPath bezierPath];
    
    // Start at top edge, after top-left corner
    [path moveToPoint:CGPointMake(cornerRadius, 0)];
    
    // Top edge: left to notch
    [path addLineToPoint:CGPointMake(notchLeft - notchCornerRadius, 0)];
    
    // Curve down into notch (left side)
    [path addQuadCurveToPoint:CGPointMake(notchLeft, notchCornerRadius)
                 controlPoint:CGPointMake(notchLeft, 0)];
    
    // Down the left side of notch
    [path addLineToPoint:CGPointMake(notchLeft, notchHeight - notchCornerRadius)];
    
    // Curve across notch bottom (left)
    [path addQuadCurveToPoint:CGPointMake(notchLeft + notchCornerRadius, notchHeight)
                 controlPoint:CGPointMake(notchLeft, notchHeight)];
    
    // Across notch bottom
    [path addLineToPoint:CGPointMake(notchRight - notchCornerRadius, notchHeight)];
    
    // Curve up (right side of notch)
    [path addQuadCurveToPoint:CGPointMake(notchRight, notchHeight - notchCornerRadius)
                 controlPoint:CGPointMake(notchRight, notchHeight)];
    
    // Up the right side of notch
    [path addLineToPoint:CGPointMake(notchRight, notchCornerRadius)];
    
    // Curve out of notch
    [path addQuadCurveToPoint:CGPointMake(notchRight + notchCornerRadius, 0)
                 controlPoint:CGPointMake(notchRight, 0)];
    
    // Top edge: notch to top-right corner
    [path addLineToPoint:CGPointMake(w - cornerRadius, 0)];
    
    // Top-right corner
    [path addQuadCurveToPoint:CGPointMake(w, cornerRadius)
                 controlPoint:CGPointMake(w, 0)];
    
    // Right edge
    [path addLineToPoint:CGPointMake(w, h - cornerRadius)];
    
    // Bottom-right corner
    [path addQuadCurveToPoint:CGPointMake(w - cornerRadius, h)
                 controlPoint:CGPointMake(w, h)];
    
    // Bottom edge
    [path addLineToPoint:CGPointMake(cornerRadius, h)];
    
    // Bottom-left corner
    [path addQuadCurveToPoint:CGPointMake(0, h - cornerRadius)
                 controlPoint:CGPointMake(0, h)];
    
    // Left edge
    [path addLineToPoint:CGPointMake(0, cornerRadius)];
    
    // Top-left corner
    [path addQuadCurveToPoint:CGPointMake(cornerRadius, 0)
                 controlPoint:CGPointMake(0, 0)];
    
    [path closePath];
    
    return path;
}

+ (void)showOutlineWithColor:(UIColor *)color
                       inView:(UIView *)view
                  repeatCount:(NSInteger)repeatCount
                        speed:(CGFloat)speed {
    
    if (!view || !color) return;
    
    // Clamp values
    if (repeatCount < 1) repeatCount = 1;
    if (speed < 0.1) speed = 0.1;
    
    UIBezierPath *path = [self outlinePathForBounds:view.bounds];
    
    CAShapeLayer *layer = [CAShapeLayer layer];
    layer.path = path.CGPath;
    layer.strokeColor = color.CGColor;
    layer.fillColor = [UIColor clearColor].CGColor;
    layer.lineWidth = 4.0;
    layer.lineCap = kCALineCapRound;
    layer.lineJoin = kCALineJoinRound;
    layer.shadowColor = color.CGColor;
    layer.shadowRadius = 12.0;
    layer.shadowOpacity = 1.0;
    layer.shadowOffset = CGSizeZero;
    layer.opacity = 0.0;
    layer.zPosition = 9999;
    
    [view.layer addSublayer:layer];
    
    CGFloat inDuration = 0.4 / speed;
    CGFloat outDuration = 0.4 / speed;
    CGFloat totalDuration = inDuration + outDuration;
    
    CABasicAnimation *fadeIn = [CABasicAnimation animationWithKeyPath:@"opacity"];
    fadeIn.fromValue = @0.0;
    fadeIn.toValue = @1.0;
    fadeIn.duration = inDuration;
    fadeIn.beginTime = 0;
    fadeIn.fillMode = kCAFillModeForwards;
    
    CABasicAnimation *fadeOut = [CABasicAnimation animationWithKeyPath:@"opacity"];
    fadeOut.fromValue = @1.0;
    fadeOut.toValue = @0.0;
    fadeOut.duration = outDuration;
    fadeOut.beginTime = inDuration;
    fadeOut.fillMode = kCAFillModeForwards;
    
    CAAnimationGroup *group = [CAAnimationGroup animation];
    group.animations = @[fadeIn, fadeOut];
    group.duration = totalDuration;
    group.repeatCount = repeatCount;
    group.removedOnCompletion = YES;
    
    [layer addAnimation:group forKey:@"moodyGlowOutline"];
    
    CGFloat removalDelay = totalDuration * repeatCount + 0.1;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(removalDelay * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [layer removeFromSuperlayer];
    });
}

@end
