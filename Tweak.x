// Moody Glow - Stage 1.6: Correct Hooks for iOS 18.7
// Developer: Moody
// Target: iOS 14.0 - 18.7 (RootHide)
// Uses the correct NCNotificationDispatcher methods discovered via diagnostics

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "PrivateHeaders.h"
#import "MoodyGlowNotificationTracker.h"

// --- iOS 14+ Notification Capture Group ---
%group iOS14Plus

#pragma mark - Main Dispatcher Hook

%hook NCNotificationDispatcher

- (void)postNotificationWithRequest:(NCNotificationRequest *)request {
    if (request) {
        NSLog(@"[MG-HOOK] postNotificationWithRequest: section=%@ id=%@",
              request.sectionIdentifier, request.notificationIdentifier);
        [[MoodyGlowNotificationTracker sharedInstance]
         addNotificationWithID:request.notificationIdentifier
                      bundleID:request.sectionIdentifier];
    }
    %orig;
}

- (void)_didRemoveNotificationRequest:(NCNotificationRequest *)request {
    if (request) {
        NSLog(@"[MG-HOOK] _didRemoveNotificationRequest: id=%@", request.notificationIdentifier);
        [[MoodyGlowNotificationTracker sharedInstance]
         removeNotificationWithID:request.notificationIdentifier];
    }
    %orig;
}

- (void)withdrawNotificationWithRequest:(NCNotificationRequest *)request {
    if (request) {
        NSLog(@"[MG-HOOK] withdrawNotificationWithRequest: id=%@", request.notificationIdentifier);
        [[MoodyGlowNotificationTracker sharedInstance]
         removeNotificationWithID:request.notificationIdentifier];
    }
    %orig;
}

- (void)_clearUnsafeNotification:(NCNotificationRequest *)request {
    if (request) {
        NSLog(@"[MG-HOOK] _clearUnsafeNotification: id=%@", request.notificationIdentifier);
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
        NSLog(@"[MG-HOOK-SB] postNotificationWithRequest: section=%@ id=%@",
              request.sectionIdentifier, request.notificationIdentifier);
        [[MoodyGlowNotificationTracker sharedInstance]
         addNotificationWithID:request.notificationIdentifier
                      bundleID:request.sectionIdentifier];
    }
    %orig;
}

- (void)_didRemoveNotificationRequest:(NCNotificationRequest *)request {
    if (request) {
        NSLog(@"[MG-HOOK-SB] _didRemoveNotificationRequest: id=%@", request.notificationIdentifier);
        [[MoodyGlowNotificationTracker sharedInstance]
         removeNotificationWithID:request.notificationIdentifier];
    }
    %orig;
}

%end

%end // iOS14Plus

// --- Tweak Initialization ---
%ctor {
    NSLog(@"[Moody Glow] ============ TWEAK LOADED (v1.6) ============");
    %init(iOS14Plus);
    
    [[MoodyGlowNotificationTracker sharedInstance] removeAll];
    NSLog(@"[Moody Glow] Hooks registered on NCNotificationDispatcher and SBNCNotificationDispatcher.");
}
