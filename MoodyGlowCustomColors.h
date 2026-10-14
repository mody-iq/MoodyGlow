// Moody Glow - Custom Colors Manager Header
// Developer: Moody
// Purpose: Store & retrieve custom colors per bundle ID

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface MoodyGlowCustomColors : NSObject

// Dictionary of { bundleID : UIColor }
+ (NSDictionary<NSString *, UIColor *> *)allCustomColors;

// Get custom color for a specific bundle ID (nil if not set)
+ (UIColor *)customColorForBundleID:(NSString *)bundleID;

// Set a custom color for a bundle ID
+ (void)setCustomColor:(UIColor *)color forBundleID:(NSString *)bundleID;

// Remove custom color for a single bundle ID
+ (void)removeCustomColorForBundleID:(NSString *)bundleID;

// Remove ALL custom colors
+ (void)removeAll;

@end
