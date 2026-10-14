// Moody Glow - Color Extractor Implementation
// Developer: Moody
// Purpose: Extract the dominant color from an app's icon using CoreImage

#import "MoodyGlowColorExtractor.h"
#import "MoodyGlowLog.h"
#import <CoreImage/CoreImage.h>

// Private UIKit API to fetch an app's icon by bundle identifier
@interface UIImage (MoodyGlowPrivate)
+ (UIImage *)_applicationIconImageForBundleIdentifier:(NSString *)bundleID format:(int)format scale:(CGFloat)scale;
@end

@implementation MoodyGlowColorExtractor

// Fetch the icon image for a given bundle ID
+ (UIImage *)iconImageForBundleID:(NSString *)bundleID {
    if (!bundleID || bundleID.length == 0) return nil;
    SEL selector = NSSelectorFromString(@"_applicationIconImageForBundleIdentifier:format:scale:");
    if (![[UIImage class] respondsToSelector:selector]) {
        NSLog(@"[Moody Glow] Private icon API not available on this iOS version");
        return nil;
    }
    @try {
        // format 2 = application icon
        UIImage *icon = [UIImage _applicationIconImageForBundleIdentifier:bundleID
                                                                    format:2
                                                                     scale:[UIScreen mainScreen].scale];
        return icon;
    } @catch (NSException *exception) {
        MGLog(@"[Moody Glow] Exception while fetching icon: %@", exception);
        return nil;
    }
}

// Extract the average color from a UIImage using CoreImage
+ (UIColor *)averageColorFromImage:(UIImage *)image {
    if (!image) return nil;
    
    CIImage *ciImage = [[CIImage alloc] initWithImage:image];
    if (!ciImage) return nil;
    
    CIFilter *filter = [CIFilter filterWithName:@"CIAreaAverage"
                            keysAndValues:
                            kCIInputImageKey, ciImage,
                            @"inputExtent", [CIVector vectorWithCGRect:ciImage.extent],
                            nil];
    CIImage *output = filter.outputImage;
    if (!output) return nil;
    
    CIContext *context = [CIContext contextWithOptions:nil];
    unsigned char pixel[4] = {0};
    [context render:output
           toBitmap:pixel
           rowBytes:4
             bounds:CGRectMake(0, 0, 1, 1)
             format:kCIFormatRGBA8
         colorSpace:nil];
    
    CGFloat r = pixel[0] / 255.0;
    CGFloat g = pixel[1] / 255.0;
    CGFloat b = pixel[2] / 255.0;
    
    return [UIColor colorWithRed:r green:g blue:b alpha:1.0];
}

// Boost saturation and brightness so the color pops nicely
+ (UIColor *)vibrantVersionOfColor:(UIColor *)color {
    if (!color) return nil;
    
    CGFloat h = 0, s = 0, b = 0, a = 0;
    if (![color getHue:&h saturation:&s brightness:&b alpha:&a]) {
        return color;
    }
    
    // Increase saturation and ensure minimum brightness
    s = MIN(s * 1.6 + 0.15, 1.0);
    b = MAX(b, 0.85);
    
    return [UIColor colorWithHue:h saturation:s brightness:b alpha:a];
}

// Public API: get a vibrant color for the app's icon
+ (UIColor *)colorForBundleID:(NSString *)bundleID {
    UIImage *icon = [self iconImageForBundleID:bundleID];
    if (!icon) {
        MGLog(@"[Moody Glow] Could not fetch icon for bundle ID: %@", bundleID);
        return nil;
    }
    
    UIColor *avg = [self averageColorFromImage:icon];
    if (!avg) {
        MGLog(@"[Moody Glow] Could not extract average color for bundle ID: %@", bundleID);
        return nil;
    }
    
    UIColor *vibrant = [self vibrantVersionOfColor:avg];
    MGLog(@"[Moody Glow] Extracted color for %@ -> %@", bundleID, vibrant);
    return vibrant;
}

@end
