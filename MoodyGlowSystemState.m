// Moody Glow - System State Implementation
// Developer: Moody
// Purpose: Detect device lock state and DND status using private APIs

#import "MoodyGlowSystemState.h"
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

@implementation MoodyGlowSystemState

+ (BOOL)isDeviceLocked {
    // Try SBUserAgent first (most reliable on iOS 14-18)
    Class SBUserAgent = objc_getClass("SBUserAgent");
    if (SBUserAgent) {
        SEL sharedSel = NSSelectorFromString(@"sharedInstance");
        if ([SBUserAgent respondsToSelector:sharedSel]) {
            IMP sharedImp = [SBUserAgent methodForSelector:sharedSel];
            if (sharedImp) {
                id (*sharedFunc)(id, SEL) = (void *)sharedImp;
                id agent = sharedFunc(SBUserAgent, sharedSel);
                if (agent) {
                    // Try isScreenLocked
                    SEL lockSel = NSSelectorFromString(@"isScreenLocked");
                    if ([agent respondsToSelector:lockSel]) {
                        IMP lockImp = [agent methodForSelector:lockSel];
                        if (lockImp) {
                            BOOL (*lockFunc)(id, SEL) = (void *)lockImp;
                            return lockFunc(agent, lockSel);
                        }
                    }
                    // Try deviceIsLocked
                    SEL lockSel2 = NSSelectorFromString(@"deviceIsLocked");
                    if ([agent respondsToSelector:lockSel2]) {
                        IMP lockImp2 = [agent methodForSelector:lockSel2];
                        if (lockImp2) {
                            BOOL (*lockFunc2)(id, SEL) = (void *)lockImp2;
                            return lockFunc2(agent, lockSel2);
                        }
                    }
                }
            }
        }
    }
    
    // Fallback: use protectedDataAvailable (inverse of unlocked)
    return ![UIApplication sharedApplication].protectedDataAvailable;
}

+ (BOOL)isDNDActive {
    Class DNDStateService = objc_getClass("DNDStateService");
    if (!DNDStateService) return NO;
    
    SEL sharedSel = NSSelectorFromString(@"sharedInstance");
    if (![DNDStateService respondsToSelector:sharedSel]) return NO;
    
    IMP sharedImp = [DNDStateService methodForSelector:sharedSel];
    if (!sharedImp) return NO;
    id (*sharedFunc)(id, SEL) = (void *)sharedImp;
    id service = sharedFunc(DNDStateService, sharedSel);
    if (!service) return NO;
    
    // queryCurrentStateWithError:
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
