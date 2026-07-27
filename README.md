# SATagSDK

接入资料：

- 开发人员：[SATagSDK-Integration.html](SATagSDK-Integration.html)
- 大模型：[SATagSDK-Integration.md](SATagSDK-Integration.md)

## CocoaPods

完整集成：

```ruby
pod 'SATagSDK'
```

按需选择：

```ruby
pod 'SATagSDK', :subspecs => ['AppsFlyer', 'Facebook']
```

AppsFlyer 是必接渠道。按需选择时也必须保留 `AppsFlyer` subspec；Facebook、
TikTok 和 Firebase 是可选渠道：

```ruby
pod 'SATagSDK', :subspecs => ['AppsFlyer']
pod 'SATagSDK', :subspecs => ['AppsFlyer', 'TikTok']
pod 'SATagSDK', :subspecs => ['AppsFlyer', 'Firebase']
```

## 渠道配置

初始化接口只接收 AppsFlyer 参数：

- `devKey`
- `appleAppID`

当任一 AppsFlyer 参数为空时，初始化回调返回 AppsFlyer 缺少配置错误，
Facebook/TikTok/Firebase 不会执行初始化。AppsFlyer 参数有效后，SDK 才会分别
检查当前是否集成了 Facebook/TikTok/Firebase，以及它们的配置是否完整。

只有选择对应 CocoaPods subspec 并完成配置的渠道才会初始化和接收事件。

## 初始化

AppsFlyer 是必接渠道。`devKey` 或 `appleAppID` 任一为空时，SATagSDK 会直接
返回 AppsFlyer 缺少配置错误，并跳过其它渠道初始化；补齐参数后可以
再次调用初始化接口。

Objective-C：

```objc
[[SATagSDK sharedInstance] initializeWithAppsFlyerDevKey:@"YOUR_DEV_KEY"
                                              appleAppID:@"YOUR_APP_ID"
                                              completion:^(NSArray<SATagInitializationResult *> *results) {
    NSLog(@"%@", results);
}];
```

Swift：

```swift
SATagSDK.sharedInstance().initialize(
    withAppsFlyerDevKey: "YOUR_DEV_KEY",
    appleAppID: "YOUR_APP_ID"
) { results in
    print(results)
}
```

## Info.plist

只有集成 Facebook subspec 时需要：

- `FacebookAppID`
- `FacebookClientToken`
- `FacebookDisplayName`

只有集成 TikTok subspec 时需要：

- `TikTokAccessToken`
- `TikTokAppID`
- `TikTokTTAppID`

只有集成 Firebase subspec 时需要：

- `GoogleService-Info.plist`

## Expo 支持

仓库提供 `expo/` 原生桥接包，供 Expo iOS development build 或 EAS Build 使用。
Expo 接入方不需要获取 SATagSDK 源码或执行本仓库的 XCFramework 构建脚本。
Expo Go 不包含本项目的自定义原生模块，不能直接加载。

Firebase 配置使用 Expo 的 `ios.googleServicesFile`：

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

JavaScript 调用方式：

```ts
import * as SATagSDK from 'satag-sdk-expo';

await SATagSDK.initialize({
  appsFlyerDevKey: 'YOUR_APPSFLYER_DEV_KEY',
  appleAppID: 'YOUR_APPLE_APP_ID'
});

await SATagSDK.trackFirebase('screen_view', {
  screen_name: 'Home'
});
```

## SDK 发布者构建 XCFramework

以下内容仅供 SDK 发布者维护发布包使用，接入方不需要执行。接入方请直接获取
发布方提供的 ZIP，并阅读 HTML 接入页或 Markdown 接入规范。

```bash
./Scripts/BuildSATagSDKXCFramework.sh
```

脚本会在临时目录完成构建和校验，最终只在 `Build/` 下生成：

```text
SATagSDK-{version}.zip
```

压缩包包含以下文件：

| 文件 | 用途 |
| --- | --- |
| `SATagSDK.xcframework` | 开发人员拖入宿主工程使用的 SDK 二进制包，已包含三方渠道依赖和隐私资源。 |
| `SATagSDK-Integration.html` | 开发人员使用浏览器打开的可视化接入说明。 |
| `SATagSDK-Integration.md` | 给大模型、代码助手或自动化接入工具读取的结构化接入规范。 |

直接集成 XCFramework 时不需要再单独添加三方 SDK。开发人员阅读 HTML，
大模型或代码助手读取 Markdown。
