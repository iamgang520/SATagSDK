# SATagSDK 接入规范（供大模型执行）

> 本文件是 SATagSDK 的机器接入规范，不是营销文档。大模型接入项目时必须优先遵守本文件中的“硬性规则”和“决策流程”，不得根据未列出的配置键、方法名或第三方 SDK 版本自行推断。

## 1. 规范元数据

```yaml
sdk_name: SATagSDK
sdk_version: 1.1.0
implementation_language: Objective-C
swift_interop: Objective-C module import, no Swift wrapper required
minimum_ios_version: "13.0"
required_provider: AppsFlyer
optional_providers:
  - Facebook
  - TikTok
  - Firebase
developer_document: SATagSDK-Integration.html
expo_package: satag-sdk-expo
```

## 2. 硬性规则

1. AppsFlyer 是必接渠道。
2. AppsFlyer 初始化参数必须通过公开初始化接口传入，不能只写入 `Info.plist`。
3. AppsFlyer 的 `devKey` 和 `appleAppID` 必须同时存在且不能是空白字符。
4. AppsFlyer 参数不完整时，SATagSDK 不初始化任何渠道，也不安装生命周期 Hook。
5. Facebook、TikTok 和 Firebase 只有在对应依赖已经集成且配置完整时才允许初始化。
6. 事件接口不会抛异常；必须读取结果对象判断每个渠道的状态。
7. 不要在宿主 App 中重复调用第三方 SDK 的初始化入口；由 SATagSDK 负责调用。
8. 不要把完整 Key、Token 或 App ID 输出到日志、工单或用户界面。
9. Swift 工程直接 `import SATagSDK`，不需要创建桥接层或 Swift 包装类。
10. 接入完成后必须执行“验收清单”，不能只根据编译成功判断接入成功。

## 3. 集成方式选择

### 3.1 优先选择 CocoaPods

适用条件：宿主工程使用 CocoaPods，并且允许通过 subspec 选择三方渠道。

完整集成：

```ruby
pod 'SATagSDK', '~> 1.1'
```

只集成 AppsFlyer 和 Facebook：

```ruby
pod 'SATagSDK', :subspecs => ['AppsFlyer', 'Facebook']
```

只集成 AppsFlyer：

```ruby
pod 'SATagSDK', :subspecs => ['AppsFlyer']
```

只集成 AppsFlyer 和 TikTok：

```ruby
pod 'SATagSDK', :subspecs => ['AppsFlyer', 'TikTok']
```

只集成 AppsFlyer 和 Firebase：

```ruby
pod 'SATagSDK', :subspecs => ['AppsFlyer', 'Firebase']
```

规则：

- `AppsFlyer` subspec 必须存在。
- `Facebook`、`TikTok` 和 `Firebase` subspec 可以省略。
- `pod 'SATagSDK'` 默认等价于集成 `Core + AppsFlyer + Facebook + TikTok + Firebase`。
- 执行 `pod install` 后，必须使用 `.xcworkspace` 打开工程。

### 3.2 使用已交付的 XCFramework 发布包

适用条件：宿主工程不使用 CocoaPods，或需要单包交付。

接入方只需要从 SDK 发布方获取已经生成的 `SATagSDK-1.1.0.zip`。接入方不需要：

- 获取 SATagSDK 源码工程。
- 获取或打开 SATagSDKDemo 工程。
- 执行 SATagSDK 的构建脚本。
- 自行编译 AppsFlyer、Facebook、TikTok 或 Firebase 依赖。

如果发布包不存在，应向 SDK 发布方索取对应版本的 ZIP，而不是要求业务开发人员修改或构建 SATagSDK 源码。

解压后，ZIP 根目录包含以下文件：

| 文件 | 用途 | 使用者 |
| --- | --- | --- |
| `SATagSDK.xcframework` | 实际拖入宿主 App 工程的 SDK 二进制包。 | 开发人员 |
| `SATagSDK-Integration.html` | 可直接用浏览器打开的可视化接入说明，包含集成步骤、配置和代码示例。 | 开发人员 |
| `SATagSDK-Integration.md` | 结构化接入规范，供大模型、代码助手或自动化接入工具读取和执行。开发人员通常不需要直接阅读。 | 大模型、代码助手 |

大模型或代码助手处理接入任务时，应读取 `SATagSDK-Integration.md`；开发人员查看接入步骤时，应打开 `SATagSDK-Integration.html`。两个文档都不要求接入方获取 SATagSDK 源码工程。

将 ZIP 中的 `SATagSDK.xcframework` 添加到宿主 Target 的 `Frameworks, Libraries, and Embedded Content`。Swift 工程使用：

```swift
import SATagSDK
```

Objective-C 工程使用：

```objc
#import <SATagSDK/SATagSDK.h>
```

XCFramework 已包含构建时使用的 AppsFlyer、Facebook、TikTok、Firebase 二进制依赖，不要在同一个宿主工程中再次添加这些渠道的 CocoaPods 依赖。

### 3.3 Expo iOS 接入

Expo 接入使用 SDK 发布方提供的 `satag-sdk-expo` npm 原生桥接包。桥接层使用
Objective-C React Native Native Module，底层仍调用 SATagSDK Objective-C API。
仓库中的 `expo/` 目录仅用于 SDK 发布方维护和发布 npm 包，接入方不需要获取
SATagSDK 源码工程。

安装发布方提供的包：

```bash
npm install satag-sdk-expo
```

如果发布方使用私有 npm registry，应使用发布方提供的 registry 配置；如果包尚未
公开发布，应向发布方索取 npm tarball 或内部包地址，不要执行 SATagSDK 的构建脚本。

支持范围：

- Expo Prebuild。
- Expo development build。
- EAS iOS Build。
- 当前只支持 iOS；Android 没有 SATagSDK 原生 Provider。
- Expo Go 不包含本项目自定义原生模块，不能直接加载。

Firebase 配置应由 Expo 项目提供 `GoogleService-Info.plist`：

```json
{
  "expo": {
    "plugins": [
      [
        "satag-sdk-expo",
        {
          "googleServicesFile": "./GoogleService-Info.plist"
        }
      ]
    ],
    "ios": {
      "googleServicesFile": "./GoogleService-Info.plist"
    }
  }
}
```

Expo JavaScript 调用：

```ts
import * as SATagSDK from 'satag-sdk-expo';

const initializationResults = await SATagSDK.initialize({
  appsFlyerDevKey: 'YOUR_APPSFLYER_DEV_KEY',
  appleAppID: 'YOUR_APPLE_APP_ID'
});

const results = await SATagSDK.track('purchase', {
  product_id: 'sku_001',
  price: 6,
  currency: 'CNY'
});

await SATagSDK.trackFirebase('screen_view', {
  screen_name: 'Home'
});
```

原生依赖变化后必须重新执行 `npx expo prebuild` 并构建 development build，不能只重新加载 Metro。

## 4. 渠道与配置矩阵

| 渠道 | 是否必接 | 依赖来源 | 配置来源 | 初始化必要配置 |
| --- | --- | --- | --- | --- |
| AppsFlyer | 是 | `SATagSDK/AppsFlyer` 或完整 XCFramework | 初始化接口 | `devKey`、`appleAppID` |
| Facebook | 否 | `SATagSDK/Facebook` 或完整 XCFramework | `Info.plist` | `FacebookAppID` |
| TikTok | 否 | `SATagSDK/TikTok` 或完整 XCFramework | `Info.plist` | `TikTokAccessToken`、`TikTokAppID`、`TikTokTTAppID` |
| Firebase | 否 | `SATagSDK/Firebase` 或完整 XCFramework | `GoogleService-Info.plist` | `GOOGLE_APP_ID` |

### 4.1 Facebook Info.plist

推荐配置：

```xml
<key>FacebookAppID</key>
<string>YOUR_FACEBOOK_APP_ID</string>
<key>FacebookClientToken</key>
<string>YOUR_FACEBOOK_CLIENT_TOKEN</string>
<key>FacebookDisplayName</key>
<string>Your App Name</string>
```

SATagSDK 读取的键：

- `FacebookAppID`：初始化必需。
- `FacebookClientToken`：建议配置。
- `FacebookDisplayName`：建议配置。

### 4.2 TikTok Info.plist

标准配置：

```xml
<key>TikTokAccessToken</key>
<string>YOUR_TIKTOK_ACCESS_TOKEN</string>
<key>TikTokAppID</key>
<string>YOUR_TIKTOK_APP_ID</string>
<key>TikTokTTAppID</key>
<string>YOUR_TIKTOK_TT_APP_ID</string>
```

兼容别名：

- `TikTokBusinessAccessToken` 等价于 `TikTokAccessToken`。
- `TikTokBusinessAppID` 等价于 `TikTokAppID`。
- `TikTokBusinessTTAppID` 等价于 `TikTokTTAppID`。

不要同时使用同一配置的多个别名；优先使用标准键名。

### 4.3 Firebase 配置

从 Firebase 控制台下载 `GoogleService-Info.plist`，将其加入宿主 App 的主 Target。文件至少应包含 `GOOGLE_APP_ID`；SATagSDK 会通过 Firebase 的 `FIRApp` 和 `FIRAnalytics` 入口完成初始化与事件调用。

DebugView 会展示脱敏后的 `GOOGLE_APP_ID`、`PROJECT_ID`、`BUNDLE_ID` 和配置文件来源，不展示完整敏感配置。

## 5. 初始化流程

### 5.1 Objective-C 标准调用

```objc
#import <SATagSDK/SATagSDK.h>

[[SATagSDK sharedInstance]
    initializeWithAppsFlyerDevKey:@"YOUR_APPSFLYER_DEV_KEY"
                        appleAppID:@"YOUR_APPLE_APP_ID"
                        completion:^(NSArray<SATagInitializationResult *> *results) {
    for (SATagInitializationResult *result in results) {
        NSLog(@"%@ state=%ld reason=%@",
              result.providerName,
              (long)result.state,
              result.reason);
    }
}];
```

### 5.2 Swift 标准调用

```swift
import SATagSDK

SATagSDK.sharedInstance().initialize(
    withAppsFlyerDevKey: "YOUR_APPSFLYER_DEV_KEY",
    appleAppID: "YOUR_APPLE_APP_ID"
) { results in
    results.forEach { result in
        print("\(result.providerName): \(result.state) - \(result.reason)")
    }
}
```

### 5.3 初始化决策算法

大模型生成接入代码时，必须按以下顺序处理：

1. 从项目安全配置或构建配置取得 AppsFlyer `devKey`。
2. 从项目安全配置或构建配置取得 AppsFlyer `appleAppID`。
3. 通过 `initialize(withAppsFlyerDevKey:appleAppID:completion:)` 传入两个值。
4. 如果任一值为空或只包含空白字符，不得调用任何其它渠道初始化代码。
5. 在 completion 中遍历全部 `SATagInitializationResult`。
6. 只有 `state` 为 `SATagInitializationStateInitialized` 或 `SATagInitializationStateAlreadyInitialized` 时，才把该渠道标记为可打点。

补齐 AppsFlyer 参数后，允许再次调用初始化接口。重复初始化已成功渠道时返回 `SATagInitializationStateAlreadyInitialized`。

### 5.4 生命周期行为

- SATagSDK 在 AppsFlyer 参数有效后自动安装 App 生命周期 Hook。
- Hook 会保留宿主 `AppDelegate` 的原始实现。
- Hook 触发时会补偿执行一次渠道初始化。
- 宿主不需要为了 SATagSDK 修改或替换 `AppDelegate` 原有逻辑。

## 6. 初始化结果协议

`SATagInitializationResult` 字段：

| 字段 | 类型 | 用途 |
| --- | --- | --- |
| `provider` | `SATagProvider` | 渠道枚举 |
| `providerName` | `NSString *` / `String` | 渠道显示名称 |
| `state` | `SATagInitializationState` | 初始化状态 |
| `reason` | `NSString *` / `String` | 状态原因 |
| `configurationSummary` | `NSDictionary<NSString *, NSString *> *` / `[String: String]` | 脱敏配置摘要 |
| `timestamp` | `NSDate *` / `Date` | 结果时间 |

`SATagInitializationState`：

| 枚举值 | 处理要求 |
| --- | --- |
| `Initialized` | 允许向该渠道打点 |
| `MissingConfiguration` | 修复必需配置后重新初始化 |
| `NotIntegrated` | 添加对应 CocoaPods subspec 或改用完整 XCFramework |
| `Failed` | 记录 `reason`，不要让异常中断宿主 App |
| `AlreadyInitialized` | 允许继续打点，不要重复初始化 |

## 7. 事件接口

### 7.1 统一事件

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
        NSLog(@"%@ state=%ld reason=%@",
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

### 7.2 单渠道事件

Objective-C 方法：

```objc
- (void)trackAppsFlyerEvent:(NSString *)eventName
                 parameters:(NSDictionary<NSString *, id> *)parameters
                 completion:(void (^)(SATagEventResult *result))completion;

- (void)trackFacebookEvent:(NSString *)eventName
                parameters:(NSDictionary<NSString *, id> *)parameters
                completion:(void (^)(SATagEventResult *result))completion;

- (void)trackTikTokEvent:(NSString *)eventName
              parameters:(NSDictionary<NSString *, id> *)parameters
              completion:(void (^)(SATagEventResult *result))completion;

- (void)trackFirebaseEvent:(NSString *)eventName
                parameters:(NSDictionary<NSString *, id> *)parameters
                completion:(void (^)(SATagEventResult *result))completion;
```

Swift 方法名：

```swift
trackAppsFlyer(event:parameters:completion:)
trackFacebook(event:parameters:completion:)
trackTikTok(event:parameters:completion:)
trackFirebase(event:parameters:completion:)
```

### 7.3 事件结果协议

`SATagEventResult` 字段：

- `provider`
- `providerName`
- `state`
- `eventName`
- `reason`
- `timestamp`

`SATagEventState`：

| 枚举值 | 处理要求 |
| --- | --- |
| `Accepted` | 已调用第三方 SDK 事件入口 |
| `NotInitialized` | 先完成 SATagSDK 初始化 |
| `NotIntegrated` | 添加对应渠道依赖 |
| `Failed` | 记录原因并继续业务流程 |
| `InvalidEvent` | 使用非空事件名重新打点 |

事件名必须是非空字符串。事件参数必须使用 `NSDictionary<NSString *, id>`，Swift 对应 `[String: Any]`。

## 8. DebugView

Objective-C：

```objc
[[SATagSDK sharedInstance] presentDebugViewFromViewController:self];
```

Swift：

```swift
SATagSDK.sharedInstance().presentDebugView(from: self)
```

DebugView 展示：

- 当前检测到的渠道依赖。
- 配置来源。
- 初始化状态。
- 脱敏后的 ID、Key、Token。
- 最近一次初始化原因。

调用条件：必须传入当前已显示或可用于 `presentViewController:` 的 `UIViewController`。如果传入空对象，方法直接返回。

## 9. 自动化验收清单

接入完成后，大模型必须要求开发人员或 CI 验证：

- [ ] iOS Deployment Target 为 `13.0` 或更高。
- [ ] AppsFlyer 依赖已集成。
- [ ] 初始化调用同时传入 `devKey` 和 `appleAppID`。
- [ ] AppsFlyer 参数缺失时，其它渠道不会初始化。
- [ ] Facebook 仅在需要时添加 `Facebook` subspec，并配置 `FacebookAppID`。
- [ ] TikTok 仅在需要时添加 `TikTok` subspec，并配置三个必要键。
- [ ] Firebase 仅在需要时添加 `Firebase` subspec，并将 `GoogleService-Info.plist` 加入宿主 Target。
- [ ] Expo 项目使用 development build/EAS Build，不使用 Expo Go 加载 SATagSDK。
- [ ] 初始化 completion 已检查每个渠道的 `state`。
- [ ] 统一事件和单渠道事件均使用非空事件名。
- [ ] 未初始化渠道打点不会导致崩溃。
- [ ] DebugView 可从真实页面打开。
- [ ] 不输出完整敏感配置。
- [ ] XCFramework 集成时没有重复添加三方 SDK。
- [ ] 使用的是 SDK 发布方提供的 `SATagSDK-{version}.zip`，没有要求接入方构建 SATagSDK 源码。
- [ ] ZIP 根目录包含 `SATagSDK.xcframework`、`SATagSDK-Integration.html`、`SATagSDK-Integration.md`，并且每个文件用途明确。

## 10. 禁止推断的内容

以下内容未由 SATagSDK 公共协议定义，接入时不得自行编造：

- 第三方渠道的服务端网络成功状态。
- 第三方渠道的额外业务事件参数约束。
- 未在本文件列出的 `Info.plist` 键。
- 未在 SATagSDK 公共头文件中声明的方法。
- 事件缓存、离线重试、去重或持久化能力。
- 任何未集成渠道的初始化成功状态。
