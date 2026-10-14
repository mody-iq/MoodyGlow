// Moody Glow - Root Preferences Controller
// Developer: Moody

#import <Preferences/PSListController.h>
#import <Preferences/PSSpecifier.h>
#import <UIKit/UIKit.h>
#import "MoodyGlowPrefsRootListController.h"
#import "MoodyGlowLocalization.h"
#import "MoodyGlowPrefs.h"
#import "MoodyGlowHeaderView.h"
#import "MoodyGlowLog.h"

static NSString * const kMoodyOriginalLabelKey = @"moodyOriginalLabel";
static NSString * const kMoodyOriginalFooterKey = @"moodyOriginalFooter";

@implementation MoodyGlowPrefsRootListController

#pragma mark - Specifiers

- (NSArray *)specifiers {
    if (!_specifiers) {
        _specifiers = [self loadSpecifiersFromPlistName:@"Root" target:self];
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

- (void)viewDidLoad {
    [super viewDidLoad];
    [self applyRTLIfNeeded];
    dispatch_async(dispatch_get_main_queue(), ^{
        [self installHeaderView];
    });
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self applyLocalization];
    [self applyRTLIfNeeded];
    
    UITableView *t = [self findTableView];
    if (t) [t reloadData];
    
    [self installHeaderView];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [self installHeaderView];
}

- (void)applyRTLIfNeeded {
    BOOL isArabic = [[MoodyGlowLocalization sharedInstance] isArabic];
    UISemanticContentAttribute attr = isArabic
        ? UISemanticContentAttributeForceRightToLeft
        : UISemanticContentAttributeForceLeftToRight;
    self.view.semanticContentAttribute = attr;
    UITableView *t = [self findTableView];
    if (t) t.semanticContentAttribute = attr;
}

#pragma mark - Header

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

- (void)installHeaderView {
    UITableView *tableView = [self findTableView];
    if (!tableView) return;
    
    MoodyGlowLocalization *loc = [MoodyGlowLocalization sharedInstance];
    NSString *subtitle = [loc isArabic] ? @"الإصدار 1.0.0 · Moody" : @"v1.0.0 · by Moody";
    
    MoodyGlowHeaderView *header = [MoodyGlowHeaderView headerViewWithTitle:@"Moody Glow" subtitle:subtitle];
    header.frame = CGRectMake(0, 0, tableView.bounds.size.width, 215);
    tableView.tableHeaderView = header;
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
    
    MGLog(@"[Moody Glow] Language changed to mode %ld", (long)mode);
    
    [self applyLocalization];
    [self applyRTLIfNeeded];
    
    UITableView *t = [self findTableView];
    if (t) [t reloadData];
    
    [self installHeaderView];
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
        MGLog(@"[Moody Glow] All settings reset to defaults.");
        
        [weakSelf applyLocalization];
        [weakSelf applyRTLIfNeeded];
        UITableView *t = [weakSelf findTableView];
        if (t) [t reloadData];
        [weakSelf installHeaderView];
    }]];
    
    [self presentViewController:alert animated:YES completion:nil];
}

@end
