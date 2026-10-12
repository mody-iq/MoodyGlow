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
            @"Repeat Count": @"Repeat Count",
            @"Speed": @"Speed",
            @"COLOR MODE": @"COLOR MODE",
            @"Color Mode Footer": @"Choose the color mode for the animations",
            @"Icon color": @"Icon color",
            @"Static color": @"Static color",
            @"Choose Static Color": @"Choose Static Color",
            @"Test animation": @"Test animation",
        };
    });
    return dict;
}

- (NSDictionary *)arabicStrings {
    static NSDictionary *dict = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        dict = @{
            @"GENERAL": @"عام",
            @"Enabled": @"مفعّل",
            @"Animations": @"الرسوم المتحركة",
            @"DISPLAY": @"العرض",
            @"Lockscreen": @"شاشة القفل",
            @"Universal": @"عالمي",
            @"VISIBILITY": @"الظهور",
            @"Show in DND": @"إظهار في وضع عدم الإزعاج",
            @"Show in Active App": @"إظهار في التطبيق النشط",
            @"MISCELLANEOUS": @"متفرقات",
            @"Blackout": @"تعتيم",
            @"Wake screen after Blackout": @"إيقاظ الشاشة بعد التعتيم",
            @"LANGUAGE": @"اللغة",
            @"Language": @"اللغة",
            @"System": @"لغة النظام",
            @"English": @"الإنجليزية",
            @"Arabic": @"العربية",
            @"Cancel": @"إلغاء",
            @"Reset Settings": @"إعادة تعيين الإعدادات",
            @"Reset": @"إعادة تعيين",
            @"Reset Settings Message": @"هل أنت متأكد من إعادة تعيين جميع الإعدادات إلى الوضع الافتراضي؟",
            @"ABOUT": @"حول",
            @"ABOUT_FOOTER": @"Moody Glow الإصدار 1.0.0\nتطوير Moody",
            @"ANIMATION STYLE": @"نمط الرسم المتحرك",
            @"Style": @"النمط",
            @"Contrary": @"معاكس",
            @"Light Bar": @"شريط ضوئي",
            @"Outline": @"إطار",
            @"Particles": @"جزيئات",
            @"Pendulum": @"بندول",
            @"Pulse": @"نبض",
            @"Symmetric": @"متناظر",
            @"ANIMATION CONTROLS": @"التحكم في الرسم",
            @"Repeat Count": @"عدد التكرارات",
            @"Speed": @"السرعة",
            @"COLOR MODE": @"وضع اللون",
            @"Color Mode Footer": @"اختر وضع اللون للرسوم المتحركة",
            @"Icon color": @"لون الأيقونة",
            @"Static color": @"لون ثابت",
            @"Choose Static Color": @"اختر لوناً ثابتاً",
            @"Test animation": @"تجربة الرسم",
        };
    });
    return dict;
}

- (NSString *)localize:(NSString *)key {
    if (!key || key.length == 0) return @"";
    NSDictionary *dict = [self isArabic] ? [self arabicStrings] : [self englishStrings];
    NSString *value = dict[key];
    return value ? value : key;
}

@end
