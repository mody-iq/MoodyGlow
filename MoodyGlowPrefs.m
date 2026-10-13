// Moody Glow - Preferences Implementation
// Developer: Moody

#import "MoodyGlowPrefs.h"

static NSString * const kMoodyGlowPrefsDomain = @"com.moody.moodyglow";

@implementation MoodyGlowPrefs

+ (instancetype)sharedInstance {
    static MoodyGlowPrefs *shared = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        shared = [[MoodyGlowPrefs alloc] init];
    });
    return shared;
}

- (NSUserDefaults *)defaults {
    return [[NSUserDefaults alloc] initWithSuiteName:kMoodyGlowPrefsDomain];
}

- (void)reload {
    [[self defaults] synchronize];
}

- (BOOL)boolForKey:(NSString *)key defaultValue:(BOOL)def {
    NSUserDefaults *d = [self defaults];
    if ([d objectForKey:key] == nil) return def;
    return [d boolForKey:key];
}

- (NSInteger)integerForKey:(NSString *)key defaultValue:(NSInteger)def {
    NSUserDefaults *d = [self defaults];
    if ([d objectForKey:key] == nil) return def;
    return [d integerForKey:key];
}

- (CGFloat)floatForKey:(NSString *)key defaultValue:(CGFloat)def {
    NSUserDefaults *d = [self defaults];
    if ([d objectForKey:key] == nil) return def;
    return [d floatForKey:key];
}

- (BOOL)isEnabled {
    return [self boolForKey:@"Enabled" defaultValue:YES];
}

- (BOOL)isLockscreenEnabled {
    return [self boolForKey:@"Lockscreen" defaultValue:YES];
}

- (BOOL)isUniversalEnabled {
    return [self boolForKey:@"Universal" defaultValue:YES];
}

- (BOOL)showInDND {
    return [self boolForKey:@"ShowInDND" defaultValue:YES];
}

- (BOOL)showInActiveApp {
    return [self boolForKey:@"ShowInActiveApp" defaultValue:NO];
}

- (BOOL)isBlackoutEnabled {
    return [self boolForKey:@"Blackout" defaultValue:YES];
}

- (BOOL)wakeScreenAfterBlackout {
    return [self boolForKey:@"WakeScreenAfterBlackout" defaultValue:NO];
}

- (NSInteger)selectedAnimationIndex {
    return [self integerForKey:@"SelectedAnimation" defaultValue:2];
}

- (NSInteger)repeatCount {
    return [self integerForKey:@"RepeatCount" defaultValue:2];
}

- (CGFloat)speed {
    return [self floatForKey:@"Speed" defaultValue:1.0];
}

- (CGFloat)breathingSpeed {
    return [self floatForKey:@"BreathingSpeed" defaultValue:1.0];
}

- (CGFloat)glowThickness {
    CGFloat t = [self floatForKey:@"GlowThickness" defaultValue:6.0];
    if (t < 1.0) t = 1.0;
    if (t > 12.0) t = 12.0;
    return t;
}

- (MoodyGlowColorMode)colorMode {
    return (MoodyGlowColorMode)[self integerForKey:@"ColorMode" defaultValue:0];
}

- (UIColor *)staticColor {
    NSUserDefaults *d = [self defaults];
    NSString *hex = [d stringForKey:@"StaticColor"];
    if (!hex || hex.length == 0) {
        return [UIColor colorWithRed:0.85 green:0.95 blue:0.10 alpha:1.0];
    }
    return [MoodyGlowPrefs colorFromHexString:hex];
}

- (BOOL)isColorCyclingEnabled {
    return [self boolForKey:@"ColorCycling" defaultValue:YES];
}

- (NSInteger)languageMode {
    return [self integerForKey:@"Language" defaultValue:0];
}

+ (UIColor *)colorFromHexString:(NSString *)hex {
    if (!hex || hex.length == 0) return [UIColor yellowColor];
    NSString *clean = [hex stringByReplacingOccurrencesOfString:@"#" withString:@""];
    if (clean.length != 6) return [UIColor yellowColor];
    unsigned int rgb = 0;
    NSScanner *scanner = [NSScanner scannerWithString:clean];
    if (![scanner scanHexInt:&rgb]) return [UIColor yellowColor];
    CGFloat r = ((rgb >> 16) & 0xFF) / 255.0;
    CGFloat g = ((rgb >> 8) & 0xFF) / 255.0;
    CGFloat b = (rgb & 0xFF) / 255.0;
    return [UIColor colorWithRed:r green:g blue:b alpha:1.0];
}

@end
