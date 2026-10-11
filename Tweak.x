// Moody Glow - Notification Capture + Outline Animation
// Developer: Moody
// Target: iOS 14.0 - 18.7 (RootHide)
// Step 3: Capture notifications and trigger the Outline animation

#import <Foundation/Foundation.h>
#import "PrivateHeaders.h"
#import "MoodyGlowOutline.h"

// --- iOS 14+ Notification Capture Group ---
%group iOS14Plus

%hook SBLockScreenNotificationListController

- (void)observer:(id)observer addBulletin:(id)bulletin forFeed:(NSUInteger)feed playLightsAndSirens:(BOOL)lights withReply:(id)reply {

    NSLog(@"[Moody Glow] ===== NEW NOTIFICATION DETECTED =====");

    // Extract notification data for logging
    if ([bulletin respondsToSelector:@selector(notificationRequest)]) {
        NCNotificationRequest *request = [bulletin performSelector:@selector(notificationRequest)];
        if (request) {
            NSLog(@"[Moody Glow] App Bundle ID: %@", request.sectionIdentifier);
            NSLog(@"[Moody Glow] Title: %@", [request title]);
            NSLog(@"[Moody Glow] Message: %@", [request message]);
        }
    }

    // --- Trigger the Outline Animation ---
    UIWindow *targetWindow = [MoodyGlowOutline findBestWindow];
    if (targetWindow) {
        // Default yellow color for now (will be replaced with app icon color later)
        UIColor *outlineColor = [UIColor colorWithRed:0.85 green:0.95 blue:0.10 alpha:1.0];
        [MoodyGlowOutline showOutlineWithColor:outlineColor
                                        inView:targetWindow
                                   repeatCount:2
                                         speed:1.0];
        NSLog(@"[Moody Glow] Outline animation triggered on window: %@", targetWindow);
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
