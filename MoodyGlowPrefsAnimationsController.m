// Moody Glow - Animations Preferences Controller
// Developer: Moody

#import <Preferences/PSListController.h>
#import <Preferences/PSSpecifier.h>
#import <UIKit/UIKit.h>
#import "MoodyGlowPrefsAnimationsController.h"
#import "MoodyGlowLocalization.h"
#import "MoodyGlowLog.h"

static NSString * const kMoodyOriginalLabelKey = @"moodyOriginalLabel";
static NSString * const kMoodyOriginalFooterKey = @"moodyOriginalFooter";

@interface MoodyGlowPrefsAnimationsController () <UIColorPickerViewControllerDelegate>
@end

@implementation MoodyGlowPrefsAnimationsController

#pragma mark - Specifiers

- (NSArray *)specifiers {
    if (!_specifiers) {
        _specifiers = [self loadSpecifiersFromPlistName:@"Animations" target:self];
        [self cacheOriginalLabels];
    }
    [self applyLocalization];
    return _specifiers;
}

- (void)cacheOriginalLabels {
    for (PSSpecifier *spec in _specifiers) {
        NSString *n = [spec name];
        if (!n || n.length == 0) {
            n = [spec propertyForKey:@"label"];
        }
        if (n && n.length > 0) {
            [spec setProperty:n forKey:kMoodyOriginalLabelKey];
        }
        NSString *footer = [spec propertyForKey:@"footerText"];
        if (footer && footer.length > 0) {
            [spec setProperty:footer forKey:kMoodyOriginalFooterKey];
        }
    }
}

- (void)applyLocalization {
    if (!_specifiers) return;
    MoodyGlowLocalization *loc = [MoodyGlowLocalization sharedInstance];
    
    for (PSSpecifier *spec in _specifiers) {
        NSString *originalLabel = [spec propertyForKey:kMoodyOriginalLabelKey];
        if (originalLabel && originalLabel.length > 0) {
            NSString *localized = [loc localize:originalLabel];
            [spec setName:localized];
            [spec setProperty:localized forKey:@"label"];
        }
        NSString *originalFooter = [spec propertyForKey:kMoodyOriginalFooterKey];
        if (originalFooter && originalFooter.length > 0) {
            NSString *localizedFooter = [loc localize:originalFooter];
            [spec setProperty:localizedFooter forKey:@"footerText"];
        }
    }
}

#pragma mark - Lifecycle

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self applyLocalization];
    
    BOOL isArabic = [[MoodyGlowLocalization sharedInstance] isArabic];
    UISemanticContentAttribute attr = isArabic
        ? UISemanticContentAttributeForceRightToLeft
        : UISemanticContentAttributeForceLeftToRight;
    self.view.semanticContentAttribute = attr;
    
    UITableView *t = [self findTableView];
    if (t) {
        t.semanticContentAttribute = attr;
        [t reloadData];
    }
}

#pragma mark - Table Finder

- (UITableView *)findTableView {
    return [self findTableViewInView:self.view];
}

- (UITableView *)findTableViewInView:(UIView *)view {
    if ([view isKindOfClass:[UITableView class]]) return (UITableView *)view;
    for (UIView *sub in view.subviews) {
        UITableView *found = [self findTableViewInView:sub];
        if (found) return found;
    }
    return nil;
}

#pragma mark - Preference I/O

- (id)readPreferenceValue:(PSSpecifier *)specifier {
    NSUserDefaults *d = [[NSUserDefaults alloc] initWithSuiteName:@"com.moody.moodyglow"];
    NSString *key = [specifier propertyForKey:@"key"];
    id value = [d objectForKey:key];
    if (value == nil) value = [specifier propertyForKey:@"default"];
    return value;
}

- (void)setPreferenceValue:(id)value specifier:(PSSpecifier *)specifier {
    NSUserDefaults *d = [[NSUserDefaults alloc] initWithSuiteName:@"com.moody.moodyglow"];
    [d setObject:value forKey:[specifier propertyForKey:@"key"]];
    [d synchronize];
}

#pragma mark - Test Animation

- (void)testAnimation {
    CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(),
                                         CFSTR("com.moody.moodyglow.test"),
                                         NULL, NULL, YES);
}

#pragma mark - Static Color Picker

- (UIColor *)currentStaticColor {
    NSUserDefaults *d = [[NSUserDefaults alloc] initWithSuiteName:@"com.moody.moodyglow"];
    NSString *hex = [d stringForKey:@"StaticColor"];
    if (!hex || hex.length == 0) {
        return [UIColor colorWithRed:0.85 green:0.95 blue:0.10 alpha:1.0];
    }
    return [self colorFromHex:hex];
}

- (UIColor *)colorFromHex:(NSString *)hex {
    NSString *clean = [hex stringByReplacingOccurrencesOfString:@"#" withString:@""];
    if (clean.length != 6) return [UIColor yellowColor];
    unsigned int rgb = 0;
    NSScanner *scanner = [NSScanner scannerWithString:clean];
    if (![scanner scanHexInt:&rgb]) return [UIColor yellowColor];
    CGFloat r = ((rgb >> 16) & 0xFF) / 255.0;
    CGFloat g = ((rgb >> 8) & 0xFF) / 255.0;
    CGFloat b = (rgb & 0xFF) / 255.0;
    return [UIColor colorWithRed:r green:g blue:b alpha:1.0];
}

- (NSString *)hexFromColor:(UIColor *)color {
    CGFloat r = 0, g = 0, b = 0, a = 0;
    if (![color getRed:&r green:&g blue:&b alpha:&a]) {
        return @"#D9F21A";
    }
    int ri = (int)round(r * 255.0);
    int gi = (int)round(g * 255.0);
    int bi = (int)round(b * 255.0);
    return [NSString stringWithFormat:@"#%02X%02X%02X", ri, gi, bi];
}

- (void)pickStaticColor {
    if (@available(iOS 14.0, *)) {
        UIColorPickerViewController *picker = [[UIColorPickerViewController alloc] init];
        picker.delegate = self;
        picker.selectedColor = [self currentStaticColor];
        picker.supportsAlpha = NO;
        [self presentViewController:picker animated:YES completion:nil];
    }
}

- (void)saveStaticColor:(UIColor *)color {
    NSString *hex = [self hexFromColor:color];
    NSUserDefaults *d = [[NSUserDefaults alloc] initWithSuiteName:@"com.moody.moodyglow"];
    [d setObject:hex forKey:@"StaticColor"];
    [d synchronize];
    MGLog(@"[Moody Glow] Static color saved: %@", hex);
}

#pragma mark - UIColorPickerViewControllerDelegate

- (void)colorPickerViewControllerDidSelectColor:(UIColorPickerViewController *)viewController API_AVAILABLE(ios(14.0)) {
    [self saveStaticColor:viewController.selectedColor];
}

- (void)colorPickerViewControllerDidFinish:(UIColorPickerViewController *)viewController API_AVAILABLE(ios(14.0)) {
    [self saveStaticColor:viewController.selectedColor];
}

@end
