// Moody Glow - Persistent Glow Engine Implementation
// Developer: Moody
// Uses a dedicated overlay window that stays above everything

#import "MoodyGlowPersistentGlow.h"
#import <QuartzCore/QuartzCore.h>

static UIWindow *gPGWindow = nil;
static CAShapeLayer *gPGLayer = nil;
static UIBezierPath *gPGPath = nil;
static UIColor *gPGCurrentColor = nil;
static BOOL gPGActive = NO;

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

#pragma mark - Path

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

#pragma mark - Public API

- (void)showWithColor:(UIColor *)color animated:(BOOL)animated {
    if (!color) return;
    
    dispatch_async(dispatch_get_main_queue(), ^{
        UIWindow *w = [self getOrCreateWindow];
        if (!w) return;
        UIView *host = w.rootViewController.view;
        if (!host) return;
        
        if (!gPGPath) {
            gPGPath = [self outlinePathForBounds:host.bounds];
        }
        
        if (!gPGLayer) {
            // ---- First time: create the layer ----
            CAShapeLayer *layer = [CAShapeLayer layer];
            layer.path = gPGPath.CGPath;
            layer.strokeColor = color.CGColor;
            layer.fillColor = [UIColor clearColor].CGColor;
            layer.lineWidth = 4.0;
            layer.lineCap = kCALineCapRound;
            layer.lineJoin = kCALineJoinRound;
            layer.shadowColor = color.CGColor;
            layer.shadowRadius = 12.0;
            layer.shadowOpacity = 1.0;
            layer.shadowOffset = CGSizeZero;
            layer.opacity = 0.55;
            layer.zPosition = 9999;
            [host.layer addSublayer:layer];
            gPGLayer = layer;
            gPGCurrentColor = color;
            
            // Breathing animation (infinite)
            CABasicAnimation *breathe = [CABasicAnimation animationWithKeyPath:@"opacity"];
            breathe.fromValue = @0.55;
            breathe.toValue = @1.0;
            breathe.duration = 1.4;
            breathe.autoreverses = YES;
            breathe.repeatCount = HUGE_VALF;
            breathe.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
            [layer addAnimation:breathe forKey:@"pg_breathe"];
            
            gPGActive = YES;
            NSLog(@"[Moody Glow PG] Glow STARTED with color: %@", color);
        } else {
            // ---- Already active: update color if changed ----
            if (![gPGCurrentColor isEqual:color]) {
                gPGCurrentColor = color;
                
                CABasicAnimation *colorAnim = [CABasicAnimation animationWithKeyPath:@"strokeColor"];
                colorAnim.fromValue = (id)gPGLayer.strokeColor;
                colorAnim.toValue = (id)color.CGColor;
                colorAnim.duration = 0.4;
                colorAnim.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
                [gPGLayer addAnimation:colorAnim forKey:@"pg_color"];
                
                CABasicAnimation *shadowAnim = [CABasicAnimation animationWithKeyPath:@"shadowColor"];
                shadowAnim.fromValue = (id)gPGLayer.shadowColor;
                shadowAnim.toValue = (id)color.CGColor;
                shadowAnim.duration = 0.4;
                [gPGLayer addAnimation:shadowAnim forKey:@"pg_shadow_color"];
                
                gPGLayer.strokeColor = color.CGColor;
                gPGLayer.shadowColor = color.CGColor;
                NSLog(@"[Moody Glow PG] Color UPDATED to: %@", color);
            }
        }
    });
}

- (void)stopAnimated:(BOOL)animated {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (!gPGLayer) {
            gPGActive = NO;
            return;
        }
        
        CAShapeLayer *layer = gPGLayer;
        gPGLayer = nil;
        gPGPath = nil;
        gPGCurrentColor = nil;
        gPGActive = NO;
        
        [layer removeAnimationForKey:@"pg_breathe"];
        [layer removeAnimationForKey:@"pg_color"];
        [layer removeAnimationForKey:@"pg_shadow_color"];
        
        if (animated) {
            CABasicAnimation *fadeOut = [CABasicAnimation animationWithKeyPath:@"opacity"];
            fadeOut.fromValue = @(layer.opacity);
            fadeOut.toValue = @0.0;
            fadeOut.duration = 0.35;
            [layer addAnimation:fadeOut forKey:@"pg_fadeout"];
            layer.opacity = 0.0;
            
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.4 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [layer removeFromSuperlayer];
            });
        } else {
            [layer removeFromSuperlayer];
        }
        
        NSLog(@"[Moody Glow PG] Glow STOPPED.");
    });
}

- (BOOL)isActive {
    return gPGActive;
}

@end
