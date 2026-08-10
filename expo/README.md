# satag-sdk-expo

SATagSDK 的 Expo iOS 原生桥接包。桥接层使用 Objective-C React Native Native Module，底层初始化和打点逻辑仍由 `SATagSDK` Objective-C 门面执行。

## 支持边界

- 支持 Expo Prebuild、Expo development build 和 EAS iOS Build。
- 不支持在 Expo Go 中直接加载，因为 Expo Go 不包含本项目的自定义原生模块。
- 当前只提供 iOS 支持；Android 没有对应的 SATagSDK 原生 Provider。
- AppsFlyer 仍然是必接渠道。

## 安装

发布 npm 包后：

```bash
npm install satag-sdk-expo@1.1.3
```

当前仓库开发验证可以使用本地包：

```bash
npm install ../SATagSDKDemo/expo
```

## Expo 配置

如果使用 Firebase，需要把 Firebase 控制台下载的 `GoogleService-Info.plist` 放在 Expo 工程中，并在 `app.json` 或 `app.config.js` 中配置：

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

然后重新生成并构建原生工程：

```bash
npx expo prebuild
npx expo run:ios
```

不要只重新加载 Metro；添加或修改原生依赖后必须重新构建 development build。

## JavaScript 调用

```ts
import * as SATagSDK from 'satag-sdk-expo';

const initializationResults = await SATagSDK.initialize({
  appsFlyerDevKey: 'YOUR_APPSFLYER_DEV_KEY',
  appleAppID: 'YOUR_APPLE_APP_ID',
});

const results = await SATagSDK.track('purchase', {
  product_id: 'sku_001',
  price: 6,
  currency: 'CNY',
});

await SATagSDK.trackFirebase('screen_view', {
  screen_name: 'Home',
});

await SATagSDK.presentDebugView();
```

初始化结果和事件结果中的 `state`、`reason` 必须由业务读取。AppsFlyer 参数缺失时，SATagSDK 不初始化其它渠道。
