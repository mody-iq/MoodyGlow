// Moody Glow - Persistent Glow Engine Implementation
// Developer: Moody

#import "MoodyGlowPersistentGlow.h"
#import <QuartzCore/QuartzCore.h>

static const NSInteger kMoodyStyleContrary  = 0;
static const NSInteger kMoodyStyleLightBar  = 1;
static const NSInteger kMoodyStyleOutline   = 2;
static const NSInteger kMoodyStyleParticles = 3;
static const NSInteger kMoodyStylePendulum  = 4;
static const NSInteger kMoodyStyleSymmetric = 6;

static const NSTimeInterval kMoodyBannerDuration = 7.0;
static const NSTimeInterval kMoodyColorCycleInterval = 3.0;
static const NSTimeInterval kMoodyDramaticDuration = 1.2;

static NSString * const kPGLogPath = @"/var/mobile/Documents/MoodyGlow.log";

static UIWindow *gPGWindow = nil;
static __weak CALayer *gPGHostLayer = nil;
static CAShapeLayer *gPGLayer = nil;
static CAShapeLayer *gPGSecondLayer = nil;
static NSMutableArray<CAShapeLayer *> *gPGParticlesArray = nil;
static NSArray<UIColor *> *gPGColors = nil;
static NSInteger gPGColorIndex = 0;
static NSInteger gPGStyle = kMoodyStyleOutline;
static BOOL gPGActive = NO;
static CGFloat gPGBreathingSpeed = 1.0;
static CGFloat gPGDrawSpeed = 1.0;
static CGFloat gPGGlowThickness = 6.0;
static NSTimer *gPGWatchTimer = nil;
static NSTimer *gPGBannerTimer = nil;
static NSTimer *gPGColorTimer = nil;

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

#pragma mark - Scene / Window Discovery

- (UIWindow *)visibleCoverSheetWindow {
    for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
        if (![scene isKindOfClass:[UIWindowScene class]]) continue;
        UIWindowScene *ws = (UIWindowScene *)scene;
        for (UIWindow *w in ws.windows) {
            if ([NSStringFromClass([w class]) isEqualToString:@"SBCoverSheetWindow"] &&
                !w.hidden && w.alpha > 0.01) {
                return w;
            }
        }
    }
    return nil;
}

- (void)dumpAllWindows {
    NSMutableString *s = [NSMutableString string];
    [s appendString:@"--- Windows dump ---\n"];
    for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
        if (![scene isKindOfClass:[UIWindowScene class]]) continue;
        UIWindowScene *ws = (UIWindowScene *)scene;
        [s appendFormat:@"Scene %p state=%ld windows=%lu\n",
         ws, (long)ws.activationState, (unsigned long)ws.windows.count];
        for (UIWindow *w in ws.windows) {
            [s appendFormat:@"   %@ level=%g key=%d hidden=%d\n",
             NSStringFromClass([w class]), w.windowLevel, w.isKeyWindow, w.hidden];
        }
    }
    [self writePGLog:s];
}

- (UIWindowScene *)findBestScene {
    UIWindowScene *fallback = nil;

    for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
        if (![scene isKindOfClass:[UIWindowScene class]]) continue;
        UIWindowScene *ws = (UIWindowScene *)scene;
        if (!fallback) fallback = ws;
        for (UIWindow *w in ws.windows) {
            if (w.isKeyWindow) return ws;
        }
    }

    for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
        if (![scene isKindOfClass:[UIWindowScene class]]) continue;
        UIWindowScene *ws = (UIWindowScene *)scene;
        if (ws.activationState == UISceneActivationStateForegroundActive) return ws;
    }

    return fallback;
}

#pragma mark - Overlay Window

- (void)destroyOverlayWindow {
    [self teardownLayers];
    if (gPGWindow) {
        gPGWindow.hidden = YES;
        gPGWindow = nil;
    }
}

- (UIWindow *)getOrCreateOverlayWindow {
    UIWindowScene *targetScene = [self findBestScene];
    if (!targetScene) {
        [self writePGLog:@"No scene available!"];
        return nil;
    }

    if (gPGWindow && (gPGWindow.windowScene != targetScene || !gPGWindow.rootViewController)) {
        [self writePGLog:@"Overlay invalid or scene changed - recreating"];
        [self destroyOverlayWindow];
    }

    if (gPGWindow) {
        gPGWindow.windowLevel = 200000;
        gPGWindow.hidden = NO;
        return gPGWindow;
    }

    UIWindow *w = [[UIWindow alloc] initWithWindowScene:targetScene];
    CGRect frame = targetScene.coordinateSpace.bounds;
    if (CGRectIsEmpty(frame)) frame = [UIScreen mainScreen].bounds;
    w.frame = frame;
    w.windowLevel = 200000;
    w.backgroundColor = [UIColor clearColor];
    w.userInteractionEnabled = NO;

    UIViewController *root = [[UIViewController alloc] init];
    root.view.backgroundColor = [UIColor clearColor];
    root.view.userInteractionEnabled = NO;
    root.view.frame = w.bounds;
    w.rootViewController = root;
    w.hidden = NO;

    gPGWindow = w;
    [self writePGLog:[NSString stringWithFormat:@"Overlay window created (level=%g, frame=%@)",
                      w.windowLevel, NSStringFromCGRect(frame)]];
    [self dumpAllWindows];
    return w;
}

#pragma mark - Host Resolution

- (CALayer *)resolveHostLayerBounds:(CGRect *)outBounds source:(NSString **)outSource {
    UIWindow *cover = [self visibleCoverSheetWindow];
    if (cover) {
        CGRect b = cover.bounds;
        if (CGRectIsEmpty(b)) b = [UIScreen mainScreen].bounds;
        if (outBounds) *outBounds = CGRectMake(0, 0, b.size.width, b.size.height);
        if (outSource) *outSource = @"CoverSheet";
        return cover.layer;
    }

    UIWindow *w = [self getOrCreateOverlayWindow];
    if (!w) return nil;
    UIView *host = w.rootViewController.view;
    if (!host) return nil;

    CGRect hostFrame = w.bounds;
    if (CGRectIsEmpty(hostFrame)) hostFrame = [UIScreen mainScreen].bounds;
    host.frame = hostFrame;
    [host layoutIfNeeded];

    if (outBounds) *outBounds = CGRectMake(0, 0, hostFrame.size.width, hostFrame.size.height);
    if (outSource) *outSource = @"Overlay";
    return host.layer;
}

#pragma mark - Helper: All Active Layers

- (NSArray<CAShapeLayer *> *)allActiveLayers {
    NSMutableArray<CAShapeLayer *> *arr = [NSMutableArray array];
    if (gPGLayer) [arr addObject:gPGLayer];
    if (gPGSecondLayer) [arr addObject:gPGSecondLayer];
    if (gPGParticlesArray) [arr addObjectsFromArray:gPGParticlesArray];
    return arr;
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
    layer.lineWidth = gPGGlowThickness;
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
    layer.lineWidth = gPGGlowThickness;
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

- (CAShapeLayer *)createPendulumLayerWithColor:(UIColor *)color bounds:(CGRect)bounds {
    CGFloat dotSize = MAX(gPGGlowThickness * 3.0, 20.0);
    CGFloat yPos = MAX(75.0, bounds.size.height * 0.09);

    UIBezierPath *circle = [UIBezierPath bezierPathWithOvalInRect:
                            CGRectMake(0, 0, dotSize, dotSize)];

    CAShapeLayer *layer = [CAShapeLayer layer];
    layer.path = circle.CGPath;
    layer.position = CGPointMake(60.0, yPos);
    layer.fillColor = color.CGColor;
    layer.strokeColor = [UIColor clearColor].CGColor;
    layer.shadowColor = color.CGColor;
    layer.shadowRadius = 15.0;
    layer.shadowOpacity = 1.0;
    layer.shadowOffset = CGSizeZero;
    layer.opacity = 1.0;
    layer.zPosition = 9999;
    return layer;
}

- (CAShapeLayer *)createContrarySegmentLayerWithColor:(UIColor *)color
                                               bounds:(CGRect)bounds {
    UIBezierPath *path = [self outlinePathForBounds:bounds];

    CAShapeLayer *layer = [CAShapeLayer layer];
    layer.path = path.CGPath;
    layer.strokeColor = color.CGColor;
    layer.fillColor = [UIColor clearColor].CGColor;
    layer.lineWidth = gPGGlowThickness;
    layer.lineCap = kCALineCapRound;
    layer.lineJoin = kCALineJoinRound;
    layer.shadowColor = color.CGColor;
    layer.shadowRadius = 14.0;
    layer.shadowOpacity = 1.0;
    layer.shadowOffset = CGSizeZero;
    layer.strokeStart = 0.0;
    layer.strokeEnd = 0.15;
    layer.opacity = 1.0;
    layer.zPosition = 9999;
    return layer;
}

- (CAShapeLayer *)createParticleLayerWithColor:(UIColor *)color
                                        center:(CGPoint)center
                                          size:(CGFloat)size {
    UIBezierPath *circle = [UIBezierPath bezierPathWithOvalInRect:
                            CGRectMake(0, 0, size, size)];

    CAShapeLayer *layer = [CAShapeLayer layer];
    layer.path = circle.CGPath;
    layer.position = center;
    layer.fillColor = color.CGColor;
    layer.strokeColor = [UIColor clearColor].CGColor;
    layer.shadowColor = color.CGColor;
    layer.shadowRadius = 8.0;
    layer.shadowOpacity = 0.9;
    layer.shadowOffset = CGSizeZero;
    layer.opacity = 0.0;
    layer.zPosition = 9999;
    return layer;
}

#pragma mark - Particles Layout

- (NSArray<NSValue *> *)particlePositionsForBounds:(CGRect)bounds {
    CGFloat w = bounds.size.width;
    CGFloat notchWidth = 209.0;
    CGFloat notchLeft = (w - notchWidth) / 2.0;
    CGFloat notchRight = notchLeft + notchWidth;

    // 10 particles clustered around the notch
    return @[
        // Left cluster (4)
        [NSValue valueWithCGPoint:CGPointMake(notchLeft - 20, 32)],
        [NSValue valueWithCGPoint:CGPointMake(notchLeft - 42, 48)],
        [NSValue valueWithCGPoint:CGPointMake(notchLeft - 12, 55)],
        [NSValue valueWithCGPoint:CGPointMake(notchLeft - 34, 68)],
        // Right cluster (4) - mirrored
        [NSValue valueWithCGPoint:CGPointMake(notchRight + 20, 32)],
        [NSValue valueWithCGPoint:CGPointMake(notchRight + 42, 48)],
        [NSValue valueWithCGPoint:CGPointMake(notchRight + 12, 55)],
        [NSValue valueWithCGPoint:CGPointMake(notchRight + 34, 68)],
        // Top-center (2)
        [NSValue valueWithCGPoint:CGPointMake(w / 2.0 - 22, 45)],
        [NSValue valueWithCGPoint:CGPointMake(w / 2.0 + 22, 45)]
    ];
}

- (NSArray<NSNumber *> *)particleSizes {
    return @[@22.0, @26.0, @18.0, @20.0,
             @22.0, @26.0, @18.0, @20.0,
             @20.0, @20.0];
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

- (void)startLightBarAnimationOnLayer:(CAShapeLayer *)layer speed:(CGFloat)speed {
    if (speed < 0.1) speed = 0.1;
    [layer removeAnimationForKey:@"pg_lightbar_start"];
    [layer removeAnimationForKey:@"pg_lightbar_end"];

    CFTimeInterval duration = 2.5 / speed;

    CABasicAnimation *startAnim = [CABasicAnimation animationWithKeyPath:@"strokeStart"];
    startAnim.fromValue = @0.0;
    startAnim.toValue = @1.0;
    startAnim.duration = duration;
    startAnim.repeatCount = HUGE_VALF;
    startAnim.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionLinear];
    [layer addAnimation:startAnim forKey:@"pg_lightbar_start"];

    CABasicAnimation *endAnim = [CABasicAnimation animationWithKeyPath:@"strokeEnd"];
    endAnim.fromValue = @0.15;
    endAnim.toValue = @1.15;
    endAnim.duration = duration;
    endAnim.repeatCount = HUGE_VALF;
    endAnim.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionLinear];
    [layer addAnimation:endAnim forKey:@"pg_lightbar_end"];
}

- (void)startPendulumAnimationOnLayer:(CAShapeLayer *)layer speed:(CGFloat)speed {
    if (speed < 0.1) speed = 0.1;
    [layer removeAnimationForKey:@"pg_pendulum"];

    CFTimeInterval duration = 1.5 / speed;
    CGFloat screenWidth = [UIScreen mainScreen].bounds.size.width;

    CABasicAnimation *swing = [CValueABasicAnimation animationWithKey =Path:@"position.x"];
 @    swing.fromValue =1 @(60.0.);
    swing15.toValue = @(screenWidth - 60.0);
    swing.duration = duration;
    swing.autoreverses = YES;
    swing.repeatCount = HUGE_VALF;
    swing.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    [layer addAnimation:swing forKey:@"pg_pendulum"];
}

- (void)startContraryAnimationOnLayer:(CAShapeLayer *)layer
                                speed:(CGFloat)speed
                               isLeft:(BOOL)isLeft {
    if (speed < 0.1) speed = 0.1;
    NSString *startKey = isLeft ? @"pg_contrary_left_start" : @"pg_contrary_right_start";
    NSString *endKey   = isLeft ? @"pg_contrary_left_end"   : @"pg_contrary_right_end";
    [layer removeAnimationForKey:startKey];
    [layer removeAnimationForKey:endKey];

    CFTimeInterval duration = 3.0 / speed;

    CABasicAnimation *startAnim = [CABasicAnimation animationWithKeyPath:@"strokeStart"];
    CABasicAnimation *endAnim   = [CABasicAnimation animationWithKeyPath:@"strokeEnd"];

    if (isLeft) {
        startAnim.fromValue = @0.0;
        startAnim.toValue = @1.0;
        endAnim.fromValue = @0.15;
        endAnim.to;
    } else {
        startAnim.fromValue = @0.0;
        startAnim.toValue = @-1.0;
        endAnim.fromValue = @0.15;
        endAnim.toValue = @-0.85;
    }

    startAnim.duration = duration;
    startAnim.repeatCount = HUGE_VALF;
    startAnim.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionLinear];
    [layer addAnimation:startAnim forKey:startKey];

    endAnim.duration = duration;
    endAnim.repeatCount = HUGE_VALF;
    endAnim.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionLinear];
    [layer addAnimation:endAnim forKey:endKey];
}

- (void)startParticleAnimationOnLayer:(CAShapeLayer *)layer
                                index:(NSInteger)index
                                speed:(CGFloat)speed {
    if (speed < 0.1) speed = 0.1;
    [layer removeAnimationForKey:@"pg_particle"];
    [layer removeAnimationForKey:@"pg_particle_scale"];

    // Different durations per particle for organic feel
    CFTimeInterval baseDuration = (1.1 + (index % 4) * 0.25) / speed;

    CABasicAnimation *fade = [CABasicAnimation animationWithKeyPath:@"opacity"];
    fade.fromValue = @0.0;
    fade.toValue = @1.0;
    fade.duration = baseDuration;
    fade.autoreverses = YES;
    fade.repeatCount = HUGE_VALF;
    fade.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    fade.beginTime = CACurrentMediaTime() + (index * 0.18);
    fade.fillMode = kCAFillModeBoth;
    [layer addAnimation:fade forKey:@"pg_particle"];

    CABasicAnimation *scale = [CABasicAnimation animationWithKeyPath:@"transform.scale"];
    scale.fromValue = @0.55;
    scale.toValue = @1.15;
    scale.duration = baseDuration;
    scale.autoreverses = YES;
    scale.repeatCount = HUGE_VALF;
    scale.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    scale.beginTime = CACurrentMediaTime() + (index * 0.18);
    scale.fillMode = kCAFillModeBoth;
    [layer addAnimation:scale forKey:@"pg_particle_scale"];
}

- (void)startAnimationForStyle:(NSInteger)style layer:(CAShapeLayer *)layer {
    if (style == kMoodyStyleSymmetric) {
        [self startSymmetricAnimationOnLayer:layer speed:gPGDrawSpeed];
    } else if (style == kMoodyStyleLightBar) {
        [self startLightBarAnimationOnLayer:layer speed:gPGDrawSpeed];
    } else if (style == kMoodyStylePendulum) {
        [self startPendulumAnimationOnLayer:layer speed:gPGDrawSpeed];
    } else if (style == kMoodyStyleContrary) {
        BOOL isLeft = (layer == gPGLayer);
        [self startContraryAnimationOnLayer:layer speed:gPGDrawSpeed isLeft:isLeft];
    } else {
        [self startBreathingAnimationOnLayer:layer speed:gPGBreathingSpeed];
    }
}

- (void)removeAllStyleAnimationsFromLayer:(CAShapeLayer *)layer {
    if (!layer) return;
    [layer removeAnimationForKey:@"pg_breathe"];
    [layer removeAnimationForKey:@"pg_symmetric"];
    [layer removeAnimationForKey:@"pg_lightbar_start"];
    [layer removeAnimationForKey:@"pg_lightbar_end"];
    [layer removeAnimationForKey:@"pg_pendulum"];
    [layer removeAnimationForKey:@"pg_contrary_left_start"];
    [layer removeAnimationForKey:@"pg_contrary_left_end"];
    [layer removeAnimationForKey:@"pg_contrary_right_start"];
    [layer removeAnimationForKey:@"pg_contrary_right_end"];
    [layer removeAnimationForKey:@"pg_particle"];
    [layer removeAnimationForKey:@"pg_particle_scale"];
}

#pragma mark - Color Cycling (Dramatic Transition)

- (void)applyColor:(UIColor *)color animated:(BOOL)animated {
    NSArray<CAShapeLayer *> *layers = [self allActiveLayers];

    for (CAShapeLayer *layer in layers) {
        if (animated) {
            CABasicAnimation *colorAnim = [CABasicAnimation animationWithKeyPath:@"strokeColor"];
            colorAnim.fromValue = (id)layer.strokeColor;
            colorAnim.toValue = (id)color.CGColor;
            colorAnim.duration = kMoodyDramaticDuration;
            colorAnim.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
            [layer addAnimation:colorAnim forKey:@"pg_color"];

            CABasicAnimation *fillAnim = [CABasicAnimation animationWithKeyPath:@"fillColor"];
            fillAnim.fromValue = (id)layer.fillColor;
            fillAnim.toValue = (id)color.CGColor;
            fillAnim.duration = kMoodyDramaticDuration;
            fillAnim.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
            [layer addAnimation:fillAnim forKey:@"pg_fill_color"];

            CABasicAnimation *shadowColor = [CABasicAnimation animationWithKeyPath:@"shadowColor"];
            shadowColor.fromValue = (id)layer.shadowColor;
            shadowColor.toValue = (id)color.CGColor;
            shadowColor.duration = kMoodyDramaticDuration;
            shadowColor.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
            [layer addAnimation:shadowColor forKey:@"pg_shadow_color"];

            CABasicAnimation *shadowPulse = [CABasicAnimation animationWithKeyPath:@"shadowRadius"];
            shadowPulse.fromValue = @12.0;
            shadowPulse.toValue = @20.0;
            shadowPulse.duration = kMoodyDramaticDuration * 0.5;
            shadowPulse.autoreverses = YES;
            shadowPulse.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
            [layer addAnimation:shadowPulse forKey:@"pg_shadow_pulse"];

            CGFloat base = gPGGlowThickness;
            CABasicAnimation *widthPulse = [CABasicAnimation animationWithKeyPath:@"lineWidth"];
            widthPulse.fromValue = @(base);
            widthPulse.toValue = @(base * 1.6);
            widthPulse.duration = kMoodyDramaticDuration * 0.5;
            widthPulse.autoreverses = YES;
            widthPulse.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
            [layer addAnimation:widthPulse forKey:@"pg_width_pulse"];
        }
        layer.strokeColor = color.CGColor;
        layer.fillColor = color.CGColor;
        layer.shadowColor = color.CGColor;
    }
}

- (void)applyColorAtIndex:(NSInteger)index animated:(BOOL)animated {
    if (!gPGColors || gPGColors.count == 0) return;
    if (index < 0 || index >= (NSInteger)gPGColors.count) index = 0;
    UIColor *color = gPGColors[index];
    [self applyColor:color animated:animated];
    [self writePGLog:[NSString stringWithFormat:@"Color cycle -> %ld/%lu color=%@",
                      (long)(index + 1), (unsigned long)gPGColors.count, color]];
}

- (void)cancelColorTimer {
    if (gPGColorTimer) {
        [gPGColorTimer invalidate];
        gPGColorTimer = nil;
    }
}

- (void)restartColorTimer {
    [self cancelColorTimer];
    if (!gPGColors || gPGColors.count <= 1) {
        return;
    }
    NSTimer *t = [NSTimer timerWithTimeInterval:kMoodyColorCycleInterval
                                         target:self
                                       selector:@selector(colorTimerFired)
                                       userInfo:nil
                                        repeats:YES];
    [[NSRunLoop mainRunLoop] addTimer:t forMode:NSRunLoopCommonModes];
    gPGColorTimer = t;
}

- (void)colorTimerFired {
    if (!gPGActive || !gPGColors || gPGColors.count <= 1) {
        [self cancelColorTimer];
        return;
    }
    gPGColorIndex = (gPGColorIndex + 1) % gPGColors.count;
    [self applyColorAtIndex:gPGColorIndex animated:YES];
}

#pragma mark - Build / Teardown

- (void)buildLayersOnHost:(CALayer *)host
                   bounds:(CGRect)bounds
                    color:(UIColor *)color
                    style:(NSInteger)style {
    if (style == kMoodyStyleSymmetric) {
        UIBezierPath *rightPath = [self symmetricRightPathForBounds:bounds];
        UIBezierPath *leftPath  = [self symmetricLeftPathForBounds:bounds];
        gPGLayer       = [self createSymmetricLayerWithPath:rightPath color:color];
        gPGSecondLayer = [self createSymmetricLayerWithPath:leftPath  color:color];
        [host addSublayer:gPGLayer];
        [host addSublayer:gPGSecondLayer];

        [self startSymmetricAnimationOnLayer:gPGLayer speed:gPGDrawSpeed];
        [self startSymmetricAnimationOnLayer:gPGSecondLayer speed:gPGDrawSpeed];
    } else if (style == kMoodyStyleLightBar) {
        gPGLayer = [self createOutlineLayerWithColor:color bounds:bounds];
        gPGLayer.strokeStart = 0.0;
        gPGLayer.strokeEnd = 0.15;
        gPGLayer.opacity = 1.0;
        gPGLayer.shadowRadius = 18.0;
        [host addSublayer:gPGLayer];
        [self startLightBarAnimationOnLayer:gPGLayer speed:gPGDrawSpeed];
    } else if (style == kMoodyStylePendulum) {
        gPGLayer = [self createPendulumLayerWithColor:color bounds:bounds];
        [host addSublayer:gPGLayer];
        [self startPendulumAnimationOnLayer:gPGLayer speed:gPGDrawSpeed];
    } else if (style == kMoodyStyleContrary) {
        gPGLayer       = [self createContrarySegmentLayerWithColor:color bounds:bounds];
        gPGSecondLayer = [self createContrarySegmentLayerWithColor:color bounds:bounds];
        [host addSublayer:gPGLayer];
        [host addSublayer:gPGSecondLayer];

        [self startContraryAnimationOnLayer:gPGLayer       speed:gPGDrawSpeed isLeft:YES];
        [self startContraryAnimationOnLayer:gPGSecondLayer speed:gPGDrawSpeed isLeft:NO];
    } else if (style == kMoodyStyleParticles) {
        gPGParticlesArray = [NSMutableArray array];
        NSArray<NSValue *> *positions = [self particlePositionsForBounds:bounds];
        NSArray<NSNumber *> *sizes = [self particleSizes];

        for (NSInteger i = 0; i < (NSInteger)positions.count; i++) {
            CGPoint center = [positions[i] CGPointValue];
            CGFloat size = (i < (NSInteger)sizes.count) ? sizes[i].doubleValue : 20.0;
            CAShapeLayer *particle = [self createParticleLayerWithColor:color
                                                                 center:center
                                                                   size:size];
            [host addSublayer:particle];
            [gPGParticlesArray addObject:particle];
            [self startParticleAnimationOnLayer:particle index:i speed:gPGDrawSpeed];
        }
    } else {
        gPGLayer = [self createOutlineLayerWithColor:color bounds:bounds];
        [host addSublayer:gPGLayer];
        [self startBreathingAnimationOnLayer:gPGLayer speed:gPGBreathingSpeed];
    }
    gPGHostLayer = host;
}

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
    if (gPGParticlesArray) {
        for (CAShapeLayer *particle in gPGParticlesArray) {
            [self removeAllStyleAnimationsFromLayer:particle];
            [particle removeFromSuperlayer];
        }
        [gPGParticlesArray removeAllObjects];
        gPGParticlesArray = nil;
    }
    gPGHostLayer = nil;
}

#pragma mark - Banner Timer

- (void)cancelBannerTimer {
    if (gPGBannerTimer) {
        [gPGBannerTimer invalidate];
        gPGBannerTimer = nil;
    }
}

- (void)restartBannerTimer {
    [self cancelBannerTimer];
    NSTimer *t = [NSTimer timerWithTimeInterval:kMoodyBannerDuration
                                         target:self
                                       selector:@selector(bannerTimerFired)
                                       userInfo:nil
                                        repeats:NO];
    [[NSRunLoop mainRunLoop] addTimer:t forMode:NSRunLoopCommonModes];
    gPGBannerTimer = t;
}

- (void)bannerTimerFired {
    gPGBannerTimer = nil;
    [self writePGLog:@"Banner timer expired - stopping glow"];
    [self stopAnimated:YES];
}

- (void)applyTimerPolicyForSource:(NSString *)source {
    if ([source isEqualToString:@"Overlay"]) {
        [self restartBannerTimer];
    } else {
        [self cancelBannerTimer];
    }
}

#pragma mark - Watch Timer

- (void)startWatchTimer {
    if (gPGWatchTimer) return;
    NSTimer *t = [NSTimer timerWithTimeInterval:0.25
                                         target:self
                                       selector:@selector(watchTick)
                                       userInfo:nil
                                        repeats:YES];
    [[NSRunLoop mainRunLoop] addTimer:t forMode:NSRunLoopCommonModes];
    gPGWatchTimer = t;
}

- (void)stopWatchTimer {
    if (gPGWatchTimer) {
        [gPGWatchTimer invalidate];
        gPGWatchTimer = nil;
    }
}

- (void)watchTick {
    if (!gPGActive || !gPGColors || gPGColors.count == 0) {
        [self stopWatchTimer];
        return;
    }

    CGRect bounds = CGRectZero;
    NSString *source = nil;
    CALayer *host = [self resolveHostLayerBounds:&bounds source:&source];
    if (!host) return;

    BOOL detached = NO;
    if (gPGLayer && gPGLayer.superlayer != host) detached = YES;
    if (gPGSecondLayer && gPGSecondLayer.superlayer != host) detached = YES;
    if (gPGParticlesArray) {
        for (CAShapeLayer *p in gPGParticlesArray) {
            if (p.superlayer != host) { detached = YES; break; }
        }
    }

    if (host != gPGHostLayer || detached) {
        UIColor *current = gPGColors[gPGColorIndex];
        NSInteger style = gPGStyle;
        [self teardownLayers];
        [self buildLayersOnHost:host bounds:bounds color:current style:style];
        [self writePGLog:[NSString stringWithFormat:@"Host switched -> %@ bounds=%@",
                          source, NSStringFromCGRect(bounds)]];
        [self applyTimerPolicyForSource:source];
    }
}

#pragma mark - Public API

- (void)showWithColors:(NSArray<UIColor *> *)colors
                 style:(NSInteger)style
              animated:(BOOL)animated {
    if (!colors || colors.count == 0) {
        [self stopAnimated:YES];
        return;
    }

    dispatch_async(dispatch_get_main_queue(), ^{
        BOOL listChanged = YES;
        if (gPGColors && gPGColors.count == colors.count) {
            listChanged = NO;
            for (NSUInteger i = 0; i < colors.count; i++) {
                if (![gPGColors[i] isEqual:colors[i]]) {
                    listChanged = YES;
                    break;
                }
            }
        }

        if (listChanged) {
            gPGColors = [colors copy];
            gPGColorIndex = 0;
            [self writePGLog:[NSString stringWithFormat:@"Color list changed (%lu colors) - reset to 0",
                              (unsigned long)colors.count]];
        }

        CGRect bounds = CGRectZero;
        NSString *source = nil;
        CALayer *host = [self resolveHostLayerBounds:&bounds source:&source];
        if (!host) {
            [self writePGLog:@"showWithColors: no host layer!"];
            return;
        }

        BOOL hostChanged = (gPGHostLayer && gPGHostLayer != host);
        BOOL styleChanged = ((gPGLayer || gPGSecondLayer || gPGParticlesArray) && gPGStyle != style);

        if (hostChanged || styleChanged) {
            [self teardownLayers];
        }

        if (!gPGLayer && !gPGSecondLayer && !gPGParticlesArray) {
            UIColor *initial = gPGColors[gPGColorIndex];
            [self buildLayersOnHost:host bounds:bounds color:initial style:style];
            gPGStyle = style;
            gPGActive = YES;
            [self writePGLog:[NSString stringWithFormat:@"STARTED style=%ld host=%@ bounds=%@ colors=%lu thickness=%.1f",
                              (long)style, source, NSStringFromCGRect(bounds),
                              (unsigned long)gPGColors.count, gPGGlowThickness]];
        } else {
            [self applyColorAtIndex:gPGColorIndex animated:YES];
        }

        [self applyTimerPolicyForSource:source];
        if ([source isEqualToString:@"Overlay"]) {
            [self writePGLog:@"Banner timer (re)started: 7s"];
        }

        if (listChanged || !gPGColorTimer) {
            [self restartColorTimer];
        }

        [self startWatchTimer];
    });
}

- (void)showWithColor:(UIColor *)color
                style:(NSInteger)style
             animated:(BOOL)animated {
    if (!color) {
        [self stopAnimated:animated];
        return;
    }
    [self showWithColors:@[color] style:style animated:animated];
}

- (void)stopAnimated:(BOOL)animated {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self stopWatchTimer];
        [self cancelBannerTimer];
        [self cancelColorTimer];

        if (!gPGLayer && !gPGSecondLayer && !gPGParticlesArray) {
            gPGActive = NO;
            gPGColors = nil;
            gPGColorIndex = 0;
            return;
        }

        NSMutableArray<CAShapeLayer *> *layers = [NSMutableArray array];
        if (gPGLayer) { [layers addObject:gPGLayer]; gPGLayer = nil; }
        if (gPGSecondLayer) { [layers addObject:gPGSecondLayer]; gPGSecondLayer = nil; }
        if (gPGParticlesArray) {
            [layers addObjectsFromArray:gPGParticlesArray];
            [gPGParticlesArray removeAllObjects];
            gPGParticlesArray = nil;
        }
        gPGColors = nil;
        gPGColorIndex = 0;
        gPGHostLayer = nil;
        gPGActive = NO;

        for (CAShapeLayer *layer in layers) {
            [self removeAllStyleAnimationsFromLayer:layer];
            [layer removeAnimationForKey:@"pg_color"];
            [layer removeAnimationForKey:@"pg_fill_color"];
            [layer removeAnimationForKey:@"pg_shadow_color"];
            [layer removeAnimationForKey:@"pg_shadow_pulse"];
            [layer removeAnimationForKey:@"pg_width_pulse"];

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
        if (gPGParticlesArray && gPGActive) {
            NSInteger i = 0;
            for (CAShapeLayer *particle in gPGParticlesArray) {
                [self removeAllStyleAnimationsFromLayer:particle];
                [self startParticleAnimationOnLayer:particle index:i speed:speed];
                i++;
            }
        }
    });
}

- (void)setGlowThickness:(CGFloat)thickness {
    if (thickness < 1.0) thickness = 1.0;
    if (thickness > 12.0) thickness = 12.0;
    gPGGlowThickness = thickness;

    dispatch_async(dispatch_get_main_queue(), ^{
        if (gPGLayer) {
            gPGLayer.lineWidth = thickness;
        }
        if (gPGSecondLayer) {
            gPGSecondLayer.lineWidth = thickness;
        }
        [self writePGLog:[NSString stringWithFormat:@"Thickness set to %.1f", thickness]];
    });
}

- (BOOL)isActive {
    return gPGActive;
}

@end
