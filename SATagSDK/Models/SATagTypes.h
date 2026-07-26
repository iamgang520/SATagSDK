//
// SATagTypes.h
// SATagSDK
//
// 对外暴露的渠道和状态枚举，使用 NS_ENUM 保证 Swift 可以获得类型安全的枚举。
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, SATagProvider) {
    SATagProviderAppsFlyer = 0,
    SATagProviderFacebook = 1,
    SATagProviderTikTok = 2
};

typedef NS_ENUM(NSInteger, SATagInitializationState) {
    SATagInitializationStateInitialized = 0,
    SATagInitializationStateMissingConfiguration,
    SATagInitializationStateNotIntegrated,
    SATagInitializationStateFailed,
    SATagInitializationStateAlreadyInitialized
};

typedef NS_ENUM(NSInteger, SATagEventState) {
    SATagEventStateAccepted = 0,
    SATagEventStateNotInitialized,
    SATagEventStateNotIntegrated,
    SATagEventStateFailed,
    SATagEventStateInvalidEvent
};

FOUNDATION_EXPORT NSString *SATagProviderDisplayName(SATagProvider provider);

NS_ASSUME_NONNULL_END
