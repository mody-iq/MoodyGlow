// Moody Glow - Private Headers
// Developer: Moody
// Purpose: Define private SpringBoard classes needed for notification capture

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

// --- Notification Request Class ---
// This class holds all the data about a single notification
@interface NCNotificationRequest : NSObject
@property (nonatomic, readonly, copy) NSString *sectionIdentifier;   // Bundle ID of the app
@property (nonatomic, readonly, copy) NSString *notificationIdentifier;
@property (nonatomic, readonly, retain) id content;
- (NSString *)title;
- (NSString *)subtitle;
- (NSString *)message;
@end

// --- Lock Screen Notification List Controller ---
// This class manages the list of notifications shown on the lock screen
@interface SBLockScreenNotificationListController : NSObject
- (void)observer:(id)observer addBulletin:(id)bulletin forFeed:(NSUInteger)feed playLightsAndSirens:(BOOL)lights withReply:(id)reply;
- (void)observer:(id)observer modifyBulletin:(id)bulletin forFeed:(NSUInteger)feed;
- (void)observer:(id)observer removeBulletin:(id)bulletin forFeed:(NSUInteger)feed;
@end
