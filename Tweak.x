// Moody Glow - Full Tweak with State Logic
// Developer: Moody
// Target: iOS 14.0 - 18.7 (RootHide)

#import <Foundation/Foundation.h>
#import "PrivateHeaders.h"
#import "MoodyGlowAnimations.h"
#import "MoodyGlowColorExtractor.h"
#import "MoodyGlowPrefs.h"
#import "MoodyGlowBlackout.h"
#import "MoodyGlowSystemState.h"

// --- Helper: Estimate animation duration ---
static NSTimeInterval moodyGlowEstimatedDuration(NSInteger index, NSInteger repeat, CGFloat speed) {
    if (speed < 0.1) speed = 0.1;
    if (repeat < 1) repeat = 1;
    
    NSTimeInterval base = 1.5;
    switch (index) {
        case 0: base = 3.6; break;
        case 1: base = 1.2; break;
        case 2: base = 0.8; break;
        case 3: base = 1.5; break;
        case 4: base = 2.0; break;
        case 5: base = 1.5; break;
        case 6: base = 2.0; break;
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

    // ---- 1. Global enabled check ----
    if (![prefs isEnabled]) {
        NSLog(@"[Moody Glow] Skipping: tweak disabled.");
        %orig;
        return;
    }

    // ---- 2. DND check ----
    if (![prefs showInDND] && [MoodyGlowSystemState isDNDActive]) {
        NSLog(@"[Moody Glow] Skipping: DND active and ShowInDND=NO.");
        %orig;
        return;
    }

    // ---- 3. Lock state + Universal / Lockscreen / Active App logic ----
    BOOL locked = [MoodyGlowSystemState isDeviceLocked];
    if (locked) {
        if (![prefs isLockscreenEnabled]) {
            NSLog(@"[Moody Glow] Skipping: Lockscreen disabled.");
            %orig;
            return;
        }
    } else {
        // Device is unlocked (active app or home screen)
        if (![prefs isUniversalEnabled]) {
            NSLog(@"[Moody Glow] Skipping: Universal disabled and not on lockscreen.");
            %orig;
            return;
        }
        if (![prefs showInActiveApp]) {
            NSLog(@"[Moody Glow] Skipping: ShowInActiveApp disabled.");
            %orig;
            return;
        }
    }

    NSLog(@"[Moody Glow] ===== NEW NOTIFICATION (locked=%d) =====", locked);

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

    // Show blackout overlay (only meaningful on lockscreen)
    if (blackoutEnabled && locked) {
        [MoodyGlowBlackout showOverlayInWindow:targetWindow];
    }

    // Play the animation
    [MoodyGlowAnimations playAnimationWithIndex:animIndex
                                           color:animColor
                                          inView:targetWindow
                                     repeatCount:repeat
                                           speed:speed];

    NSLog(@"[Moody Glow] Animation played (index=%ld, color=%@).", (long)animIndex, animColor);

    // Schedule blackout cleanup
    if (blackoutEnabled && locked) {
        NSTimeInterval duration = moodyGlowEstimatedDuration(animIndex, repeat, speed);
        NSTimeInterval delay = duration + 0.3;
        
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            if (wakeAfter) {
                [MoodyGlowBlackout removeOverlayAnimated:YES];
            } else {
                [MoodyGlowBlackout removeOverlayAnimated:NO];
                [MoodyGlowBlackout turnOffScreen];
            }
        });
    }

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
