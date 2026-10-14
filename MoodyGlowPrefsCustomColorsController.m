// Moody Glow - Custom Colors Controller Implementation
// Developer: Moody

#import <Preferences/PSListController.h>
#import <Preferences/PSSpecifier.h>
#import <UIKit/UIKit.h>
#import "MoodyGlowPrefsCustomColorsController.h"
#import "MoodyGlowCustomColors.h"

@interface MoodyGlowPrefsCustomColorsController () <UIColorPickerViewControllerDelegate>
@property (nonatomic, strong) NSArray<NSDictionary *> *apps;
@property (nonatomic, strong) NSString *editingBundleID;
@end

@implementation MoodyGlowPrefsCustomColorsController

#pragma mark - App List

- (NSArray<NSDictionary *> *)fetchInstalledApps {
    NSMutableArray *result = [NSMutableArray array];

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
        NSString *bundleID = nil;
        NSString *name = nil;

        SEL bidSel = NSSelectorFromString(@"applicationIdentifier");
        if ([proxy respondsToSelector:bidSel]) {
            bundleID = [proxy performSelector:bidSel];
        }

        SEL nameSel = NSSelectorFromString(@"localizedName");
        if ([proxy respondsToSelector:nameSel]) {
            name = [proxy performSelector:nameSel];
        }

        if (bundleID && name) {
            [result addObject:@{@"bundleID": bundleID, @"name": name}];
        }
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

        // Header
        PSSpecifier *header = [PSSpecifier groupSpecifierWithName:@"Custom App Colors"];
        [header setProperty:@"Tap an app to assign a custom color. Tap again to remove it."
                     forKey:@"footerText"];
        [_specifiers addObject:header];

        if (!self.apps) {
            self.apps = [self fetchInstalledApps];
        }

        NSDictionary<NSString *, UIColor *> *current = [MoodyGlowCustomColors allCustomColors];

        for (NSDictionary *app in self.apps) {
            NSString *name = app[@"name"];
            NSString *bundleID = app[@"bundleID"];
            UIColor *existing = current[bundleID];
            NSString *detail = existing ? @"Custom" : @"Default";

            PSSpecifier *spec = [PSSpecifier preferenceSpecifierNamed:name
                                                               target:self
                                                                  set:nil
                                                                  get:nil
                                                               detail:nil
                                                                 cell:0
                                                                 edit:nil];
            [spec setProperty:bundleID forKey:@"bundleID"];
            [spec setProperty:detail forKey:@"detail"];
            [_specifiers addObject:spec];
        }

        // Reset button
        [_specifiers addObject:[PSSpecifier groupSpecifierWithName:@""]];

        PSSpecifier *reset = [PSSpecifier preferenceSpecifierNamed:@"Reset All Custom Colors"
                                                            target:self
                                                               set:nil
                                                               get:nil
                                                            detail:nil
                                                              cell:PSButtonCell
                                                              edit:nil];
        [reset setProperty:@"resetAllColors" forKey:@"action"];
        [_specifiers addObject:reset];
    }
    return _specifiers;
}

#pragma mark - Cell Appearance

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [super tableView:tableView cellForRowAtIndexPath:indexPath];
    PSSpecifier *spec = [self specifierAtIndexPath:indexPath];
    NSString *bundleID = [spec propertyForKey:@"bundleID"];
    if (bundleID) {
        UIColor *c = [MoodyGlowCustomColors customColorForBundleID:bundleID];
        if (c) {
            cell.detailTextLabel.textColor = c;
            cell.detailTextLabel.text = @"● Custom";
        } else {
            cell.detailTextLabel.textColor = [UIColor secondaryLabelColor];
            cell.detailTextLabel.text = @"Default";
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

    UIColor *existing = [MoodyGlowCustomColors customColorForBundleID:bundleID];

    UIAlertController *alert = [UIAlertController alertControllerWithTitle:[spec name]
                                                                   message:nil
                                                            preferredStyle:UIAlertControllerStyleActionSheet];
    [alert addAction:[UIAlertAction actionWithTitle:@"Choose Color"
                                              style:UIAlertActionStyleDefault
                                            handler:^(UIAlertAction *a) {
        self.editingBundleID = bundleID;
        [self presentColorPicker];
    }]];

    if (existing) {
        [alert addAction:[UIAlertAction actionWithTitle:@"Remove Custom Color"
                                                  style:UIAlertActionStyleDestructive
                                                handler:^(UIAlertAction *a) {
            [MoodyGlowCustomColors removeCustomColorForBundleID:bundleID];
            _specifiers = nil;
            [self reloadSpecifiers];
        }]];
    }

    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel"
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
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Reset All Custom Colors"
                                                                   message:@"Remove all custom colors?"
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel"
                                              style:UIAlertActionStyleCancel
                                            handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Reset"
                                              style:UIAlertActionStyleDestructive
                                            handler:^(UIAlertAction *a) {
        [MoodyGlowCustomColors removeAll];
        _specifiers = nil;
        [self reloadSpecifiers];
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

@end
