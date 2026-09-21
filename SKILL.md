---
name: integrate-satagsdk-ios
description: 为 iOS 原生工程或 Expo Prebuild 工程接入、升级、验证星合 SATagSDK 聚合打点 SDK。适用于私有 CocoaPods、已交付 XCFramework 和 @starsdk/ios-satagsdk-expo；涉及初始化、AppsFlyer/Facebook/TikTok/Firebase 事件或 SDK 发布时必须使用。
---

# SATagSDK iOS 接入规范

本文件供代码助手执行接入与发布任务，不是营销文档。先读取 SDK 对外头文件、当前已发布 Podspec 和 npm 包清单；不得根据历史公网 Trunk、类似 SDK 或未公开的内部类型猜测 API、版本或最低系统要求。

## 事实来源

按以下优先级取得事实；出现冲突时，以靠前者为准：

1. `SATagSDK/SATagSDK.h`：原生公开 API、初始化参数和事件入口。
2. `/Users/iamgang/Documents/星合互娱/star_ios_pod_specs/SATagSDK/<版本>/SATagSDK.podspec`：已发布私有 Pod 的版本、最低系统版本和二进制路径。
3. `expo/package.json`、`expo/SATagSDKExpo.podspec`、`expo/README.md`：Expo 包名、原生依赖和支持范围。
4. `SATagSDK/Config/SATagVersion.json`：下一个/当前 SDK 发布版本。
5. `Scripts/PublishSATagSDKPod.sh`：唯一的 Pod + npm 联合发布流程。

最低 iOS 版本必须从 `SATagSDK` Scheme 的 Release 生效构建设置或当前发布 Podspec 读取，不得手写猜测值。

## 硬性规则

1. Pod 名称和 import 模块名都是 `SATagSDK`。
2. 正式分发只走私有 Specs：`http://172.20.30.113:13000/StarSdk/star_ios_pod_specs.git`。不要再从 CocoaPods Trunk 或 `https://github.com/iamgang520/SATagSDK` 安装。
3. 私有二进制 Pod 已嵌入 AppsFlyer、Facebook、TikTok 和 Firebase，不要在宿主工程再添加这些渠道的 CocoaPods 依赖，也不要再使用公网时期的 subspec。
4. AppsFlyer 是必接渠道。`devKey` 和 `appleAppID` 必须通过公开初始化接口同时传入，且不能是空白字符。
5. AppsFlyer 参数不完整时，SATagSDK 不初始化任何渠道，也不安装生命周期 Hook。
6. Facebook、TikTok、Firebase 只有在对应配置完整时才会初始化；未配置时结果为缺少配置或未集成，不要当成成功。
7. 事件接口不会抛异常；必须读取结果对象判断每个渠道的状态。
8. 不要在宿主 App 中重复调用第三方 SDK 的初始化入口。
9. 不记录、输出或提交 npm Token、完整 Dev Key、Client Token、Access Token 或用户标识。
10. Expo 第一版只支持 iOS。Android、Web 和 Expo Go 必须返回包中定义的错误，不能伪造成功。
11. 接入完成必须执行验收清单，编译通过不是验收完成。

## 接入方式选择

| 宿主条件 | 使用方式 | 不应做的事 |
| --- | --- | --- |
| 原生 iOS 且使用 CocoaPods | `SATagSDK` 私有 Pod | 再添加 AppsFlyer/Facebook/TikTok/Firebase Pod，或手动再嵌一份 XCFramework |
| 原生 iOS 且不用 CocoaPods | 发布方交付的 `SATagSDK-<版本>.zip` | 要求业务方拉取 SDK 源码或自行构建 XCFramework |
| Expo Prebuild / Development Build / EAS iOS Build | `@starsdk/ios-satagsdk-expo` | 在 Expo Go、Android、Web 上调用原生打点 |

## CocoaPods 接入

在宿主 `Podfile` 顶部保留公开 CDN 和统一的 `star_ios_pod_specs` 私有 Specs 源。

```ruby
source 'https://cdn.cocoapods.org/'
source 'http://172.20.30.113:13000/StarSdk/star_ios_pod_specs.git'

target 'AppTarget' do
  pod 'SATagSDK'
end
```

执行 `pod install` 后只使用 `.xcworkspace` 打开和构建工程。宿主最低系统版本应满足已解析的 `SATagSDK` Podspec 要求。

Objective-C：

```objc
#import <SATagSDK/SATagSDK.h>

[[SATagSDK sharedInstance] initializeWithAppsFlyerDevKey:@"YOUR_DEV_KEY"
                                              appleAppID:@"YOUR_APP_ID"
                                              completion:^(NSArray<SATagInitializationResult *> *results) {
    for (SATagInitializationResult *result in results) {
        NSLog(@"%@ %@", result.providerName, result.reason);
    }
}];
```

Swift：

```swift
import SATagSDK

SATagSDK.sharedInstance().initialize(
    withAppsFlyerDevKey: "YOUR_DEV_KEY",
    appleAppID: "YOUR_APP_ID"
) { results in
    results.forEach { print("\($0.providerName): \($0.reason)") }
}
```

## 渠道配置

初始化接口只接收 AppsFlyer 参数：`devKey`、`appleAppID`。

只有业务确实使用对应渠道时才配置：

- Facebook：`FacebookAppID`，建议同时配置 `FacebookClientToken`、`FacebookDisplayName`
- TikTok：`TikTokAccessToken`、`TikTokAppID`、`TikTokTTAppID`
- Firebase：把 `GoogleService-Info.plist` 加入宿主 Target

## XCFramework 直接接入

仅使用发布方交付的、与目标版本对应的 ZIP。将其中的 `SATagSDK.xcframework` 添加到宿主 Target 的 **Frameworks, Libraries, and Embedded Content**。

接入方不需要 SDK 源码工程、不运行 `BuildSATagSDKXCFramework`，也不重复添加 XCFramework 已携带的渠道二进制。

## Expo iOS 接入

在宿主项目的 `.npmrc` 配置内网 registry。`@starsdk/ios-satagsdk-expo` 是公开可读包，安装和查询版本不需要配置 `authToken`。

```ini
@starsdk:registry=http://172.20.30.113:13000/api/packages/StarSdk/npm/
```

```sh
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

插件会向 `Podfile` 注入私有 Specs 源和 `pod 'SATagSDK'`，npm 包不携带 XCFramework。每次安装、升级或修改原生依赖后，都要重新执行 `npx expo prebuild --platform ios` 并构建 Development Build 或 EAS iOS Build；只重载 Metro 无效。

```ts
import * as SATagSDK from '@starsdk/ios-satagsdk-expo';

await SATagSDK.initialize({
  appsFlyerDevKey: 'YOUR_APPSFLYER_DEV_KEY',
  appleAppID: 'YOUR_APPLE_APP_ID',
});

await SATagSDK.track('purchase', {
  product_id: 'sku_001',
  price: 6,
  currency: 'CNY',
});
```

## 发布规范

使用 Xcode 的 `PublishSATagSDKPod` Target 的 **Build** 操作发布，不能 Run 聚合 Target。它会构建 `BuildSATagSDKXCFramework`、创建 `star_ios_pod_specs/SATagSDK/<版本>/`、只提交该版本目录、创建 `SATagSDK-<版本>` tag、原子推送，然后发布同版本的 npm 包。

发布前检查：

1. `SATagVersion.json` 首项版本和 `expo/package.json` 版本一致。
2. Specs 仓库工作区干净，且当前分支没有未推送或未拉取提交；脚本会弹窗中止，不应绕过检查。
3. 从 Xcode 启动发布时，环境中必须有 `GITEA_NPM_TOKEN`；不要把 Token 写入脚本、项目 `.npmrc` 或 Git。
4. 实际发布前脚本会执行 Expo 的安装、构建、插件测试和 `npm pack --dry-run`。
5. 已存在的 Pod tag 或 npm 版本不可覆盖。若 Pod 已成功但 npm 发布失败，修复 npm 鉴权后只在 `expo/` 中补发同版本 npm 包，不得重发 Pod 版本。

发布完成后分别验证：

```sh
pod ipc spec /Users/iamgang/Documents/星合互娱/star_ios_pod_specs/SATagSDK/<版本>/SATagSDK.podspec
npm view @starsdk/ios-satagsdk-expo version --registry=http://172.20.30.113:13000/api/packages/StarSdk/npm/
```

## 验收清单

- CocoaPods：私有源 `pod install` 成功，`.xcworkspace` 的真机或模拟器构建成功。
- 原生 API：初始化、统一事件和单渠道事件均能编译并调用。
- Expo：`npm run build`、`npm test`、`npx expo prebuild --platform ios` 和 iOS Development Build 成功。
- Expo：iOS 真机或模拟器调用成功；Expo Go、Android、Web 返回明确的受支持范围错误。
- 发布：Podspec 可解析，Specs 的对应提交与 `SATagSDK-<版本>` tag 已推送，npm 查询到同版本且 `latest` 指向该版本。
- 安全：Git diff、日志、包文件清单及最终说明中均无 Token、签名密钥或其他敏感配置。
