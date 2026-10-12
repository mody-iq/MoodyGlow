// Moody Glow - Color Extractor Header
// Developer: Moody
// Purpose: Extract the dominant color from an app's icon

#import <UIKit/UIKit.h>

@interface MoodyGlowColorExtractor : NSObject

// Returns a vibrant color extracted from the app icon, or nil on failure
+ (UIColor *)colorForBundleID:(NSString *)bundleID;

@end
