// Moody Glow - Notification Capture + Outline Animation + Preferences
// Developer: Moody
// Target: iOS 14.0 - 18.7 (RootHide)
// Step 5: Respect user settings from MoodyGlowPrefs

#import <Foundation/Foundation.h>
#import "PrivateHeaders.h"
#import "MoodyGlowOutline.h"
#import "MoodyGlowColorExtractor.h"
#import "MoodyGlowPrefs.h"

// --- iOS 14+ Notification Capture Group ---
%group iOS14Plus

%hook SBLockScreenNotificationListController

- (void)observer:(id)observer addBulletin:(id)bulletin forFeed:(NSUInteger)feed playLightsAndSirens:(BOOL)lights withReply:(id)reply {

    // Load the latest user settings
    MoodyGlowPrefs *prefs = [MoodyGlowPrefs sharedInstance];
    [prefs reload];

    // If the tweak is disabled, skip everything
    if (![prefs isEnabled]) {
        NSLog(@"[Moody Glow] Tweak disabled. Skipping.");
        %orig;
        return;
    }

    NSLog(@"[Moody Glow] ===== NEW NOTIFICATION DETECTED =====");

    NSString *bundleID = nil;

    // Extract notification data
    if ([bulletin respondsToSelector:@selector(notificationRequest)]) {
        NCNotificationRequest *request = [bulletin performSelector:@selector(notificationRequest)];
        if (request) {
            bundleID = request.sectionIdentifier;
            NSLog(@"[Moody Glow] App Bundle ID: %@", bundleID);
            NSLog(@"[Moody Glow] Title: %@", [request title]);
            NSLog(@"[Moody Glow] Message: %@", [request message]);
        }
    }

    // --- Determine the outline color based on user's color mode ---
    UIColor *outlineColor = nil;

    if ([prefs colorMode] == MoodyGlowColorModeIcon) {
        // Mode 0: Extract color from the app icon
        if (bundleID && bundleID.length > 0) {
            outlineColor = [MoodyGlowColorExtractor colorForBundleID:bundleID];
        }
        if (!outlineColor) {
            outlineColor = [UIColor colorWithRed:0.85 green:0.95 blue:0.10 alpha:1.0];
            NSLog(@"[Moody Glow] Icon color extraction failed. Using fallback yellow.");
        }
    } else {
        // Mode 1: Use the user-defined static color
        outlineColor = [prefs staticColor];
        NSLog(@"[Moody Glow] Using static color from preferences.");
    }

    // --- Trigger the Outline Animation ---
    UIWindow *targetWindow = [MoodyGlowOutline findBestWindow];
    if (targetWindow) {
        [MoodyGlowOutline showOutlineWithColor:outlineColor
                                        inView:targetWindow
                                   repeatCount:[prefs repeatCount]
                                         speed:[prefs speed]];
        NSLog(@"[Moody Glow] Outline triggered. Color: %@ | Repeat: %ld | Speed: %.2f",
              outlineColor, (long)[prefs repeatCount], (double)[prefs speed]);
    } else {
        NSLog(@"[Moody Glow] ERROR: Could not find a window for outline animation");
    }

    NSLog(@"[Moody Glow] =================================");

    %orig;
}

%end

%end // iOS14Plus

// --- Tweak Initialization ---
%ctor {
    NSLog(@"[Moody Glow] Tweak loaded. Initializing iOS14Plus group...");
    %init(iOS14Plus);
}
