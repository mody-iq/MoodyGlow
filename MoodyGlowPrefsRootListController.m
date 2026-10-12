// Moody Glow - Root Preferences Controller
// Developer: Moody

#import <Preferences/PSListController.h>
#import <Preferences/PSSpecifier.h>
#import <UIKit/UIKit.h>
#import "MoodyGlowPrefsRootListController.h"
#import "MoodyGlowLocalization.h"

@implementation MoodyGlowPrefsRootListController

#pragma mark - Specifiers

- (NSArray *)specifiers {
    if (!_specifiers) {
        _specifiers = [self loadSpecifiersFromPlistName:@"Root" target:self];
        _specifiers = [self applyLocalization:_specifiers];
    }
    return _specifiers;
}

- (NSArray *)applyLocalization:(NSArray *)specifiers {
    MoodyGlowLocalization *loc = [MoodyGlowLocalization sharedInstance];
    for (PSSpecifier *spec in specifiers) {
        NSString *label = [spec propertyForKey:@"label"];
        if (label && label.length > 0) {
            [spec setProperty:[loc localize:label] forKey:@"label"];
        }
        NSString *footer = [spec propertyForKey:@"footerText"];
        if (footer && footer.length > 0) {
            [spec setProperty:[loc localize:footer] forKey:@"footerText"];
        }
    }
    return specifiers;
}

#pragma mark - Lifecycle

- (void)viewDidLoad {
    [super viewDidLoad];
    [self applyRTLIfNeeded];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self applyRTLIfNeeded];
}

- (void)applyRTLIfNeeded {
    BOOL isArabic = [[MoodyGlowLocalization sharedInstance] isArabic];
    UISemanticContentAttribute attr = isArabic
        ? UISemanticContentAttributeForceRightToLeft
        : UISemanticContentAttributeForceLeftToRight;
    self.view.semanticContentAttribute = attr;
    if ([self respondsToSelector:@selector(table)]) {
        UITableView *t = [self performSelector:@selector(table)];
        if (t) t.semanticContentAttribute = attr;
    }
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

#pragma mark - Language Picker

- (void)selectLanguage {
    MoodyGlowLocalization *loc = [MoodyGlowLocalization sharedInstance];
    NSInteger current = [[MoodyGlowPrefs sharedInstance] languageMode];
    
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:[loc localize:@"Language"]
                                                                   message:nil
                                                            preferredStyle:UIAlertControllerStyleActionSheet];
    
    NSString *systemTitle = [loc localize:@"System"];
    NSString *englishTitle = [loc localize:@"English"];
    NSString *arabicTitle = [loc localize:@"Arabic"];
    NSString *cancelTitle = [loc localize:@"Cancel"];
    
    if (current == 0) systemTitle = [systemTitle stringByAppendingString:@" ✓"];
    if (current == 1) englishTitle = [englishTitle stringByAppendingString:@" ✓"];
    if (current == 2) arabicTitle = [arabicTitle stringByAppendingString:@" ✓"];
    
    [alert addAction:[UIAlertAction actionWithTitle:systemTitle
                                              style:UIAlertActionStyleDefault
                                            handler:^(UIAlertAction *a) { [self setLanguageMode:0]; }]];
    [alert addAction:[UIAlertAction actionWithTitle:englishTitle
                                              style:UIAlertActionStyleDefault
                                            handler:^(UIAlertAction *a) { [self setLanguageMode:1]; }]];
    [alert addAction:[UIAlertAction actionWithTitle:arabicTitle
                                              style:UIAlertActionStyleDefault
                                            handler:^(UIAlertAction *a) { [self setLanguageMode:2]; }]];
    [alert addAction:[UIAlertAction actionWithTitle:cancelTitle
                                              style:UIAlertActionStyleCancel
                                            handler:nil]];
    
    if (alert.popoverPresentationController) {
        alert.popoverPresentationController.sourceView = self.view;
        alert.popoverPresentationController.sourceRect = self.view.bounds;
    }
    
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)setLanguageMode:(NSInteger)mode {
    NSUserDefaults *d = [[NSUserDefaults alloc] initWithSuiteName:@"com.moody.moodyglow"];
    [d setInteger:mode forKey:@"Language"];
    [d synchronize];
    
    NSLog(@"[Moody Glow] Language changed to mode %ld", (long)mode);
    
    // Reset specifiers cache to force re-localization
    _specifiers = nil;
    [self reloadSpecifiers];
    [self applyRTLIfNeeded];
}

#pragma mark - Reset Settings

- (void)resetSettings {
    MoodyGlowLocalization *loc = [MoodyGlowLocalization sharedInstance];
    
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:[loc localize:@"Reset Settings"]
                                                                   message:[loc localize:@"Reset Settings Message"]
                                                            preferredStyle:UIAlertControllerStyleAlert];
    
    [alert addAction:[UIAlertAction actionWithTitle:[loc localize:@"Cancel"]
                                              style:UIAlertActionStyleCancel
                                            handler:nil]];
    
    __weak typeof(self) weakSelf = self;
    [alert addAction:[UIAlertAction actionWithTitle:[loc localize:@"Reset"]
                                              style:UIAlertActionStyleDestructive
                                            handler:^(UIAlertAction *action) {
        NSUserDefaults *d = [[NSUserDefaults alloc] initWithSuiteName:@"com.moody.moodyglow"];
        NSDictionary *dict = [d dictionaryRepresentation];
        for (NSString *key in dict) {
            [d removeObjectForKey:key];
        }
        [d synchronize];
        NSLog(@"[Moody Glow] All settings reset to defaults.");
        _specifiers = nil;
        [weakSelf reloadSpecifiers];
        [weakSelf applyRTLIfNeeded];
    }]];
    
    [self presentViewController:alert animated:YES completion:nil];
}

@end
