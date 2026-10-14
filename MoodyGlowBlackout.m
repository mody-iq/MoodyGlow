// Moody Glow - Blackout Manager Implementation
// Developer: Moody
// Purpose: Manage black overlay + screen wake/sleep for Blackout feature

#import "MoodyGlowBlackout.h"
#import "MoodyGlowLog.h"
#import <objc/runtime.h>

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
        
        MGLog(@"[Moody Glow] Blackout overlay shown.");
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
        
        MGLog(@"[Moody Glow] Blackout overlay removed (animated=%d)", animated);
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
            MGLog(@"[Moody Glow] SBBacklightController not found.");
            return;
        }
        
        id controller = [backlightClass performSelector:@selector(sharedInstance)];
        if (!controller) {
            MGLog(@"[Moody Glow] SBBacklightController sharedInstance nil.");
            return;
        }
        
        SEL sel = NSSelectorFromString(@"turnOffScreen");
        if (![controller respondsToSelector:sel]) {
            MGLog(@"[Moody Glow] turnOffScreen selector not available.");
            return;
        }
        
        // Use IMP (function pointer) to avoid ARC performSelector warning
        IMP imp = [controller methodForSelector:sel];
        if (!imp) {
            MGLog(@"[Moody Glow] Could not obtain IMP for turnOffScreen.");
            return;
        }
        
        void (*func)(id, SEL) = (void *)imp;
        func(controller, sel);
        
        MGLog(@"[Moody Glow] Screen turned off.");
    };
    
    if ([NSThread isMainThread]) {
        work();
    } else {
        dispatch_async(dispatch_get_main_queue(), work);
    }
}

@end
