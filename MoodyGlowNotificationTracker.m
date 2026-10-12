// Moody Glow - Notification Tracker Implementation
// Developer: Moody

#import "MoodyGlowNotificationTracker.h"

@interface MoodyGlowNotificationTracker ()
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSString *> *map;
@end

@implementation MoodyGlowNotificationTracker

+ (instancetype)sharedInstance {
    static MoodyGlowNotificationTracker *shared = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        shared = [[MoodyGlowNotificationTracker alloc] init];
    });
    return shared;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _map = [NSMutableDictionary dictionary];
    }
    return self;
}

- (void)addNotificationWithID:(NSString *)identifier bundleID:(NSString *)bundleID {
    if (!identifier || identifier.length == 0) return;
    if (!bundleID || bundleID.length == 0) bundleID = @"unknown";
    
    dispatch_async(dispatch_get_main_queue(), ^{
        self.map[identifier] = bundleID;
        NSLog(@"[Moody Glow Tracker] ADD %@ (bundle=%@) | total=%lu | uniqueApps=%lu",
              identifier,
              bundleID,
              (unsigned long)self.map.count,
              (unsigned long)[self uniqueBundleIDs].count);
    });
}

- (void)removeNotificationWithID:(NSString *)identifier {
    if (!identifier || identifier.length == 0) return;
    
    dispatch_async(dispatch_get_main_queue(), ^{
        BOOL existed = (self.map[identifier] != nil);
        [self.map removeObjectForKey:identifier];
        NSLog(@"[Moody Glow Tracker] REMOVE %@ (existed=%d) | total=%lu | uniqueApps=%lu",
              identifier,
              existed,
              (unsigned long)self.map.count,
              (unsigned long)[self uniqueBundleIDs].count);
    });
}

- (void)removeAll {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.map removeAllObjects];
        NSLog(@"[Moody Glow Tracker] REMOVE ALL | total=0");
    });
}

- (NSInteger)activeCount {
    return self.map.count;
}

- (NSArray<NSString *> *)uniqueBundleIDs {
    NSSet *set = [NSSet setWithArray:[self.map allValues]];
    return [set allObjects];
}

@end
