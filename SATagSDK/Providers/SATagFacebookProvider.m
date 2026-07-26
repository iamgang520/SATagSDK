//
// SATagFacebookProvider.m
// SATagSDK
//

#import "SATagFacebookProvider.h"
#import "SATagProviderSupport.h"
#import <UIKit/UIKit.h>

@implementation SATagFacebookProvider

- (SATagProvider)provider {
    return SATagProviderFacebook;
}

- (NSDictionary<NSString *,NSString *> *)configurationSummary {
    NSDictionary *configuration = [SATagConfigurationReader facebookConfiguration];
    return @{
        @"appID": [SATagConfigurationReader maskedValue:configuration[@"appID"]],
        @"clientToken": [SATagConfigurationReader maskedValue:configuration[@"clientToken"]],
        @"displayName": [SATagConfigurationReader isNonEmptyValue:configuration[@"displayName"]] ? configuration[@"displayName"] : @"未配置",
        @"配置来源": @"Info.plist"
    };
}

- (SATagInitializationResult *)initializeWithConfiguration:(NSDictionary<NSString *,NSString *> *)configuration {
    NSDictionary *summary = @{
        @"appID": [SATagConfigurationReader maskedValue:configuration[@"appID"]],
        @"clientToken": [SATagConfigurationReader maskedValue:configuration[@"clientToken"]],
        @"displayName": [SATagConfigurationReader isNonEmptyValue:configuration[@"displayName"]] ? configuration[@"displayName"] : @"未配置",
        @"配置来源": @"Info.plist"
    };

    Class applicationDelegateClass = NSClassFromString(@"FBSDKApplicationDelegate");
    Class appEventsClass = NSClassFromString(@"FBSDKAppEvents");
    if (!applicationDelegateClass && !appEventsClass) {
        return SATagInitializationResultMake(self.provider,
                                             SATagInitializationStateNotIntegrated,
                                             @"未检测到 FBSDKCoreKit，请检查 Facebook subspec。",
                                             summary);
    }

    if (![SATagConfigurationReader isNonEmptyValue:configuration[@"appID"]]) {
        return SATagInitializationResultMake(self.provider,
                                             SATagInitializationStateMissingConfiguration,
                                             @"Info.plist 缺少 FacebookAppID。",
                                             summary);
    }

    @try {
        id delegate = SATagInvokeClassSelector(applicationDelegateClass, NSSelectorFromString(@"sharedInstance"));
        if (!delegate) {
            delegate = SATagInvokeClassSelector(applicationDelegateClass, NSSelectorFromString(@"shared"));
        }

        SEL launchSelector = NSSelectorFromString(@"application:didFinishLaunchingWithOptions:");
        if (delegate && [delegate respondsToSelector:launchSelector]) {
            BOOL (*message)(id, SEL, UIApplication *, NSDictionary *) =
                (BOOL (*)(id, SEL, UIApplication *, NSDictionary *))objc_msgSend;
            message(delegate, launchSelector, UIApplication.sharedApplication, nil);
        } else if (appEventsClass) {
            // 新版 FBSDK 会自行处理启动流程，这里用 activateApp 触发 App Events 生命周期。
            SEL activateSelector = NSSelectorFromString(@"activateApp");
            if ([appEventsClass respondsToSelector:activateSelector]) {
                SATagInvokeVoidClassSelector(appEventsClass, activateSelector);
            }
        }
    } @catch (NSException *exception) {
        return SATagInitializationResultMake(self.provider,
                                             SATagInitializationStateFailed,
                                             exception.reason ?: @"Facebook 初始化异常。",
                                             summary);
    }

    return SATagInitializationResultMake(self.provider,
                                         SATagInitializationStateInitialized,
                                         @"Facebook 初始化调用已完成。",
                                         summary);
}

- (SATagEventResult *)trackEvent:(NSString *)eventName
                      parameters:(NSDictionary<NSString *,id> *)parameters {
    if (eventName.trimWhitespaceAndNewlines.length == 0) {
        return SATagEventResultMake(self.provider,
                                    SATagEventStateInvalidEvent,
                                    eventName ?: @"",
                                    @"事件名不能为空。");
    }

    Class appEventsClass = NSClassFromString(@"FBSDKAppEvents");
    if (!appEventsClass) {
        return SATagEventResultMake(self.provider,
                                    SATagEventStateNotIntegrated,
                                    eventName,
                                    @"未检测到 FBSDKAppEvents。");
    }

    @try {
        id appEvents = SATagInvokeClassSelector(appEventsClass, NSSelectorFromString(@"shared"));
        if (!appEvents) {
            appEvents = SATagInvokeClassSelector(appEventsClass, NSSelectorFromString(@"sharedInstance"));
        }

        SEL instanceSelector = NSSelectorFromString(@"logEvent:parameters:");
        if (appEvents && [appEvents respondsToSelector:instanceSelector]) {
            void (*message)(id, SEL, id, id) = (void (*)(id, SEL, id, id))objc_msgSend;
            message(appEvents, instanceSelector, eventName, parameters ?: @{});
        } else {
            SEL classSelector = NSSelectorFromString(@"logEvent:parameters:");
            if (![appEventsClass respondsToSelector:classSelector]) {
                return SATagEventResultMake(self.provider,
                                            SATagEventStateFailed,
                                            eventName,
                                            @"当前 Facebook SDK 不提供 logEvent 入口。");
            }
            void (*message)(id, SEL, id, id) = (void (*)(id, SEL, id, id))objc_msgSend;
            message(appEventsClass, classSelector, eventName, parameters ?: @{});
        }
    } @catch (NSException *exception) {
        return SATagEventResultMake(self.provider,
                                    SATagEventStateFailed,
                                    eventName,
                                    exception.reason ?: @"Facebook 打点异常。");
    }

    return SATagEventResultMake(self.provider,
                                SATagEventStateAccepted,
                                eventName,
                                @"Facebook 已接受事件。");
}

@end
