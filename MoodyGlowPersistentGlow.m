// Moody Glow - Persistent Glow Engine Implementation
// Developer: Moody
// Supports: Outline (style 2), Symmetric (style 6)
// Host strategy: SBCoverSheetWindow while it is visible (lock screen),
// own overlay window otherwise. A watch timer switches host automatically.

#import "MoodyGlowPersistentGlow.h"
#import <QuartzCore/QuartzCore.h>

static const NSInteger kMoodyStyleOutline   = 2;
static const NSInteger kMoodyStyleSymmetric = 6;

static NSString * const kPGLogPath = @"/var/mobile/Documents/MoodyGlow.log";

static UIWindow *gPGWindow = nil;
static __weak CALayer *gPGHostLayer = nil;
static CAShapeLayer *gPGLayer = nil;
static CAShapeLayer *gPGSecondLayer = nil;
static UIColor *gPGCurrentColor = nil;
static NSInteger gPGStyle = kMoodyStyleOutline;
static BOOL gPGActive = NO;
static CGFloat gPGBreathingSpeed = 1.0;
static CGFloat gPGDrawSpeed = 1.0;
static NSTimer *gPGWatchTimer = nil;

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

// The lock screen window (visible only while the cover sheet is showing)
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

    // Priority 1: scene with key window
    for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
        if (![scene isKindOfClass:[UIWindowScene class]]) continue;
        UIWindowScene *ws = (UIWindowScene *)scene;
        if (!fallback) fallback = ws;
        for (UIWindow *w in ws.windows) {
            if (w.isKeyWindow) return ws;
        }
    }

    // Priority 2: foreground active scene
    for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
        if (![scene isKindOfClass:[UIWindowScene class]]) continue;
        UIWindowScene *ws = (UIWindowScene *)scene;
        if (ws.activationState == UISceneActivationStateForegroundActive) return ws;
    }

    // Priority 3: any scene
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

// Returns the layer our glow layers must be attached to.
// CoverSheet while the lock screen is visible, otherwise our own overlay.
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
    CGFloat cornerRadius = 
