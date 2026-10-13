// Moody Glow - Stage 2: Persistent Glow + Breathing Speed
// Developer: Moody
// Target: iOS 14.0 - 18.7 (RootHide)

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "PrivateHeaders.h"
#import "MoodyGlowNotificationTracker.h"
#import "MoodyGlowPersistentGlow.h"
#import "MoodyGlowColorExtractor.h"
#import "MoodyGlowPrefs.h"

#pragma mark - Glow Refresh Logic

static void moodyGlowRefreshPersistentGlow(NSInteger count, NSArray<NSString *> *bundleIDs) {
    MoodyGlowPrefs *prefs = [MoodyGlowPrefs sharedInstance];
    [prefs reload];
    
    // If tweak disabled → stop
    if (![prefs isEnabled]) {
        NSLog(@"[Moody Glow] Tweak disabled. Stopping glow.");
        [[MoodyGlowPersistentGlow sharedInstance] stopAnimated:YES];
        return;
    }
    
    // If no notifications → stop
    if (count <= 0 || bundleIDs.count == 0) {
        NSLog(@"[Moody Glow] No notifications left. Stopping glow.");
        [[MoodyGlowPersistentGlow sharedInstance] stopAnimated:YES];
        return;
    }
    
    // ---- Apply breathing speed from prefs ----
    CGFloat breathing = [prefs breathingSpeed];
    [[MoodyGlowPersistentGlow sharedInstance] setBreathingSpeed:breathing];
    
    // Determine the color of the first app
    NSString *firstBundle = bundleIDs.firstObject;
    UIColor *color = nil;
    
    if ([prefs colorMode] == MoodyGlowColorModeIcon) {
        color = [MoodyGlowColorExtractor colorForBundleID:firstBundle];
        if (!color) {
            color = [UIColor colorWithRed:0.85 green:0.95 blue:0.10 alpha:1.0];
            NSLog(@"[Moody Glow] Icon color extraction failed for %@, using fallback.", firstBundle);
        }
    } else {
        color = [prefs staticColor];
    }
    
    NSLog(@"[Moody Glow] Refresh glow: count=%ld, apps=%lu, breathing=%.2f, color=%@",
          (long)count, (unsigned long)bundleIDs.count, breathing, color);
    
    [[MoodyGlowPersistentGlow sharedInstance] showWithColor:color animated:YES];
}

// --- iOS 14+ Group ---
%group iOS14Plus

#pragma mark - Main Dispatcher Hook

%hook NCNotificationDispatcher

- (void)postNotificationWithRequest:(NCNotificationRequest *)request {
    if (request) {
        NSLog(@"[MG-HOOK] post: section=%@ id=%@",
              request.sectionIdentifier, request.notificationIdentifier);
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

#pragma mark - SpringBoard Subclass Hook

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

%end // iOS14Plus

// --- Tweak Initialization ---
%ctor {
    NSLog(@"[Moody Glow] ============ TWEAK LOADED (Stage 2 + Breathing Speed) ============");
    %init(iOS14Plus);
    
    // Register the change handler
    [[MoodyGlowNotificationTracker sharedInstance] setChangeHandler:^(NSInteger count, NSArray<NSString *> *bundleIDs) {
        moodyGlowRefreshPersistentGlow(count, bundleIDs);
    }];
    
    // Clean state on load
    [[MoodyGlowNotificationTracker sharedInstance] removeAll];
    
    NSLog(@"[Moody Glow] Persistent glow handler with breathing speed registered.");
}
