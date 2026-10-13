static void moodyGlowRefreshPersistentGlow(NSInteger count, NSArray<NSString *> *bundleIDs) {
    MoodyGlowPrefs *prefs = [MoodyGlowPrefs sharedInstance];
    [prefs reload];

    if (![prefs isEnabled]) {
        [[MoodyGlowPersistentGlow sharedInstance] stopAnimated:YES];
        return;
    }

    if (count <= 0 || bundleIDs.count == 0) {
        [[MoodyGlowPersistentGlow sharedInstance] stopAnimated:YES];
        return;
    }

    CGFloat breathing = [prefs breathingSpeed];
    CGFloat draw = [prefs speed];
    CGFloat thickness = [prefs glowThickness];
    [[MoodyGlowPersistentGlow sharedInstance] setBreathingSpeed:breathing];
    [[MoodyGlowPersistentGlow sharedInstance] setDrawSpeed:draw];
    [[MoodyGlowPersistentGlow sharedInstance] setGlowThickness:thickness];

    UIColor *fallback = [UIColor colorWithRed:0.85 green:0.95 blue:0.10 alpha:1.0];

    if ([prefs colorMode] == MoodyGlowColorModeStatic) {
        UIColor *single = [prefs staticColor];
        if (!single) single = fallback;
        [[MoodyGlowPersistentGlow sharedInstance] showWithColors:@[single]
                                                          style:[prefs selectedAnimationIndex]
                                                       animated:YES];
        return;
    }

    if (![prefs isColorCyclingEnabled] || bundleIDs.count == 1) {
        NSString *first = bundleIDs.firstObject;
        UIColor *c = moodyGlowCachedColorForBundle(first);
        if (!c) c = fallback;
        [[MoodyGlowPersistentGlow sharedInstance] showWithColors:@[c]
                                                          style:[prefs selectedAnimationIndex]
                                                       animated:YES];
        return;
    }

    NSMutableArray<UIColor *> *colors = [NSMutableArray arrayWithCapacity:bundleIDs.count];
    for (NSString *bundleID in bundleIDs) {
        UIColor *c = moodyGlowCachedColorForBundle(bundleID);
        [colors addObject:c ? c : fallback];
    }

    NSInteger style = [prefs selectedAnimationIndex];
    NSLog(@"[Moody Glow] Refresh: count=%ld, style=%ld, colors=%lu, thickness=%.1f",
          (long)count, (long)style, (unsigned long)colors.count, thickness);

    [[MoodyGlowPersistentGlow sharedInstance] showWithColors:colors
                                                       style:style
                                                    animated:YES];
}
