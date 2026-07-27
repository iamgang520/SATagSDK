//
//  SATagSDK.h
//  SATagSDK
//
//  Created by iamgang on 2026/7/26.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

#import <SATagSDK/SATagTypes.h>
#import <SATagSDK/SATagInitializationResult.h>
#import <SATagSDK/SATagEventResult.h>

//! Project version number for SATagSDK.
FOUNDATION_EXPORT double SATagSDKVersionNumber;

//! Project version string for SATagSDK.
FOUNDATION_EXPORT const unsigned char SATagSDKVersionString[];

NS_ASSUME_NONNULL_BEGIN

/**
 * 聚合 AppsFlyer、Facebook、TikTok 和 Firebase Analytics 的统一打点入口。
 *
 * SDK 主体使用 Objective-C 实现，公开头文件使用 nullability、轻量泛型和
 * NS_ENUM，Swift 工程可以直接通过 SATagSDK.sharedInstance() 调用。
 */
@interface SATagSDK : NSObject

/// 返回进程内唯一的 SDK 实例。
+ (instancetype)sharedInstance;

/**
 * 初始化已集成且配置完整的打点 SDK。
 *
 * AppsFlyer 的 devKey 和 Apple App ID 由本方法传入；Facebook/TikTok 的配置
 * 从宿主 App 的 Info.plist 读取；Firebase Analytics 的配置从
 * GoogleService-Info.plist 读取。completion 会在主线程回调，每个渠道都会返回
 * 明确的“已初始化、未集成、缺少配置或失败”状态。
 *
 * AppsFlyer 是必接渠道。devKey 或 appleAppID 任一为空时，SDK 会直接返回
 * AppsFlyer 缺少配置错误，并跳过 Facebook/TikTok 初始化；补齐参数后可以
 * 再次调用本方法。
 *
 * @param devKey AppsFlyer Dev Key。
 * @param appleAppID AppsFlyer Apple App ID。
 * @param completion 初始化结果回调。
 */
- (void)initializeWithAppsFlyerDevKey:(NSString *)devKey
                           appleAppID:(NSString *)appleAppID
                           completion:(void (^)(NSArray<SATagInitializationResult *> *results))completion
    NS_SWIFT_NAME(initialize(withAppsFlyerDevKey:appleAppID:completion:));

/**
 * 将自定义事件广播到所有已成功初始化的渠道。
 *
 * 事件参数会原样传递给各个 Provider；未初始化或未集成的渠道不会阻断其它
 * 渠道，结果数组会逐个说明每个渠道是否接受了本次事件。
 */
- (void)trackEvent:(NSString *)eventName
        parameters:(NSDictionary<NSString *, id> *)parameters
        completion:(void (^)(NSArray<SATagEventResult *> *results))completion
    NS_SWIFT_NAME(track(event:parameters:completion:));

/// 只向 AppsFlyer 发送自定义事件。
- (void)trackAppsFlyerEvent:(NSString *)eventName
                 parameters:(NSDictionary<NSString *, id> *)parameters
                 completion:(void (^)(SATagEventResult *result))completion
    NS_SWIFT_NAME(trackAppsFlyer(event:parameters:completion:));

/// 只向 Facebook 发送自定义事件。
- (void)trackFacebookEvent:(NSString *)eventName
                parameters:(NSDictionary<NSString *, id> *)parameters
                completion:(void (^)(SATagEventResult *result))completion
    NS_SWIFT_NAME(trackFacebook(event:parameters:completion:));

/// 只向 TikTok 发送自定义事件。
- (void)trackTikTokEvent:(NSString *)eventName
              parameters:(NSDictionary<NSString *, id> *)parameters
              completion:(void (^)(SATagEventResult *result))completion
    NS_SWIFT_NAME(trackTikTok(event:parameters:completion:));

/// 只向 Firebase Analytics 发送自定义事件。
- (void)trackFirebaseEvent:(NSString *)eventName
                parameters:(NSDictionary<NSString *, id> *)parameters
                completion:(void (^)(SATagEventResult *result))completion
    NS_SWIFT_NAME(trackFirebase(event:parameters:completion:));

/**
 * 从当前界面弹出 SDK 调试页。
 *
 * 调试页只展示脱敏后的配置，不会展示完整 Token、Key 或其它敏感值。
 */
- (void)presentDebugViewFromViewController:(UIViewController *)viewController
    NS_SWIFT_NAME(presentDebugView(from:));

@end

NS_ASSUME_NONNULL_END
