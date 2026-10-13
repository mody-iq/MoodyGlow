// Moody Glow - Localization Manager Implementation
// Developer: Moody

#import "MoodyGlowLocalization.h"
#import "MoodyGlowPrefs.h"

@implementation MoodyGlowLocalization

+ (instancetype)sharedInstance {
    static MoodyGlowLocalization *shared = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        shared = [[MoodyGlowLocalization alloc] init];
    });
    return shared;
}

- (NSString *)effectiveLanguageCode {
    NSInteger mode = [[MoodyGlowPrefs sharedInstance] languageMode];
    if (mode == 1) return @"en";
    if (mode == 2) return @"ar";
    NSString *sysLang = [[NSLocale preferredLanguages] firstObject];
    if ([sysLang hasPrefix:@"ar"]) return @"ar";
    return @"en";
}

- (BOOL)isArabic {
    return [[self effectiveLanguageCode] isEqualToString:@"ar"];
}

- (NSDictionary *)englishStrings {
    static NSDictionary *dict = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        dict = @{
            @"GENERAL": @"GENERAL",
            @"Enabled": @"Enabled",
            @"Animations": @"Animations",
            @"DISPLAY": @"DISPLAY",
            @"Lockscreen": @"Lockscreen",
            @"Universal": @"Universal",
            @"VISIBILITY": @"VISIBILITY",
            @"Show in DND": @"Show in DND",
            @"Show in Active App": @"Show in Active App",
            @"MISCELLANEOUS": @"MISCELLANEOUS",
            @"Blackout": @"Blackout",
            @"Wake screen after Blackout": @"Wake screen after Blackout",
            @"LANGUAGE": @"LANGUAGE",
            @"Language": @"Language",
            @"System": @"System",
            @"English": @"English",
            @"Arabic": @"Arabic",
            @"Cancel": @"Cancel",
            @"Reset Settings": @"Reset Settings",
            @"Reset": @"Reset",
            @"Reset Settings Message": @"Are you sure you want to reset all settings to their defaults?",
            @"ABOUT": @"ABOUT",
            @"ABOUT_FOOTER": @"Moody Glow v1.0.0\nDeveloped by Moody",
            @"ANIMATION STYLE": @"ANIMATION STYLE",
            @"Style": @"Style",
            @"Contrary": @"Contrary",
            @"Light Bar": @"Light Bar",
            @"Outline": @"Outline",
            @"Particles": @"Particles",
            @"Pendulum": @"Pendulum",
            @"Pulse": @"Pulse",
            @"Symmetric": @"Symmetric",
            @"ANIMATION CONTROLS": @"ANIMATION CONTROLS",
            @"Repe
