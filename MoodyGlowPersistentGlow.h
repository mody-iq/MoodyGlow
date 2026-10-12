// Moody Glow - Persistent Glow Engine Header
// Developer: Moody
// Purpose: A glow that stays on screen as long as notifications exist

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface MoodyGlowPersistentGlow : NSObject

+ (instancetype)sharedInstance;

// Show or update the persistent glow.
// If already active, only updates the color (with smooth crossfade).
- (void)showWithColor:(UIColor *)color animated:(BOOL)animated;

// Stop and hide the glow.
- (void)stopAnimated:(BOOL)animated;

- (BOOL)isActive;

@end
