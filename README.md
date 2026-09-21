# SATagSDK

接入资料：

- 开发人员：[SATagSDK-Integration.html](SATagSDK-Integration.html)
- 大模型 / 代码助手：[SKILL.md](SKILL.md)、[SATagSDK-Integration.md](SATagSDK-Integration.md)

正式分发只走内网私有 CocoaPods 与私有 npm，不再使用 CocoaPods Trunk 或公网 `satag-sdk-expo`。

## CocoaPods

```ruby
source 'https://cdn.cocoapods.org/'
source 'http://172.20.30.113:13000/StarSdk/star_ios_pod_specs.git'

target 'YourApp' do
  pod 'SATagSDK'
end
```

私有二进制 Pod 已包含 AppsFlyer、Facebook、TikTok 和 Firebase，不要再单独添加这些渠道依赖，也不要再使用公网时期的 subspec。

## 渠道配置

初始化接口只接收 AppsFlyer 参数：

- `devKey`
- `appleAppID`

任一 AppsFlyer 参数为空时，初始化回调返回 AppsFlyer 缺少配置错误，其它渠道不会执行初始化。

只有完成配置的渠道才会初始化和接收事件。

## 初始化

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

Facebook：

- `FacebookAppID`
- `FacebookClientToken`
- `FacebookDisplayName`

TikTok：

- `TikTokAccessToken`
- `TikTokAppID`
- `TikTokTTAppID`

Firebase：

- `GoogleService-Info.plist`

## Expo 支持

```ini
@starsdk:registry=http://172.20.30.113:13000/api/packages/StarSdk/npm/
```

```bash
npm install @starsdk/ios-satagsdk-expo
npx expo prebuild --platform ios
```

```json
{
  "expo": {
    "plugins": [
      [
        "@starsdk/ios-satagsdk-expo",
        {
          "googleServicesFile": "./GoogleService-Info.plist"
        }
      ]
    ]
  }
}
```

```ts
import * as SATagSDK from '@starsdk/ios-satagsdk-expo';

await SATagSDK.initialize({
  appsFlyerDevKey: 'YOUR_APPSFLYER_DEV_KEY',
  appleAppID: 'YOUR_APPLE_APP_ID'
});
```

Expo Go 不包含本项目的自定义原生模块，不能直接加载。

## SDK 发布者

使用 Xcode `PublishSATagSDKPod` 的 **Build** 操作，或先构建 `BuildSATagSDKXCFramework` 再运行发布脚本。接入方不需要执行这些步骤。
