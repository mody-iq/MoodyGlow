// Moody Glow - Diagnostics Mode
// Developer: Moody
// Purpose: Enumerate notification-related classes on iOS 18.7

#import <Foundation/Foundation.h>
#import <objc/runtime>
#import "MoodyGlowNotificationTracker.h"

static NSString * const kDiagLogPath = @"/var/mobile/Documents/MoodyGlowDiag.log";

#pragma mark - Diagnostic Logger

static void writeDiag(NSString *s) {
    if (!s) return;
    NSData *d = [s dataUsingEncoding:NSUTF8StringEncoding];
    NSFileHandle *fh = [NSFileHandle fileHandleForWritingAtPath:kDiagLogPath];
    if (!fh) {
        [[NSFileManager defaultManager] createFileAtPath:kDiagLogPath contents:d attributes:nil];
    } else {
        [fh seekToEndOfFile];
        [fh writeData:d];
        [fh closeFile];
    }
    NSLog(@"[Moody Glow Diag] %@", s);
}

#pragma mark - Class / Method Dumpers

static void dumpClassesMatching(const char *pattern) {
    int count = objc_getClassList(NULL, 0);
    if (count <= 0) return;
    Class *classes = (Class *)malloc(sizeof(Class) * count);
    if (!classes) return;
    objc_getClassList(classes, count);
    
    NSMutableString *out = [NSMutableString string];
    [out appendFormat:@"\n=== Classes matching '%s' ===\n", pattern];
    int found = 0;
    for (int i = 0; i < count; i++) {
        const char *name = class_getName(classes[i]);
        if (name && strstr(name, pattern)) {
            [out appendFormat:@"  %s\n", name];
            found++;
        }
    }
    free(classes);
    [out appendFormat:@"--- Total: %d ---\n", found];
    writeDiag(out);
}

static void dumpMethodsOfClass(const char *className) {
    Class c = objc_getClass(className);
    if (!c) {
        writeDiag([NSString stringWithFormat:@"\n=== %s NOT FOUND ===\n", className]);
        return;
    }
    NSMutableString *out = [NSMutableString string];
    [out appendFormat:@"\n=== Methods of %s ===\n", className];
    
    // Instance methods
    unsigned int imCount = 0;
    Method *im = class_copyMethodList(c, &imCount);
    for (unsigned int i = 0; i < imCount; i++) {
        SEL sel = method_getName(im[i]);
        [out appendFormat:@"  - %s\n", sel_getName(sel)];
    }
    free(im);
    
    // Class methods (metaclass)
    Class mc = object_getClass(c);
    unsigned int cmCount = 0;
    Method *cm = class_copyMethodList(mc, &cmCount);
    [out appendFormat:@"  --- class methods ---\n"];
    for (unsigned int i = 0; i < cmCount; i++) {
        SEL sel = method_getName(cm[i]);
        [out appendFormat:@"  + %s\n", sel_getName(sel)];
    }
    free(cm);
    
    writeDiag(out);
}

static void runDiagnostics(void) {
    writeDiag([NSString stringWithFormat:@"\n\n######## DIAGNOSTICS @ %@ ########\n", [NSDate date]]);
    
    dumpClassesMatching("Notification");
    dumpClassesMatching("Bulletin");
    dumpClassesMatching("LockScreen");
    dumpClassesMatching("Banner");
    dumpClassesMatching("NC");
    
    // Dump methods of specific candidates
    dumpMethodsOfClass("NCNotificationDispatcher");
    dumpMethodsOfClass("SBLockScreenNotificationListController");
    dumpMethodsOfClass("SBNotificationCenterController");
    dumpMethodsOfClass("NCNotificationRequest");
    dumpMethodsOfClass("SBLockScreenManager");
    
    writeDiag(@"\n######## DIAGNOSTICS DONE ########\n");
}

// --- iOS 14+ Group ---
%group iOS14Plus

// Keep original hooks for now (may fire or not, doesn't matter for diagnostics)
%hook SBLockScreenNotificationListController
- (void)observer:(id)observer addBulletin:(id)bulletin forFeed:(NSUInteger)feed playLightsAndSirens:(BOOL)lights withReply:(id)reply {
    NSLog(@"[MG-H1] fired");
    %orig;
}
- (void)observer:(id)observer removeBulletin:(id)bulletin forFeed:(NSUInteger)feed {
    NSLog(@"[MG-H3] fired");
    %orig;
}
%end

%hook NCNotificationDispatcher
- (void)postNotificationRequest:(NCNotificationRequest *)request {
    NSLog(@"[MG-H4] fired: %@", request);
    %orig;
}
%end

%end // iOS14Plus

// --- Tweak Initialization ---
%ctor {
    NSLog(@"[Moody Glow] ============ DIAGNOSTICS BUILD LOADED ============");
    %init(iOS14Plus);
    
    // Also write to tracker log to confirm load
    [[MoodyGlowNotificationTracker sharedInstance] removeAll];
    
    // Wait 5 seconds for SpringBoard to fully initialize, then dump
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5.0 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        runDiagnostics();
    });
}
