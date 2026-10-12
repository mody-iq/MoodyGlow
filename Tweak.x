// Moody Glow - Notification Capture + Outline Animation + Icon Color
// Developer: Moody
// Target: iOS 14.0 - 18.7 (RootHide)
// Step 4: Use the app's icon color for the outline animation

#import <Foundation/Foundation.h>
#import "PrivateHeaders.h"
#import "MoodyGlowOutline.h"
#import "MoodyGlowColorExtractor.h"

// --- iOS 14+ Notification Capture Group ---
%group iOS14Plus

%hook SBLockScreenNotificationListController

- (void)observer:(id)observer addBulletin:(id)bulletin forFeed:(NSUInteger)feed playLightsAndSirens:(BOOL)lights withReply:(id)reply {

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

    // --- Determine the outline color ---
    UIColor *outlineColor = nil;

    // Try to extract the color from the app icon
    if (bundleID && bundleID.length > 0) {
        outlineColor = [MoodyGlowColorExtractor colorForBundleID:bundleID];
    }

    // Fallback: yellow if extraction fails
    if (!outlineColor) {
        outlineColor = [UIColor colorWithRed:0.85 green:0.95 blue:0.10 alpha:1.0];
        NSLog(@"[Moody Glow] Using fallback yellow color");
    }

    // --- Trigger the Outline Animation ---
    UIWindow *targetWindow = [MoodyGlowOutline findBestWindow];
    if (targetWindow) {
        [MoodyGlowOutline showOutlineWithColor:outlineColor
                                        inView:targetWindow
                                   repeatCount:2
                                         speed:1.0];
        NSLog(@"[Moody Glow] Outline animation triggered with color: %@", outlineColor);
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
