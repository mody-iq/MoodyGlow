// Moody Glow - Custom Colors Manager Implementation
// Developer: Moody

#import "MoodyGlowCustomColors.h"

static NSString * const kMoodyGlowPrefsDomain = @"com.moody.moodyglow";
static NSString * const kMoodyCustomColorsKey = @"CustomColors";

@implementation MoodyGlowCustomColors

+ (NSUserDefaults *)defaults {
    return [[NSUserDefaults alloc] initWithSuiteName:kMoodyGlowPrefsDomain];
}

+ (NSDictionary<NSString *, NSString *> *)rawDictionary {
    NSUserDefaults *d = [self defaults];
    NSDictionary *dict = [d dictionaryForKey:kMoodyCustomColorsKey];
    return dict ? dict : @{};
}

#pragma mark - Hex Helpers

+ (UIColor *)colorFromHexString:(NSString *)hex {
    if (!hex || hex.length == 0) return nil;
    NSString *clean = [hex stringByReplacingOccurrencesOfString:@"#" withString:@""];
    if (clean.length != 6) return nil;
    unsigned int rgb = 0;
    NSScanner *scanner = [NSScanner scannerWithString:clean];
    if (![scanner scanHexInt:&rgb]) return nil;
    CGFloat r = ((rgb >> 16) & 0xFF) / 255.0;
    CGFloat g = ((rgb >> 8) & 0xFF) / 255.0;
    CGFloat b = (rgb & 0xFF) / 255.0;
    return [UIColor colorWithRed:r green:g blue:b alpha:1.0];
}

+ (NSString *)hexStringFromColor:(UIColor *)color {
    if (!color) return nil;
    CGFloat r = 0, g = 0, b = 0, a = 0;
    if (![color getRed:&r green:&g blue:&b alpha:&a]) return nil;
    int ri = (int)round(r * 255.0);
    int gi = (int)round(g * 255.0);
    int bi = (int)round(b * 255.0);
    return [NSString stringWithFormat:@"#%02X%02X%02X", ri, gi, bi];
}

#pragma mark - Public API

+ (NSDictionary<NSString *, UIColor *> *)allCustomColors {
    NSDictionary<NSString *, NSString *> *raw = [self rawDictionary];
    NSMutableDictionary<NSString *, UIColor *> *out = [NSMutableDictionary dictionary];

    for (NSString *bundleID in raw) {
        UIColor *c = [self colorFromHexString:raw[bundleID]];
        if (c) out[bundleID] = c;
    }
    return out;
}

+ (UIColor *)customColorForBundleID:(NSString *)bundleID {
    if (!bundleID || bundleID.length == 0) return nil;
    NSDictionary<NSString *, NSString *> *raw = [self rawDictionary];
    NSString *hex = raw[bundleID];
    if (!hex) return nil;
    return [self colorFromHexString:hex];
}

+ (void)setCustomColor:(UIColor *)color forBundleID:(NSString *)bundleID {
    if (!bundleID || bundleID.length == 0) return;
    if (!color) {
        [self removeCustomColorForBundleID:bundleID];
        return;
    }

    NSString *hex = [self hexStringFromColor:color];
    if (!hex) return;

    NSUserDefaults *d = [self defaults];
    NSMutableDictionary *dict = [[d dictionaryForKey:kMoodyCustomColorsKey] mutableCopy];
    if (!dict) dict = [NSMutableDictionary dictionary];
    dict[bundleID] = hex;
    [d setObject:dict forKey:kMoodyCustomColorsKey];
    [d synchronize];
}

+ (void)removeCustomColorForBundleID:(NSString *)bundleID {
    if (!bundleID || bundleID.length == 0) return;
    NSUserDefaults *d = [self defaults];
    NSMutableDictionary *dict = [[d dictionaryForKey:kMoodyCustomColorsKey] mutableCopy];
    if (!dict) return;
    [dict removeObjectForKey:bundleID];
    [d setObject:dict forKey:kMoodyCustomColorsKey];
    [d synchronize];
}

+ (void)removeAll {
    NSUserDefaults *d = [self defaults];
    [d removeObjectForKey:kMoodyCustomColorsKey];
    [d synchronize];
}

@end
