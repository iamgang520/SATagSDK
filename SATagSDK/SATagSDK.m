//
// SATagSDK.m
// SATagSDK
//

#import "SATagSDK.h"
#import "Core/SATagConfigurationReader.h"
#import "Core/SATagInitializationCoordinator.h"
#import "Core/SATagLifecycleHook.h"
#import "Providers/SATagAppsFlyerProvider.h"
#import "Providers/SATagFacebookProvider.h"
#import "Providers/SATagTikTokProvider.h"
#import "Providers/SATagFirebaseProvider.h"
#import "Views/SATagDebugViewController.h"

@interface SATagSDK ()

@property (nonatomic, strong) SATagInitializationCoordinator *coordinator;
@property (nonatomic, copy) NSDictionary<NSString *, NSString *> *appsFlyerConfiguration;
@property (nonatomic, assign) BOOL hasReceivedInitializationRequest;

- (instancetype)initPrivate;
- (void)satag_initializeIfNeededWithCompletion:(void (^ _Nullable)(NSArray<SATagInitializationResult *> *))completion;
- (void)satag_trackEvent:(NSString *)eventName
              parameters:(NSDictionary<NSString *, id> *)parameters
               provider:(SATagProvider)provider
            completion:(void (^)(SATagEventResult *result))completion;
- (void)satag_callOnMain:(dispatch_block_t)block;

@end

@implementation SATagSDK

+ (instancetype)sharedInstance {
    static SATagSDK *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[self alloc] initPrivate];
    });
    return instance;
}

- (instancetype)init {
    return [SATagSDK sharedInstance];
}

- (instancetype)initPrivate {
    self = [super init];
    if (self) {
        _coordinator = [[SATagInitializationCoordinator alloc] initWithProviders:@[
            [[SATagAppsFlyerProvider alloc] init],
            [[SATagFacebookProvider alloc] init],
            [[SATagTikTokProvider alloc] init],
            [[SATagFirebaseProvider alloc] init]
        ]];
    }
    return self;
}

- (void)initializeWithAppsFlyerDevKey:(NSString *)devKey
                           appleAppID:(NSString *)appleAppID
                           completion:(void (^)(NSArray<SATagInitializationResult *> *))completion {
    self.appsFlyerConfiguration =
        [SATagConfigurationReader appsFlyerConfigurationWithDevKey:devKey
                                                         appleAppID:appleAppID];

    /*
     * AppsFlyer 是必接渠道。参数不完整时直接返回错误结果，不安装生命周期
     * Hook，也不触发其它 Provider；补齐参数后宿主可以再次调用初始化接口。
     */
    BOOL hasValidAppsFlyerConfiguration =
        [SATagConfigurationReader isNonEmptyValue:self.appsFlyerConfiguration[@"devKey"]] &&
        [SATagConfigurationReader isNonEmptyValue:self.appsFlyerConfiguration[@"appleAppID"]];
    if (!hasValidAppsFlyerConfiguration) {
        NSArray<SATagInitializationResult *> *results =
            [self.coordinator initializeWithAppsFlyerConfiguration:self.appsFlyerConfiguration];
        [self satag_callOnMain:^{
            if (completion) {
                completion(results);
            }
        }];
        return;
    }

    self.hasReceivedInitializationRequest = YES;

    __weak typeof(self) weakSelf = self;
    [SATagLifecycleHook installWithLaunchHandler:^(UIApplication *application,
                                                   NSDictionary<UIApplicationLaunchOptionsKey,id> *launchOptions) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        [strongSelf satag_initializeIfNeededWithCompletion:nil];
    }];

    [self satag_initializeIfNeededWithCompletion:completion];
}

- (void)trackEvent:(NSString *)eventName
        parameters:(NSDictionary<NSString *,id> *)parameters
        completion:(void (^)(NSArray<SATagEventResult *> *))completion {
    NSArray<SATagEventResult *> *results = [self.coordinator trackEvent:eventName
                                                              parameters:parameters ?: @{}];
    [self satag_callOnMain:^{
        if (completion) {
            completion(results);
        }
    }];
}

- (void)trackAppsFlyerEvent:(NSString *)eventName
                 parameters:(NSDictionary<NSString *,id> *)parameters
                 completion:(void (^)(SATagEventResult *))completion {
    [self satag_trackEvent:eventName
                parameters:parameters
                 provider:SATagProviderAppsFlyer
              completion:completion];
}

- (void)trackFacebookEvent:(NSString *)eventName
                parameters:(NSDictionary<NSString *,id> *)parameters
                completion:(void (^)(SATagEventResult *))completion {
    [self satag_trackEvent:eventName
                parameters:parameters
                 provider:SATagProviderFacebook
              completion:completion];
}

- (void)trackTikTokEvent:(NSString *)eventName
              parameters:(NSDictionary<NSString *,id> *)parameters
              completion:(void (^)(SATagEventResult *))completion {
    [self satag_trackEvent:eventName
                parameters:parameters
                 provider:SATagProviderTikTok
              completion:completion];
}

- (void)trackFirebaseEvent:(NSString *)eventName
                parameters:(NSDictionary<NSString *,id> *)parameters
                completion:(void (^)(SATagEventResult *))completion {
    [self satag_trackEvent:eventName
                parameters:parameters
                 provider:SATagProviderFirebase
              completion:completion];
}

- (void)presentDebugViewFromViewController:(UIViewController *)viewController {
    if (!viewController) {
        return;
    }

    NSArray<SATagInitializationResult *> *results = self.coordinator.latestInitializationResults;
    SATagDebugViewController *debugViewController =
        [[SATagDebugViewController alloc] initWithResults:results];
    UINavigationController *navigationController =
        [[UINavigationController alloc] initWithRootViewController:debugViewController];
    [viewController presentViewController:navigationController animated:YES completion:nil];
}

- (void)satag_initializeIfNeededWithCompletion:(void (^ _Nullable)(NSArray<SATagInitializationResult *> *))completion {
    if (!self.hasReceivedInitializationRequest) {
        return;
    }

    NSArray<SATagInitializationResult *> *results =
        [self.coordinator initializeWithAppsFlyerConfiguration:self.appsFlyerConfiguration ?: @{}];
    [self satag_callOnMain:^{
        if (completion) {
            completion(results);
        }
    }];
}

- (void)satag_trackEvent:(NSString *)eventName
              parameters:(NSDictionary<NSString *,id> *)parameters
               provider:(SATagProvider)provider
            completion:(void (^)(SATagEventResult *))completion {
    SATagEventResult *result = [self.coordinator trackEvent:eventName
                                                 parameters:parameters ?: @{}
                                                  forProvider:provider];
    [self satag_callOnMain:^{
        if (completion) {
            completion(result);
        }
    }];
}

- (void)satag_callOnMain:(dispatch_block_t)block {
    if ([NSThread isMainThread]) {
        block();
    } else {
        dispatch_async(dispatch_get_main_queue(), block);
    }
}

@end
