// Moody Glow - Full Tweak with Notification Tracking
// Developer: Moody
// Target: iOS 14.0 - 18.7 (RootHide)
// Stage 1: Track notifications only (visuals unchanged)

#import <Foundation/Foundation.h>
#import "PrivateHeaders.h"
#import "MoodyGlowAnimations.h"
#import "MoodyGlowColorExtractor.h"
#import "MoodyGlowPrefs.h"
#import "MoodyGlowBlackout.h"
#import "MoodyGlowSystemState.h"
#import "MoodyGlowNotificationTracker.h"

#pragma mark - Deduplication Helpers

static NSMutableSet *gRecentHandledIDs = nil;
static dispatch_queue_t gRecentHandledQueue = nil;

static void moodyGlowInitDedupIfNeeded(void) {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        gRecentHandledIDs = [NSMutableSet set];
        gRecentHandledQueue = dispatch_queue_create("com.moody.moodyglow.dedup", DISPATCH_QUEUE_SERIAL);
    });
}

static void moodyGlowMarkHandled(NSString *identifier) {
    if (!identifier || identifier.length == 0) return;
    moodyGlowInitDedupIfNeeded();
    dispatch_async(gRecentHandledQueue, ^{
        [gRecentHandledIDs addObject:identifier];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), gRecentHandledQueue, ^{
            [gRecentHandledIDs removeObject:identifier];
        });
    });
}

static BOOL moodyGlowWasRecentlyHandled(NSString *identifier) {
    if (!identifier || identifier.length == 0) return NO;
    moodyGlowInitDedupIfNeeded();
    __block BOOL result = NO;
    dispatch_sync(gRecentHandledQueue, ^{
        result = [gRecentHandledIDs containsObject:identifier];
    });
    return result;
}

#pragma mark - Duration Helper

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

#pragma mark - Core Handler

static void moodyGlowHandleNotification(NCNotificationRequest *request, BOOL fromLockScreen) {
    if (!request) return;
    
    // ---- Always update the tracker FIRST ----
    [[MoodyGlowNotificationTracker sharedInstance]
     addNotificationWithID:request.notificationIdentifier
                  bundleID:request.sectionIdentifier];
    
    MoodyGlowPrefs *prefs = [MoodyGlowPrefs sharedInstance];
    [prefs reload];
    
    if (![prefs isEnabled]) {
        NSLog(@"[Moody Glow] Tweak disabled. Skipping visual.");
        return;
    }
    
    NSString *notifID = request.notificationIdentifier;
    if (moodyGlowWasRecentlyHandled(notifID)) {
        NSLog(@"[Moody Glow] Skipping visual: duplicate (id=%@)", notifID);
        return;
    }
    moodyGlowMarkHandled(notifID);
    
    if (![prefs showInDND] && [MoodyGlowSystemState isDNDActive]) {
        NSLog(@"[Moody Glow] Skipping visual: DND active.");
        return;
    }
    
    BOOL locked = [MoodyGlowSystemState isDeviceLocked];
    
    if (locked) {
        if (![prefs isLockscreenEnabled]) {
            NSLog(@"[Moody Glow] Skipping visual: Lockscreen disabled.");
            return;
        }
    } else {
        if (![prefs isUniversalEnabled]) {
            NSLog(@"[Moody Glow] Skipping visual: Universal disabled.");
            return;
        }
        if (![prefs showInActiveApp]) {
            NSLog(@"[Moody Glow] Skipping visual: ShowInActiveApp disabled.");
            return;
        }
    }
    
    NSString *bundleID = request.sectionIdentifier;
    
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
        NSLog(@"[Moody Glow] No window available. Aborting visual.");
        return;
    }
    
    BOOL blackoutEnabled = [prefs isBlackoutEnabled];
    BOOL wakeAfter = [prefs wakeScreenAfterBlackout];
    NSInteger animIndex = [prefs selectedAnimationIndex];
    NSInteger repeat = [prefs repeatCount];
    CGFloat speed = [prefs speed];
    
    if (blackoutEnabled && locked) {
        [MoodyGlowBlackout showOverlayInWindow:targetWindow];
    }
    
    [MoodyGlowAnimations playAnimationWithIndex:animIndex
                                           color:animColor
                                          inView:targetWindow
                                     repeatCount:repeat
                                           speed:speed];
    
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
}

#pragma mark - Test Animation Callback

static void moodyGlowTestCallback(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo) {
    dispatch_async(dispatch_get_main_queue(), ^{
        NSLog(@"[Moody Glow] Test animation button pressed.");
        MoodyGlowPrefs *prefs = [MoodyGlowPrefs sharedInstance];
        [prefs reload];
        
        UIWindow *window = [MoodyGlowAnimations findBestWindow];
        if (!window) return;
        
        UIColor *color = [UIColor colorWithRed:0.85 green:0.95 blue:0.10 alpha:1.0];
        if ([prefs colorMode] == MoodyGlowColorModeStatic) {
            color = [prefs staticColor];
        }
        
        [MoodyGlowAnimations playAnimationWithIndex:[prefs selectedAnimationIndex]
                                               color:color
                                              inView:window
                                         repeatCount:[prefs repeatCount]
                                               speed:[prefs speed]];
    });
}

// --- iOS 14+ Notification Capture Group ---
%group iOS14Plus

%hook SBLockScreenNotificationListController

- (void)observer:(id)observer addBulletin:(id)bulletin forFeed:(NSUInteger)feed playLightsAndSirens:(BOOL)lights withReply:(id)reply {
    NCNotificationRequest *request = nil;
    if ([bulletin respondsToSelector:@selector(notificationRequest)]) {
        request = [bulletin performSelector:@selector(notificationRequest)];
    }
    moodyGlowHandleNotification(request, YES);
    %orig;
}

- (void)observer:(id)observer removeBulletin:(id)bulletin forFeed:(NSUInteger)feed {
    NCNotificationRequest *request = nil;
    if ([bulletin respondsToSelector:@selector(notificationRequest)]) {
        request = [bulletin performSelector:@selector(notificationRequest)];
    }
    if (request) {
        [[MoodyGlowNotificationTracker sharedInstance]
         removeNotificationWithID:request.notificationIdentifier];
    }
    %orig;
}

%end

%hook NCNotificationDispatcher

- (void)postNotificationRequest:(NCNotificationRequest *)request {
    moodyGlowHandleNotification(request, NO);
    %orig;
}

- (void)postNotificationRequest:(NCNotificationRequest *)request completion:(void (^)(BOOL))completion {
    moodyGlowHandleNotification(request, NO);
    %orig;
}

%end

%end // iOS14Plus

// --- Tweak Initialization ---
%ctor {
    NSLog(@"[Moody Glow] ============ TWEAK LOADED ============");
    %init(iOS14Plus);
    
    // Force tracker initialization so log file is created immediately
    [[MoodyGlowNotificationTracker sharedInstance] removeAll];
    
    CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(),
                                     NULL,
                                     moodyGlowTestCallback,
                                     CFSTR("com.moody.moodyglow.test"),
                                     NULL,
                                     CFNotificationSuspensionBehaviorDeliverImmediately);
}
