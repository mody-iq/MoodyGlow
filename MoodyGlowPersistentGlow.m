// Moody Glow - Persistent Glow Engine Implementation
// Developer: Moody
// Supports: Outline (style 2), Symmetric (style 6)

#import "MoodyGlowPersistentGlow.h"
#import <QuartzCore/QuartzCore.h>

// Style constants
static const NSInteger kMoodyStyleOutline   = 2;
static const NSInteger kMoodyStyleSymmetric = 6;

static UIWindow *gPGWindow = nil;
static CAShapeLayer *gPGLayer = nil;
static CAShapeLayer *gPGSecondLayer = nil;
static UIColor *gPGCurrentColor = nil;
static NSInteger gPGStyle = kMoodyStyleOutline;
static BOOL gPGActive = NO;
static CGFloat gPGBreathingSpeed = 1.0;
static CGFloat gPGDrawSpeed = 1.0;

@implementation MoodyGlowPersistentGlow

+ (instancetype)sharedInstance {
    static MoodyGlowPersistentGlow *shared = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        shared = [[MoodyGlowPersistentGlow alloc] init];
    });
    return shared;
}

#pragma mark - Window

- (UIWindow *)getOrCreateWindow {
    if (gPGWindow) return gPGWindow;
    
    UIWindowScene *targetScene = nil;
    for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
        if ([scene isKindOfClass:[UIWindowScene class]]) {
            UIWindowScene *ws = (UIWindowScene *)scene;
            if (ws.activationState == UISceneActivationStateForegroundActive) {
                targetScene = ws;
                break;
            }
            if (!targetScene) targetScene = ws;
        }
    }
    if (!targetScene) {
        NSLog(@"[Moody Glow PG] No scene available.");
        return nil;
    }
    
    UIWindow *w = [[UIWindow alloc] initWithWindowScene:targetScene];
    w.frame = targetScene.coordinateSpace.bounds;
    w.windowLevel = UIWindowLevelAlert + 1000;
    w.backgroundColor = [UIColor clearColor];
    w.userInteractionEnabled = NO;
    w.hidden = NO;
    
    UIViewController *root = [[UIViewController alloc] init];
    root.view.backgroundColor = [UIColor clearColor];
    root.view.userInteractionEnabled = NO;
    root.view.frame = w.bounds;
    w.rootViewController = root;
    
    gPGWindow = w;
    NSLog(@"[Moody Glow PG] Overlay window created.");
    return w;
}

#pragma mark - Paths

- (UIBezierPath *)outlinePathForBounds:(CGRect)bounds {
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

- (UIBezierPath *)symmetricRightPathForBounds:(CGRect)bounds {
    CGFloat w = bounds.size.width;
    CGFloat h = bounds.size.height;
    CGFloat cornerRadius = 39.0;
    CGFloat notchWidth = 209.0;
    CGFloat notchHeight = 30.0;
    CGFloat notchCornerRadius = 15.0;
    CGFloat notchLeft = (w - notchWidth) / 2.0;
    CGFloat notchRight = notchLeft + notchWidth;
    
    UIBezierPath *path = [UIBezierPath bezierPath];
    [path moveToPoint:CGPointMake(notchRight, notchHeight)];
    [path addLineToPoint:CGPointMake(notchRight, notchCornerRadius)];
    [path addQuadCurveToPoint:CGPointMake(notchRight + notchCornerRadius, 0)
                 controlPoint:CGPointMake(notchRight, 0)];
    [path addLineToPoint:CGPointMake(w - cornerRadius, 0)];
    [path addQuadCurveToPoint:CGPointMake(w, cornerRadius) controlPoint:CGPointMake(w, 0)];
    [path addLineToPoint:CGPointMake(w, h - cornerRadius)];
    [path addQuadCurveToPoint:CGPointMake(w - cornerRadius, h) controlPoint:CGPointMake(w, h)];
    [path addLineToPoint:CGPointMake(w / 2.0, h)];
    return path;
}

- (UIBezierPath *)symmetricLeftPathForBounds:(CGRect)bounds {
    CGFloat w = bounds.size.width;
    CGFloat h = bounds.size.height;
    CGFloat cornerRadius = 39.0;
    CGFloat notchWidth = 209.0;
    CGFloat notchHeight = 30.0;
    CGFloat notchCornerRadius = 15.0;
    CGFloat notchLeft = (w - notchWidth) / 2.0;
    
    UIBezierPath *path = [UIBezierPath bezierPath];
    [path moveToPoint:CGPointMake(notchLeft, notchHeight)];
    [path addLineToPoint:CGPointMake(notchLeft, notchCornerRadius)];
    [path addQuadCurveToPoint:CGPointMake(notchLeft - notchCornerRadius, 0)
                 controlPoint:CGPointMake(notchLeft, 0)];
    [path addLineToPoint:CGPointMake(cornerRadius, 0)];
    [path addQuadCurveToPoint:CGPointMake(0, cornerRadius) controlPoint:CGPointMake(0, 0)];
    [path addLineToPoint:CGPointMake(0, h - cornerRadius)];
    [path addQuadCurveToPoint:CGPointMake(cornerRadius, h) controlPoint:CGPointMake(0, h)];
    [path addLineToPoint:CGPointMake(w / 2.0, h)];
    return path;
}

#pragma mark - Layer Creation

- (CAShapeLayer *)createOutlineLayerWithColor:(UIColor *)color bounds:(CGRect)bounds {
    UIBezierPath *path = [self outlinePathForBounds:bounds];
    
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
    layer.opacity = 0.4;
    layer.zPosition = 9999;
    return layer;
}

- (CAShapeLayer *)createSymmetricLayerWithPath:(UIBezierPath *)path
                                         color:(UIColor *)color {
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
    layer.strokeStart = 0.0;
    layer.strokeEnd = 0.0;
    layer.zPosition = 9999;
    return layer;
}

#pragma mark - Animations

- (void)startBreathingAnimationOnLayer:(CAShapeLayer *)layer speed:(CGFloat)speed {
    if (speed < 0.1) speed = 0.1;
    [layer removeAnimationForKey:@"pg_breathe"];
    
    CABasicAnimation *breathe = [CABasicAnimation animationWithKeyPath:@"opacity"];
    breathe.fromValue = @0.4;
    breathe.toValue = @1.0;
    breathe.duration = 0.7 / speed;
    breathe.autoreverses = YES;
    breathe.repeatCount = HUGE_VALF;
    breathe.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    [layer addAnimation:breathe forKey:@"pg_breathe"];
}

- (void)startSymmetricAnimationOnLayer:(CAShapeLayer *)layer speed:(CGFloat)speed {
    if (speed < 0.1) speed = 0.1;
    [layer removeAnimationForKey:@"pg_symmetric"];
    
    CFTimeInterval drawDuration = 1.2 / speed;
    
    CABasicAnimation *draw = [CABasicAnimation animationWithKeyPath:@"strokeEnd"];
    draw.fromValue = @0.0;
    draw.toValue = @1.0;
    draw.duration = drawDuration;
    draw.autoreverses = YES;
    draw.repeatCount = HUGE_VALF;
    draw.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    [layer addAnimation:draw forKey:@"pg_symmetric"];
}

- (void)startAnimationForStyle:(NSInteger)style layer:(CAShapeLayer *)layer {
    if (style == kMoodyStyleSymmetric) {
        [self startSymmetricAnimationOnLayer:layer speed:gPGDrawSpeed];
    } else {
        [self startBreathingAnimationOnLayer:layer speed:gPGBreathingSpeed];
    }
}

- (void)removeAllStyleAnimationsFromLayer:(CAShapeLayer *)layer {
    if (!layer) return;
    [layer removeAnimationForKey:@"pg_breathe"];
    [layer removeAnimationForKey:@"pg_symmetric"];
}

#pragma mark - Teardown

- (void)teardownLayers {
    if (gPGLayer) {
        [self removeAllStyleAnimationsFromLayer:gPGLayer];
        [gPGLayer removeFromSuperlayer];
        gPGLayer = nil;
    }
    if (gPGSecondLayer) {
        [self removeAllStyleAnimationsFromLayer:gPGSecondLayer];
        [gPGSecondLayer removeFromSuperlayer];
        gPGSecondLayer = nil;
    }
}

#pragma mark - Public API

- (void)showWithColor:(UIColor *)color
                style:(NSInteger)style
             animated:(BOOL)animated {
    if (!color) return;
    
    dispatch_async(dispatch_get_main_queue(), ^{
        UIWindow *w = [self getOrCreateWindow];
        if (!w) return;
        UIView *host = w.rootViewController.view;
        if (!host) return;
        
        if ((gPGLayer || gPGSecondLayer) && gPGStyle != style) {
            NSLog(@"[Moody Glow PG] Style change (%ld -> %ld). Recreating.", (long)gPGStyle, (long)style);
            [self teardownLayers];
        }
        
        if (!gPGLayer && !gPGSecondLayer) {
            if (style == kMoodyStyleSymmetric) {
                UIBezierPath *rightPath = [self symmetricRightPathForBounds:host.bounds];
                UIBezierPath *leftPath  = [self symmetricLeftPathForBounds:host.bounds];
                gPGLayer       = [self createSymmetricLayerWithPath:rightPath color:color];
                gPGSecondLayer = [self createSymmetricLayerWithPath:leftPath  color:color];
                [host.layer addSublayer:gPGLayer];
                [host.layer addSublayer:gPGSecondLayer];
                
                [self startSymmetricAnimationOnLayer:gPGLayer speed:gPGDrawSpeed];
                [self startSymmetricAnimationOnLayer:gPGSecondLayer speed:gPGDrawSpeed];
            } else {
                gPGLayer = [self createOutlineLayerWithColor:color bounds:host.bounds];
                [host.layer addSublayer:gPGLayer];
                [self startBreathingAnimationOnLayer:gPGLayer speed:gPGBreathingSpeed];
            }
            
            gPGStyle = style;
            gPGCurrentColor = color;
            gPGActive = YES;
            NSLog(@"[Moody Glow PG] Glow STARTED. style=%ld color=%@ breathe=%.2f draw=%.2f",
                  (long)style, color, gPGBreathingSpeed, gPGDrawSpeed);
        } else {
            if (![gPGCurrentColor isEqual:color]) {
                gPGCurrentColor = color;
                
                NSArray<CAShapeLayer *> *layers = @[];
                if (gPGLayer) layers = [layers arrayByAddingObject:gPGLayer];
                if (gPGSecondLayer) layers = [layers arrayByAddingObject:gPGSecondLayer];
                
                for (CAShapeLayer *layer in layers) {
                    CABasicAnimation *colorAnim = [CABasicAnimation animationWithKeyPath:@"strokeColor"];
                    colorAnim.fromValue = (id)layer.strokeColor;
                    colorAnim.toValue = (id)color.CGColor;
                    colorAnim.duration = 0.4;
                    colorAnim.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
                    [layer addAnimation:colorAnim forKey:@"pg_color"];
                    
                    CABasicAnimation *shadowAnim = [CABasicAnimation animationWithKeyPath:@"shadowColor"];
                    shadowAnim.fromValue = (id)layer.shadowColor;
                    shadowAnim.toValue = (id)color.CGColor;
                    shadowAnim.duration = 0.4;
                    [layer addAnimation:shadowAnim forKey:@"pg_shadow_color"];
                    
                    layer.strokeColor = color.CGColor;
                    layer.shadowColor = color.CGColor;
                }
                
                NSLog(@"[Moody Glow PG] Color UPDATED to: %@", color);
            }
        }
    });
}

- (void)stopAnimated:(BOOL)animated {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (!gPGLayer && !gPGSecondLayer) {
            gPGActive = NO;
            return;
        }
        
        NSMutableArray<CAShapeLayer *> *layers = [NSMutableArray array];
        if (gPGLayer) { [layers addObject:gPGLayer]; gPGLayer = nil; }
        if (gPGSecondLayer) { [layers addObject:gPGSecondLayer]; gPGSecondLayer = nil; }
        gPGCurrentColor = nil;
        gPGActive = NO;
        
        for (CAShapeLayer *layer in layers) {
            [self removeAllStyleAnimationsFromLayer:layer];
            [layer removeAnimationForKey:@"pg_color"];
            [layer removeAnimationForKey:@"pg_shadow_color"];
            
            if (animated) {
                CABasicAnimation *fadeOut = [CABasicAnimation animationWithKeyPath:@"opacity"];
                fadeOut.fromValue = @(layer.opacity);
                fadeOut.toValue = @0.0;
                fadeOut.duration = 0.35;
                [layer addAnimation:fadeOut forKey:@"pg_fadeout"];
                layer.opacity = 0.0;
                
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.4 * NSEC_PER_SEC)),
                               dispatch_get_main_queue(), ^{
                    [layer removeFromSuperlayer];
                });
            } else {
                [layer removeFromSuperlayer];
            }
        }
        
        NSLog(@"[Moody Glow PG] Glow STOPPED.");
    });
}

- (void)setBreathingSpeed:(CGFloat)speed {
    if (speed < 0.1) speed = 0.1;
    gPGBreathingSpeed = speed;
    NSLog(@"[Moody Glow PG] Breathing speed = %.2f", speed);
    
    dispatch_async(dispatch_get_main_queue(), ^{
        if (gPGLayer && gPGActive) {
            [self removeAllStyleAnimationsFromLayer:gPGLayer];
            [self startAnimationForStyle:gPGStyle layer:gPGLayer];
        }
        if (gPGSecondLayer && gPGActive) {
            [self removeAllStyleAnimationsFromLayer:gPGSecondLayer];
            [self startAnimationForStyle:gPGStyle layer:gPGSecondLayer];
        }
    });
}

- (void)setDrawSpeed:(CGFloat)speed {
    if (speed < 0.1) speed = 0.1;
    gPGDrawSpeed = speed;
    NSLog(@"[Moody Glow PG] Draw speed = %.2f", speed);
    
    dispatch_async(dispatch_get_main_queue(), ^{
        if (gPGLayer && gPGActive) {
            [self removeAllStyleAnimationsFromLayer:gPGLayer];
            [self startAnimationForStyle:gPGStyle layer:gPGLayer];
        }
        if (gPGSecondLayer && gPGActive) {
            [self removeAllStyleAnimationsFromLayer:gPGSecondLayer];
            [self startAnimationForStyle:gPGStyle layer:gPGSecondLayer];
        }
    });
}

- (BOOL)isActive {
    return gPGActive;
}

@end
