// Moody Glow - Tweak.x
// Developer: Moody
// Target: iOS 14.0 - 18.7 (RootHide)
// Features: filters, blackout, wake screen, color cycling, custom colors

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "PrivateHeaders.h"
#import "MoodyGlowNotificationTracker.h"
#import "MoodyGlowPersistentGlow.h"
#import "MoodyGlowColorExtractor.h"
#import "MoodyGlowPrefs.h"
#import "MoodyGlowSystemState.h"
#import "MoodyGlowCustomColors.h"
#import "MoodyGlowBlackout.h"
#import "MoodyGlowLog.h"

#pragma mark - Color Cache

static NSMutableDictionary<NSString *, UIColor *> *gColorCache = nil;
static dispatch_queue_t gColorCacheQueue = nil;

static void moodyGlowInitColorCacheIfNeeded(void) {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        gColorCache = [NSMutableDictionary dictionary];
        gColorCacheQueue = dispatch_queue_create("com.moody.moodyglow.colorcache", DISPATCH_QUEUE_SERIAL);
    });
}

static UIColor *moodyGlowCachedColorForBundle(NSString *bundleID) {
    if (!bundleID || bundleID.length == 0) return nil;

    UIColor *custom = [MoodyGlowCustomColors customColorForBundleID:bundleID];
    if (custom) return custom;

    moodyGlowInitColorCacheIfNeeded();

    __block UIColor *cached = nil;
    dispatch_sync(gColorCacheQueue, ^{
        cached = gColorCache[bundleID];
    });
    if (cached) return cached;

    UIColor *fetched = [MoodyGlowColorExtractor colorForBundleID:bundleID];
    if (fetched) {
        dispatch_async(gColorCacheQueue, ^{
            gColorCache[bundleID] = fetched;
        });
    }
    return fetched;
}

#pragma mark - Blackout Helper

static UIWindow *moodyGlowLockScreenWindow(void) {
    Class lockCls = NSClassFromString(@"SBCoverSheetWindow");
    if (!lockCls) return nil;
    for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
        if (![scene isKindOfClass:[UIWindowScene class]]) continue;
        UIWindowScene *ws = (UIWindowScene *)scene;
        for (UIWindow *w in ws.windows) {
            if ([w isKindOfClass:lockCls] && !w.hidden && w.alpha > 0.01) {
                return w;
            }
        }
    }
    return nil;
}

#pragma mark - Glow Refresh Logic

static void moodyGlowRefreshPersistentGlow(NSInteger count, NSArray<NSString *> *bundleIDs) {
    MoodyGlowPrefs *prefs = [MoodyGlowPrefs sharedInstance];
    [prefs reload];

    if (![prefs isEnabled]) {
        [[MoodyGlowPersistentGlow sharedInstance] stopAnimated:YES];
        [MoodyGlowBlackout removeOverlayAnimated:NO];
        return;
    }

    if (count <= 0 || bundleIDs.count == 0) {
        [[MoodyGlowPersistentGlow sharedInstance] stopAnimated:YES];
        return;
    }

    BOOL locked = [MoodyGlowSystemState isDeviceLocked];

    // Lock state filtering
    if (locked) {
        if (![prefs isLockscreenEnabled]) {
            [[MoodyGlowPersistentGlow sharedInstance] stopAnimated:YES];
            return;
        }
    } else {
        if (![prefs isUniversalEnabled]) {
            [[MoodyGlowPersistentGlow sharedInstance] stopAnimated:YES];
            return;
        }
        if (![prefs showInActiveApp]) {
            [[MoodyGlowPersistentGlow sharedInstance] stopAnimated:YES];
            return;
        }
    }

    // DND filtering
    if (![prefs showInDND] && [MoodyGlowSystemState isDNDActive]) {
        [[MoodyGlowPersistentGlow sharedInstance] stopAnimated:YES];
        return;
    }

    // Speeds & thickness
    CGFloat breathing = [prefs breathingSpeed];
    CGFloat draw = [prefs speed];
    CGFloat thickness = [prefs glowThickness];
    [[MoodyGlowPersistentGlow sharedInstance] setBreathingSpeed:breathing];
    [[MoodyGlowPersistentGlow sharedInstance] setDrawSpeed:draw];
    [[MoodyGlowPersistentGlow sharedInstance] setGlowThickness:thickness];

    UIColor *fallback = [UIColor colorWithRed:0.85 green:0.95 blue:0.10 alpha:1.0];

    // Compute colors array
    NSMutableArray<UIColor *> *colors = [NSMutableArray array];
    if ([prefs colorMode] == MoodyGlowColorModeStatic) {
        UIColor *single = [prefs staticColor] ?: fallback;
        [colors addObject:single];
    } else if (![prefs isColorCyclingEnabled] || bundleIDs.count == 1) {
        UIColor *c = moodyGlowCachedColorForBundle(bundleIDs.firstObject) ?: fallback;
        [colors addObject:c];
    } else {
        for (NSString *bundleID in bundleIDs) {
            UIColor *c = moodyGlowCachedColorForBundle(bundleID) ?: fallback;
            [colors addObject:c];
        }
    }

    // ---- Blackout (only when locked) ----
    BOOL blackoutEnabled = [prefs isBlackoutEnabled];
    BOOL wakeAfter = [prefs wakeScreenAfterBlackout];
    UIWindow *lockWindow = nil;

    if (blackoutEnabled && locked) {
        lockWindow = moodyGlowLockScreenWindow();
        if (lockWindow) {
            [MoodyGlowBlackout showOverlayInWindow:lockWindow];
        }
    }

    // Show the persistent glow
    [[MoodyGlowPersistentGlow sharedInstance] showWithColors:colors
                                                       style:[prefs selectedAnimationIndex]
                                                    animated:YES];

    MGLog(@"[Moody Glow] Refresh: count=%ld, locked=%d, blackout=%d, wake=%d",
          (long)count, locked, blackoutEnabled, wakeAfter);

    // ---- Schedule blackout cleanup ----
    if (blackoutEnabled && locked) {
        NSTimeInterval delay = 4.0; // showcase duration
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{
            if (wakeAfter) {
                [MoodyGlowBlackout removeOverlayAnimated:YES];
            } else {
                [MoodyGlowBlackout removeOverlayAnimated:NO];
                [MoodyGlowBlackout turnOffScreen];
            }
        });
    }
}

#pragma mark - Test Animation Callback

static void moodyGlowTestCallback(CFNotificationCenterRef center,
                                   void *observer,
                                   CFStringRef name,
                                   const void *object,
                                   CFDictionaryRef userInfo) {
    dispatch_async(dispatch_get_main_queue(), ^{
        MGLog(@"[Moody Glow] Test button pressed");

        MoodyGlowPrefs *prefs = [MoodyGlowPrefs sharedInstance];
        [prefs reload];

        if (![prefs isEnabled]) {
            MGLog(@"[Moody Glow] Tweak disabled - test ignored");
            return;
        }

        // Determine color
        UIColor *color = nil;
        if ([prefs colorMode] == MoodyGlowColorModeStatic) {
            color = [prefs staticColor];
        }
        if (!color) {
            color = [UIColor colorWithRed:0.85 green:0.95 blue:0.10 alpha:1.0];
        }

        // Apply current speeds & thickness
        [[MoodyGlowPersistentGlow sharedInstance] setBreathingSpeed:[prefs breathingSpeed]];
        [[MoodyGlowPersistentGlow sharedInstance] setDrawSpeed:[prefs speed]];
        [[MoodyGlowPersistentGlow sharedInstance] setGlowThickness:[prefs glowThickness]];

        // Show the glow with the selected style
        [[MoodyGlowPersistentGlow sharedInstance] showWithColors:@[color]
                                                          style:[prefs selectedAnimationIndex]
                                                       animated:YES];

        MGLog(@"[Moody Glow] Test animation started (style=%ld)",
              (long)[prefs selectedAnimationIndex]);

        // Auto-stop after 4 seconds (test only)
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(4.0 * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{
            [[MoodyGlowPersistentGlow sharedInstance] stopAnimated:YES];
            MGLog(@"[Moody Glow] Test animation stopped");
        });
    });
}

// --- iOS 14+ Group ---
%group iOS14Plus

#pragma mark - Notification Hooks

%hook NCNotificationDispatcher

- (void)postNotificationWithRequest:(NCNotificationRequest *)request {
    if (request) {
        [[MoodyGlowNotificationTracker sharedInstance]
         addNotificationWithID:request.notificationIdentifier
                      bundleID:request.sectionIdentifier];
    }
    %orig;
}

- (void)_didRemoveNotificationRequest:(NCNotificationRequest *)request {
    if (request) {
        [[MoodyGlowNotificationTracker sharedInstance]
         removeNotificationWithID:request.notificationIdentifier];
    }
    %orig;
}

- (void)withdrawNotificationWithRequest:(NCNotificationRequest *)request {
    if (request) {
        [[MoodyGlowNotificationTracker sharedInstance]
         removeNotificationWithID:request.notificationIdentifier];
    }
    %orig;
}

- (void)_clearUnsafeNotification:(NCNotificationRequest *)request {
    if (request) {
        [[MoodyGlowNotificationTracker sharedInstance]
         removeNotificationWithID:request.notificationIdentifier];
    }
    %orig;
}

%end

%hook SBNCNotificationDispatcher

- (void)postNotificationWithRequest:(NCNotificationRequest *)request {
    if (request) {
        [[MoodyGlowNotificationTracker sharedInstance]
         addNotificationWithID:request.notificationIdentifier
                      bundleID:request.sectionIdentifier];
    }
    %orig;
}

- (void)_didRemoveNotificationRequest:(NCNotificationRequest *)request {
    if (request) {
        [[MoodyGlowNotificationTracker sharedInstance]
         removeNotificationWithID:request.notificationIdentifier];
    }
    %orig;
}

%end

#pragma mark - Lock State Hook

%hook SBLockScreenManager

- (void)_setUILocked:(BOOL)locked {
    %orig;

    if (!locked) {
        MGLog(@"[Moody Glow] Device UNLOCKED. Stopping glow + blackout.");
        [[MoodyGlowPersistentGlow sharedInstance] stopAnimated:YES];
        [MoodyGlowBlackout removeOverlayAnimated:NO];
        [[MoodyGlowNotificationTracker sharedInstance] removeAll];
    }
}

%end

%end // iOS14Plus

// --- Tweak Initialization ---
%ctor {
    MGLog(@"[Moody Glow] ============ TWEAK LOADED (Blackout Active) ============");
    %init(iOS14Plus);

    moodyGlowInitColorCacheIfNeeded();

    [[MoodyGlowNotificationTracker sharedInstance] setChangeHandler:^(NSInteger count, NSArray<NSString *> *bundleIDs) {
        moodyGlowRefreshPersistentGlow(count, bundleIDs);
    }];

    [[MoodyGlowNotificationTracker sharedInstance] removeAll];

    // Register test-animation notification observer
    CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(),
                                     NULL,
                                     moodyGlowTestCallback,
                                     CFSTR("com.moody.moodyglow.test"),
                                     NULL,
                                     CFNotificationSuspensionBehaviorDeliverImmediately);

    MGLog(@"[Moody Glow] Blackout + Wake + Test handlers registered.");
}
