//
// SATagInitializationCoordinatorTests.m
// SATagSDKTests
//
// 通过协调器的行为验证各 Provider 状态和事件分发规则。
//

#import <XCTest/XCTest.h>
#import "../SATagSDK/Core/SATagInitializationCoordinator.h"
#import "../SATagSDK/Core/SATagConfigurationReader.h"

@interface SATagTestProvider : NSObject <SATagProviderAdapter>

@property (nonatomic, assign) SATagProvider provider;
@property (nonatomic, assign) SATagInitializationState initializationState;
@property (nonatomic, assign) NSUInteger initializationCount;

@end

@implementation SATagTestProvider

- (SATagInitializationResult *)initializeWithConfiguration:(NSDictionary<NSString *,NSString *> *)configuration {
    self.initializationCount += 1;
    return [[SATagInitializationResult alloc] initWithProvider:self.provider
                                                         state:self.initializationState
                                                  providerName:SATagProviderDisplayName(self.provider)
                                                        reason:@"测试 Provider 结果"
                                          configurationSummary:@{
                                              @"token": [SATagConfigurationReader maskedValue:@"abcdef123456"]
                                          }];
}

- (SATagEventResult *)trackEvent:(NSString *)eventName
                      parameters:(NSDictionary<NSString *,id> *)parameters {
    return [[SATagEventResult alloc] initWithProvider:self.provider
                                                state:SATagEventStateAccepted
                                         providerName:SATagProviderDisplayName(self.provider)
                                            eventName:eventName
                                               reason:@"测试 Provider 接受事件"];
}

- (NSDictionary<NSString *,NSString *> *)configurationSummary {
    return @{@"token": @"已配置"};
}

@end

@interface SATagInitializationCoordinatorTests : XCTestCase
@end

@implementation SATagInitializationCoordinatorTests

- (void)testTrackBeforeInitializationReturnsNotInitialized {
    SATagTestProvider *provider = [self providerWithState:SATagInitializationStateInitialized
                                                 provider:SATagProviderAppsFlyer];
    SATagInitializationCoordinator *coordinator =
        [[SATagInitializationCoordinator alloc] initWithProviders:@[provider]];

    SATagEventResult *result = [coordinator trackEvent:@"before_init"
                                            parameters:@{}
                                         forProvider:SATagProviderAppsFlyer];

    XCTAssertEqual(result.state, SATagEventStateNotInitialized);
}

- (void)testMissingConfigurationDoesNotSendEvents {
    SATagTestProvider *provider = [self providerWithState:SATagInitializationStateMissingConfiguration
                                                 provider:SATagProviderAppsFlyer];
    SATagInitializationCoordinator *coordinator =
        [[SATagInitializationCoordinator alloc] initWithProviders:@[provider]];
    [coordinator initializeWithAppsFlyerConfiguration:@{
        @"devKey": @"valid-dev-key",
        @"appleAppID": @"123456789"
    }];

    SATagEventResult *result = [coordinator trackEvent:@"missing_config"
                                            parameters:@{}
                                         forProvider:SATagProviderAppsFlyer];

    XCTAssertEqual(result.state, SATagEventStateNotInitialized);
    XCTAssertEqual(provider.initializationCount, 1U);
}

- (void)testAppsFlyerIsRequiredBeforeAnyProviderInitializes {
    SATagTestProvider *appsFlyerProvider =
        [self providerWithState:SATagInitializationStateInitialized provider:SATagProviderAppsFlyer];
    SATagTestProvider *facebookProvider =
        [self providerWithState:SATagInitializationStateInitialized provider:SATagProviderFacebook];
    SATagTestProvider *tikTokProvider =
        [self providerWithState:SATagInitializationStateInitialized provider:SATagProviderTikTok];
    SATagInitializationCoordinator *coordinator =
        [[SATagInitializationCoordinator alloc] initWithProviders:@[
            appsFlyerProvider, facebookProvider, tikTokProvider
        ]];

    NSArray<SATagInitializationResult *> *results =
        [coordinator initializeWithAppsFlyerConfiguration:@{
            @"devKey": @"",
            @"appleAppID": @""
        }];

    XCTAssertEqual(results[0].state, SATagInitializationStateMissingConfiguration);
    XCTAssertEqual(results[1].state, SATagInitializationStateFailed);
    XCTAssertEqual(results[2].state, SATagInitializationStateFailed);
    XCTAssertEqual(appsFlyerProvider.initializationCount, 0U);
    XCTAssertEqual(facebookProvider.initializationCount, 0U);
    XCTAssertEqual(tikTokProvider.initializationCount, 0U);
    XCTAssertEqual([coordinator trackEvent:@"blocked"
                                parameters:@{}
                             forProvider:SATagProviderFacebook].state,
                   SATagEventStateNotInitialized);
}

- (void)testNotIntegratedProviderIsReportedAndDoesNotSendEvents {
    SATagTestProvider *provider = [self providerWithState:SATagInitializationStateNotIntegrated
                                                 provider:SATagProviderFacebook];
    SATagInitializationCoordinator *coordinator =
        [[SATagInitializationCoordinator alloc] initWithProviders:@[provider]];
    NSArray<SATagInitializationResult *> *results =
        [coordinator initializeWithAppsFlyerConfiguration:@{
            @"devKey": @"valid-dev-key",
            @"appleAppID": @"123456789"
        }];

    XCTAssertEqual(results.firstObject.state, SATagInitializationStateNotIntegrated);
    XCTAssertEqual([coordinator trackEvent:@"not_integrated"
                                parameters:@{}
                             forProvider:SATagProviderFacebook].state,
                   SATagEventStateNotIntegrated);
}

- (void)testSuccessfulProviderIsInitializedOnlyOnce {
    SATagTestProvider *provider = [self providerWithState:SATagInitializationStateInitialized
                                                 provider:SATagProviderTikTok];
    SATagInitializationCoordinator *coordinator =
        [[SATagInitializationCoordinator alloc] initWithProviders:@[provider]];

    NSArray<SATagInitializationResult *> *firstResults =
        [coordinator initializeWithAppsFlyerConfiguration:@{
            @"devKey": @"valid-dev-key",
            @"appleAppID": @"123456789"
        }];
    NSArray<SATagInitializationResult *> *secondResults =
        [coordinator initializeWithAppsFlyerConfiguration:@{
            @"devKey": @"valid-dev-key",
            @"appleAppID": @"123456789"
        }];
    SATagEventResult *eventResult = [coordinator trackEvent:@"success"
                                                  parameters:@{}
                                               forProvider:SATagProviderTikTok];

    XCTAssertEqual(firstResults.firstObject.state, SATagInitializationStateInitialized);
    XCTAssertEqual(secondResults.firstObject.state, SATagInitializationStateAlreadyInitialized);
    XCTAssertEqual(provider.initializationCount, 1U);
    XCTAssertEqual(eventResult.state, SATagEventStateAccepted);
}

- (void)testMaskedValueNeverExposesFullSecret {
    NSString *maskedValue = [SATagConfigurationReader maskedValue:@"abcdef123456"];

    XCTAssertEqualObjects(maskedValue, @"abc****456");
    XCTAssertFalse([maskedValue containsString:@"abcdef123456"]);
}

- (SATagTestProvider *)providerWithState:(SATagInitializationState)state
                               provider:(SATagProvider)provider {
    SATagTestProvider *testProvider = [[SATagTestProvider alloc] init];
    testProvider.provider = provider;
    testProvider.initializationState = state;
    return testProvider;
}

@end
