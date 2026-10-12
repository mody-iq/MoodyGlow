// --- Tweak Initialization ---
%ctor {
    NSLog(@"[Moody Glow] ============ TWEAK LOADED ============");
    NSLog(@"[Moody Glow] Tweak loaded. Stage 1 (Tracker) initialized.");
    %init(iOS14Plus);
    
    CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(),
                                     NULL,
                                     moodyGlowTestCallback,
                                     CFSTR("com.moody.moodyglow.test"),
                                     NULL,
                                     CFNotificationSuspensionBehaviorDeliverImmediately);
}
