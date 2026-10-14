// Moody Glow - Notification Tracker Implementation
// Developer: Moody

#import "MoodyGlowNotificationTracker.h"
#import "MoodyGlowLog.h"
#import <unistd.h>

@interface MoodyGlowNotificationTracker ()
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSString *> *map;
@property (nonatomic, strong) NSMutableArray<NSString *> *order;
@property (nonatomic, strong) NSString *logFilePath;
@property (nonatomic, copy) void (^changeHandler)(NSInteger, NSArray<NSString *> *);
@end

@implementation MoodyGlowNotificationTracker

@synthesize changeHandler = _changeHandler;

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
        _order = [NSMutableArray array];
        _logFilePath = @"/var/mobile/Documents/MoodyGlow.log";
        
        NSString *dir = [_logFilePath stringByDeletingLastPathComponent];
        [[NSFileManager defaultManager] createDirectoryAtPath:dir
                                  withIntermediateDirectories:YES
                                                   attributes:nil
                                                        error:nil];
        
        [self writeLog:[NSString stringWithFormat:@"=== Tracker initialized (pid=%d) ===", getpid()]];
    }
    return self;
}

- (void)writeLog:(NSString *)line {
    if (!line) return;
    NSDateFormatter *fmt = [[NSDateFormatter alloc] init];
    fmt.dateFormat = @"HH:mm:ss";
    NSString *timestamp = [fmt stringFromDate:[NSDate date]];
    NSString *entry = [NSString stringWithFormat:@"[%@] %@\n", timestamp, line];
    MGLog(@"[Moody Glow Tracker] %@", line);
    
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
    
    NSDictionary *attrs = [[NSFileManager defaultManager] attributesOfItemAtPath:self.logFilePath error:nil];
    unsigned long long size = [attrs fileSize];
    if (size > 100 * 1024) {
        [[NSFileManager defaultManager] createFileAtPath:self.logFilePath
                                                contents:[@"(Log rotated)\n" dataUsingEncoding:NSUTF8StringEncoding]
                                              attributes:nil];
    }
}

- (void)notifyChange {
    void (^handler)(NSInteger, NSArray<NSString *> *) = _changeHandler;
    if (!handler) return;
    NSInteger count = self.map.count;
    NSArray<NSString *> *apps = [self uniqueBundleIDs];
    handler(count, apps);
}

- (void)addNotificationWithID:(NSString *)identifier bundleID:(NSString *)bundleID {
    if (!identifier || identifier.length == 0) return;
    if (!bundleID || bundleID.length == 0) bundleID = @"unknown";
    
    dispatch_async(dispatch_get_main_queue(), ^{
        BOOL wasExisting = (self.map[identifier] != nil);
        NSString *oldBundle = self.map[identifier];
        self.map[identifier] = bundleID;
        
        if (!wasExisting) {
            [self.order addObject:identifier];
            NSArray *apps = [self uniqueBundleIDs];
            [self writeLog:[NSString stringWithFormat:@"ADD %@ | bundle=%@ | total=%lu | uniqueApps=%lu",
                            identifier, bundleID,
                            (unsigned long)self.map.count,
                            (unsigned long)apps.count]];
        }
        
        BOOL bundleChanged = (oldBundle && ![oldBundle isEqualToString:bundleID]);
        if (!wasExisting || bundleChanged) {
            [self notifyChange];
        }
    });
}

- (void)removeNotificationWithID:(NSString *)identifier {
    if (!identifier || identifier.length == 0) return;
    
    dispatch_async(dispatch_get_main_queue(), ^{
        BOOL existed = (self.map[identifier] != nil);
        if (!existed) return;
        
        [self.map removeObjectForKey:identifier];
        [self.order removeObject:identifier];
        NSArray *apps = [self uniqueBundleIDs];
        [self writeLog:[NSString stringWithFormat:@"REMOVE %@ | total=%lu | uniqueApps=%lu",
                        identifier,
                        (unsigned long)self.map.count,
                        (unsigned long)apps.count]];
        
        [self notifyChange];
    });
}

- (void)removeAll {
    dispatch_async(dispatch_get_main_queue(), ^{
        BOOL hadAny = (self.map.count > 0);
        [self.map removeAllObjects];
        [self.order removeAllObjects];
        [self writeLog:@"REMOVE ALL | total=0 | uniqueApps=0"];
        
        if (hadAny) {
            [self notifyChange];
        }
    });
}

- (NSInteger)activeCount {
    return self.map.count;
}

// Unique bundle IDs in order of first arrival (stable order for color cycling)
- (NSArray<NSString *> *)uniqueBundleIDs {
    NSMutableArray<NSString *> *result = [NSMutableArray array];
    NSMutableSet<NSString *> *seen = [NSMutableSet set];
    
    for (NSString *identifier in self.order) {
        NSString *bundle = self.map[identifier];
        if (!bundle) continue;
        if ([seen containsObject:bundle]) continue;
        [seen addObject:bundle];
        [result addObject:bundle];
    }
    return result;
}

- (void)setChangeHandler:(void (^)(NSInteger, NSArray<NSString *> *))handler {
    _changeHandler = [handler copy];
}

- (void (^)(NSInteger, NSArray<NSString *> *))changeHandler {
    return _changeHandler;
}

@end
