// Moody Glow - Animations Manager Implementation
// Developer: Moody
// Contains all 7 animation styles

#import "MoodyGlowAnimations.h"
#import <QuartzCore/QuartzCore.h>

@implementation MoodyGlowAnimations

#pragma mark - Window Finder

+ (UIWindow *)findBestWindow {
    UIApplication *app = [UIApplication sharedApplication];
    
    Class lockScreenWindowClass = NSClassFromString(@"SBLockScreenWindow");
    if (lockScreenWindowClass) {
        for (UIScene *scene in app.connectedScenes) {
            if ([scene isKindOfClass:[UIWindowScene class]]) {
                UIWindowScene *ws = (UIWindowScene *)scene;
                for (UIWindow *w in ws.windows) {
                    if ([w isKindOfClass:lockScreenWindowClass]) return w;
                }
            }
        }
    }
    
    for (UIScene *scene in app.connectedScenes) {
        if ([scene isKindOfClass:[UIWindowScene class]]) {
            UIWindowScene *ws = (UIWindowScene *)scene;
            for (UIWindow *w in ws.windows) {
                if (w.isKeyWindow) return w;
            }
        }
    }
    
    for (UIScene *scene in app.connectedScenes) {
        if ([scene isKindOfClass:[UIWindowScene class]]) {
            UIWindowScene *ws = (UIWindowScene *)scene;
            if (ws.windows.count > 0) return ws.windows.firstObject;
        }
    }
    
    return nil;
}

#pragma mark - Dispatcher

+ (void)playAnimationWithIndex:(NSInteger)index
                         color:(UIColor *)color
                        inView:(UIView *)view
                   repeatCount:(NSInteger)repeatCount
                         speed:(CGFloat)speed {
    if (!view || !color) return;
    if (repeatCount < 1) repeatCount = 1;
    if (speed < 0.1) speed = 0.1;
    
    switch (index) {
        case 0: [self playContrary:color inView:view repeat:repeatCount speed:speed]; break;
        case 1: [self playLightBar:color inView:view repeat:repeatCount speed:speed]; break;
        case 2: [self playOutline:color inView:view repeat:repeatCount speed:speed]; break;
        case 3: [self playParticles:color inView:view repeat:repeatCount speed:speed]; break;
        case 4: [self playPendulum:color inView:view repeat:repeatCount speed:speed]; break;
        case 5: [self playPulse:color inView:view repeat:repeatCount speed:speed]; break;
        case 6: [self playSymmetric:color inView:view repeat:repeatCount speed:speed]; break;
        default: [self playOutline:color inView:view repeat:repeatCount speed:speed]; break;
    }
}

#pragma mark - Animation 0: Contrary

+ (void)playContrary:(UIColor *)color inView:(UIView *)view repeat:(NSInteger)repeat speed:(CGFloat)speed {
    CGRect bounds = view.bounds;
    CGFloat barWidth = 6.0;
    CGFloat barHeight = bounds.size.height * 0.35;
    CGFloat xOffset = 30.0;
    
    // Left bar
    CALayer *leftBar = [CALayer layer];
    leftBar.backgroundColor = color.CGColor;
    leftBar.frame = CGRectMake(xOffset, 0, barWidth, barHeight);
    leftBar.cornerRadius = barWidth / 2.0;
    leftBar.shadowColor = color.CGColor;
    leftBar.shadowRadius = 12.0;
    leftBar.shadowOpacity = 1.0;
    leftBar.shadowOffset = CGSizeZero;
    [view.layer addSublayer:leftBar];
    
    CGFloat startY = barHeight / 2.0;
    CGFloat endY = bounds.size.height - barHeight / 2.0;
    
    CABasicAnimation *leftAnim = [CABasicAnimation animationWithKeyPath:@"position.y"];
    leftAnim.fromValue = @(startY);
    leftAnim.toValue = @(endY);
    leftAnim.duration = 1.8 / speed;
    leftAnim.autoreverses = YES;
    leftAnim.repeatCount = repeat;
    leftAnim.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    [leftBar addAnimation:leftAnim forKey:@"contrary"];
    
    // Right bar (opposite direction)
    CALayer *rightBar = [CALayer layer];
    rightBar.backgroundColor = color.CGColor;
    rightBar.frame = CGRectMake(bounds.size.width - xOffset - barWidth, 0, barWidth, barHeight);
    rightBar.cornerRadius = barWidth / 2.0;
    rightBar.shadowColor = color.CGColor;
    rightBar.shadowRadius = 12.0;
    rightBar.shadowOpacity = 1.0;
    rightBar.shadowOffset = CGSizeZero;
    [view.layer addSublayer:rightBar];
    
    CABasicAnimation *rightAnim = [CABasicAnimation animationWithKeyPath:@"position.y"];
    rightAnim.fromValue = @(endY);
    rightAnim.toValue = @(startY);
    rightAnim.duration = 1.8 / speed;
    rightAnim.autoreverses = YES;
    rightAnim.repeatCount = repeat;
    rightAnim.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    [rightBar addAnimation:rightAnim forKey:@"contrary"];
    
    NSTimeInterval cleanupDelay = (3.6 * repeat) / speed + 0.5;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(cleanupDelay * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [leftBar removeFromSuperlayer];
        [rightBar removeFromSuperlayer];
    });
}

#pragma mark - Animation 1: Light Bar

+ (void)playLightBar:(UIColor *)color inView:(UIView *)view repeat:(NSInteger)repeat speed:(CGFloat)speed {
    CGRect bounds = view.bounds;
    CGFloat barHeight = 6.0;
    
    CALayer *bar = [CALayer layer];
    bar.backgroundColor = color.CGColor;
    bar.frame = CGRectMake(0, -barHeight, bounds.size.width, barHeight);
    bar.shadowColor = color.CGColor;
    bar.shadowRadius = 15.0;
    bar.shadowOpacity = 1.0;
    bar.shadowOffset = CGSizeZero;
    [view.layer addSublayer:bar];
    
    CABasicAnimation *anim = [CABasicAnimation animationWithKeyPath:@"position.y"];
    anim.fromValue = @(-barHeight / 2.0);
    anim.toValue = @(bounds.size.height + barHeight / 2.0);
    anim.duration = 1.2 / speed;
    anim.repeatCount = repeat;
    anim.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionLinear];
    [bar addAnimation:anim forKey:@"lightBar"];
    
    NSTimeInterval cleanupDelay = (1.2 * repeat) / speed + 0.5;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(cleanupDelay * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [bar removeFromSuperlayer];
    });
}

#pragma mark - Animation 2: Outline

+ (UIBezierPath *)outlinePathForBounds:(CGRect)bounds {
    CGFloat w = bounds.size.width;
    CGFloat h = bounds.size.height;
    CGFloat cornerRadius = 39.0;
    CGFloat notchWidth = 209.0;
    CGFloat notchHeight = 30.0;
    CGFloat notchCornerRadius = 15.0;
    CGFloat notchLeft = (w - notchWidth) / 2.0;
    CGFloat notchRight = notchLeft + notchWidth;
    
    UIBezierPath *path = [UIBezierPath bezierPath];
    [path moveToPoint:CGPointMake(cornerRadius, 0)];
    [path addLineToPoint:CGPointMake(notchLeft - notchCornerRadius, 0)];
    [path addQuadCurveToPoint:CGPointMake(notchLeft, notchCornerRadius) controlPoint:CGPointMake(notchLeft, 0)];
    [path addLineToPoint:CGPointMake(notchLeft, notchHeight - notchCornerRadius)];
    [path addQuadCurveToPoint:CGPointMake(notchLeft + notchCornerRadius, notchHeight) controlPoint:CGPointMake(notchLeft, notchHeight)];
    [path addLineToPoint:CGPointMake(notchRight - notchCornerRadius, notchHeight)];
    [path addQuadCurveToPoint:CGPointMake(notchRight, notchHeight - notchCornerRadius) controlPoint:CGPointMake(notchRight, notchHeight)];
    [path addLineToPoint:CGPointMake(notchRight, notchCornerRadius)];
    [path addQuadCurveToPoint:CGPointMake(notchRight + notchCornerRadius, 0) controlPoint:CGPointMake(notchRight, 0)];
    [path addLineToPoint:CGPointMake(w - cornerRadius, 0)];
    [path addQuadCurveToPoint:CGPointMake(w, cornerRadius) controlPoint:CGPointMake(w, 0)];
    [path addLineToPoint:CGPointMake(w, h - cornerRadius)];
    [path addQuadCurveToPoint:CGPointMake(w - cornerRadius, h) controlPoint:CGPointMake(w, h)];
    [path addLineToPoint:CGPointMake(cornerRadius, h)];
    [path addQuadCurveToPoint:CGPointMake(0, h - cornerRadius) controlPoint:CGPointMake(0, h)];
    [path addLineToPoint:CGPointMake(0, cornerRadius)];
    [path addQuadCurveToPoint:CGPointMake(cornerRadius, 0) controlPoint:CGPointMake(0, 0)];
    [path closePath];
    return path;
}

+ (void)playOutline:(UIColor *)color inView:(UIView *)view repeat:(NSInteger)repeat speed:(CGFloat)speed {
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
    group.repeatCount = repeat;
    group.removedOnCompletion = YES;
    [layer addAnimation:group forKey:@"outline"];
    
    NSTimeInterval cleanupDelay = totalDuration * repeat + 0.1;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(cleanupDelay * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [layer removeFromSuperlayer];
    });
}

#pragma mark - Animation 3: Particles

+ (void)playParticles:(UIColor *)color inView:(UIView *)view repeat:(NSInteger)repeat speed:(CGFloat)speed {
    CGRect bounds = view.bounds;
    NSInteger particleCount = 20;
    CGFloat baseDuration = 1.5 / speed;
    
    NSMutableArray *particles = [NSMutableArray array];
    CGPoint origin = CGPointMake(bounds.size.width / 2.0, 40.0);
    
    for (NSInteger i = 0; i < particleCount; i++) {
        CGFloat size = 4.0 + (arc4random_uniform(6));
        CALayer *p = [CALayer layer];
        p.backgroundColor = color.CGColor;
        p.cornerRadius = size / 2.0;
        p.frame = CGRectMake(origin.x - size / 2.0, origin.y - size / 2.0, size, size);
        p.shadowColor = color.CGColor;
        p.shadowRadius = 8.0;
        p.shadowOpacity = 1.0;
        p.shadowOffset = CGSizeZero;
        [view.layer addSublayer:p];
        [particles addObject:p];
        
        // Random direction
        CGFloat angle = ((CGFloat)arc4random_uniform(360)) * M_PI / 180.0;
        CGFloat distance = 80.0 + arc4random_uniform(120);
        CGFloat dx = cos(angle) * distance;
        CGFloat dy = sin(angle) * distance;
        
        CABasicAnimation *move = [CABasicAnimation animationWithKeyPath:@"position"];
        move.fromValue = [NSValue valueWithCGPoint:origin];
        move.toValue = [NSValue valueWithCGPoint:CGPointMake(origin.x + dx, origin.y + dy)];
        move.duration = baseDuration;
        move.repeatCount = repeat;
        move.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseOut];
        [p addAnimation:move forKey:@"move"];
        
        CABasicAnimation *fade = [CABasicAnimation animationWithKeyPath:@"opacity"];
        fade.fromValue = @1.0;
        fade.toValue = @0.0;
        fade.duration = baseDuration;
        fade.repeatCount = repeat;
        [p addAnimation:fade forKey:@"fade"];
    }
    
    NSTimeInterval cleanupDelay = (baseDuration * repeat) + 0.5;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(cleanupDelay * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        for (CALayer *p in particles) {
            [p removeFromSuperlayer];
        }
    });
}

#pragma mark - Animation 4: Pendulum

+ (void)playPendulum:(UIColor *)color inView:(UIView *)view repeat:(NSInteger)repeat speed:(CGFloat)speed {
    CGRect bounds = view.bounds;
    CGFloat dotSize = 20.0;
    
    CALayer *dot = [CALayer layer];
    dot.backgroundColor = color.CGColor;
    dot.cornerRadius = dotSize / 2.0;
    dot.frame = CGRectMake(0, 60, dotSize, dotSize);
    dot.shadowColor = color.CGColor;
    dot.shadowRadius = 15.0;
    dot.shadowOpacity = 1.0;
    dot.shadowOffset = CGSizeZero;
    [view.layer addSublayer:dot];
    
    CGFloat leftX = 40.0;
    CGFloat rightX = bounds.size.width - 40.0 - dotSize;
    
    CABasicAnimation *swing = [CABasicAnimation animationWithKeyPath:@"position.x"];
    swing.fromValue = @(leftX + dotSize / 2.0);
    swing.toValue = @(rightX + dotSize / 2.0);
    swing.duration = 1.0 / speed;
    swing.autoreverses = YES;
    swing.repeatCount = repeat;
    swing.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    [dot addAnimation:swing forKey:@"pendulum"];
    
    NSTimeInterval cleanupDelay = (2.0 * repeat) / speed + 0.5;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(cleanupDelay * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [dot removeFromSuperlayer];
    });
}

#pragma mark - Animation 5: Pulse

+ (void)playPulse:(UIColor *)color inView:(UIView *)view repeat:(NSInteger)repeat speed:(CGFloat)speed {
    CGPoint center = CGPointMake(view.bounds.size.width / 2.0, view.bounds.size.height / 2.0);
    CGFloat maxRadius = view.bounds.size.width * 0.8;
    
    CAShapeLayer *ring = [CAShapeLayer layer];
    UIBezierPath *path = [UIBezierPath bezierPathWithArcCenter:CGPointZero radius:1 startAngle:0 endAngle:2 * M_PI clockwise:YES];
    ring.path = path.CGPath;
    ring.position = center;
    ring.strokeColor = color.CGColor;
    ring.fillColor = [UIColor clearColor].CGColor;
    ring.lineWidth = 4.0;
    ring.shadowColor = color.CGColor;
    ring.shadowRadius = 15.0;
    ring.shadowOpacity = 1.0;
    ring.shadowOffset = CGSizeZero;
    [view.layer addSublayer:ring];
    
    // Animate path (scaling)
    CAKeyframeAnimation *scale = [CAKeyframeAnimation animationWithKeyPath:@"transform.scale"];
    scale.values = @[@0.01, @1.0];
    scale.duration = 1.5 / speed;
    scale.repeatCount = repeat;
    scale.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseOut];
    
    // We need to scale the path itself. Use transform.scale
    CABasicAnimation *pathAnim = [CABasicAnimation animationWithKeyPath:@"transform.scale"];
    pathAnim.fromValue = @0.01;
    pathAnim.toValue = @(maxRadius);
    pathAnim.duration = 1.5 / speed;
    pathAnim.repeatCount = repeat;
    pathAnim.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseOut];
    [ring addAnimation:pathAnim forKey:@"pulse"];
    
    CABasicAnimation *fade = [CABasicAnimation animationWithKeyPath:@"opacity"];
    fade.fromValue = @1.0;
    fade.toValue = @0.0;
    fade.duration = 1.5 / speed;
    fade.repeatCount = repeat;
    [ring addAnimation:fade forKey:@"fade"];
    
    NSTimeInterval cleanupDelay = (1.5 * repeat) / speed + 0.5;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(cleanupDelay * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [ring removeFromSuperlayer];
    });
}

#pragma mark - Animation 6: Symmetric

+ (void)playSymmetric:(UIColor *)color inView:(UIView *)view repeat:(NSInteger)repeat speed:(CGFloat)speed {
    CGRect bounds = view.bounds;
    CGFloat barHeight = 6.0;
    CGFloat barLength = bounds.size.width * 0.35;
    CGFloat yCenter = bounds.size.height / 2.0;
    
    // Left bar
    CALayer *leftBar = [CALayer layer];
    leftBar.backgroundColor = color.CGColor;
    leftBar.frame = CGRectMake(-barLength, yCenter - barHeight / 2.0, barLength, barHeight);
    leftBar.cornerRadius = barHeight / 2.0;
    leftBar.shadowColor = color.CGColor;
    leftBar.shadowRadius = 12.0;
    leftBar.shadowOpacity = 1.0;
    leftBar.shadowOffset = CGSizeZero;
    [view.layer addSublayer:leftBar];
    
    CABasicAnimation *leftMove = [CABasicAnimation animationWithKeyPath:@"position.x"];
    leftMove.fromValue = @(-barLength / 2.0);
    leftMove.toValue = @(bounds.size.width / 2.0 - barLength / 2.0);
    leftMove.duration = 1.0 / speed;
    leftMove.autoreverses = YES;
    leftMove.repeatCount = repeat;
    leftMove.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    [leftBar addAnimation:leftMove forKey:@"symmetricLeft"];
    
    // Right bar
    CALayer *rightBar = [CALayer layer];
    rightBar.backgroundColor = color.CGColor;
    rightBar.frame = CGRectMake(bounds.size.width, yCenter - barHeight / 2.0, barLength, barHeight);
    rightBar.cornerRadius = barHeight / 2.0;
    rightBar.shadowColor = color.CGColor;
    rightBar.shadowRadius = 12.0;
    rightBar.shadowOpacity = 1.0;
    rightBar.shadowOffset = CGSizeZero;
    [view.layer addSublayer:rightBar];
    
    CABasicAnimation *rightMove = [CABasicAnimation animationWithKeyPath:@"position.x"];
    rightMove.fromValue = @(bounds.size.width + barLength / 2.0);
    rightMove.toValue = @(bounds.size.width / 2.0 + barLength / 2.0);
    rightMove.duration = 1.0 / speed;
    rightMove.autoreverses = YES;
    rightMove.repeatCount = repeat;
    rightMove.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    [rightBar addAnimation:rightMove forKey:@"symmetricRight"];
    
    NSTimeInterval cleanupDelay = (2.0 * repeat) / speed + 0.5;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(cleanupDelay * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [leftBar removeFromSuperlayer];
        [rightBar removeFromSuperlayer];
    });
}

@end
