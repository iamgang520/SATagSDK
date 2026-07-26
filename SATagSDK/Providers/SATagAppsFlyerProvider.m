//
// SATagAppsFlyerProvider.m
// SATagSDK
//

#import "SATagAppsFlyerProvider.h"
#import "SATagProviderSupport.h"

@interface SATagAppsFlyerProvider ()

/// 保存最近一次初始化请求，确保 DebugView 能展示实际传入的脱敏配置。
@property (nonatomic, copy) NSDictionary<NSString *, NSString *> *lastConfiguration;

@end

@implementation SATagAppsFlyerProvider

- (SATagProvider)provider {
    return SATagProviderAppsFlyer;
}

- (NSDictionary<NSString *,NSString *> *)configurationSummary {
    NSDictionary *configuration = self.lastConfiguration ?: @{};
    return @{
        @"devKey": [SATagConfigurationReader maskedValue:configuration[@"devKey"]],
        @"appleAppID": [SATagConfigurationReader maskedValue:configuration[@"appleAppID"]],
        @"配置来源": @"initialize 参数"
    };
}

- (SATagInitializationResult *)initializeWithConfiguration:(NSDictionary<NSString *,NSString *> *)configuration {
    self.lastConfiguration = [configuration copy];
    Class appsFlyerClass = NSClassFromString(@"AppsFlyerLib");
    NSDictionary *summary = @{
        @"devKey": [SATagConfigurationReader maskedValue:configuration[@"devKey"]],
        @"appleAppID": [SATagConfigurationReader maskedValue:configuration[@"appleAppID"]],
        @"配置来源": @"initialize 参数"
    };

    if (!appsFlyerClass) {
        return SATagInitializationResultMake(self.provider,
                                             SATagInitializationStateNotIntegrated,
                                             @"未检测到 AppsFlyerLib 类，请检查 AppsFlyerFramework subspec。",
                                             summary);
    }

    NSString *devKey = configuration[@"devKey"];
    NSString *appleAppID = configuration[@"appleAppID"];
    if (![SATagConfigurationReader isNonEmptyValue:devKey] ||
        ![SATagConfigurationReader isNonEmptyValue:appleAppID]) {
        return SATagInitializationResultMake(self.provider,
                                             SATagInitializationStateMissingConfiguration,
                                             @"缺少 AppsFlyer devKey 或 appleAppID。",
                                             summary);
    }

    id shared = SATagInvokeClassSelector(appsFlyerClass, NSSelectorFromString(@"shared"));
    if (!shared) {
        shared = SATagInvokeClassSelector(appsFlyerClass, NSSelectorFromString(@"sharedLib"));
    }
    if (!shared) {
        return SATagInitializationResultMake(self.provider,
                                             SATagInitializationStateFailed,
                                             @"无法获取 AppsFlyerLib 单例。",
                                             summary);
    }

    @try {
        [shared setValue:devKey forKey:@"appsFlyerDevKey"];
        [shared setValue:appleAppID forKey:@"appleAppID"];

        SEL startWithCompletionSelector = NSSelectorFromString(@"startWithCompletionHandler:");
        if ([shared respondsToSelector:startWithCompletionSelector]) {
            void (^completion)(NSDictionary *, NSError *) = ^(NSDictionary *dictionary, NSError *error) {
                if (error) {
                    NSLog(@"[SATagSDK][AppsFlyer] start error: %@", error.localizedDescription);
                }
            };
            void (*message)(id, SEL, id) = (void (*)(id, SEL, id))objc_msgSend;
            message(shared, startWithCompletionSelector, completion);
        } else {
            SEL startSelector = NSSelectorFromString(@"start");
            if (![shared respondsToSelector:startSelector]) {
                return SATagInitializationResultMake(self.provider,
                                                     SATagInitializationStateFailed,
                                                     @"当前 AppsFlyer SDK 不提供 start 入口。",
                                                     summary);
            }
            void (*message)(id, SEL) = (void (*)(id, SEL))objc_msgSend;
            message(shared, startSelector);
        }
    } @catch (NSException *exception) {
        return SATagInitializationResultMake(self.provider,
                                             SATagInitializationStateFailed,
                                             exception.reason ?: @"AppsFlyer 初始化异常。",
                                             summary);
    }

    return SATagInitializationResultMake(self.provider,
                                         SATagInitializationStateInitialized,
                                         @"AppsFlyer 初始化调用已完成。",
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

    Class appsFlyerClass = NSClassFromString(@"AppsFlyerLib");
    id shared = SATagInvokeClassSelector(appsFlyerClass, NSSelectorFromString(@"shared"));
    if (!shared) {
        shared = SATagInvokeClassSelector(appsFlyerClass, NSSelectorFromString(@"sharedLib"));
    }
    if (!shared) {
        return SATagEventResultMake(self.provider,
                                    SATagEventStateNotIntegrated,
                                    eventName,
                                    @"未检测到 AppsFlyerLib。");
    }

    @try {
        SEL completionSelector = NSSelectorFromString(@"logEvent:withValues:completionHandler:");
        if ([shared respondsToSelector:completionSelector]) {
            void (^completion)(NSDictionary *, NSError *) = ^(NSDictionary *dictionary, NSError *error) {
                if (error) {
                    NSLog(@"[SATagSDK][AppsFlyer] event error: %@", error.localizedDescription);
                }
            };
            void (*message)(id, SEL, id, id, id) = (void (*)(id, SEL, id, id, id))objc_msgSend;
            message(shared, completionSelector, eventName, parameters ?: @{}, completion);
        } else {
            SEL eventSelector = NSSelectorFromString(@"logEvent:withValues:");
            if (![shared respondsToSelector:eventSelector]) {
                return SATagEventResultMake(self.provider,
                                            SATagEventStateFailed,
                                            eventName,
                                            @"当前 AppsFlyer SDK 不提供 logEvent 入口。");
            }
            void (*message)(id, SEL, id, id) = (void (*)(id, SEL, id, id))objc_msgSend;
            message(shared, eventSelector, eventName, parameters ?: @{});
        }
    } @catch (NSException *exception) {
        return SATagEventResultMake(self.provider,
                                    SATagEventStateFailed,
                                    eventName,
                                    exception.reason ?: @"AppsFlyer 打点异常。");
    }

    return SATagEventResultMake(self.provider,
                                SATagEventStateAccepted,
                                eventName,
                                @"AppsFlyer 已接受事件。");
}

@end
