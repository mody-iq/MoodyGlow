// Moody Glow - Persistent Glow Engine Implementation
// Developer: Moody
// Supports: Outline (style 2), Symmetric (style 6)

#import "MoodyGlowPersistentGlow.h"
#import <QuartzCore/QuartzCore.h>

// Style constants
static const NSInteger kMoodyStyleOutline   = 2;
static const NSInteger kMoodyStyleSymmetric = 6;

static NSString * const kPGLogPath = @"/var/mobile/Documents/MoodyGlow.log";

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

#pragma mark - Debug Logging

- (void)writePGLog:(NSString *)msg {
    if (!msg) return;
    NSDateFormatter *fmt = [[NSDateFormatter alloc] init];
    fmt.dateFormat = @"HH:mm:ss";
    NSString *entry = [NSString stringWithFormat:@"[%@] [PG] %@\n",
                       [fmt stringFromDate:[NSDate date]], msg];
    NSLog(@"[Moody Glow PG] %@", msg);
    
    NSFileHandle *fh = [NSFileHandle fileHandleForWritingAtPath:kPGLogPath];
    if (!fh) {
        [[NSFileManager defaultManager] createFileAtPath:kPGLogPath
                                                contents:[entry dataUsingEncoding:NSUTF8StringEncoding]
                                              attributes:nil];
    } else {
        [fh seekToEndOfFile];
        [fh writeData:[entry dataUsingEncoding:NSUTF8StringEncoding]];
        [fh closeFile];
    }
}

#pragma mark - Lock Screen Scene Detection

// Try to get the lock screen scene from SBLockScreenManager._hostingWindowScene
- (UIWindowScene *)lockScreenScene {
    Class cls = NSClassFromString(@"SBLockScreenManager");
    if (!cls) return nil;
    
    id mgr = nil;
    SEL sharedSel = NSSelectorFromString(@"sharedInstance");
    if ([cls respondsToSelector:sharedSel]) {
        IMP imp = [cls methodForSelector:sharedSel];
        if (imp) {
            id (*func)(id, SEL) = (void *)imp;
            mgr = func(cls, sharedSel);
        }
    }
    if (!mgr) return nil;
    
    SEL hostSel = NSSelectorFromString(@"_hostingWindowScene");
    if (![mgr respondsToSelector:hostSel]) {
        [self writePGLog:@"SBLockScreenManager does not respond to _hostingWindowScene"];
        return nil;
    }
    
    IMP imp = [mgr methodForSelector:hostSel];
    if (!imp) return nil;
    
    id (*func)(id, SEL) = (void *)imp;
    id result = func(mgr, hostSel);
    if ([result isKindOfClass:[UIWindowScene class]]) {
        return (UIWindowScene *)result;
    }
    return nil;
}

- (UIWindowScene *)findBestScene {
    // Priority 1: Lock screen scene (if available)
    UIWindowScene *lsScene = [self lockScreenScene];
    if (lsScene) {
        [self writePGLog:[NSString stringWithFormat:@"Using LOCK SCREEN scene (state=%ld, windows=%lu)",
                          (long)lsScene.activationState, (unsigned long)lsScene.windows.count]];
        return lsScene;
    }
    
    // Priority 2: Scene with key window
    for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
        if (![scene isKindOfClass:[UIWindowScene class]]) continue;
        UIWindowScene *ws = (UIWindowScene *)scene;
        for (UIWindow *w in ws.windows) {
            if (w.isKeyWindow) {
                [self writePGLog:@"Using scene with key window"];
                return ws;
            }
        }
    }
    
    // Priority 3: Foreground active scene
    for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
        if (![scene isKindOfClass:[UIWindowScene class]]) continue;
        UIWindowScene *ws = (UIWindowScene *)scene;
        if (ws.activationState == UISceneActivationStateForegroundActive) {
            [self writePGLog:@"Using foreground active scene"];
            return ws;
        }
    }
    
    // Priority 4: Any scene
    for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
        if ([scene isKindOfClass:[UIWindowScene class]]) {
            [self writePGLog:@"Using any available scene"];
            return (UIWindowScene *)scene;
        }
    }
    
    return nil;
}

#pragma mark - Window

- (UIWindow *)getOrCreateWindow {
    UIWindowScene *targetScene = [self findBestScene];
    if (!targetScene) {
        [self writePGLog:@"No scene available!"];
        return nil;
    }
    
    // If cached window belongs to a different scene → destroy it
    if (gPGWindow && gPGWindow.windowScene != targetScene) {
        [self writePGLog:@"Scene changed - recreating window"];
        gPGWindow.hidden = YES;
        gPGWindow = nil;
    }
    
    if (gPGWindow) return gPGWindow;
    
    UIWindow *w = [[UIWindow alloc] initWithWindowScene:targetScene];
    w.frame = targetScene.coordinateSpace.bounds;
    w.windowLevel = UIWindowLevelAlert + 100000;
    w.backgroundColor = [UIColor clearColor];
    w.userInteractionEnabled = NO;
    w.hidden = NO;
    
    UIViewController *root = [[UIViewController alloc] init];
    root.view.backgroundColor = [UIColor clearColor];
    root.view.userInteractionEnabled = NO;
    root.view.frame = w.bounds;
    w.rootViewController = root;
    
    gPGWindow = w;
    [self writePGLog:[NSString stringWithFormat:@"Window created (level=%g, scene=%p)",
                      w.windowLevel, targetScene]];
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
        if (!w) {
            [self writePGLog:@"showWithColor: no window!"];
            return;
        }
        UIView *host = w.rootViewController.view;
        if (!host) {
            [self writePGLog:@"showWithColor: no host view!"];
            return;
        }
        
        if ((gPGLayer || gPGSecondLayer) && gPGStyle != style) {
            [self writePGLog:[NSString stringWithFormat:@"Style change (%ld -> %ld)", (long)gPGStyle, (long)style]];
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
            [self writePGLog:[NSString stringWithFormat:@"STARTED style=%ld color=%@ breathe=%.2f draw=%.2f",
                              (long)style, color, gPGBreathingSpeed, gPGDrawSpeed]];
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
                [self writePGLog:[NSString stringWithFormat:@"Color UPDATED to %@", color]];
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
        [self writePGLog:@"STOPPED"];
    });
}

- (void)setBreathingSpeed:(CGFloat)speed {
    if (speed < 0.1) speed = 0.1;
    gPGBreathingSpeed = speed;
    
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
