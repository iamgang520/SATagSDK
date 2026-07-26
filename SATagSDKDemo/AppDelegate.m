//
//  AppDelegate.m
//  SATagSDKDemo
//
//  Created by iamgang on 2026/7/26.
//

#import "AppDelegate.h"
#import <SATagSDK/SATagSDK.h>

@interface AppDelegate ()

@end

@implementation AppDelegate


- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    /*
     * Demo 使用 Info.plist 读取 AppsFlyer 参数，真实项目只需要把对应 Key
     * 写入自己的配置管理方式，SATagSDK 对外接口和宿主 AppDelegate 无需改变。
     * 当前 Demo 未配置时会在回调中看到“缺少配置”，用于验证失败状态。
     */
    NSString *devKey = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"AppsFlyerDevKey"] ?: @"";
    NSString *appleAppID = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"AppsFlyerAppleAppID"] ?: @"";
    [[SATagSDK sharedInstance] initializeWithAppsFlyerDevKey:devKey
                                                  appleAppID:appleAppID
                                                  completion:^(NSArray<SATagInitializationResult *> *results) {
        for (SATagInitializationResult *result in results) {
            NSLog(@"[SATagSDK Demo] %@: %@ - %@",
                  result.providerName,
                  @(result.state),
                  result.reason);
        }
    }];
    return YES;
}


#pragma mark - UISceneSession lifecycle


- (UISceneConfiguration *)application:(UIApplication *)application configurationForConnectingSceneSession:(UISceneSession *)connectingSceneSession options:(UISceneConnectionOptions *)options {
    // Called when a new scene session is being created.
    // Use this method to select a configuration to create the new scene with.
    return [[UISceneConfiguration alloc] initWithName:@"Default Configuration" sessionRole:connectingSceneSession.role];
}


- (void)application:(UIApplication *)application didDiscardSceneSessions:(NSSet<UISceneSession *> *)sceneSessions {
    // Called when the user discards a scene session.
    // If any sessions were discarded while the application was not running, this will be called shortly after application:didFinishLaunchingWithOptions.
    // Use this method to release any resources that were specific to the discarded scenes, as they will not return.
}


@end
