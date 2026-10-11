// Moody Glow - Notification Capture
// Developer: Moody
// Target: iOS 14.0 - 18.7 (RootHide)
// Step 2: Capture incoming notifications on the lock screen

#import <Foundation/Foundation.h>
#import "PrivateHeaders.h"

// --- iOS 14+ Notification Capture Group ---
%group iOS14Plus

%hook SBLockScreenNotificationListController

// This method is called every time a new notification arrives on the lock screen
- (void)observer:(id)observer addBulletin:(id)bulletin forFeed:(NSUInteger)feed playLightsAndSirens:(BOOL)lights withReply:(id)reply {

    // Capture the notification data
    NSLog(@"[Moody Glow] ===== NEW NOTIFICATION DETECTED =====");
    NSLog(@"[Moody Glow] Bulletin Class: %@", [bulletin class]);
    NSLog(@"[Moody Glow] Bulletin Object: %@", bulletin);

    // Try to extract the notification request if available
    if ([bulletin respondsToSelector:@selector(notificationRequest)]) {
        NCNotificationRequest *request = [bulletin performSelector:@selector(notificationRequest)];
        if (request) {
            NSLog(@"[Moody Glow] App Bundle ID: %@", request.sectionIdentifier);
            NSLog(@"[Moody Glow] Notification Title: %@", [request title]);
            NSLog(@"[Moody Glow] Notification Subtitle: %@", [request subtitle]);
            NSLog(@"[Moody Glow] Notification Message: %@", [request message]);
        }
    }

    NSLog(@"[Moody Glow] =================================");

    // Call the original method to preserve system behavior
    %orig;
}

%end

%end // iOS14Plus

// --- Tweak Initialization ---
%ctor {
    NSLog(@"[Moody Glow] Tweak loaded successfully. Initializing iOS14Plus group...");
    %init(iOS14Plus);
}
