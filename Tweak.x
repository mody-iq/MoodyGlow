// Moody Glow - Lock State Awareness
// Developer: Moody
// Target: iOS 14.0 - 18.7 (RootHide)

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "PrivateHeaders.h"
#import "MoodyGlowNotificationTracker.h"
#import "MoodyGlowPersistentGlow.h"
#import "MoodyGlowColorExtractor.h"
#import "MoodyGlowPrefs.h"
#import "MoodyGlowSystemState.h"

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
    [[MoodyGlowPersistentGlow sharedInstance] setBreathingSpeed:breathing];
    [[MoodyGlowPersistentGlow sharedInstance] setDrawSpeed:draw];
    
    NSString *firstBundle = bundleIDs.firstObject;
    UIColor *color = nil;
    if ([prefs colorMode] == MoodyGlowColorModeIcon) {
        color = [MoodyGlowColorExtractor colorForBundleID:firstBundle];
        if (!color) {
            color = [UIColor colorWithRed:0.85 green:0.95 blue:0.10 alpha:1.0];
        }
    } else {
        color = [prefs staticColor];
    }
    
    NSInteger style = [prefs selectedAnimationIndex];
    BOOL locked = [MoodyGlowSystemState isDeviceLocked];
    NSLog(@"[Moody Glow] Refresh: count=%ld, style=%ld, locked=%d, color=%@",
          (long)count, (long)style, locked, color);
    
    [[MoodyGlowPersistentGlow sharedInstance] showWithColor:color
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
    
    BOOL wasLocked = [MoodyGlowSystemState isDeviceLocked];
    NSLog(@"[Moody Glow] _setUILocked called: locked=%d (wasLocked=%d)", locked, wasLocked);
    
    // If device just got UNLOCKED (locked == NO), stop glow immediately
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
    NSLog(@"[Moody Glow] ============ TWEAK LOADED (Lock Aware) ============");
    %init(iOS14Plus);
    
    [[MoodyGlowNotificationTracker sharedInstance] setChangeHandler:^(NSInteger count, NSArray<NSString *> *bundleIDs) {
        moodyGlowRefreshPersistentGlow(count, bundleIDs);
    }];
    
    [[MoodyGlowNotificationTracker sharedInstance] removeAll];
    NSLog(@"[Moody Glow] Lock-aware handler registered.");
}
