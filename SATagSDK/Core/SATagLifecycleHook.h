//
// SATagLifecycleHook.h
// SATagSDK
//
// 在不要求宿主修改 AppDelegate 的前提下，Hook 启动回调并保留原始实现。
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

typedef void (^SATagApplicationLaunchHandler)(UIApplication *application,
                                               NSDictionary<UIApplicationLaunchOptionsKey, id> * _Nullable launchOptions);

@interface SATagLifecycleHook : NSObject

+ (void)installWithLaunchHandler:(SATagApplicationLaunchHandler)handler;

@end

NS_ASSUME_NONNULL_END
