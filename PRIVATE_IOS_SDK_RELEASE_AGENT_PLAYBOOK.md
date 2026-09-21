# iOS 二进制 SDK：构建、私有 CocoaPods、Expo npm 与接入 Skill 实施手册

> 目标读者：为其他 iOS SDK 项目开发、发布或接入的 Agent。
>
> 本文沉淀的是已经在 `SUReportData` 项目跑通的端到端模式。迁移到其他项目时，必须先完成“项目参数表”中的核验，不能把示例中的 SDK 名、版本、最低系统版本、仓库地址或依赖关系当成通用常量。

## 1. 目标与边界

本流程将一个 iOS Framework SDK 交付为三类面向使用者的产物：

1. 私有 CocoaPods Pod：Podspec + 版本化 XCFramework。
2. Expo 原生模块 npm 包：只包含桥接代码、TypeScript API 和 Config Plugin，不重复放入 XCFramework。
3. 接入 Skill：供其他 Agent 在业务项目中自动、规范地完成 Pod、XCFramework 或 Expo 接入。

发布必须遵循以下顺序：

```text
SDK 源码与测试
  -> Xcode BuildLocalXCFramework Target
  -> 真机/模拟器 XCFramework
  -> Pod 版本目录与 Podspec 校验
  -> 仅提交当前 Pod 版本目录 + 创建 Git tag + 原子推送
  -> 发布同版本 Expo npm 包
  -> 从私有 Pod/npm Registry 独立查询验证
```

不在本流程内的事项：

- 不把敏感 Token、签名密钥、业务 AppKey 提交到 Git。
- 不让接入方下载 SDK 源码或自行运行 SDK 构建脚本。
- 不把“源码能编译”当作完成；必须验证实际发布和消费者接入。
- 不通过 Expo Go、Android 或 Web 伪造 iOS 原生模块调用成功。

## 2. 迁移前必须核实的项目参数

将下面项目参数填入项目专属配置或发布脚本，并在开始开发前从真实工程核实。

| 参数 | 示例（SUReportData） | 必须从哪里核实 |
| --- | --- | --- |
| Framework 二进制模块名 | `SUReportDataSDK` | Framework Target / Public Header / 产物目录 |
| CocoaPods Pod 名 | `SUEvent` | 既有接入契约或新建 Podspec |
| 版本来源 | `RDVersion.json` 第一项 | SDK 版本配置文件，不能从脚本参数猜测 |
| 构建 Workspace | `SUReportDataDemo.xcworkspace` | CocoaPods 实际生成的 Workspace |
| Framework Scheme | `SUReportDataSDK` | Xcode Scheme |
| 构建聚合 Target | `BuildLocalXCFramework` | Xcode Shared Scheme |
| 发布聚合 Target | `PublishSUEventPod` | Xcode Shared Scheme |
| 私有 Specs 仓库 | `http://172.20.30.113:13000/StarSdk/star_ios_pod_specs.git` | 仓库管理员或当前可用 Podfile |
| npm 包名 | `@starsdk/ios-suevent-expo` | `expo/package.json` |
| 私有 npm Registry | `http://172.20.30.113:13000/api/packages/StarSdk/npm/` | Gitea Packages 页面或 npm 配置 |
| 最低 iOS 版本 | 从 Release 生效 `IPHONEOS_DEPLOYMENT_TARGET` 读取 | `xcodebuild -showBuildSettings`，不能手填 |
| 基础 Pod | `SUBase` | 主 Podspec / 私有 Specs 仓库 |

### 2.1 本项目已确认的 Specs 规则

`star_ios_pod_specs` 已包含 `SUEvent` 与 `SUBase` 的 Specs。因此消费者的 Podfile 和 Expo Config Plugin **只**需要私有源：

```ruby
source 'https://cdn.cocoapods.org/'
source 'http://172.20.30.113:13000/StarSdk/star_ios_pod_specs.git'
```

不要再添加：

```ruby
source 'https://gitlab.outer.staruniongame.com/platform_sdk/starpodspace.git'
```

公开 CocoaPods 源使用 `https://cdn.cocoapods.org/`；不要把旧的 `https://github.com/CocoaPods/Specs.git` 当作默认新配置。

## 3. 推荐目录与职责划分

```text
SDKRepository/
├── SDKDemo/
│   ├── SDKDemo.xcworkspace
│   ├── SDKDemo.xcodeproj/
│   │   └── xcshareddata/xcschemes/
│   │       ├── BuildLocalXCFramework.xcscheme
│   │       └── PublishSDKPod.xcscheme
│   ├── SDKSource/
│   │   ├── PublicSDK.h
│   │   └── Config/Version.json
│   ├── Scripts/
│   │   ├── BuildLocalXCFramework.sh
│   │   └── PublishSDKPod.sh
│   └── Build/                         # 生成物，不提交 SDK 源仓库
├── expo/
│   ├── package.json
│   ├── app.plugin.js
│   ├── expo-module.config.json
│   ├── ios/
│   │   ├── XxxExpo.podspec
│   │   ├── XxxExpoModule.swift
│   │   └── XxxExpoBridge.{h,m}
│   ├── src/
│   ├── tests/
│   ├── README.md
│   └── RELEASE.md
├── SKILL.md                            # 当前 SDK 的接入 Skill
└── PRIVATE_IOS_SDK_RELEASE_AGENT_PLAYBOOK.md

PrivateSpecsRepository/
└── <PodName>/<Version>/
    ├── <PodName>.podspec
    └── Frameworks/<FrameworkName>.xcframework/
```

职责必须分开：

- `BuildLocalXCFramework.sh` 只负责稳定构建真实二进制产物。
- `PublishSDKPod.sh` 只负责发布编排、预检、版本目录、Git tag/push 与 npm publish。
- Expo Module 只负责桥接已公开的 SDK API；不访问 SDK 内部 `RD*`、`XX*` 私有类。
- Config Plugin 只负责改造消费者的 iOS Podfile；不静默修改宿主最低系统版本。
- `SKILL.md` 只记录消费者需要的稳定契约、集成方式、验收条件和发布边界。

## 4. Xcode Target 设计

### 4.1 `BuildLocalXCFramework`

创建一个 `PBXAggregateTarget`，仅使用 **Build**，不提供 Launch/Run 行为。它调用构建脚本，依赖 SDK Framework Target。

构建脚本必须：

1. 使用 `.xcworkspace`，不要直接构建 `.xcodeproj`，否则会绕过 CocoaPods 集成。
2. 对真机和模拟器分别使用独立 `-derivedDataPath`，避免 `build.db locked` 和交叉污染。
3. 关闭签名：`CODE_SIGNING_ALLOWED=NO`。
4. 分别验证两个 Framework 二进制存在后，再执行 `xcodebuild -create-xcframework`。
5. 最终验证 XCFramework 至少包含 `ios-arm64` 与模拟器 slice。

示例骨架：

```sh
#!/bin/sh
set -eu

FRAMEWORK_NAME='SUReportDataSDK'             # 迁移时替换
WORKSPACE="${PROJECT_DIR}/SUReportDataDemo.xcworkspace"
OUTPUT_DIR="${PROJECT_DIR}/Build"
DEVICE_DERIVED_DATA="${OUTPUT_DIR}/iphoneos"
SIMULATOR_DERIVED_DATA="${OUTPUT_DIR}/iphonesimulator"

xcodebuild -workspace "$WORKSPACE" -scheme "$FRAMEWORK_NAME" \
  -configuration Release -destination 'generic/platform=iOS' build \
  -derivedDataPath "$DEVICE_DERIVED_DATA" CODE_SIGNING_ALLOWED=NO

xcodebuild -workspace "$WORKSPACE" -scheme "$FRAMEWORK_NAME" \
  -configuration Release -destination 'generic/platform=iOS Simulator' build \
  -derivedDataPath "$SIMULATOR_DERIVED_DATA" CODE_SIGNING_ALLOWED=NO

xcodebuild -create-xcframework \
  -framework "${DEVICE_DERIVED_DATA}/Build/Products/Release-iphoneos/${FRAMEWORK_NAME}.framework" \
  -framework "${SIMULATOR_DERIVED_DATA}/Build/Products/Release-iphonesimulator/${FRAMEWORK_NAME}.framework" \
  -output "${OUTPUT_DIR}/${FRAMEWORK_NAME}.xcframework"
```

本项目的独立验收命令：

```sh
xcodebuild \
  -workspace SUReportDataDemo/SUReportDataDemo.xcworkspace \
  -scheme BuildLocalXCFramework \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  build
```

### 4.2 `PublishSDKPod`

同样创建 `PBXAggregateTarget`，并让它依赖 `BuildLocalXCFramework`。该 Target 也只能执行 **Build**。

发布 Target 的职责是：

1. 消费上一步生成的 XCFramework。
2. 读取版本与最低系统版本。
3. 校验 Expo 包版本与 SDK 版本一致。
4. 校验私有 Specs 仓库状态。
5. 创建版本目录和 Podspec。
6. 只提交当前版本目录、创建 tag、原子推送。
7. 成功推送后发布相同版本的 npm 包。

不要让它从外部参数接受版本号，也不要在 Target 中执行 `git add -A`。

## 5. 版本与最低系统版本

### 5.1 单一版本来源

SDK 发布版本要有一个可审计的单一来源，例如：

```json
[
  { "version": "5.26.1", "date": "2026-08-19" }
]
```

发布脚本读取首项版本，并强制校验：

```text
SDK Version == Podspec Version == Specs 目录名 == Git Tag 中版本 == Expo package.json version
```

其中任意一项不一致，必须停止发布并弹窗/打印明确原因。

### 5.2 最低 iOS 版本必须从工程读取

不能为了方便在脚本或 Podspec 模板中写死 `13.0`、`15.0`、`16.4`。应从 Framework Scheme 的 Release 生效构建设置读取：

```sh
xcodebuild \
  -workspace "$WORKSPACE" \
  -scheme "$FRAMEWORK_NAME" \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  -showBuildSettings \
| awk -F ' = ' '/^[[:space:]]*IPHONEOS_DEPLOYMENT_TARGET = / { print $2; exit }'
```

读取出的值写入主 Podspec 的：

```ruby
s.ios.deployment_target = '<读取结果>'
```

Expo Module 的 Podspec 可能因为 ExpoModulesCore/Expo SDK 而有更高的 iOS 要求。它必须声明自己的真实约束；Config Plugin 只报告或让 `pod install` 失败，不能悄悄抬高宿主 App 的 deployment target。

## 6. 私有 CocoaPods 发布

### 6.1 Podspec 设计原则

主 Podspec 应包含：

```ruby
Pod::Spec.new do |s|
  s.name = 'SUEvent'                 # Pod 名，迁移时替换
  s.version = '5.26.1'               # 由版本文件生成
  s.summary = 'SDK 简短说明。'
  s.homepage = 'http://172.20.30.113:13000/StarSdk/star_ios_pod_specs'
  s.license = { :type => 'Proprietary' }
  s.author = { 'StarSdk' => 'oubu@staruniongame.com' }

  s.source = {
    :git => 'http://172.20.30.113:13000/StarSdk/star_ios_pod_specs.git',
    :tag => 'SUEvent-5.26.1'
  }
  s.ios.deployment_target = '13'     # 实际应由构建设置读取
  s.vendored_frameworks = 'Frameworks/SUReportDataSDK.xcframework'
  s.dependency 'SUBase'               # 不锁版本
end
```

关键约束：

- `s.source` 必须指向能被消费者访问的 Git 地址和版本 tag，不能依赖 Specs 仓库中的相对 ZIP 路径。
- 发布目录内只放当前版本的 Podspec 与 XCFramework。
- 同一应用内只由 CocoaPods 解析、嵌入一份共享的基础动态库；不要把相同基础 Framework 重复塞进多个 SDK 的 XCFramework。
- 如果私有 Specs 仓库已包含基础 Pod 的 Specs，消费者和 Config Plugin 不应继续注入额外的旧基础库源。
- 不为主库额外罗列或展示系统 Framework 链接列表；SDK 所需链接信息应由 Podspec、二进制和 Xcode 构建配置本身处理。

### 6.2 发布前 Git 预检

发布脚本需要在 Specs 仓库执行：

1. `git status --porcelain` 必须为空。
2. 当前必须在本地分支，且具有远端 tracking branch。
3. `git fetch` 成功。
4. 当前分支 ahead 数量必须为 `0`；否则弹窗提示“有未推送提交，请手动推送”。
5. 当前分支 behind 数量必须为 `0`；否则提示先手动同步并处理。
6. 当前 `<PodName>-<Version>` tag 和 `<PodName>/<Version>/` 目录都不能已存在。

这一步防止发布 Target 顺手提交、推送任何其他人的变更。

### 6.3 只提交当前版本目录

正确做法：

```sh
git -C "$POD_SPECS_REPO" add -- "$RELEASE_RELATIVE_PATH"
git -C "$POD_SPECS_REPO" diff --cached --check -- "$RELEASE_RELATIVE_PATH/$POD_NAME.podspec"
git -C "$POD_SPECS_REPO" commit --only -m "发布 $POD_NAME $VERSION" -- "$RELEASE_RELATIVE_PATH"
git -C "$POD_SPECS_REPO" tag -a "$TAG_NAME" -m "发布 $POD_NAME $VERSION"
git -C "$POD_SPECS_REPO" push --atomic "$PUSH_REMOTE" \
  "HEAD:refs/heads/$PUSH_BRANCH" \
  "refs/tags/$TAG_NAME:refs/tags/$TAG_NAME"
```

提交说明使用简体中文。暂存后和提交后均要检查变更路径只属于当前版本目录。

### 6.4 发布前二进制与 Podspec 校验

发布脚本应在复制二进制后验证：

```sh
test -f "$FRAMEWORK_DIR/Info.plist"
test -f "$FRAMEWORK_DIR/ios-arm64/$FRAMEWORK_NAME.framework/$FRAMEWORK_NAME"
test -f "$FRAMEWORK_DIR/ios-arm64_x86_64-simulator/$FRAMEWORK_NAME.framework/$FRAMEWORK_NAME"
plutil -lint "$FRAMEWORK_DIR/Info.plist"
pod ipc spec "$RELEASE_DIRECTORY/$POD_NAME.podspec"
```

模拟器实际 slice 名随 Xcode/产物不同可能变化。迁移时需解析 XCFramework `Info.plist` 或根据构建结果验证，不能强行复制字符串。

## 7. Expo 原生模块与 npm 包

### 7.1 包的职责

Expo npm 包提供：

- Expo Modules API 的 iOS 原生模块。
- Swift 层对 SDK **公开 API** 的调用。
- 必要时用 Objective-C Bridge 把 Swift 与现有 Objective-C SDK 头文件连接起来。
- TypeScript 稳定 API、参数类型、错误类型和 JSON 校验。
- Config Plugin，在 prebuild 时注入私有 Specs 源与 `pod '<PodName>'`。

Expo npm 包不提供：

- XCFramework、重复二进制依赖或其拷贝。
- SDK 内部实现类型的 JS API。
- Android/Web 的空实现或“调用成功”假象。

### 7.2 TypeScript API 设计

只暴露稳定且业务接入实际需要的接口。本项目对外约定为：

```ts
initialize({ distinctId })
initialize({ appKey, distinctId, baseURL, secretKey, aesSecret })
updateRoleInfo({ accountId, playerId, serverId })
report(eventName, eventData)
reportUserData(eventDataArray)
```

规则：

- `eventData` 仅接受 JSON 可序列化值。
- 非空字符串、初始化可判别参数和角色字段在 JS 层和 Swift 层双重校验。
- 初始化的两种模式要通过 TypeScript 联合类型表达，避免漏传 AppKey 模式所需字段。
- 原生模块不可用、非 iOS 平台、Expo Go 使用、非法 JSON 参数必须有稳定、可识别的错误类型或错误码。
- 除非明确要求，不把 SDK 自有环境、内部开关、私有配置或未对业务开放的事件入口暴露到 Skill 或业务 API。

### 7.3 iOS Module Podspec

Expo Module 的 podspec 只声明桥接源文件和 Pod 依赖：

```ruby
s.source_files = 'ios/**/*.{h,m,swift}'
s.dependency 'ExpoModulesCore'
s.dependency 'SUEvent'
```

不要增加 `vendored_frameworks`，因为 `SUEvent` 已由消费者 Podfile 解析。Expo module 的 `s.version` 应从 `expo/package.json` 读取，且发布脚本必须校验它与 SDK 版本一致。

### 7.4 Config Plugin

插件的最小职责是对 Podfile 幂等地注入：

```ruby
source 'https://cdn.cocoapods.org/'
source 'http://172.20.30.113:13000/StarSdk/star_ios_pod_specs.git'

target 'AppTarget' do
  pod 'SUEvent'
end
```

实现要求：

1. 首次运行插入，第二次运行内容不变化。
2. 优先在 `use_expo_modules!` 后插入 `pod '<PodName>'`。
3. 非标准 Podfile 可回退到第一个 `target`。
4. 无 `target` 时明确抛错，不生成无效 Podfile。
5. 单元测试至少覆盖标准 Expo Podfile、非 Expo Podfile、无 target、重复执行。
6. 不注入已经废弃或不需要的额外私有 Specs 源。

消费者配置示例：

```json
{
  "expo": {
    "plugins": ["@starsdk/ios-suevent-expo"]
  }
}
```

消费者必须执行：

```sh
npx expo prebuild --platform ios
```

随后使用 Development Build 或 EAS iOS Build。原生依赖变更后只重载 Metro 不会生效；Expo Go 不包含自定义原生模块。

### 7.5 npm Registry 与鉴权

对于公开可读的 npm 包，消费者项目的 `.npmrc` 只需配置 scope registry，不需要 `authToken`：

```ini
@starsdk:registry=http://172.20.30.113:13000/api/packages/StarSdk/npm/
```

发布 npm 包时才需要真实 Token，规则如下：

- 只保存到开发机用户级 npm 配置、CI Secret 或安全环境变量。
- 不写入项目 `.npmrc`、`package.json`、发布脚本、文档、终端日志或 Git。
- 发布 Target 如果由 Xcode 发起，Xcode 必须能继承 `GITEA_NPM_TOKEN`。可在本机登录会话配置后完全退出并重新打开 Xcode：

```sh
launchctl setenv GITEA_NPM_TOKEN '<仅在本机输入真实 Token>'
```

### 7.6 本机固定 npm 凭据约定

对于本机多个 SDK 项目共用的内网 Gitea npm Registry，真实 Token 已由开发者保存在当前 macOS 用户的 `~/.npmrc`，该文件权限必须为 `600`。该凭据仅供 Agent 在 `expo/` 手动补发 npm 包或执行其他发布操作使用；消费者安装公开包、查询公开版本时不需要复制或配置该 Token。

```sh
# 仅检查用户级 npm 配置文件权限；不要输出或读取其中的 Token 内容。
stat -f '%Lp %N' "$HOME/.npmrc"

# 期望输出：600 /Users/<当前用户>/.npmrc
```

当发布流程从 Xcode 的 `PublishSDKPod` Target 启动时，脚本仍以 `GITEA_NPM_TOKEN` 环境变量作为唯一输入。原因是脚本会创建发布后自动清理的临时 npmrc，避免依赖项目文件或把凭据留在发布产物中。Agent 必须在执行 Xcode 发布前确认该环境变量已为当前登录会话配置，但不得打印其值。

不要依赖 `npm whoami` 作为 Gitea npm registry 的唯一鉴权检测；部分内部 Gitea 端点会对 `/-/whoami` 返回 404。应以 `npm view <package>@<version>` 和真实 publish 响应作为可用性证据。

## 8. 联合发布脚本

### 8.1 正常发布流程

发布脚本顺序不可颠倒：

1. 验证构建产物、版本文件、最低系统版本、CocoaPods CLI、Node/npm。
2. 验证 Expo manifest、Podspec、版本一致性、registry URL。
3. 在 `expo/` 执行 `npm ci --ignore-scripts`、`npm run build`、`npm run test`、`npm pack --dry-run --ignore-scripts`。
4. 预检私有 Specs 仓库与 npm Token。
5. 创建版本目录、复制 XCFramework、生成 Podspec、执行 `pod ipc spec`。
6. 仅提交版本目录，创建 annotated tag，`git push --atomic` 推送分支与 tag。
7. 从临时 npm 配置文件执行 `npm publish --ignore-scripts --tag latest`。
8. 输出 commit、tag、npm 包名与版本。

`npm publish` 放在 Pod Git 原子推送之后，是为了确保 npm 包被安装时其 `SUEvent` Pod 版本已经可用。

### 8.2 发布脚本的安全实现

发布脚本中：

- 使用 `set -eu`。
- 用 `mktemp` 创建临时 npmrc；退出时用 `trap` 删除。
- npmrc 中写入 Token 时不回显文件内容。
- 先调用 `npm view <package>@<version>` 检查该版本是否已存在；npm 版本不可覆盖。
- 发布失败应让 Xcode 弹窗显示简体中文原因，同时保留终端错误输出。
- 支持 `SDK_RELEASE_DRY_RUN=1`：构建临时版本目录并校验，不提交、不 tag、不 push、不 npm publish。
- 本地发生 tag 或 commit 后如果 push 失败，必须停止并提示人工处理；不能自动回滚或强推。

### 8.3 Pod 成功、npm 失败的恢复流程

这是正常发布流程中的唯一非原子边界：Pod Git/tag 已推送后，npm 仍可能因 Token、网络或 Registry 问题失败。

恢复规则：

1. 不重新执行完整 Pod 发布 Target，因为 tag/版本目录已经存在，脚本应拒绝覆盖。
2. 修复鉴权或 Registry 后，进入 `expo/`。
3. 重新执行 `npm ci --ignore-scripts`、构建、测试和打包预演。
4. 仅补发同版本：

```sh
npm publish --registry=http://172.20.30.113:13000/api/packages/StarSdk/npm/ --tag latest
```

5. 使用 `npm view <package> version` 和 `npm view <package> dist-tags.latest` 验证。

建议后续给每个项目的发布脚本补充一个显式 `npm-only recovery` 模式，但它必须先验证对应 Pod tag 已在远端存在、npm 同版本尚不存在，避免误发布。

## 9. 构建与发布验收矩阵

| 阶段 | 必须通过的证据 |
| --- | --- |
| SDK 编译 | Framework Scheme 通过；对使用 Pods 的工程使用 `.xcworkspace` |
| XCFramework | 真机和模拟器 slice 存在，`Info.plist` 合法 |
| Podspec | `pod ipc spec <podspec>` 成功 |
| Expo 包 | `npm run build` 成功，Config Plugin 测试通过，`npm pack --dry-run` 不包含 XCFramework |
| Expo 消费者 | `npx expo prebuild --platform ios` 成功，Pod 解析出 Expo Module、主 Pod 和基础 Pod |
| iOS 消费者 | Development Build 或 Xcode Simulator 构建成功；不能只验证 prebuild |
| Specs Git | 只提交当前版本目录，远端 commit 和 annotated tag 均存在 |
| npm | `npm view <package> version` 查询到目标版本，`latest` 指向目标版本 |
| 安全 | `git diff --check` 通过，产物与日志中不含 Token、私钥、业务密钥 |

发布完成后的最小独立检查：

```sh
pod ipc spec /path/to/star_ios_pod_specs/<PodName>/<Version>/<PodName>.podspec
npm view @scope/package version --registry=http://172.20.30.113:13000/api/packages/StarSdk/npm/
npm view @scope/package dist-tags.latest --registry=http://172.20.30.113:13000/api/packages/StarSdk/npm/
```

## 10. 为 SDK 生成 `SKILL.md`

每个发布 SDK 的项目根目录应有一个面向接入 Agent 的 `SKILL.md`。它不是营销文档，也不应复制实现细节或泄露敏感配置。

### 10.1 Skill 的最小 Frontmatter

```yaml
---
name: integrate-<sdk-name>-ios
description: 为 iOS 原生工程或 Expo Prebuild 工程接入、升级、验证 <SDK 名称>。适用于 CocoaPods、已交付 XCFramework 和 @scope/package；涉及初始化、角色信息、普通事件、用户事件或 SDK 发布时必须使用。
---
```

`name` 只能使用小写字母、数字和连字符。`description` 要同时描述什么时候触发和能做什么，不要写 Token、版本号或容易过期的实现细节。

### 10.2 Skill 必须写入的事实

1. **事实来源优先级**：公开头文件、已发布 Podspec、Expo manifest/Podspec、版本文件、发布脚本。
2. **硬性规则**：实际 import 模块名与 Pod 名、事件前缀保留规则、JSON 参数规则、敏感数据禁令。
3. **接入方式选择**：CocoaPods、XCFramework、Expo 的适用条件与互斥关系。
4. **消费者步骤**：Podfile/Expo plugin、初始化、角色更新、普通事件和用户事件示例。
5. **支持范围**：Expo iOS 的真实最低系统版本、Expo Go/Android/Web 行为。
6. **发布规则**：版本一致性、Build 而非 Run、Specs Git 预检、仅提交当前版本目录、Pod 成功/npm 失败恢复。
7. **验收清单**：消费者编译、Pod/npm 查询、真实 iOS 构建和安全检查。

### 10.3 Skill 不应写入的内容

- 未对业务侧开放的 SDK 自有环境事件、内部 API、内部配置格式、私有 `RD*` 类型。
- System Framework 罗列；除非消费者确有独立手动链接需求且该需求已被公开契约确认。
- 真实 npm Token、AppKey、签名密钥、AES 密钥、用户标识或内网账号。
- 从别的 SDK 复制而来但未在当前项目核实的方法名、版本号、第三方依赖版本。

### 10.4 生成/更新 Skill 后的校验

```sh
python3 /Users/iamgang/.codex/skills/.system/skill-creator/scripts/quick_validate.py .
git diff --check -- SKILL.md
```

如果当前环境没有该校验脚本，至少确认 YAML frontmatter 只有 `name` 与 `description` 等允许字段，且文件中所有路径、包名、最低系统版本和 API 都能在项目事实来源中定位。

## 11. Agent 执行清单

当其他项目的 Agent 被要求“把 iOS SDK 发布为私有 Pod 并支持 Expo”时，应按以下顺序工作：

1. 阅读项目 `AGENTS.md`、既有公共头文件、Xcode Targets、Podfile、版本文件、现有发布/构建脚本和 Git 状态。
2. 填写并核实第 2 节项目参数，遇到未知仓库、包名、最低版本或 API 时停下说明，不做猜测。
3. 实现或修正 Framework 构建 Target，优先保证 Workspace 构建与独立 DerivedData。
4. 构建本地 XCFramework，并验证真实 device/simulator slices。
5. 创建或更新发布脚本，加入版本一致性、Podspec 校验、Git 边界、tag、原子推送、Dry Run 和 npm 发布恢复策略。
6. 实现 Expo Module、Config Plugin、TypeScript 参数校验与插件单测；不把二进制塞入 npm 包。
7. 用隔离的 Expo 消费者项目运行 prebuild、pod install 和 iOS 构建。
8. 创建或更新项目 `SKILL.md`，去除未对接入方开放的内部能力。
9. 运行所有适用测试、`pod ipc spec`、`npm pack --dry-run`、`git diff --check`。
10. 只有用户明确授权真实发布时，才执行 `PublishSDKPod`；之后独立查询 Pod Git/tag 和 npm Registry。
11. 提交 SDK 源码时只提交本次实现涉及的文件；提交说明使用简体中文；不修改或回退用户已有的无关脏文件。

## 12. 常见失败与正确处理

| 现象 | 根因 | 正确处理 |
| --- | --- | --- |
| `Pods-...` library not found | 构建了 `.xcodeproj` 而非 `.xcworkspace` | 通过 Workspace 和 SDK Scheme 构建 |
| `build.db locked` | 真机/模拟器内层构建共享 DerivedData | 为两个 destination 使用独立 `-derivedDataPath` |
| `pod install` 找不到基础 Pod | Config Plugin 漏了实际包含该 Pod 的私有 Specs 源 | 核实 Specs 仓库；若主私有源已含基础 Pod，只保留该源 |
| 发布前发现其他未推送提交 | Specs 仓库不是干净、可控的发布基线 | 弹窗中止，要求手动推送/同步/清理，不能顺带推送 |
| Pod 已发布、npm 不在 Packages 页面 | npm 只做了 `pack --dry-run` 或鉴权失败 | 修复 Token 后仅补发 npm，同版本不可重发 Pod |
| `npm whoami` 404 | 内部 Gitea 端点不实现 whoami | 以 `npm view` 与 publish 响应检查 |
| Expo Go 找不到模块 | Expo Go 不含自定义 native module | 运行 prebuild 后构建 Development Build/EAS iOS Build |
| 宿主 iOS 版本报错 | ExpoModulesCore 或 SDK Pod 的真实最低版本更高 | 声明真实 podspec 要求，让宿主显式调整，不静默修改 |
| npm 包体积异常或含二进制 | `files` 未受控或误把 Build 放入包 | 配置 npm `files`，使用 `npm pack --dry-run` 检查 |

## 13. 完成定义

以下条件同时满足，才可以对用户说“从构建到私有 Pod、npm 和接入 Skill 已完成”：

- 本地 XCFramework 已由 Workspace 构建，并有真实真机和模拟器 slice。
- 私有 Podspec 引用与版本对应的 tag，最低 iOS 版本来自项目构建设置。
- Specs 仓库只包含当前版本目录的发布提交和 tag；没有夹带无关改动。
- Expo npm 包不含 XCFramework，Config Plugin 只注入必要的公开 CDN、统一私有 Specs 源与主 Pod。
- Expo 构建、插件测试、打包预演和消费者 iOS 构建均通过。
- 私有 npm Registry 能查询到同版本，`latest` 正确指向它。
- `SKILL.md` 已校验，且只给业务接入方公开稳定 API，不包含内部能力和敏感信息。
- 最终记录中明确列出已执行的验证、已发布的版本与 tag；未执行的真实发布不得描述为已完成。
