// Moody Glow - Notification Tracker Header
// Developer: Moody
// Purpose: Track which notifications are currently on the lock screen

#import <Foundation/Foundation.h>

@interface MoodyGlowNotificationTracker : NSObject

+ (instancetype)sharedInstance;

// Add or update a tracked notification
- (void)addNotificationWithID:(NSString *)identifier bundleID:(NSString *)bundleID;

// Remove a tracked notification
- (void)removeNotificationWithID:(NSString *)identifier;

// Clear all tracked notifications
- (void)removeAll;

// Number of currently tracked notifications
- (NSInteger)activeCount;

// List of unique bundle IDs (one per app that has notifications)
- (NSArray<NSString *> *)uniqueBundleIDs;

@end
