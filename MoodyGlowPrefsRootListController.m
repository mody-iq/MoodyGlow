// Moody Glow - Root Preferences Controller
// Developer: Moody

#import <Preferences/PSListController.h>
#import <Preferences/PSSpecifier.h>
#import "MoodyGlowPrefsRootListController.h"

@implementation MoodyGlowPrefsRootListController

- (NSArray *)specifiers {
    if (!_specifiers) {
        _specifiers = [self loadSpecifiersFromPlistName:@"Root" target:self];
    }
    return _specifiers;
}

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

@end
