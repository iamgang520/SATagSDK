//
//  ViewController.m
//  SATagSDKDemo
//
//  Created by iamgang on 2026/7/26.
//

#import "ViewController.h"
#import <SATagSDK/SATagSDK.h>

@interface ViewController ()

@property (nonatomic, strong) UIStackView *stackView;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    self.title = @"SATagSDK Demo";
    self.view.backgroundColor = UIColor.systemBackgroundColor;

    UILabel *descriptionLabel = [[UILabel alloc] init];
    descriptionLabel.numberOfLines = 0;
    descriptionLabel.textAlignment = NSTextAlignmentCenter;
    descriptionLabel.text = @"Objective-C 调用示例\nAppsFlyer / Facebook / TikTok";

    self.stackView = [[UIStackView alloc] initWithArrangedSubviews:@[
        descriptionLabel,
        [self buttonWithTitle:@"重新初始化" action:@selector(initializeSDK)],
        [self buttonWithTitle:@"统一打点" action:@selector(trackEvent)],
        [self buttonWithTitle:@"打开 DebugView" action:@selector(openDebugView)]
    ]];
    self.stackView.axis = UILayoutConstraintAxisVertical;
    self.stackView.spacing = 16.0;
    self.stackView.alignment = UIStackViewAlignmentFill;
    self.stackView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.stackView];

    UILayoutGuide *safeArea = self.view.safeAreaLayoutGuide;
    [NSLayoutConstraint activateConstraints:@[
        [self.stackView.leadingAnchor constraintEqualToAnchor:safeArea.leadingAnchor constant:24.0],
        [self.stackView.trailingAnchor constraintEqualToAnchor:safeArea.trailingAnchor constant:-24.0],
        [self.stackView.centerYAnchor constraintEqualToAnchor:safeArea.centerYAnchor],
    ]];
}

- (UIButton *)buttonWithTitle:(NSString *)title action:(SEL)action {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    [button setTitle:title forState:UIControlStateNormal];
    button.titleLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleHeadline];
    button.accessibilityIdentifier = title;
    [button addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    return button;
}

- (void)initializeSDK {
    NSString *devKey = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"AppsFlyerDevKey"] ?: @"";
    NSString *appleAppID = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"AppsFlyerAppleAppID"] ?: @"";
    [[SATagSDK sharedInstance] initializeWithAppsFlyerDevKey:devKey
                                                  appleAppID:appleAppID
                                                  completion:^(NSArray<SATagInitializationResult *> *results) {
        NSLog(@"[SATagSDK Demo] 初始化结果：%@", results);
    }];
}

- (void)trackEvent {
    [[SATagSDK sharedInstance] trackEvent:@"demo_button_tapped"
                               parameters:@{@"source": @"objective-c-demo"}
                               completion:^(NSArray<SATagEventResult *> *results) {
        NSLog(@"[SATagSDK Demo] 统一打点结果：%@", results);
    }];
}

- (void)openDebugView {
    [[SATagSDK sharedInstance] presentDebugViewFromViewController:self];
}

@end
