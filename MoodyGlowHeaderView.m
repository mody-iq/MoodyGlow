// Moody Glow - Custom Settings Header View
// Developer: Moody
// Purpose: Modern, elegant header with icon + title + subtitle

#import "MoodyGlowHeaderView.h"

@implementation MoodyGlowHeaderView

+ (instancetype)headerViewWithTitle:(NSString *)title subtitle:(NSString *)subtitle {
    CGFloat width = [UIScreen mainScreen].bounds.size.width;
    MoodyGlowHeaderView *view = [[MoodyGlowHeaderView alloc] initWithFrame:CGRectMake(0, 0, width, 215)];
    view.backgroundColor = [UIColor clearColor];
    [view buildWithTitle:title subtitle:subtitle];
    return view;
}

- (void)buildWithTitle:(NSString *)title subtitle:(NSString *)subtitle {
    CGFloat width = self.bounds.size.width;
    CGFloat iconSize = 88.0;
    CGFloat iconX = (width - iconSize) / 2.0;
    CGFloat iconY = 32.0;
    
    // Icon container (rounded square, dark)
    UIView *iconBox = [[UIView alloc] initWithFrame:CGRectMake(iconX, iconY, iconSize, iconSize)];
    iconBox.backgroundColor = [UIColor colorWithRed:0.04 green:0.04 blue:0.06 alpha:1.0];
    iconBox.layer.cornerRadius = 21.0;
    iconBox.layer.cornerCurve = kCACornerCurveContinuous;
    iconBox.layer.shadowColor = [UIColor blackColor].CGColor;
    iconBox.layer.shadowOffset = CGSizeMake(0, 6);
    iconBox.layer.shadowRadius = 14;
    iconBox.layer.shadowOpacity = 0.20;
    [self addSubview:iconBox];
    
    // Glowing outline inside icon
    CGRect innerRect = CGRectInset(iconBox.bounds, 12, 12);
    UIBezierPath *path = [UIBezierPath bezierPathWithRoundedRect:innerRect cornerRadius:10];
    CAShapeLayer *outline = [CAShapeLayer layer];
    outline.path = path.CGPath;
    outline.strokeColor = [UIColor colorWithRed:0.85 green:0.95 blue:0.10 alpha:1.0].CGColor;
    outline.fillColor = [UIColor clearColor].CGColor;
    outline.lineWidth = 3.0;
    outline.lineCap = kCALineCapRound;
    outline.lineJoin = kCALineJoinRound;
    outline.shadowColor = outline.strokeColor;
    outline.shadowRadius = 8.0;
    outline.shadowOpacity = 1.0;
    outline.shadowOffset = CGSizeZero;
    [iconBox.layer addSublayer:outline];
    
    // Center glowing dot
    CGFloat dotSize = 10.0;
    UIView *dot = [[UIView alloc] initWithFrame:CGRectMake((iconSize - dotSize) / 2.0,
                                                            (iconSize - dotSize) / 2.0,
                                                            dotSize, dotSize)];
    dot.backgroundColor = [UIColor colorWithRed:0.85 green:0.95 blue:0.10 alpha:1.0];
    dot.layer.cornerRadius = dotSize / 2.0;
    dot.layer.shadowColor = dot.backgroundColor.CGColor;
    dot.layer.shadowRadius = 6.0;
    dot.layer.shadowOpacity = 1.0;
    dot.layer.shadowOffset = CGSizeZero;
    [iconBox addSubview:dot];
    
    // Title
    UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(20,
                                                                     iconY + iconSize + 18,
                                                                     width - 40,
                                                                     38)];
    titleLabel.text = title;
    titleLabel.font = [UIFont systemFontOfSize:30 weight:UIFontWeightBold];
    titleLabel.textColor = [UIColor labelColor];
    titleLabel.textAlignment = NSTextAlignmentCenter;
    titleLabel.adjustsFontSizeToFitWidth = YES;
    titleLabel.minimumScaleFactor = 0.7;
    [self addSubview:titleLabel];
    
    // Subtitle
    UILabel *subtitleLabel = [[UILabel alloc] initWithFrame:CGRectMake(20,
                                                                        titleLabel.frame.origin.y + titleLabel.frame.size.height + 4,
                                                                        width - 40,
                                                                        20)];
    subtitleLabel.text = subtitle;
    subtitleLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightMedium];
    subtitleLabel.textColor = [UIColor secondaryLabelColor];
    subtitleLabel.textAlignment = NSTextAlignmentCenter;
    [self addSubview:subtitleLabel];
}

@end
