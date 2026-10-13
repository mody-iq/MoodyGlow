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

- (BOOL)isEnabled;

- (BOOL)isLockscreenEnabled;
- (BOOL)isUniversalEnabled;

- (BOOL)showInDND;
- (BOOL)showInActiveApp;

- (BOOL)isBlackoutEnabled;
- (BOOL)wakeScreenAfterBlackout;

- (NSInteger)selectedAnimationIndex;
- (NSInteger)repeatCount;
- (CGFloat)speed;
- (CGFloat)breathingSpeed;

// NEW: glow thickness (line width) in pixels (1.0 - 12.0, default 6.0)
- (CGFloat)glowThickness;

- (MoodyGlowColorMode)colorMode;
- (UIColor *)staticColor;

- (BOOL)isColorCyclingEnabled;

- (NSInteger)languageMode;

+ (UIColor *)colorFromHexString:(NSString *)hex;

@end
