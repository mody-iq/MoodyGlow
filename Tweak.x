// Moody Glow - Notification Capture + Animations + Test Listener
// Developer: Moody
// Target: iOS 14.0 - 18.7 (RootHide)

#import <Foundation/Foundation.h>
#import "PrivateHeaders.h"
#import "MoodyGlowAnimations.h"
#import "MoodyGlowColorExtractor.h"
#import "MoodyGlowPrefs.h"

// --- Test Animation Callback (triggered by settings button) ---
static void moodyGlowTestCallback(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo) {
    dispatch_async(dispatch_get_main_queue(), ^{
        NSLog(@"[Moody Glow] Test animation button pressed");
        
        MoodyGlowPrefs *prefs = [MoodyGlowPrefs sharedInstance];
        [prefs reload];
        
        UIWindow *window = [MoodyGlowAnimations findBestWindow];
        if (!window) {
            NSLog(@"[Moody Glow] No window available for test animation");
            return;
        }
        
        // Determine color
        UIColor *color = [UIColor colorWithRed:0.85 green:0.95 blue:0.10 alpha:1.0];
        if ([prefs colorMode] == MoodyGlowColorModeStatic) {
            color = [prefs staticColor];
        }
        
        [MoodyGlowAnimations playAnimationWithIndex:[prefs selectedAnimationIndex]
                                               color:color
                                              inView:window
                                         repeatCount:[prefs repeatCount]
                                               speed:[prefs speed]];
        NSLog(@"[Moody Glow] Test animation played. Index: %ld", (long)[prefs selectedAnimationIndex]);
    });
}

// --- iOS 14+ Notification Capture Group ---
%group iOS14Plus

%hook SBLockScreenNotificationListController

- (void)observer:(id)observer addBulletin:(id)bulletin forFeed:(NSUInteger)feed playLightsAndSirens:(BOOL)lights withReply:(id)reply {

    MoodyGlowPrefs *prefs = [MoodyGlowPrefs sharedInstance];
    [prefs reload];

    if (![prefs isEnabled]) {
        %orig;
        return;
    }

    NSLog(@"[Moody Glow] ===== NEW NOTIFICATION DETECTED =====");

    NSString *bundleID = nil;
    if ([bulletin respondsToSelector:@selector(notificationRequest)]) {
        NCNotificationRequest *request = [bulletin performSelector:@selector(notificationRequest)];
        if (request) {
            bundleID = request.sectionIdentifier;
            NSLog(@"[Moody Glow] Bundle ID: %@", bundleID);
            NSLog(@"[Moody Glow] Title: %@", [request title]);
        }
    }

    // Determine color
    UIColor *outlineColor = nil;
    if ([prefs colorMode] == MoodyGlowColorModeIcon) {
        if (bundleID && bundleID.length > 0) {
            outlineColor = [MoodyGlowColorExtractor colorForBundleID:bundleID];
        }
        if (!outlineColor) {
            outlineColor = [UIColor colorWithRed:0.85 green:0.95 blue:0.10 alpha:1.0];
        }
    } else {
        outlineColor = [prefs staticColor];
    }

    // Play animation
    UIWindow *targetWindow = [MoodyGlowAnimations findBestWindow];
    if (targetWindow) {
        [MoodyGlowAnimations playAnimationWithIndex:[prefs selectedAnimationIndex]
                                               color:outlineColor
                                              inView:targetWindow
                                         repeatCount:[prefs repeatCount]
                                               speed:[prefs speed]];
        NSLog(@"[Moody Glow] Animation played. Index: %ld | Color: %@",
              (long)[prefs selectedAnimationIndex], outlineColor);
    }

    NSLog(@"[Moody Glow] =================================");

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
    NSLog(@"[Moody Glow] Test animation listener registered.");
}
