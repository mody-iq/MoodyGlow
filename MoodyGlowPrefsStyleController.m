// Moody Glow - Style Selection Controller Implementation
// Developer: Moody
// Purpose: Custom controller to avoid iOS 18 PSListItemsController crashes

#import <Preferences/PSListController.h>
#import <Preferences/PSSpecifier.h>
#import <UIKit/UIKit.h>
#import "MoodyGlowPrefsStyleController.h"
#import "MoodyGlowLocalization.h"
#import "MoodyGlowPrefs.h"

static NSString * const kMoodyStyleIndexKey = @"moodyStyleIndex";

@implementation MoodyGlowPrefsStyleController

#pragma mark - Specifiers

- (NSArray *)specifiers {
    if (!_specifiers) {
        _specifiers = [NSMutableArray array];
        
        MoodyGlowLocalization *loc = [MoodyGlowLocalization sharedInstance];
        
        NSArray *styleKeys = @[
            @"Contrary",
            @"Light Bar",
            @"Outline",
            @"Particles",
            @"Pendulum",
            @"Symmetric"
        ];
        
        // Group header
        PSSpecifier *header = [PSSpecifier groupSpecifierWithName:@""];
        [_specifiers addObject:header];
        
        for (NSInteger i = 0; i < (NSInteger)styleKeys.count; i++) {
            NSString *localized = [loc localize:styleKeys[i]];
            
            PSSpecifier *spec = [PSSpecifier preferenceSpecifierNamed:localized
                                                               target:self
                                                                  set:nil
                                                                  get:nil
                                                               detail:nil
                                                                 cell:PSListItemCell
                                                                 edit:nil];
            [spec setProperty:@(i) forKey:kMoodyStyleIndexKey];
            [_specifiers addObject:spec];
        }
    }
    return _specifiers;
}

#pragma mark - Lifecycle

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = [[MoodyGlowLocalization sharedInstance] localize:@"Style"];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
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

#pragma mark - Specifier Lookup

// Uses PSListController's built-in method for correct index-path → specifier mapping
- (PSSpecifier *)safeSpecifierForIndexPath:(NSIndexPath *)indexPath {
    if ([self respondsToSelector:@selector(specifierAtIndexPath:)]) {
        SEL sel = NSSelectorFromString(@"specifierAtIndexPath:");
        IMP imp = [self methodForSelector:sel];
        if (imp) {
            PSSpecifier *(*func)(id, SEL, NSIndexPath *) = (void *)imp;
            PSSpecifier *spec = func(self, sel, indexPath);
            if (spec) {
                NSLog(@"[Moody Glow] specifierAtIndexPath:%@ -> %@", indexPath, [spec name]);
                return spec;
            }
        }
    }
    return nil;
}

#pragma mark - Table View

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [super tableView:tableView cellForRowAtIndexPath:indexPath];
    
    PSSpecifier *spec = [self safeSpecifierForIndexPath:indexPath];
    if (!spec) {
        cell.accessoryType = UITableViewCellAccessoryNone;
        return cell;
    }
    
    NSNumber *idx = [spec propertyForKey:kMoodyStyleIndexKey];
    if (idx) {
        NSInteger current = [[MoodyGlowPrefs sharedInstance] selectedAnimationIndex];
        cell.accessoryType = (idx.integerValue == current)
            ? UITableViewCellAccessoryCheckmark
            : UITableViewCellAccessoryNone;
    } else {
        cell.accessoryType = UITableViewCellAccessoryNone;
    }
    
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    PSSpecifier *spec = [self safeSpecifierForIndexPath:indexPath];
    if (!spec) {
        NSLog(@"[Moody Glow] No specifier for index path %@", indexPath);
        return;
    }
    
    NSNumber *idx = [spec propertyForKey:kMoodyStyleIndexKey];
    if (!idx) {
        NSLog(@"[Moody Glow] Specifier has no style index (likely group header)");
        return;
    }
    
    NSUserDefaults *d = [[NSUserDefaults alloc] initWithSuiteName:@"com.moody.moodyglow"];
    [d setInteger:idx.integerValue forKey:@"SelectedAnimation"];
    [d synchronize];
    
    NSLog(@"[Moody Glow] Style selected: %ld (spec=%@)", (long)idx.integerValue, [spec name]);
    
    [tableView reloadData];
    
    __weak typeof(self) weakSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.35 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [weakSelf.navigationController popViewControllerAnimated:YES];
    });
}

@end
