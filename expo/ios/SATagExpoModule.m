//
// SATagExpoModule.m
// SATagSDK Expo bridge
//

#import "SATagExpoModule.h"
#import <React/RCTBridgeModule.h>
#import <SATagSDK/SATagSDK.h>
#import <UIKit/UIKit.h>

static NSString *SATagExpoInitializationStateName(SATagInitializationState state) {
    switch (state) {
        case SATagInitializationStateInitialized:
            return @"initialized";
        case SATagInitializationStateMissingConfiguration:
            return @"missingConfiguration";
        case SATagInitializationStateNotIntegrated:
            return @"notIntegrated";
        case SATagInitializationStateFailed:
            return @"failed";
        case SATagInitializationStateAlreadyInitialized:
            return @"alreadyInitialized";
    }
    return @"unknown";
}

static NSString *SATagExpoEventStateName(SATagEventState state) {
    switch (state) {
        case SATagEventStateAccepted:
            return @"accepted";
        case SATagEventStateNotInitialized:
            return @"notInitialized";
        case SATagEventStateNotIntegrated:
            return @"notIntegrated";
        case SATagEventStateFailed:
            return @"failed";
        case SATagEventStateInvalidEvent:
            return @"invalidEvent";
    }
    return @"unknown";
}

static NSDictionary *SATagExpoInitializationResultDictionary(SATagInitializationResult *result) {
    return @{
        @"provider": @(result.provider),
        @"providerName": result.providerName ?: @"",
        @"state": SATagExpoInitializationStateName(result.state),
        @"stateCode": @(result.state),
        @"reason": result.reason ?: @"",
        @"configurationSummary": result.configurationSummary ?: @{},
        @"timestamp": @([result.timestamp timeIntervalSince1970] * 1000.0)
    };
}

static NSDictionary *SATagExpoEventResultDictionary(SATagEventResult *result) {
    return @{
        @"provider": @(result.provider),
        @"providerName": result.providerName ?: @"",
        @"state": SATagExpoEventStateName(result.state),
        @"stateCode": @(result.state),
        @"eventName": result.eventName ?: @"",
        @"reason": result.reason ?: @"",
        @"timestamp": @([result.timestamp timeIntervalSince1970] * 1000.0)
    };
}

static UIViewController *SATagExpoTopViewController(void) {
    UIWindow *window = nil;
    for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
        if (scene.activationState != UISceneActivationStateForegroundActive &&
            scene.activationState != UISceneActivationStateForegroundInactive) {
            continue;
        }
        if (![scene isKindOfClass:UIWindowScene.class]) {
            continue;
        }
        for (UIWindow *candidate in ((UIWindowScene *)scene).windows) {
            if (candidate.isKeyWindow) {
                window = candidate;
                break;
            }
        }
        if (window) {
            break;
        }
    }

    if (!window) {
        for (UIWindow *candidate in UIApplication.sharedApplication.windows) {
            if (candidate.isKeyWindow) {
                window = candidate;
                break;
            }
        }
    }

    UIViewController *viewController = window.rootViewController;
    while (viewController.presentedViewController) {
        viewController = viewController.presentedViewController;
    }
    if ([viewController isKindOfClass:UINavigationController.class]) {
        viewController = [(UINavigationController *)viewController visibleViewController];
    } else if ([viewController isKindOfClass:UITabBarController.class]) {
        viewController = [(UITabBarController *)viewController selectedViewController];
    }
    return viewController;
}

@implementation SATagExpoModule

RCT_EXPORT_MODULE(SATagExpoModule);

RCT_REMAP_METHOD(initialize,
                 initializeWithOptions:(NSDictionary *)options
                 resolver:(RCTPromiseResolveBlock)resolve
                 rejecter:(RCTPromiseRejectBlock)reject) {
    NSString *devKey = [options[@"appsFlyerDevKey"] isKindOfClass:NSString.class]
        ? options[@"appsFlyerDevKey"]
        : nil;
    NSString *appleAppID = [options[@"appleAppID"] isKindOfClass:NSString.class]
        ? options[@"appleAppID"]
        : nil;

    [[SATagSDK sharedInstance]
        initializeWithAppsFlyerDevKey:devKey
                            appleAppID:appleAppID
                            completion:^(NSArray<SATagInitializationResult *> *results) {
        NSMutableArray *serializedResults = [NSMutableArray arrayWithCapacity:results.count];
        for (SATagInitializationResult *result in results) {
            [serializedResults addObject:SATagExpoInitializationResultDictionary(result)];
        }
        resolve(serializedResults);
    }];
}

RCT_REMAP_METHOD(track,
                 trackEvent:(NSString *)eventName
                 parameters:(NSDictionary *)parameters
                 resolver:(RCTPromiseResolveBlock)resolve
                 rejecter:(RCTPromiseRejectBlock)reject) {
    [[SATagSDK sharedInstance]
        trackEvent:eventName
        parameters:parameters ?: @{}
        completion:^(NSArray<SATagEventResult *> *results) {
        NSMutableArray *serializedResults = [NSMutableArray arrayWithCapacity:results.count];
        for (SATagEventResult *result in results) {
            [serializedResults addObject:SATagExpoEventResultDictionary(result)];
        }
        resolve(serializedResults);
    }];
}

- (void)satag_trackEvent:(NSString *)eventName
              parameters:(NSDictionary *)parameters
               provider:(SATagProvider)provider
                resolve:(RCTPromiseResolveBlock)resolve {
    void (^completion)(SATagEventResult *) = ^(SATagEventResult *result) {
        resolve(SATagExpoEventResultDictionary(result));
    };

    switch (provider) {
        case SATagProviderAppsFlyer:
            [[SATagSDK sharedInstance] trackAppsFlyerEvent:eventName
                                               parameters:parameters ?: @{}
                                               completion:completion];
            break;
        case SATagProviderFacebook:
            [[SATagSDK sharedInstance] trackFacebookEvent:eventName
                                              parameters:parameters ?: @{}
                                              completion:completion];
            break;
        case SATagProviderTikTok:
            [[SATagSDK sharedInstance] trackTikTokEvent:eventName
                                            parameters:parameters ?: @{}
                                            completion:completion];
            break;
        case SATagProviderFirebase:
            [[SATagSDK sharedInstance] trackFirebaseEvent:eventName
                                               parameters:parameters ?: @{}
                                               completion:completion];
            break;
    }
}

RCT_REMAP_METHOD(trackAppsFlyer,
                 trackAppsFlyerEvent:(NSString *)eventName
                 parameters:(NSDictionary *)parameters
                 resolver:(RCTPromiseResolveBlock)resolve
                 rejecter:(RCTPromiseRejectBlock)reject) {
    [self satag_trackEvent:eventName
                parameters:parameters
                 provider:SATagProviderAppsFlyer
                  resolve:resolve];
}

RCT_REMAP_METHOD(trackFacebook,
                 trackFacebookEvent:(NSString *)eventName
                 parameters:(NSDictionary *)parameters
                 resolver:(RCTPromiseResolveBlock)resolve
                 rejecter:(RCTPromiseRejectBlock)reject) {
    [self satag_trackEvent:eventName
                parameters:parameters
                 provider:SATagProviderFacebook
                  resolve:resolve];
}

RCT_REMAP_METHOD(trackTikTok,
                 trackTikTokEvent:(NSString *)eventName
                 parameters:(NSDictionary *)parameters
                 resolver:(RCTPromiseResolveBlock)resolve
                 rejecter:(RCTPromiseRejectBlock)reject) {
    [self satag_trackEvent:eventName
                parameters:parameters
                 provider:SATagProviderTikTok
                  resolve:resolve];
}

RCT_REMAP_METHOD(trackFirebase,
                 trackFirebaseEvent:(NSString *)eventName
                 parameters:(NSDictionary *)parameters
                 resolver:(RCTPromiseResolveBlock)resolve
                 rejecter:(RCTPromiseRejectBlock)reject) {
    [self satag_trackEvent:eventName
                parameters:parameters
                 provider:SATagProviderFirebase
                  resolve:resolve];
}

RCT_REMAP_METHOD(presentDebugView,
                 presentDebugViewWithResolver:(RCTPromiseResolveBlock)resolve
                 rejecter:(RCTPromiseRejectBlock)reject) {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIViewController *viewController = SATagExpoTopViewController();
        if (!viewController) {
            reject(@"SATAG_NO_VIEW_CONTROLLER",
                   @"当前 Expo 页面没有可用于展示 DebugView 的 UIViewController。",
                   nil);
            return;
        }
        [[SATagSDK sharedInstance] presentDebugViewFromViewController:viewController];
        resolve(nil);
    });
}

@end
