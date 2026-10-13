// Moody Glow - Preferences Header
// Developer: Moody

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

typedef NS_ENUM(NSInteger, MoodyGlowColorMode) {
    MoodyGlowColorModeIcon = 0,
    MoodyGlowColorModeStatic = 1
};

@interface MoodyGlowPrefs : NSObject

+ (instancetype)sharedInstance;
- (void)reload;

// General
- (BOOL)isEnabled;

// Display
- (BOOL)isLockscreenEnabled;
- (BOOL)isUniversalEnabled;

// Visibility
- (BOOL)showInDND;
- (BOOL)showInActiveApp;

// Miscellaneous
- (BOOL)isBlackoutEnabled;
- (BOOL)wakeScreenAfterBlackout;

// Animation
- (NSInteger)selectedAnimationIndex;
- (NSInteger)repeatCount;
- (CGFloat)speed;
- (CGFloat)breathingSpeed;

// Color
- (MoodyGlowColorMode)colorMode;
- (UIColor *)staticColor;

// Language
- (NSInteger)languageMode;

// Utility
+ (UIColor *)colorFromHexString:(NSString *)hex;

@end
