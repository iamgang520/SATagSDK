//
// SATagInitializationCoordinator.m
// SATagSDK
//

#import "SATagInitializationCoordinator.h"
#import "SATagConfigurationReader.h"

@interface SATagInitializationCoordinator ()

@property (nonatomic, copy, readwrite) NSArray<id<SATagProviderAdapter>> *providers;
@property (nonatomic, assign, readwrite, getter=isInitialized) BOOL initialized;
@property (nonatomic, copy) NSArray<SATagInitializationResult *> *latestResults;
@property (nonatomic, copy) NSDictionary<NSNumber *, SATagInitializationResult *> *resultsByProvider;
@property (nonatomic, strong) NSLock *lock;

@end

@implementation SATagInitializationCoordinator

- (instancetype)initWithProviders:(NSArray<id<SATagProviderAdapter>> *)providers {
    self = [super init];
    if (self) {
        _providers = [providers copy];
        _latestResults = @[];
        _resultsByProvider = @{};
        _lock = [[NSLock alloc] init];
    }
    return self;
}

- (NSArray<SATagInitializationResult *> *)initializeWithAppsFlyerConfiguration:(NSDictionary<NSString *,NSString *> *)appsFlyerConfiguration {
    [self.lock lock];
    @try {
        /*
         * AppsFlyer 是聚合 SDK 的必接渠道。没有完整的 Dev Key 和 Apple App ID
         * 时，整个初始化流程立即短路，避免 Facebook/TikTok 被部分初始化，
         * 让宿主误以为聚合 SDK 已经处于可用状态。这里不调用任何 Provider 的
         * initialize 方法，后续补齐 AppsFlyer 参数后仍然可以重新初始化。
         */
        BOOL hasAppsFlyerDevKey = [SATagConfigurationReader isNonEmptyValue:appsFlyerConfiguration[@"devKey"]];
        BOOL hasAppsFlyerAppleAppID = [SATagConfigurationReader isNonEmptyValue:appsFlyerConfiguration[@"appleAppID"]];
        if (!hasAppsFlyerDevKey || !hasAppsFlyerAppleAppID) {
            NSMutableArray<SATagInitializationResult *> *requiredResults =
                [NSMutableArray arrayWithCapacity:self.providers.count];
            for (id<SATagProviderAdapter> provider in self.providers) {
                NSDictionary<NSString *, NSString *> *summary = provider.configurationSummary ?: @{};
                SATagInitializationState state = provider.provider == SATagProviderAppsFlyer
                    ? SATagInitializationStateMissingConfiguration
                    : SATagInitializationStateFailed;
                NSString *reason = provider.provider == SATagProviderAppsFlyer
                    ? @"AppsFlyer 是必接渠道，必须传入 devKey 和 appleAppID 后才能初始化。"
                    : @"AppsFlyer 必接参数缺失，已跳过该渠道初始化。";

                if (provider.provider == SATagProviderAppsFlyer) {
                    summary = @{
                        @"devKey": [SATagConfigurationReader maskedValue:appsFlyerConfiguration[@"devKey"]],
                        @"appleAppID": [SATagConfigurationReader maskedValue:appsFlyerConfiguration[@"appleAppID"]],
                        @"配置来源": @"initialize 参数"
                    };
                }

                [requiredResults addObject:[[SATagInitializationResult alloc]
                                            initWithProvider:provider.provider
                                                        state:state
                                                 providerName:SATagProviderDisplayName(provider.provider)
                                                       reason:reason
                                         configurationSummary:summary]];
            }
            self.latestResults = [requiredResults copy];
            return requiredResults;
        }

        NSMutableArray<SATagInitializationResult *> *results = [NSMutableArray arrayWithCapacity:self.providers.count];
        for (id<SATagProviderAdapter> provider in self.providers) {
            SATagInitializationResult *previousResult = self.resultsByProvider[@(provider.provider)];
            if (previousResult &&
                (previousResult.state == SATagInitializationStateInitialized ||
                 previousResult.state == SATagInitializationStateAlreadyInitialized)) {
                SATagInitializationResult *alreadyInitializedResult =
                    [[SATagInitializationResult alloc] initWithProvider:provider.provider
                                                                    state:SATagInitializationStateAlreadyInitialized
                                                             providerName:SATagProviderDisplayName(provider.provider)
                                                                   reason:@"该渠道已经初始化过。"
                                                     configurationSummary:previousResult.configurationSummary];
                [results addObject:alreadyInitializedResult];
                continue;
            }

            NSDictionary *configuration = provider.provider == SATagProviderAppsFlyer
                ? appsFlyerConfiguration
                : (provider.provider == SATagProviderFacebook
                   ? [SATagConfigurationReader facebookConfiguration]
                   : [SATagConfigurationReader tikTokConfiguration]);
            [results addObject:[provider initializeWithConfiguration:configuration]];
        }

        self.latestResults = [results copy];
        NSMutableDictionary<NSNumber *, SATagInitializationResult *> *resultsByProvider =
            [NSMutableDictionary dictionaryWithCapacity:results.count];
        BOOL hasInitializedProvider = NO;
        for (SATagInitializationResult *result in results) {
            resultsByProvider[@(result.provider)] = result;
            if (result.state == SATagInitializationStateInitialized ||
                result.state == SATagInitializationStateAlreadyInitialized) {
                hasInitializedProvider = YES;
            }
        }
        self.resultsByProvider = [resultsByProvider copy];
        self.initialized = hasInitializedProvider;
        return results;
    } @finally {
        [self.lock unlock];
    }
}

- (SATagEventResult *)trackEvent:(NSString *)eventName
                      parameters:(NSDictionary<NSString *,id> *)parameters
                       forProvider:(SATagProvider)provider {
    [self.lock lock];
    @try {
        id<SATagProviderAdapter> selectedProvider = nil;
        for (id<SATagProviderAdapter> candidate in self.providers) {
            if (candidate.provider == provider) {
                selectedProvider = candidate;
                break;
            }
        }

        if (!selectedProvider) {
            return [[SATagEventResult alloc] initWithProvider:provider
                                                       state:SATagEventStateNotIntegrated
                                                providerName:SATagProviderDisplayName(provider)
                                                   eventName:eventName ?: @""
                                                      reason:@"未找到对应的 Provider。"];
        }

        SATagInitializationResult *initializationResult = self.resultsByProvider[@(provider)];
        if (!initializationResult) {
            return [[SATagEventResult alloc] initWithProvider:provider
                                                       state:SATagEventStateNotInitialized
                                                providerName:SATagProviderDisplayName(provider)
                                                   eventName:eventName ?: @""
                                                      reason:@"请先初始化 SATagSDK。"];
        }

        if (initializationResult.state == SATagInitializationStateNotIntegrated) {
            return [[SATagEventResult alloc] initWithProvider:provider
                                                       state:SATagEventStateNotIntegrated
                                                providerName:SATagProviderDisplayName(provider)
                                                   eventName:eventName ?: @""
                                                      reason:initializationResult.reason];
        }

        if (initializationResult.state != SATagInitializationStateInitialized &&
            initializationResult.state != SATagInitializationStateAlreadyInitialized) {
            return [[SATagEventResult alloc] initWithProvider:provider
                                                       state:SATagEventStateNotInitialized
                                                providerName:SATagProviderDisplayName(provider)
                                                   eventName:eventName ?: @""
                                                      reason:[NSString stringWithFormat:@"该渠道尚未完成初始化：%@",
                                                              initializationResult.reason]];
        }

        return [selectedProvider trackEvent:eventName parameters:parameters ?: @{}];
    } @finally {
        [self.lock unlock];
    }
}

- (NSArray<SATagEventResult *> *)trackEvent:(NSString *)eventName
                                parameters:(NSDictionary<NSString *,id> *)parameters {
    NSMutableArray<SATagEventResult *> *results = [NSMutableArray arrayWithCapacity:self.providers.count];
    for (id<SATagProviderAdapter> provider in self.providers) {
        [results addObject:[self trackEvent:eventName
                                 parameters:parameters
                                  forProvider:provider.provider]];
    }
    return results;
}

- (NSArray<SATagInitializationResult *> *)latestInitializationResults {
    [self.lock lock];
    NSArray *results = [self.latestResults copy];
    [self.lock unlock];
    return results;
}

@end
