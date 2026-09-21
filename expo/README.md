# @starsdk/ios-satagsdk-expo

SATagSDK 的 Expo iOS 原生桥接包。桥接层使用 Objective-C React Native Native Module，底层初始化和打点逻辑仍由 `SATagSDK` Objective-C 门面执行。

## 支持边界

- 支持 Expo Prebuild、Expo development build 和 EAS iOS Build。
- 不支持在 Expo Go 中直接加载。
- 当前只提供 iOS 支持；Android 没有对应的 SATagSDK 原生 Provider。
- AppsFlyer 仍然是必接渠道。

## 安装

```ini
@starsdk:registry=http://172.20.30.113:13000/api/packages/StarSdk/npm/
```

```bash
npm install @starsdk/ios-satagsdk-expo
npx expo prebuild --platform ios
```

## Expo 配置

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

插件会向 Podfile 注入私有 Specs 源和 `pod 'SATagSDK'`。原生依赖变更后必须重新 prebuild，不要只重载 Metro。

## JavaScript 调用

```ts
import * as SATagSDK from '@starsdk/ios-satagsdk-expo';

const initializationResults = await SATagSDK.initialize({
  appsFlyerDevKey: 'YOUR_APPSFLYER_DEV_KEY',
  appleAppID: 'YOUR_APPLE_APP_ID',
});

await SATagSDK.track('purchase', {
  product_id: 'sku_001',
  price: 6,
  currency: 'CNY',
});
```
