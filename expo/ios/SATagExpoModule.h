//
// SATagExpoModule.h
// SATagSDK Expo bridge
//

#import <Foundation/Foundation.h>
#import <React/RCTBridgeModule.h>

NS_ASSUME_NONNULL_BEGIN

/// Expo/React Native 原生桥接模块。业务逻辑由 SATagSDK Objective-C 门面执行。
///
/// 显式遵循 RCTBridgeModule 协议，React Native 才能将 RCT_EXPORT_MODULE
/// 注册为可供 JavaScript 调用的 NativeModules 模块。
@interface SATagExpoModule : NSObject <RCTBridgeModule>
@end

NS_ASSUME_NONNULL_END
