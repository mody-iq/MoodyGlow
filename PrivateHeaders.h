// Moody Glow - Private Headers
// Developer: Moody
// Purpose: Define private SpringBoard classes needed for notification capture

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

// --- Notification Request Class ---
@interface NCNotificationRequest : NSObject
@property (nonatomic, readonly, copy) NSString *sectionIdentifier;
@property (nonatomic, readonly, copy) NSString *notificationIdentifier;
@property (nonatomic, readonly, retain) id content;
- (NSString *)title;
- (NSString *)subtitle;
- (NSString *)message;
@end

// --- Lock Screen Notification List Controller ---
@interface SBLockScreenNotificationListController : NSObject
- (void)observer:(id)observer addBulletin:(id)bulletin forFeed:(NSUInteger)feed playLightsAndSirens:(BOOL)lights withReply:(id)reply;
- (void)observer:(id)observer modifyBulletin:(id)bulletin forFeed:(NSUInteger)feed;
- (void)observer:(id)observer removeBulletin:(id)bulletin forFeed:(NSUInteger)feed;
@end

// --- Notification Dispatcher (handles ALL notifications including banners) ---
@interface NCNotificationDispatcher : NSObject
- (void)postNotificationRequest:(NCNotificationRequest *)request;
- (void)postNotificationRequest:(NCNotificationRequest *)request completion:(void (^)(BOOL))completion;
@end
