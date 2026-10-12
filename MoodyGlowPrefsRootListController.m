// Moody Glow - Root Preferences Controller
// Developer: Moody

#import <Preferences/PSListController.h>
#import <Preferences/PSSpecifier.h>
#import <UIKit/UIKit.h>
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

#pragma mark - Reset Settings

- (void)resetSettings {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Reset Settings"
                                                                   message:@"Are you sure you want to reset all settings to their defaults?"
                                                            preferredStyle:UIAlertControllerStyleAlert];
    
    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel"
                                              style:UIAlertActionStyleCancel
                                            handler:nil]];
    
    __weak typeof(self) weakSelf = self;
    [alert addAction:[UIAlertAction actionWithTitle:@"Reset"
                                              style:UIAlertActionStyleDestructive
                                            handler:^(UIAlertAction *action) {
        NSUserDefaults *d = [[NSUserDefaults alloc] initWithSuiteName:@"com.moody.moodyglow"];
        NSDictionary *dict = [d dictionaryRepresentation];
        for (NSString *key in dict) {
            [d removeObjectForKey:key];
        }
        [d synchronize];
        
        NSLog(@"[Moody Glow] All settings reset to defaults.");
        
        [weakSelf reloadSpecifiers];
    }]];
    
    [self presentViewController:alert animated:YES completion:nil];
}

@end
