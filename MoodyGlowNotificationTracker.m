// Moody Glow - Notification Tracker Implementation
// Developer: Moody
// Logs are written to /var/mobile/Library/Logs/MoodyGlow.log

#import "MoodyGlowNotificationTracker.h"

@interface MoodyGlowNotificationTracker ()
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSString *> *map;
@property (nonatomic, strong) NSString *logFilePath;
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
        _logFilePath = @"/var/mobile/Library/Logs/MoodyGlow.log";
        
        // Ensure log directory exists
        NSString *dir = [_logFilePath stringByDeletingLastPathComponent];
        [[NSFileManager defaultManager] createDirectoryAtPath:dir
                                  withIntermediateDirectories:YES
                                                   attributes:nil
                                                        error:nil];
    }
    return self;
}

#pragma mark - File Logging

- (void)writeLog:(NSString *)line {
    if (!line) return;
    
    NSDateFormatter *fmt = [[NSDateFormatter alloc] init];
    fmt.dateFormat = @"HH:mm:ss";
    NSString *timestamp = [fmt stringFromDate:[NSDate date]];
    
    NSString *entry = [NSString stringWithFormat:@"[%@] %@\n", timestamp, line];
    
    // Also log to console (NSLog) for compatibility
    NSLog(@"[Moody Glow Tracker] %@", line);
    
    // Append to file
    NSFileHandle *fh = [NSFileHandle fileHandleForWritingAtPath:self.logFilePath];
    if (!fh) {
        [[NSFileManager defaultManager] createFileAtPath:self.logFilePath
                                                contents:[entry dataUsingEncoding:NSUTF8StringEncoding]
                                              attributes:nil];
    } else {
        [fh seekToEndOfFile];
        [fh writeData:[entry dataUsingEncoding:NSUTF8StringEncoding]];
        [fh closeFile];
    }
    
    // Truncate if file exceeds 100 KB
    NSDictionary *attrs = [[NSFileManager defaultManager] attributesOfItemAtPath:self.logFilePath error:nil];
    unsigned long long size = [attrs fileSize];
    if (size > 100 * 1024) {
        // Reset the file
        [[NSFileManager defaultManager] createFileAtPath:self.logFilePath
                                                contents:[@"(Log rotated)\n" dataUsingEncoding:NSUTF8StringEncoding]
                                              attributes:nil];
    }
}

#pragma mark - Public API

- (void)addNotificationWithID:(NSString *)identifier bundleID:(NSString *)bundleID {
    if (!identifier || identifier.length == 0) return;
    if (!bundleID || bundleID.length == 0) bundleID = @"unknown";
    
    dispatch_async(dispatch_get_main_queue(), ^{
        self.map[identifier] = bundleID;
        NSArray *apps = [self uniqueBundleIDs];
        [self writeLog:[NSString stringWithFormat:@"ADD %@ | bundle=%@ | total=%lu | uniqueApps=%lu",
                        identifier, bundleID,
                        (unsigned long)self.map.count,
                        (unsigned long)apps.count]];
    });
}

- (void)removeNotificationWithID:(NSString *)identifier {
    if (!identifier || identifier.length == 0) return;
    
    dispatch_async(dispatch_get_main_queue(), ^{
        BOOL existed = (self.map[identifier] != nil);
        [self.map removeObjectForKey:identifier];
        NSArray *apps = [self uniqueBundleIDs];
        [self writeLog:[NSString stringWithFormat:@"REMOVE %@ | existed=%d | total=%lu | uniqueApps=%lu",
                        identifier,
                        existed,
                        (unsigned long)self.map.count,
                        (unsigned long)apps.count]];
    });
}

- (void)removeAll {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.map removeAllObjects];
        [self writeLog:@"REMOVE ALL | total=0 | uniqueApps=0"];
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
