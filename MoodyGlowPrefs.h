// Moody Glow - Preferences Header
// Developer: Moody
// Purpose: Read user settings from NSUserDefaults

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

typedef NS_ENUM(NSInteger, MoodyGlowColorMode) {
    MoodyGlowColorModeIcon = 0,     // Use dominant color from app icon
    MoodyGlowColorModeStatic = 1    // Use a user-defined static color
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

// Color
- (MoodyGlowColorMode)colorMode;
- (UIColor *)staticColor;

// Utility
+ (UIColor *)colorFromHexString:(NSString *)hex;

@end
