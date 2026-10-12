// Moody Glow - Full Tweak with Broad Notification Hooks (Debug Mode)
// Developer: Moody
// Target: iOS 14.0 - 18.7 (RootHide)
// Stage 1.5: Hunting for correct notification hook on iOS 18

#import <Foundation/Foundation.h>
#import "PrivateHeaders.h"
#import "MoodyGlowNotificationTracker.h"

// --- iOS 14+ Group ---
%group iOS14Plus

#pragma mark - Hook 1: SBLockScreenNotificationListController (various method names)

%hook SBLockScreenNotificationListController

- (void)observer:(id)observer addBulletin:(id)bulletin forFeed:(NSUInteger)feed playLightsAndSirens:(BOOL)lights withReply:(id)reply {
    NSLog(@"[MG-H1] addBulletin (old) called: %@", bulletin);
    NCNotificationRequest *req = nil;
    if ([bulletin respondsToSelector:@selector(notificationRequest)]) {
        req = [bulletin performSelector:@selector(notificationRequest)];
        NSLog(@"[MG-H1] req=%@ bundle=%@ id=%@", req, req.sectionIdentifier, req.notificationIdentifier);
        [[MoodyGlowNotificationTracker sharedInstance]
         addNotificationWithID:req.notificationIdentifier bundleID:req.sectionIdentifier];
    }
    %orig;
}

- (void)observer:(id)observer addBulletin:(id)bulletin forFeed:(NSUInteger)feed {
    NSLog(@"[MG-H2] addBulletin (new) called: %@", bulletin);
    NCNotificationRequest *req = nil;
    if ([bulletin respondsToSelector:@selector(notificationRequest)]) {
        req = [bulletin performSelector:@selector(notificationRequest)];
        NSLog(@"[MG-H2] req=%@ bundle=%@ id=%@", req, req.sectionIdentifier, req.notificationIdentifier);
        [[MoodyGlowNotificationTracker sharedInstance]
         addNotificationWithID:req.notificationIdentifier bundleID:req.sectionIdentifier];
    }
    %orig;
}

- (void)observer:(id)observer removeBulletin:(id)bulletin forFeed:(NSUInteger)feed {
    NSLog(@"[MG-H3] removeBulletin called: %@", bulletin);
    NCNotificationRequest *req = nil;
    if ([bulletin respondsToSelector:@selector(notificationRequest)]) {
        req = [bulletin performSelector:@selector(notificationRequest)];
        if (req) {
            [[MoodyGlowNotificationTracker sharedInstance]
             removeNotificationWithID:req.notificationIdentifier];
        }
    }
    %orig;
}

%end

#pragma mark - Hook 2: NCNotificationDispatcher (all known methods)

%hook NCNotificationDispatcher

- (void)postNotificationRequest:(NCNotificationRequest *)request {
    NSLog(@"[MG-H4] Dispatcher post: %@", request);
    [[MoodyGlowNotificationTracker sharedInstance]
     addNotificationWithID:request.notificationIdentifier bundleID:request.sectionIdentifier];
    %orig;
}

- (void)postNotificationRequest:(NCNotificationRequest *)request completion:(void (^)(BOOL))completion {
    NSLog(@"[MG-H5] Dispatcher post+completion: %@", request);
    [[MoodyGlowNotificationTracker sharedInstance]
     addNotificationWithID:request.notificationIdentifier bundleID:request.sectionIdentifier];
    %orig;
}

- (void)_didReceiveNotificationRequest:(NCNotificationRequest *)request {
    NSLog(@"[MG-H6] Dispatcher _didReceive: %@", request);
    [[MoodyGlowNotificationTracker sharedInstance]
     addNotificationWithID:request.notificationIdentifier bundleID:request.sectionIdentifier];
    %orig;
}

- (void)_postNotificationRequest:(NCNotificationRequest *)request {
    NSLog(@"[MG-H7] Dispatcher _post: %@", request);
    [[MoodyGlowNotificationTracker sharedInstance]
     addNotificationWithID:request.notificationIdentifier bundleID:request.sectionIdentifier];
    %orig;
}

%end

#pragma mark - Hook 3: NCNotificationRequest init (see every new request)

%hook NCNotificationRequest

- (instancetype)initWithNotificationRequest:(id)request {
    id result = %orig;
    NSLog(@"[MG-H8] NCNotificationRequest init: %@", result);
    return result;
}

%end

#pragma mark - Hook 4: SBNotificationCenterController (fallback)

%hook SBNotificationCenterController

- (void)addNotificationRequest:(NCNotificationRequest *)request {
    NSLog(@"[MG-H9] NC Controller add: %@", request);
    [[MoodyGlowNotificationTracker sharedInstance]
     addNotificationWithID:request.notificationIdentifier bundleID:request.sectionIdentifier];
    %orig;
}

%end

%end // iOS14Plus

// --- Tweak Initialization ---
%ctor {
    NSLog(@"[Moody Glow] ============ TWEAK LOADED (DEBUG MODE) ============");
    %init(iOS14Plus);
    
    [[MoodyGlowNotificationTracker sharedInstance] removeAll];
    NSLog(@"[Moody Glow] All notification hooks registered.");
}
