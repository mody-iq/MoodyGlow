// Moody Glow - System State Implementation
// Developer: Moody

#import "MoodyGlowSystemState.h"
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

static BOOL gMoodyCachedLocked = NO;
static BOOL gMoodyHasCached = NO;

@implementation MoodyGlowSystemState

+ (void)setCachedLocked:(BOOL)locked {
    gMoodyCachedLocked = locked;
    gMoodyHasCached = YES;
}

+ (void)refreshFromSystem {
    Class mgrCls = NSClassFromString(@"SBLockScreenManager");
    if (!mgrCls) {
        [self setCachedLocked:![UIApplication sharedApplication].protectedDataAvailable];
        return;
    }

    SEL sharedSel = NSSelectorFromString(@"sharedInstance");
    if (![mgrCls respondsToSelector:sharedSel]) {
        [self setCachedLocked:![UIApplication sharedApplication].protectedDataAvailable];
        return;
    }

    IMP sharedImp = [mgrCls methodForSelector:sharedSel];
    if (!sharedImp) {
        [self setCachedLocked:![UIApplication sharedApplication].protectedDataAvailable];
        return;
    }
    id (*sharedFunc)(id, SEL) = (void *)sharedImp;
    id mgr = sharedFunc(mgrCls, sharedSel);
    if (!mgr) {
        [self setCachedLocked:![UIApplication sharedApplication].protectedDataAvailable];
        return;
    }

    SEL lockedSel = NSSelectorFromString(@"isUILocked");
    if (![mgr respondsToSelector:lockedSel]) {
        [self setCachedLocked:![UIApplication sharedApplication].protectedDataAvailable];
        return;
    }

    IMP lockedImp = [mgr methodForSelector:lockedSel];
    if (!lockedImp) {
        [self setCachedLocked:![UIApplication sharedApplication].protectedDataAvailable];
        return;
    }
    BOOL (*lockedFunc)(id, SEL) = (void *)lockedImp;
    BOOL locked = lockedFunc(mgr, lockedSel);
    [self setCachedLocked:locked];
}

+ (BOOL)isDeviceLocked {
    if (!gMoodyHasCached) {
        [self refreshFromSystem];
    }
    return gMoodyCachedLocked;
}

+ (BOOL)isDNDActive {
    Class DNDStateService = NSClassFromString(@"DNDStateService");
    if (!DNDStateService) return NO;

    id service = nil;

    // Try sharedInstance
    SEL sharedSel = NSSelectorFromString(@"sharedInstance");
    if ([DNDStateService respondsToSelector:sharedSel]) {
        IMP imp = [DNDStateService methodForSelector:sharedSel];
        if (imp) {
            id (*func)(id, SEL) = (void *)imp;
            service = func(DNDStateService, sharedSel);
        }
    }

    // Fallback: serviceForClientIdentifier:
    if (!service) {
        SEL clientSel = NSSelectorFromString(@"serviceForClientIdentifier:");
        if ([DNDStateService respondsToSelector:clientSel]) {
            IMP imp = [DNDStateService methodForSelector:clientSel];
            if (imp) {
                id (*func)(id, SEL, NSString *) = (void *)imp;
                service = func(DNDStateService, clientSel, @"com.apple.springboard");
            }
        }
    }

    if (!service) return NO;

    // Query state
    SEL querySel = NSSelectorFromString(@"queryCurrentStateWithError:");
    if (![service respondsToSelector:querySel]) return NO;

    IMP queryImp = [service methodForSelector:querySel];
    if (!queryImp) return NO;
    id (*queryFunc)(id, SEL, NSError **) = (void *)queryImp;
    NSError *error = nil;
    id state = queryFunc(service, querySel, &error);
    if (!state) return NO;

    // Check isActive
    SEL activeSel = NSSelectorFromString(@"isActive");
    if ([state respondsToSelector:activeSel]) {
        IMP activeImp = [state methodForSelector:activeSel];
        if (activeImp) {
            BOOL (*activeFunc)(id, SEL) = (void *)activeImp;
            return activeFunc(state, activeSel);
        }
    }

    return NO;
}

@end
