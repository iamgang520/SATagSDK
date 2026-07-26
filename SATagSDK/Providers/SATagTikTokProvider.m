//
// SATagTikTokProvider.m
// SATagSDK
//

#import "SATagTikTokProvider.h"
#import "SATagProviderSupport.h"

@implementation SATagTikTokProvider

- (SATagProvider)provider {
    return SATagProviderTikTok;
}

- (NSDictionary<NSString *,NSString *> *)configurationSummary {
    NSDictionary *configuration = [SATagConfigurationReader tikTokConfiguration];
    return @{
        @"accessToken": [SATagConfigurationReader maskedValue:configuration[@"accessToken"]],
        @"appID": [SATagConfigurationReader maskedValue:configuration[@"appID"]],
        @"tiktokAppID": [SATagConfigurationReader maskedValue:configuration[@"tiktokAppID"]],
        @"配置来源": @"Info.plist"
    };
}

- (SATagInitializationResult *)initializeWithConfiguration:(NSDictionary<NSString *,NSString *> *)configuration {
    NSDictionary *summary = @{
        @"accessToken": [SATagConfigurationReader maskedValue:configuration[@"accessToken"]],
        @"appID": [SATagConfigurationReader maskedValue:configuration[@"appID"]],
        @"tiktokAppID": [SATagConfigurationReader maskedValue:configuration[@"tiktokAppID"]],
        @"配置来源": @"Info.plist"
    };

    Class businessClass = NSClassFromString(@"TikTokBusiness");
    Class configClass = NSClassFromString(@"TikTokConfig");
    if (!businessClass || !configClass) {
        return SATagInitializationResultMake(self.provider,
                                             SATagInitializationStateNotIntegrated,
                                             @"未检测到 TikTokBusinessSDK，请检查 TikTok subspec。",
                                             summary);
    }

    if (![SATagConfigurationReader isNonEmptyValue:configuration[@"accessToken"]] ||
        ![SATagConfigurationReader isNonEmptyValue:configuration[@"appID"]] ||
        ![SATagConfigurationReader isNonEmptyValue:configuration[@"tiktokAppID"]]) {
        return SATagInitializationResultMake(self.provider,
                                             SATagInitializationStateMissingConfiguration,
                                             @"Info.plist 缺少 TikTokAccessToken、TikTokAppID 或 TikTokTTAppID。",
                                             summary);
    }

    @try {
        SEL configSelector = NSSelectorFromString(@"configWithAccessToken:appId:tiktokAppId:");
        id (*makeConfig)(id, SEL, id, id, id) = (id (*)(id, SEL, id, id, id))objc_msgSend;
        id config = makeConfig(configClass,
                               configSelector,
                               configuration[@"accessToken"],
                               configuration[@"appID"],
                               configuration[@"tiktokAppID"]);
        if (!config) {
            return SATagInitializationResultMake(self.provider,
                                                 SATagInitializationStateFailed,
                                                 @"TikTokConfig 创建失败。",
                                                 summary);
        }

        SEL initSelector = NSSelectorFromString(@"initializeSdk:completionHandler:");
        if (![businessClass respondsToSelector:initSelector]) {
            return SATagInitializationResultMake(self.provider,
                                                 SATagInitializationStateFailed,
                                                 @"当前 TikTok SDK 不提供 initializeSdk 入口。",
                                                 summary);
        }

        void (^completion)(BOOL, NSError *) = ^(BOOL success, NSError *error) {
            if (!success || error) {
                NSLog(@"[SATagSDK][TikTok] initialize error: %@", error.localizedDescription);
            }
        };
        void (*message)(id, SEL, id, id) = (void (*)(id, SEL, id, id))objc_msgSend;
        message(businessClass, initSelector, config, completion);
    } @catch (NSException *exception) {
        return SATagInitializationResultMake(self.provider,
                                             SATagInitializationStateFailed,
                                             exception.reason ?: @"TikTok 初始化异常。",
                                             summary);
    }

    return SATagInitializationResultMake(self.provider,
                                         SATagInitializationStateInitialized,
                                         @"TikTok 初始化调用已完成。",
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

    Class businessClass = NSClassFromString(@"TikTokBusiness");
    Class eventClass = NSClassFromString(@"TikTokBaseEvent");
    if (!businessClass || !eventClass) {
        return SATagEventResultMake(self.provider,
                                    SATagEventStateNotIntegrated,
                                    eventName,
                                    @"未检测到 TikTokBusinessSDK。");
    }

    @try {
        SEL eventSelector = NSSelectorFromString(@"alloc");
        id event = SATagInvokeClassSelector(eventClass, eventSelector);
        SEL initSelector = NSSelectorFromString(@"initWithEventName:properties:eventId:");
        if (event && [event respondsToSelector:initSelector]) {
            id (*message)(id, SEL, id, id, id) = (id (*)(id, SEL, id, id, id))objc_msgSend;
            event = message(event, initSelector, eventName, parameters ?: @{}, nil);
        } else {
            SEL fallbackSelector = NSSelectorFromString(@"initWithEventName:");
            if (event && [event respondsToSelector:fallbackSelector]) {
                id (*message)(id, SEL, id) = (id (*)(id, SEL, id))objc_msgSend;
                event = message(event, fallbackSelector, eventName);
            }
        }

        SEL trackSelector = NSSelectorFromString(@"trackTTEvent:");
        if (!event || ![businessClass respondsToSelector:trackSelector]) {
            return SATagEventResultMake(self.provider,
                                        SATagEventStateFailed,
                                        eventName,
                                        @"当前 TikTok SDK 不提供 trackTTEvent 入口。");
        }
        void (*message)(id, SEL, id) = (void (*)(id, SEL, id))objc_msgSend;
        message(businessClass, trackSelector, event);
    } @catch (NSException *exception) {
        return SATagEventResultMake(self.provider,
                                    SATagEventStateFailed,
                                    eventName,
                                    exception.reason ?: @"TikTok 打点异常。");
    }

    return SATagEventResultMake(self.provider,
                                SATagEventStateAccepted,
                                eventName,
                                @"TikTok 已接受事件。");
}

@end
