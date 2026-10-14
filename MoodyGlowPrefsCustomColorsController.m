// Moody Glow - Custom Colors Controller Implementation
// Developer: Moody

#import <Preferences/PSListController.h>
#import <Preferences/PSSpecifier.h>
#import <UIKit/UIKit.h>
#import "MoodyGlowPrefsCustomColorsController.h"
#import "MoodyGlowCustomColors.h"
#import "MoodyGlowLocalization.h"

@interface MoodyGlowPrefsCustomColorsController () <UIColorPickerViewControllerDelegate, UISearchResultsUpdating>
@property (nonatomic, strong) NSArray<NSDictionary *> *allApps;
@property (nonatomic, strong) NSArray<NSDictionary *> *filteredApps;
@property (nonatomic, strong) NSString *editingBundleID;
@property (nonatomic, strong) UISearchController *searchController;
@end

@implementation MoodyGlowPrefsCustomColorsController

#pragma mark - App Icon Helper

- (UIImage *)iconForBundleID:(NSString *)bundleID {
    if (!bundleID || bundleID.length == 0) return nil;
    Class imgCls = NSClassFromString(@"UIImage");
    SEL sel = NSSelectorFromString(@"_applicationIconImageForBundleIdentifier:format:scale:");
    if (![imgCls respondsToSelector:sel]) return nil;
    IMP imp = [imgCls methodForSelector:sel];
    if (!imp) return nil;
    UIImage *(*func)(id, SEL, NSString *, int, CGFloat) = (void *)imp;
    @try {
        return func(imgCls, sel, bundleID, 2, [UIScreen mainScreen].scale);
    } @catch (NSException *e) {
        return nil;
    }
}

#pragma mark - App List

- (NSArray<NSDictionary *> *)fetchUserApps {
    NSMutableArray *result = [NSMutableArray array];
    NSMutableSet *seen = [NSMutableSet set];

    Class wsClass = NSClassFromString(@"LSApplicationWorkspace");
    if (!wsClass) return result;

    SEL defaultSel = NSSelectorFromString(@"defaultWorkspace");
    IMP defaultImp = [wsClass methodForSelector:defaultSel];
    if (!defaultImp) return result;
    id (*defaultFunc)(id, SEL) = (void *)defaultImp;
    id workspace = defaultFunc(wsClass, defaultSel);
    if (!workspace) return result;

    SEL allSel = NSSelectorFromString(@"allApplications");
    IMP allImp = [workspace methodForSelector:allSel];
    if (!allImp) return result;
    NSArray *(*allFunc)(id, SEL) = (void *)allImp;
    NSArray *apps = allFunc(workspace, allSel);

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"

    for (id proxy in apps) {
        SEL typeSel = NSSelectorFromString(@"applicationType");
        if ([proxy respondsToSelector:typeSel]) {
            NSString *type = [proxy performSelector:typeSel];
            if (![type isKindOfClass:[NSString class]]) continue;
            if (![type isEqualToString:@"User"]) continue;
        } else {
            continue;
        }

        SEL bidSel = NSSelectorFromString(@"applicationIdentifier");
        if (![proxy respondsToSelector:bidSel]) continue;
        NSString *bundleID = [proxy performSelector:bidSel];
        if (!bundleID || bundleID.length == 0) continue;
        if ([seen containsObject:bundleID]) continue;

        // Skip Apple system apps/bundles entirely
        if ([bundleID hasPrefix:@"com.apple."]) continue;
        // Skip internal service bundles
        if ([bundleID containsString:@".PushBundle."]) continue;
        if ([bundleID containsString:@".WebKit."]) continue;

        [seen addObject:bundleID];

        SEL nameSel = NSSelectorFromString(@"localizedName");
        if (![proxy respondsToSelector:nameSel]) continue;
        NSString *name = [proxy performSelector:nameSel];
        if (!name || name.length == 0) continue;

        [result addObject:@{@"bundleID": bundleID, @"name": name}];
    }

#pragma clang diagnostic pop

    [result sortUsingComparator:^NSComparisonResult(NSDictionary *a, NSDictionary *b) {
        return [a[@"name"] localizedCaseInsensitiveCompare:b[@"name"]];
    }];

    return result;
}

#pragma mark - Specifiers

- (NSArray *)specifiers {
    if (!_specifiers) {
        _specifiers = [NSMutableArray array];

        if (!self.allApps) {
            self.allApps = [self fetchUserApps];
        }
        if (!self.filteredApps) {
            self.filteredApps = self.allApps;
        }

        BOOL isArabic = [[MoodyGlowLocalization sharedInstance] isArabic];

        PSSpecifier *header = [PSSpecifier groupSpecifierWithName:@""];
        NSString *footer = isArabic
            ? @"اضغط على أي تطبيق لتعيين لون مخصص. اضغط مرة أخرى لإزالته."
            : @"Tap an app to assign a custom color. Tap again to remove it.";
        [header setProperty:footer forKey:@"footerText"];
        [_specifiers addObject:header];

        NSDictionary<NSString *, UIColor *> *current = [MoodyGlowCustomColors allCustomColors];

        if (self.filteredApps.count == 0) {
            NSString *emptyTitle = isArabic ? @"لا توجد نتائج" : @"No results";
            PSSpecifier *empty = [PSSpecifier preferenceSpecifierNamed:emptyTitle
                                                                 target:nil set:nil get:nil
                                                                 detail:nil cell:0 edit:nil];
            [_specifiers addObject:empty];
        } else {
            for (NSDictionary *app in self.filteredApps) {
                NSString *name = app[@"name"];
                NSString *bundleID = app[@"bundleID"];
                UIColor *existing = current[bundleID];

                PSSpecifier *spec = [PSSpecifier preferenceSpecifierNamed:name
                                                                   target:self
                                                                      set:nil get:nil
                                                                   detail:nil
                                                                     cell:-1
                                                                     edit:nil];
                [spec setProperty:bundleID forKey:@"bundleID"];
                [spec setProperty:name forKey:@"appName"];
                [spec setProperty:@(existing ? 1 : 0) forKey:@"hasCustom"];
                if (existing) {
                    [spec setProperty:existing forKey:@"customUIColor"];
                }
                [_specifiers addObject:spec];
            }
        }

        [_specifiers addObject:[PSSpecifier groupSpecifierWithName:@""]];
        NSString *resetTitle = isArabic ? @"إزالة جميع الألوان المخصصة" : @"Reset All Custom Colors";
        PSSpecifier *reset = [PSSpecifier preferenceSpecifierNamed:resetTitle
                                                            target:self
                                                               set:nil get:nil
                                                            detail:nil
                                                              cell:13
                                                              edit:nil];
        [reset setProperty:@"resetAllColors" forKey:@"action"];
        [_specifiers addObject:reset];
    }
    return _specifiers;
}

#pragma mark - Lifecycle

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = [[MoodyGlowLocalization sharedInstance] localize:@"Custom App Colors"];

    self.searchController = [[UISearchController alloc] initWithSearchResultsController:nil];
    self.searchController.searchResultsUpdater = self;
    self.searchController.obscuresBackgroundDuringPresentation = NO;

    BOOL isArabic = [[MoodyGlowLocalization sharedInstance] isArabic];
    self.searchController.searchBar.placeholder = isArabic
        ? @"ابحث عن تطبيق..."
        : @"Search for an app...";

    if (@available(iOS 11.0, *)) {
        self.navigationItem.searchController = self.searchController;
        self.navigationItem.hidesSearchBarWhenScrolling = NO;
    }
    self.definesPresentationContext = YES;
}

#pragma mark - Search

- (void)updateSearchResultsForSearchController:(UISearchController *)searchController {
    NSString *query = searchController.searchBar.text.lowercaseString;
    if (!query || query.length == 0) {
        self.filteredApps = self.allApps;
    } else {
        NSMutableArray *filtered = [NSMutableArray array];
        for (NSDictionary *app in self.allApps) {
            NSString *name = app[@"name"];
            NSString *bundleID = app[@"bundleID"];
            if ([name.lowercaseString containsString:query] ||
                [bundleID.lowercaseString containsString:query]) {
                [filtered addObject:app];
            }
        }
        self.filteredApps = filtered;
    }

    _specifiers = nil;
    [self reloadSpecifiers];
}

#pragma mark - Cell Appearance

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [super tableView:tableView cellForRowAtIndexPath:indexPath];
    PSSpecifier *spec = [self specifierAtIndexPath:indexPath];
    NSString *bundleID = [spec propertyForKey:@"bundleID"];
    NSString *appName = [spec propertyForKey:@"appName"];

    if (bundleID && appName) {
        cell.textLabel.text = appName;
        cell.textLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightRegular];

        cell.detailTextLabel.text = bundleID;
        cell.detailTextLabel.textColor = [UIColor secondaryLabelColor];
        cell.detailTextLabel.font = [UIFont systemFontOfSize:11 weight:UIFontWeightRegular];
        cell.detailTextLabel.numberOfLines = 1;

        UIImage *icon = [self iconForBundleID:bundleID];
        if (icon) {
            UIGraphicsBeginImageContextWithOptions(CGSizeMake(38, 38), NO, 0.0);
            [icon drawInRect:CGRectMake(0, 0, 38, 38)];
            UIImage *resized = UIGraphicsGetImageFromCurrentImageContext();
            UIGraphicsEndImageContext();

            cell.imageView.image = resized;
            cell.imageView.layer.cornerRadius = 8.5;
            cell.imageView.layer.cornerCurve = kCACornerCurveContinuous;
            cell.imageView.clipsToBounds = YES;
            cell.imageView.contentMode = UIViewContentModeScaleAspectFit;
        }

        NSNumber *hasCustom = [spec propertyForKey:@"hasCustom"];
        UIColor *customColor = [spec propertyForKey:@"customUIColor"];
        if (hasCustom.boolValue && customColor) {
            UIView *dot = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 12, 12)];
            dot.backgroundColor = customColor;
            dot.layer.cornerRadius = 6;
            dot.layer.shadowColor = customColor.CGColor;
            dot.layer.shadowRadius = 4;
            dot.layer.shadowOpacity = 0.8;
            cell.accessoryView = dot;
        } else {
            cell.accessoryView = nil;
        }
    }

    return cell;
}

#pragma mark - Tap Handling

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];

    PSSpecifier *spec = [self specifierAtIndexPath:indexPath];
    NSString *bundleID = [spec propertyForKey:@"bundleID"];
    if (!bundleID) return;

    BOOL isArabic = [[MoodyGlowLocalization sharedInstance] isArabic];
    UIColor *existing = [MoodyGlowCustomColors customColorForBundleID:bundleID];

    UIAlertController *alert = [UIAlertController alertControllerWithTitle:[spec name]
                                                                   message:nil
                                                            preferredStyle:UIAlertControllerStyleActionSheet];
    [alert addAction:[UIAlertAction actionWithTitle:isArabic ? @"اختيار لون" : @"Choose Color"
                                              style:UIAlertActionStyleDefault
                                            handler:^(UIAlertAction *a) {
        self.editingBundleID = bundleID;
        [self presentColorPicker];
    }]];

    if (existing) {
        [alert addAction:[UIAlertAction actionWithTitle:isArabic ? @"إزالة اللون المخصص" : @"Remove Custom Color"
                                                  style:UIAlertActionStyleDestructive
                                                handler:^(UIAlertAction *a) {
            [MoodyGlowCustomColors removeCustomColorForBundleID:bundleID];
            _specifiers = nil;
            [self reloadSpecifiers];
        }]];
    }

    [alert addAction:[UIAlertAction actionWithTitle:isArabic ? @"إلغاء" : @"Cancel"
                                              style:UIAlertActionStyleCancel
                                            handler:nil]];

    if (alert.popoverPresentationController) {
        UITableViewCell *cell = [tableView cellForRowAtIndexPath:indexPath];
        alert.popoverPresentationController.sourceView = cell;
        alert.popoverPresentationController.sourceRect = cell.bounds;
    }

    [self presentViewController:alert animated:YES completion:nil];
}

- (void)presentColorPicker {
    if (@available(iOS 14.0, *)) {
        UIColorPickerViewController *picker = [[UIColorPickerViewController alloc] init];
        picker.delegate = self;
        UIColor *initial = [MoodyGlowCustomColors customColorForBundleID:self.editingBundleID];
        if (initial) picker.selectedColor = initial;
        picker.supportsAlpha = NO;
        [self presentViewController:picker animated:YES completion:nil];
    }
}

#pragma mark - UIColorPickerViewControllerDelegate

- (void)colorPickerViewControllerDidSelectColor:(UIColorPickerViewController *)viewController API_AVAILABLE(ios(14.0)) {
    [MoodyGlowCustomColors setCustomColor:viewController.selectedColor forBundleID:self.editingBundleID];
}

- (void)colorPickerViewControllerDidFinish:(UIColorPickerViewController *)viewController API_AVAILABLE(ios(14.0)) {
    [MoodyGlowCustomColors setCustomColor:viewController.selectedColor forBundleID:self.editingBundleID];
    _specifiers = nil;
    [self reloadSpecifiers];
}

#pragma mark - Reset

- (void)resetAllColors {
    BOOL isArabic = [[MoodyGlowLocalization sharedInstance] isArabic];
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:isArabic ? @"إزالة جميع الألوان المخصصة" : @"Reset All Custom Colors"
                                                                   message:isArabic ? @"هل تريد إزالة جميع الألوان المخصصة؟" : @"Remove all custom colors?"
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:isArabic ? @"إلغاء" : @"Cancel"
                                              style:UIAlertActionStyleCancel
                                            handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:isArabic ? @"إزالة" : @"Reset"
                                              style:UIAlertActionStyleDestructive
                                            handler:^(UIAlertAction *a) {
        [MoodyGlowCustomColors removeAll];
        _specifiers = nil;
        [self reloadSpecifiers];
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

@end
