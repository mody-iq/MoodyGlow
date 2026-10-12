// Moody Glow - Full Tweak with Blackout
// Developer: Moody
// Target: iOS 14.0 - 18.7 (RootHide)

#import <Foundation/Foundation.h>
#import "PrivateHeaders.h"
#import "MoodyGlowAnimations.h"
#import "MoodyGlowColorExtractor.h"
#import "MoodyGlowPrefs.h"
#import "MoodyGlowBlackout.h"

// --- Helper: Estimate animation duration based on index/repeat/speed ---
static NSTimeInterval moodyGlowEstimatedDuration(NSInteger index, NSInteger repeat, CGFloat speed) {
    if (speed < 0.1) speed = 0.1;
    if (repeat < 1) repeat = 1;
    
    NSTimeInterval base = 1.5;
    switch (index) {
        case 0: base = 3.6; break; // Contrary (autoreverses)
        case 1: base = 1.2; break; // Light Bar
        case 2: base = 0.8; break; // Outline
        case 3: base = 1.5; break; // Particles
        case 4: base = 2.0; break; // Pendulum (autoreverses)
        case 5: base = 1.5; break; // Pulse
        case 6: base = 2.0; break; // Symmetric (autoreverses)
    }
    return (base * repeat) / speed;
}

// --- Test Animation Callback ---
static void moodyGlowTestCallback(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo) {
    dispatch_async(dispatch_get_main_queue(), ^{
        NSLog(@"[Moody Glow] Test animation button pressed.");
        
        MoodyGlowPrefs *prefs = [MoodyGlowPrefs sharedInstance];
        [prefs reload];
        
        UIWindow *window = [MoodyGlowAnimations findBestWindow];
        if (!window) {
            NSLog(@"[Moody Glow] No window for test animation.");
            return;
        }
        
        UIColor *color = [UIColor colorWithRed:0.85 green:0.95 blue:0.10 alpha:1.0];
        if ([prefs colorMode] == MoodyGlowColorModeStatic) {
            color = [prefs staticColor];
        }
        
        [MoodyGlowAnimations playAnimationWithIndex:[prefs selectedAnimationIndex]
                                               color:color
                                              inView:window
                                         repeatCount:[prefs repeatCount]
                                               speed:[prefs speed]];
        
        NSLog(@"[Moody Glow] Test animation played (index=%ld).", (long)[prefs selectedAnimationIndex]);
    });
}

// --- iOS 14+ Notification Capture Group ---
%group iOS14Plus

%hook SBLockScreenNotificationListController

- (void)observer:(id)observer addBulletin:(id)bulletin forFeed:(NSUInteger)feed playLightsAndSirens:(BOOL)lights withReply:(id)reply {

    MoodyGlowPrefs *prefs = [MoodyGlowPrefs sharedInstance];
    [prefs reload];

    if (![prefs isEnabled]) {
        %orig;
        return;
    }

    NSLog(@"[Moody Glow] ===== NEW NOTIFICATION =====");

    NSString *bundleID = nil;
    if ([bulletin respondsToSelector:@selector(notificationRequest)]) {
        NCNotificationRequest *request = [bulletin performSelector:@selector(notificationRequest)];
        if (request) {
            bundleID = request.sectionIdentifier;
            NSLog(@"[Moody Glow] Bundle ID: %@", bundleID);
        }
    }

    // Determine animation color
    UIColor *animColor = nil;
    if ([prefs colorMode] == MoodyGlowColorModeIcon) {
        if (bundleID && bundleID.length > 0) {
            animColor = [MoodyGlowColorExtractor colorForBundleID:bundleID];
        }
        if (!animColor) {
            animColor = [UIColor colorWithRed:0.85 green:0.95 blue:0.10 alpha:1.0];
        }
    } else {
        animColor = [prefs staticColor];
    }

    UIWindow *targetWindow = [MoodyGlowAnimations findBestWindow];
    if (!targetWindow) {
        NSLog(@"[Moody Glow] No window available. Aborting.");
        %orig;
        return;
    }

    BOOL blackoutEnabled = [prefs isBlackoutEnabled];
    BOOL wakeAfter = [prefs wakeScreenAfterBlackout];
    NSInteger animIndex = [prefs selectedAnimationIndex];
    NSInteger repeat = [prefs repeatCount];
    CGFloat speed = [prefs speed];

    // 1) Show blackout overlay BEFORE the animation
    if (blackoutEnabled) {
        [MoodyGlowBlackout showOverlayInWindow:targetWindow];
    }

    // 2) Play the animation
    [MoodyGlowAnimations playAnimationWithIndex:animIndex
                                           color:animColor
                                          inView:targetWindow
                                     repeatCount:repeat
                                           speed:speed];

    NSLog(@"[Moody Glow] Animation played (index=%ld, color=%@).", (long)animIndex, animColor);

    // 3) Schedule blackout cleanup after animation finishes
    if (blackoutEnabled) {
        NSTimeInterval duration = moodyGlowEstimatedDuration(animIndex, repeat, speed);
        NSTimeInterval delay = duration + 0.3;
        
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            if (wakeAfter) {
                // Reveal the lock screen
                [MoodyGlowBlackout removeOverlayAnimated:YES];
            } else {
                // Stay dark: remove overlay then turn off screen
                [MoodyGlowBlackout removeOverlayAnimated:NO];
                [MoodyGlowBlackout turnOffScreen];
            }
        });
    }

    NSLog(@"[Moody Glow] Blackout: %@ | WakeAfter: %@", blackoutEnabled ? @"YES" : @"NO", wakeAfter ? @"YES" : @"NO");
    NSLog(@"[Moody Glow] ===============================");

    %orig;
}

%end

%end // iOS14Plus

// --- Tweak Initialization ---
%ctor {
    NSLog(@"[Moody Glow] Tweak loaded. Initializing...");
    %init(iOS14Plus);
    
    CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(),
                                     NULL,
                                     moodyGlowTestCallback,
                                     CFSTR("com.moody.moodyglow.test"),
                                     NULL,
                                     CFNotificationSuspensionBehaviorDeliverImmediately);
    
    NSLog(@"[Moody Glow] Test listener registered.");
}
