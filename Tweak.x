// Moody Glow - Full Tweak with Banners + Lock Screen
// Developer: Moody
// Target: iOS 14.0 - 18.7 (RootHide)

#import <Foundation/Foundation.h>
#import "PrivateHeaders.h"
#import "MoodyGlowAnimations.h"
#import "MoodyGlowColorExtractor.h"
#import "MoodyGlowPrefs.h"
#import "MoodyGlowBlackout.h"
#import "MoodyGlowSystemState.h"

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
    
    MoodyGlowPrefs *prefs = [MoodyGlowPrefs sharedInstance];
    [prefs reload];
    
    // ---- 1. Global enabled check ----
    if (![prefs isEnabled]) {
        NSLog(@"[Moody Glow] Skipping: tweak disabled.");
        return;
    }
    
    // ---- 2. Deduplication ----
    NSString *notifID = request.notificationIdentifier;
    if (moodyGlowWasRecentlyHandled(notifID)) {
        NSLog(@"[Moody Glow] Skipping: duplicate (id=%@)", notifID);
        return;
    }
    moodyGlowMarkHandled(notifID);
    
    // ---- 3. DND check ----
    if (![prefs showInDND] && [MoodyGlowSystemState isDNDActive]) {
        NSLog(@"[Moody Glow] Skipping: DND active and ShowInDND=NO.");
        return;
    }
    
    // ---- 4. Lock state logic ----
    BOOL locked = [MoodyGlowSystemState isDeviceLocked];
    
    if (locked) {
        if (![prefs isLockscreenEnabled]) {
            NSLog(@"[Moody Glow] Skipping: Lockscreen disabled.");
            return;
        }
    } else {
        if (![prefs isUniversalEnabled]) {
            NSLog(@"[Moody Glow] Skipping: Universal disabled and not on lockscreen.");
            return;
        }
        if (![prefs showInActiveApp]) {
            NSLog(@"[Moody Glow] Skipping: ShowInActiveApp disabled.");
            return;
        }
    }
    
    NSLog(@"[Moody Glow] ===== HANDLING NOTIFICATION (locked=%d, fromLockScreen=%d) =====", locked, fromLockScreen);
    
    NSString *bundleID = request.sectionIdentifier;
    NSLog(@"[Moody Glow] Bundle ID: %@", bundleID);
    
    // ---- 5. Determine color ----
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
    
    // ---- 6. Find window ----
    UIWindow *targetWindow = [MoodyGlowAnimations findBestWindow];
    if (!targetWindow) {
        NSLog(@"[Moody Glow] No window available. Aborting.");
        return;
    }
    
    BOOL blackoutEnabled = [prefs isBlackoutEnabled];
    BOOL wakeAfter = [prefs wakeScreenAfterBlackout];
    NSInteger animIndex = [prefs selectedAnimationIndex];
    NSInteger repeat = [prefs repeatCount];
    CGFloat speed = [prefs speed];
    
    // ---- 7. Blackout (only on lock screen) ----
    if (blackoutEnabled && locked) {
        [MoodyGlowBlackout showOverlayInWindow:targetWindow];
    }
    
    // ---- 8. Play animation ----
    [MoodyGlowAnimations playAnimationWithIndex:animIndex
                                           color:animColor
                                          inView:targetWindow
                                     repeatCount:repeat
                                           speed:speed];
    
    NSLog(@"[Moody Glow] Animation played (index=%ld, color=%@).", (long)animIndex, animColor);
    
    // ---- 9. Schedule blackout cleanup ----
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
}

#pragma mark - Test Animation Callback

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

#pragma mark - Lock Screen Hook

%hook SBLockScreenNotificationListController

- (void)observer:(id)observer addBulletin:(id)bulletin forFeed:(NSUInteger)feed playLightsAndSirens:(BOOL)lights withReply:(id)reply {
    NCNotificationRequest *request = nil;
    if ([bulletin respondsToSelector:@selector(notificationRequest)]) {
        request = [bulletin performSelector:@selector(notificationRequest)];
    }
    moodyGlowHandleNotification(request, YES);
    %orig;
}

%end

#pragma mark - Dispatcher Hook (banners + all notifications)

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
