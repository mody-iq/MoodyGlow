// Moody Glow - Tweak.x
// Developer: Moody
// Target: iOS 14.0 - 18.7 (RootHide)
// Features: notification tracking, lock-aware glow, color cycling, glow thickness

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "PrivateHeaders.h"
#import "MoodyGlowNotificationTracker.h"
#import "MoodyGlowPersistentGlow.h"
#import "MoodyGlowColorExtractor.h"
#import "MoodyGlowPrefs.h"
#import "MoodyGlowSystemState.h"

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

#pragma mark - Glow Refresh Logic

static void moodyGlowRefreshPersistentGlow(NSInteger count, NSArray<NSString *> *bundleIDs) {
    MoodyGlowPrefs *prefs = [MoodyGlowPrefs sharedInstance];
    [prefs reload];

    if (![prefs isEnabled]) {
        [[MoodyGlowPersistentGlow sharedInstance] stopAnimated:YES];
        return;
    }

    if (count <= 0 || bundleIDs.count == 0) {
        [[MoodyGlowPersistentGlow sharedInstance] stopAnimated:YES];
        return;
    }

    CGFloat breathing = [prefs breathingSpeed];
    CGFloat draw = [prefs speed];
    CGFloat thickness = [prefs glowThickness];
    [[MoodyGlowPersistentGlow sharedInstance] setBreathingSpeed:breathing];
    [[MoodyGlowPersistentGlow sharedInstance] setDrawSpeed:draw];
    [[MoodyGlowPersistentGlow sharedInstance] setGlowThickness:thickness];

    UIColor *fallback = [UIColor colorWithRed:0.85 green:0.95 blue:0.10 alpha:1.0];

    if ([prefs colorMode] == MoodyGlowColorModeStatic) {
        UIColor *single = [prefs staticColor];
        if (!single) single = fallback;
        [[MoodyGlowPersistentGlow sharedInstance] showWithColors:@[single]
                                                          style:[prefs selectedAnimationIndex]
                                                       animated:YES];
        return;
    }

    if (![prefs isColorCyclingEnabled] || bundleIDs.count == 1) {
        NSString *first = bundleIDs.firstObject;
        UIColor *c = moodyGlowCachedColorForBundle(first);
        if (!c) c = fallback;
        [[MoodyGlowPersistentGlow sharedInstance] showWithColors:@[c]
                                                          style:[prefs selectedAnimationIndex]
                                                       animated:YES];
        return;
    }

    NSMutableArray<UIColor *> *colors = [NSMutableArray arrayWithCapacity:bundleIDs.count];
    for (NSString *bundleID in bundleIDs) {
        UIColor *c = moodyGlowCachedColorForBundle(bundleID);
        [colors addObject:c ? c : fallback];
    }

    NSInteger style = [prefs selectedAnimationIndex];
    NSLog(@"[Moody Glow] Refresh: count=%ld, style=%ld, colors=%lu, thickness=%.1f",
          (long)count, (long)style, (unsigned long)colors.count, thickness);

    [[MoodyGlowPersistentGlow sharedInstance] showWithColors:colors
                                                       style:style
                                                    animated:YES];
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
        NSLog(@"[Moody Glow] Device UNLOCKED. Stopping glow.");
        [[MoodyGlowPersistentGlow sharedInstance] stopAnimated:YES];
        [[MoodyGlowNotificationTracker sharedInstance] removeAll];
    }
}

%end

%end // iOS14Plus

// --- Tweak Initialization ---
%ctor {
    NSLog(@"[Moody Glow] ============ TWEAK LOADED (Dramatic + Thickness) ============");
    %init(iOS14Plus);

    moodyGlowInitColorCacheIfNeeded();

    [[MoodyGlowNotificationTracker sharedInstance] setChangeHandler:^(NSInteger count, NSArray<NSString *> *bundleIDs) {
        moodyGlowRefreshPersistentGlow(count, bundleIDs);
    }];

    [[MoodyGlowNotificationTracker sharedInstance] removeAll];
    NSLog(@"[Moody Glow] Dramatic color transition + thickness handler registered.");
}
