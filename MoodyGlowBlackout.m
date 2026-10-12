// Moody Glow - Blackout Manager Implementation
// Developer: Moody
// Purpose: Manage black overlay + screen wake/sleep for Blackout feature

#import "MoodyGlowBlackout.h"

static UIView *gBlackoutOverlay = nil;

@implementation MoodyGlowBlackout

#pragma mark - Overlay

+ (void)showOverlayInWindow:(UIWindow *)window {
    if (!window) return;
    
    void (^work)(void) = ^{
        // Remove any existing overlay first
        if (gBlackoutOverlay) {
            [gBlackoutOverlay removeFromSuperview];
            gBlackoutOverlay = nil;
        }
        
        UIView *overlay = [[UIView alloc] initWithFrame:window.bounds];
        overlay.backgroundColor = [UIColor blackColor];
        overlay.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        overlay.userInteractionEnabled = NO;
        overlay.alpha = 0.0;
        overlay.layer.zPosition = 8000;
        
        [window addSubview:overlay];
        gBlackoutOverlay = overlay;
        
        [UIView animateWithDuration:0.15 animations:^{
            overlay.alpha = 1.0;
        }];
        
        NSLog(@"[Moody Glow] Blackout overlay shown.");
    };
    
    if ([NSThread isMainThread]) {
        work();
    } else {
        dispatch_sync(dispatch_get_main_queue(), work);
    }
}

+ (void)removeOverlayAnimated:(BOOL)animated {
    void (^work)(void) = ^{
        if (!gBlackoutOverlay) return;
        
        UIView *overlay = gBlackoutOverlay;
        gBlackoutOverlay = nil;
        
        if (animated) {
            [UIView animateWithDuration:0.4 animations:^{
                overlay.alpha = 0.0;
            } completion:^(BOOL finished) {
                [overlay removeFromSuperview];
            }];
        } else {
            [overlay removeFromSuperview];
        }
        
        NSLog(@"[Moody Glow] Blackout overlay removed (animated=%d)", animated);
    };
    
    if ([NSThread isMainThread]) {
        work();
    } else {
        dispatch_async(dispatch_get_main_queue(), work);
    }
}

+ (BOOL)isOverlayActive {
    return gBlackoutOverlay != nil;
}

#pragma mark - Backlight Control

+ (void)turnOffScreen {
    void (^work)(void) = ^{
        Class backlightClass = NSClassFromString(@"SBBacklightController");
        if (!backlightClass) {
            NSLog(@"[Moody Glow] SBBacklightController not found.");
            return;
        }
        
        id controller = [backlightClass performSelector:@selector(sharedInstance)];
        if (!controller) {
            NSLog(@"[Moody Glow] SBBacklightController sharedInstance nil.");
            return;
        }
        
        SEL sel = NSSelectorFromString(@"turnOffScreen");
        if ([controller respondsToSelector:sel]) {
            [controller performSelector:sel];
            NSLog(@"[Moody Glow] Screen turned off.");
        } else {
            NSLog(@"[Moody Glow] turnOffScreen selector not available.");
        }
    };
    
    if ([NSThread isMainThread]) {
        work();
    } else {
        dispatch_async(dispatch_get_main_queue(), work);
    }
}

@end
