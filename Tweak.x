// Moody Glow - Multi-Style Persistent Glow
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
    
    if (![prefs isEnabled]) {
        [[MoodyGlowPersistentGlow sharedInstance] stopAnimated:YES];
        return;
    }
    
    if (count <= 0 || bundleIDs.count == 0) {
        [[MoodyGlowPersistentGlow sharedInstance] stopAnimated:YES];
        return;
    }
    
    CGFloat breathing = [prefs breathingSpeed];
    [[MoodyGlowPersistentGlow sharedInstance] setBreathingSpeed:breathing];
    
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
    NSLog(@"[Moody Glow] Refresh: count=%ld, style=%ld, color=%@, breathing=%.2f",
          (long)count, (long)style, color, breathing);
    
    [[MoodyGlowPersistentGlow sharedInstance] showWithColor:color
                                                      style:style
                                                   animated:YES];
}

// --- iOS 14+ Group ---
%group iOS14Plus

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

%end // iOS14Plus

// --- Tweak Initialization ---
%ctor {
    NSLog(@"[Moody Glow] ============ TWEAK LOADED (Multi-Style) ============");
    %init(iOS14Plus);
    
    [[MoodyGlowNotificationTracker sharedInstance] setChangeHandler:^(NSInteger count, NSArray<NSString *> *bundleIDs) {
        moodyGlowRefreshPersistentGlow(count, bundleIDs);
    }];
    
    [[MoodyGlowNotificationTracker sharedInstance] removeAll];
    NSLog(@"[Moody Glow] Multi-style handler registered.");
}
