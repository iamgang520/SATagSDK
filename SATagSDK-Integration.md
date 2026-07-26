# SATagSDK 接入说明

SATagSDK 是一个基于 Objective-C 实现的聚合打点 SDK，统一封装以下渠道：

- AppsFlyer
- Facebook
- TikTok

公开头文件兼容 Objective-C 和 Swift，Swift 工程可以直接导入模块调用，不需要额外编写 Swift 包装层。

## 1. 环境要求

- iOS 13.0 及以上
- Xcode 及 CocoaPods
- AppsFlyer 为必接渠道
- Facebook 和 TikTok 为可选渠道

AppsFlyer 的 `devKey` 和 `appleAppID` 必须通过 SATagSDK 初始化接口传入。Facebook 和 TikTok 的配置通过宿主 App 的 `Info.plist` 提供。

## 2. CocoaPods 集成

### 2.1 集成全部渠道

在 `Podfile` 中添加：

```ruby
target 'YourApp' do
  pod 'SATagSDK', '~> 1.0'
end
```

默认会集成：

- `SATagSDK/Core`
- `SATagSDK/AppsFlyer`
- `SATagSDK/Facebook`
- `SATagSDK/TikTok`

执行安装：

```bash
pod install
```

以后请使用生成的 `.xcworkspace` 打开工程。

### 2.2 按需选择渠道

例如只接入 AppsFlyer 和 Facebook：

```ruby
target 'YourApp' do
  pod 'SATagSDK', :subspecs => ['AppsFlyer', 'Facebook']
end
```

只接入 AppsFlyer：

```ruby
target 'YourApp' do
  pod 'SATagSDK', :subspecs => ['AppsFlyer']
end
```

只接入 AppsFlyer 和 TikTok：

```ruby
target 'YourApp' do
  pod 'SATagSDK', :subspecs => ['AppsFlyer', 'TikTok']
end
```

`AppsFlyer` subspec 必须保留。没有 AppsFlyer subspec 时，即使传入了 AppsFlyer 参数，SATagSDK 也会返回“未集成”或初始化失败结果。

## 3. Info.plist 配置

### 3.1 Facebook

选择 `Facebook` subspec 后，建议在宿主 App 的 `Info.plist` 中添加：

```xml
<key>FacebookAppID</key>
<string>YOUR_FACEBOOK_APP_ID</string>
<key>FacebookClientToken</key>
<string>YOUR_FACEBOOK_CLIENT_TOKEN</string>
<key>FacebookDisplayName</key>
<string>Your App Name</string>
```

SATagSDK 会读取以下键：

| 键名 | 说明 |
| --- | --- |
| `FacebookAppID` | Facebook App ID，初始化必需 |
| `FacebookClientToken` | Facebook Client Token |
| `FacebookDisplayName` | Facebook 展示名称 |

### 3.2 TikTok

选择 `TikTok` subspec 后，在 `Info.plist` 中添加：

```xml
<key>TikTokAccessToken</key>
<string>YOUR_TIKTOK_ACCESS_TOKEN</string>
<key>TikTokAppID</key>
<string>YOUR_TIKTOK_APP_ID</string>
<key>TikTokTTAppID</key>
<string>YOUR_TIKTOK_TT_APP_ID</string>
```

TikTok 也兼容以下别名：

- `TikTokBusinessAccessToken`
- `TikTokBusinessAppID`
- `TikTokBusinessTTAppID`

TikTok 初始化要求访问令牌、App ID 和 TT App ID 三项配置都存在。

### 3.3 AppsFlyer

AppsFlyer 参数不由 SATagSDK 从 `Info.plist` 读取，必须通过初始化接口传入：

- `devKey`
- `appleAppID`

## 4. 初始化

建议在 App 启动阶段调用初始化接口。SATagSDK 会自动通过运行时 Hook 接管 App 生命周期，并保留宿主 `AppDelegate` 原有实现。

### 4.1 Objective-C

```objc
#import <SATagSDK/SATagSDK.h>

- (BOOL)application:(UIApplication *)application
    didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    [[SATagSDK sharedInstance]
        initializeWithAppsFlyerDevKey:@"YOUR_APPSFLYER_DEV_KEY"
                            appleAppID:@"YOUR_APPLE_APP_ID"
                            completion:^(NSArray<SATagInitializationResult *> *results) {
        for (SATagInitializationResult *result in results) {
            NSLog(@"渠道：%@，状态：%ld，原因：%@",
                  result.providerName,
                  (long)result.state,
                  result.reason);
        }
    }];

    return YES;
}
```

### 4.2 Swift

```swift
import SATagSDK

let sdk = SATagSDK.sharedInstance()

sdk.initialize(
    withAppsFlyerDevKey: "YOUR_APPSFLYER_DEV_KEY",
    appleAppID: "YOUR_APPLE_APP_ID"
) { results in
    results.forEach { result in
        print("\(result.providerName): \(result.state) - \(result.reason)")
    }
}
```

### 4.3 AppsFlyer 必接规则

以下任一情况成立时，SATagSDK 不会初始化任何渠道：

- `devKey` 为空
- `appleAppID` 为空
- 参数只有空白字符

此时：

- AppsFlyer 返回 `SATagInitializationStateMissingConfiguration`
- Facebook/TikTok 返回跳过初始化的失败结果
- 生命周期 Hook 不会安装
- 补齐 AppsFlyer 参数后可以再次调用初始化接口

初始化结果只代表本地 SDK 初始化调用是否完成，不代表第三方服务端网络请求已经成功。

## 5. 初始化状态

`SATagInitializationResult.state` 使用 `SATagInitializationState` 枚举：

| 状态 | 含义 |
| --- | --- |
| `SATagInitializationStateInitialized` | 已完成本地初始化调用 |
| `SATagInitializationStateMissingConfiguration` | 必要配置缺失 |
| `SATagInitializationStateNotIntegrated` | 当前工程没有集成对应第三方 SDK |
| `SATagInitializationStateFailed` | 初始化过程失败或被必接渠道规则跳过 |
| `SATagInitializationStateAlreadyInitialized` | 该渠道已经初始化过 |

可通过以下属性查看结果：

```objc
result.provider
result.providerName
result.state
result.reason
result.configurationSummary
result.timestamp
```

`configurationSummary` 只包含脱敏后的配置值，不会返回完整 Key、Token 或 ID。

## 6. 事件打点

事件参数使用 `NSDictionary<NSString *, id> *`，Swift 中对应 `[String: Any]`。

### 6.1 统一广播到所有渠道

Objective-C：

```objc
[[SATagSDK sharedInstance]
    trackEvent:@"purchase"
        parameters:@{
            @"product_id": @"sku_001",
            @"price": @6.0,
            @"currency": @"CNY"
        }
        completion:^(NSArray<SATagEventResult *> *results) {
        for (SATagEventResult *result in results) {
            NSLog(@"%@：%ld，%@",
                  result.providerName,
                  (long)result.state,
                  result.reason);
        }
    }];
```

Swift：

```swift
SATagSDK.sharedInstance().track(
    event: "purchase",
    parameters: [
        "product_id": "sku_001",
        "price": 6.0,
        "currency": "CNY"
    ]
) { results in
    results.forEach { result in
        print("\(result.providerName): \(result.state)")
    }
}
```

未集成或未初始化的渠道只会在自己的结果中返回失败状态，不会阻断其它已初始化渠道。

### 6.2 单独向指定渠道打点

Objective-C：

```objc
[[SATagSDK sharedInstance]
    trackAppsFlyerEvent:@"login"
              parameters:@{@"source": @"email"}
              completion:^(SATagEventResult *result) {
        NSLog(@"AppsFlyer：%@", result.reason);
    }];

[[SATagSDK sharedInstance]
    trackFacebookEvent:@"login"
             parameters:@{@"source": @"email"}
             completion:^(SATagEventResult *result) {
        NSLog(@"Facebook：%@", result.reason);
    }];

[[SATagSDK sharedInstance]
    trackTikTokEvent:@"login"
           parameters:@{@"source": @"email"}
           completion:^(SATagEventResult *result) {
        NSLog(@"TikTok：%@", result.reason);
    }];
```

Swift：

```swift
let parameters = ["source": "email"]

SATagSDK.sharedInstance().trackAppsFlyer(
    event: "login",
    parameters: parameters
) { result in
    print(result.reason)
}

SATagSDK.sharedInstance().trackFacebook(
    event: "login",
    parameters: parameters
) { result in
    print(result.reason)
}

SATagSDK.sharedInstance().trackTikTok(
    event: "login",
    parameters: parameters
) { result in
    print(result.reason)
}
```

### 6.3 事件状态

`SATagEventResult.state` 使用 `SATagEventState` 枚举：

| 状态 | 含义 |
| --- | --- |
| `SATagEventStateAccepted` | 已调用对应第三方 SDK 的事件接口 |
| `SATagEventStateNotInitialized` | 该渠道尚未完成初始化 |
| `SATagEventStateNotIntegrated` | 当前工程没有集成对应第三方 SDK |
| `SATagEventStateFailed` | 第三方 SDK 调用失败 |
| `SATagEventStateInvalidEvent` | 事件名为空 |

SATagSDK 的事件接口不会因为第三方 SDK 初始化或打点失败而抛出异常。

## 7. DebugView

从当前可见的 `UIViewController` 打开调试页：

Objective-C：

```objc
[[SATagSDK sharedInstance]
    presentDebugViewFromViewController:self];
```

Swift：

```swift
SATagSDK.sharedInstance().presentDebugView(from: self)
```

DebugView 会展示：

- AppsFlyer、Facebook、TikTok 是否已集成
- 每个渠道的初始化状态
- 初始化失败原因
- 配置来源
- 脱敏后的 App ID、Key、Token

DebugView 不展示完整敏感配置。未调用初始化接口时，页面会提示尚未初始化。

## 8. XCFramework 集成

### 8.1 构建

在仓库根目录执行：

```bash
chmod +x Scripts/BuildSATagSDKXCFramework.sh
./Scripts/BuildSATagSDKXCFramework.sh
```

脚本会分别构建设备和模拟器版本，并生成：

```text
Build/SATagSDK.xcframework
```

包含的平台：

- iOS 真机 `arm64`
- iOS Simulator `arm64`
- iOS Simulator `x86_64`

构建脚本会检查三方依赖和资源是否完整，任一关键产物缺失时直接失败，不生成不完整的 XCFramework。

### 8.2 宿主工程集成

1. 将 `Build/SATagSDK.xcframework` 拖入宿主工程。
2. 在目标 Target 的 `Frameworks, Libraries, and Embedded Content` 中确认已添加。
3. 按 Xcode 对 XCFramework 中动态依赖的提示完成 Embed 配置。
4. 在需要使用的 `.m` 文件中导入：

   ```objc
   #import <SATagSDK/SATagSDK.h>
   ```

5. Swift 工程直接导入：

   ```swift
   import SATagSDK
   ```

XCFramework 已包含构建时使用的 AppsFlyer、Facebook、TikTok 依赖，不需要在使用 XCFramework 的宿主工程中再次通过 CocoaPods 添加这三个渠道 SDK。

## 9. 常见问题

### 9.1 AppsFlyer 返回缺少配置

检查初始化调用中的 `devKey` 和 `appleAppID` 是否为空或只包含空白字符。AppsFlyer 是必接渠道，两个参数不完整时其它渠道也不会初始化。

### 9.2 返回“未集成”

检查 Podfile 是否包含对应 subspec：

```ruby
pod 'SATagSDK', :subspecs => ['AppsFlyer', 'Facebook', 'TikTok']
```

如果使用的是 XCFramework，确认使用的是包含完整依赖的 `Build/SATagSDK.xcframework`。

### 9.3 Facebook 返回缺少配置

检查 `Info.plist` 中是否存在 `FacebookAppID`。同时建议补齐 `FacebookClientToken` 和 `FacebookDisplayName`。

### 9.4 TikTok 返回缺少配置

确认以下三项均已填写：

- `TikTokAccessToken`
- `TikTokAppID`
- `TikTokTTAppID`

### 9.5 重复调用初始化

重复初始化不会重复执行第三方初始化逻辑，已完成初始化的渠道会返回 `SATagInitializationStateAlreadyInitialized`。

## 10. 版本信息

- 当前版本：`1.0.0`
- CocoaPods：`SATagSDK`
- 最低 iOS 版本：`13.0`
- GitHub：[iamgang520/SATagSDK](https://github.com/iamgang520/SATagSDK)
- CocoaPods：[SATagSDK](https://cocoapods.org/pods/SATagSDK)
