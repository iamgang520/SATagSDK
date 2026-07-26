# SATagSDK

## CocoaPods

完整集成：

```ruby
pod 'SATagSDK'
```

按需选择：

```ruby
pod 'SATagSDK', :subspecs => ['AppsFlyer', 'Facebook']
```

AppsFlyer 是必接渠道。按需选择时也必须保留 `AppsFlyer` subspec；Facebook 和
TikTok 是可选渠道：

```ruby
pod 'SATagSDK', :subspecs => ['AppsFlyer']
pod 'SATagSDK', :subspecs => ['AppsFlyer', 'TikTok']
```

## 渠道配置

初始化接口只接收 AppsFlyer 参数：

- `devKey`
- `appleAppID`

当任一 AppsFlyer 参数为空时，初始化回调返回 AppsFlyer 缺少配置错误，
Facebook/TikTok 不会执行初始化。AppsFlyer 参数有效后，SDK 才会分别检查
当前是否集成了 Facebook/TikTok，以及它们的 Info.plist 配置是否完整。

只有选择对应 CocoaPods subspec 并完成配置的渠道才会初始化和接收事件。

## 初始化

AppsFlyer 是必接渠道。`devKey` 或 `appleAppID` 任一为空时，SATagSDK 会直接
返回 AppsFlyer 缺少配置错误，并跳过 Facebook/TikTok 初始化；补齐参数后可以
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

## 构建 XCFramework

```bash
./Scripts/BuildSATagSDKXCFramework.sh
```

生成的 `Build/SATagSDK.xcframework` 已包含 AppsFlyer、Facebook、TikTok 的
二进制依赖和隐私资源。直接集成这个 XCFramework 时不需要再单独添加三方
SDK；若使用 CocoaPods，则由 subspec 负责选择三方依赖。
