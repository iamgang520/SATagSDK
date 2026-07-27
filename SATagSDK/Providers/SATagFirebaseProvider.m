//
// SATagFirebaseProvider.m
// SATagSDK
//

#import "SATagFirebaseProvider.h"
#import "SATagProviderSupport.h"

@implementation SATagFirebaseProvider

- (SATagProvider)provider {
    return SATagProviderFirebase;
}

- (NSDictionary<NSString *, NSString *> *)configurationSummary {
    NSDictionary *configuration = [SATagConfigurationReader firebaseConfiguration];
    return @{
        @"googleAppID": [SATagConfigurationReader maskedValue:configuration[@"googleAppID"]],
        @"projectID": [SATagConfigurationReader maskedValue:configuration[@"projectID"]],
        @"bundleID": [SATagConfigurationReader maskedValue:configuration[@"bundleID"]],
        @"配置文件": configuration[@"configFile"] ?: @"未配置",
        @"配置来源": @"GoogleService-Info.plist"
    };
}

- (SATagInitializationResult *)initializeWithConfiguration:(NSDictionary<NSString *, NSString *> *)configuration {
    NSDictionary *summary = @{
        @"googleAppID": [SATagConfigurationReader maskedValue:configuration[@"googleAppID"]],
        @"projectID": [SATagConfigurationReader maskedValue:configuration[@"projectID"]],
        @"bundleID": [SATagConfigurationReader maskedValue:configuration[@"bundleID"]],
        @"配置文件": configuration[@"configFile"] ?: @"未配置",
        @"配置来源": @"GoogleService-Info.plist"
    };

    Class firebaseAppClass = NSClassFromString(@"FIRApp");
    Class analyticsClass = NSClassFromString(@"FIRAnalytics");
    if (!firebaseAppClass || !analyticsClass) {
        return SATagInitializationResultMake(self.provider,
                                             SATagInitializationStateNotIntegrated,
                                             @"未检测到 FirebaseAnalytics，请检查 Firebase subspec。",
                                             summary);
    }

    if (![SATagConfigurationReader isNonEmptyValue:configuration[@"googleAppID"]]) {
        return SATagInitializationResultMake(self.provider,
                                             SATagInitializationStateMissingConfiguration,
                                             @"未找到有效的 GoogleService-Info.plist 或 GOOGLE_APP_ID。",
                                             summary);
    }

    SEL defaultAppSelector = NSSelectorFromString(@"defaultApp");
    if ([firebaseAppClass respondsToSelector:defaultAppSelector] &&
        SATagInvokeClassSelector(firebaseAppClass, defaultAppSelector)) {
        return SATagInitializationResultMake(self.provider,
                                             SATagInitializationStateAlreadyInitialized,
                                             @"Firebase 已由宿主应用完成初始化。",
                                             summary);
    }

    SEL configureSelector = NSSelectorFromString(@"configure");
    if (![firebaseAppClass respondsToSelector:configureSelector]) {
        return SATagInitializationResultMake(self.provider,
                                             SATagInitializationStateFailed,
                                             @"当前 Firebase SDK 不提供 configure 入口。",
                                             summary);
    }

    @try {
        if (!SATagInvokeVoidClassSelector(firebaseAppClass, configureSelector)) {
            return SATagInitializationResultMake(self.provider,
                                                 SATagInitializationStateFailed,
                                                 @"Firebase configure 调用失败。",
                                                 summary);
        }
    } @catch (NSException *exception) {
        return SATagInitializationResultMake(self.provider,
                                             SATagInitializationStateFailed,
                                             exception.reason ?: @"Firebase 初始化异常。",
                                             summary);
    }

    if ([firebaseAppClass respondsToSelector:defaultAppSelector] &&
        !SATagInvokeClassSelector(firebaseAppClass, defaultAppSelector)) {
        return SATagInitializationResultMake(self.provider,
                                             SATagInitializationStateFailed,
                                             @"Firebase 初始化后未获取到默认 Firebase App。",
                                             summary);
    }

    return SATagInitializationResultMake(self.provider,
                                         SATagInitializationStateInitialized,
                                         @"Firebase Analytics 初始化调用已完成。",
                                         summary);
}

- (SATagEventResult *)trackEvent:(NSString *)eventName
                      parameters:(NSDictionary<NSString *, id> *)parameters {
    if (eventName.trimWhitespaceAndNewlines.length == 0) {
        return SATagEventResultMake(self.provider,
                                    SATagEventStateInvalidEvent,
                                    eventName ?: @"",
                                    @"事件名不能为空。");
    }

    Class analyticsClass = NSClassFromString(@"FIRAnalytics");
    if (!analyticsClass) {
        return SATagEventResultMake(self.provider,
                                    SATagEventStateNotIntegrated,
                                    eventName,
                                    @"未检测到 FIRAnalytics。");
    }

    SEL logEventSelector = NSSelectorFromString(@"logEventWithName:parameters:");
    if (![analyticsClass respondsToSelector:logEventSelector]) {
        return SATagEventResultMake(self.provider,
                                    SATagEventStateFailed,
                                    eventName,
                                    @"当前 Firebase SDK 不提供 logEventWithName 入口。");
    }

    @try {
        void (*message)(id, SEL, id, id) = (void (*)(id, SEL, id, id))objc_msgSend;
        message(analyticsClass, logEventSelector, eventName, parameters ?: @{});
    } @catch (NSException *exception) {
        return SATagEventResultMake(self.provider,
                                    SATagEventStateFailed,
                                    eventName,
                                    exception.reason ?: @"Firebase 打点异常。");
    }

    return SATagEventResultMake(self.provider,
                                SATagEventStateAccepted,
                                eventName,
                                @"Firebase Analytics 已接受事件。");
}

@end
