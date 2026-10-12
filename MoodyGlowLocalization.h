// Moody Glow - Localization Manager Header
// Developer: Moody
// Purpose: Provide localized strings based on user's language choice

#import <Foundation/Foundation.h>

@interface MoodyGlowLocalization : NSObject

+ (instancetype)sharedInstance;

// Returns the effective language code ("en" or "ar") after resolving "system"
- (NSString *)effectiveLanguageCode;

// Returns YES if Arabic is currently active (for RTL)
- (BOOL)isArabic;

// Returns a localized string for a key (key is the English text)
- (NSString *)localize:(NSString *)key;

@end
