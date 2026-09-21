#!/bin/sh

# 发布 Target 的职责包括 SATagSDK 二进制 Pod 和对应 Expo npm 包：
# 使用 BuildSATagSDKXCFramework 的产物，创建与 SDK 配置一致的版本目录，
# 仅提交该目录，推送对应分支/tag 后再发布 npm 包。
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
PROJECT_DIR=$(CDPATH= cd -- "${SCRIPT_DIR}/.." && pwd)

FRAMEWORK_NAME="SATagSDK"
WORKSPACE="${PROJECT_DIR}/SATagSDKDemo.xcworkspace"
VERSION_FILE="${PROJECT_DIR}/SATagSDK/Config/SATagVersion.json"
XCFRAMEWORK_PATH="${PROJECT_DIR}/Build/${FRAMEWORK_NAME}.xcframework"
POD_SPECS_REPO="${SATAG_POD_SPECS_REPO:-/Users/iamgang/Documents/星合互娱/star_ios_pod_specs}"
POD_NAME="SATagSDK"
EXPO_PACKAGE_NAME="@starsdk/ios-satagsdk-expo"
EXPO_PACKAGE_DIR="${PROJECT_DIR}/expo"
NPM_REGISTRY="${SATAG_NPM_REGISTRY:-http://172.20.30.113:13000/api/packages/StarSdk/npm/}"
DRY_RUN="${SATAG_RELEASE_DRY_RUN:-${SDK_RELEASE_DRY_RUN:-0}}"
TEMP_DIRECTORY=""
NPM_CONFIG_FILE=""
RELEASE_RELATIVE_PATH=""
CREATED_RELEASE_DIRECTORY=""
RELEASE_COMMITTED=0
RELEASE_STAGED=0

fail() {
    echo "错误：$1" >&2
    exit 1
}

alert_and_fail() {
    message="$1"

    echo "错误：${message}" >&2
    /usr/bin/osascript -e '
        on run argv
            display alert "SATagSDK 发布已中止" message (item 1 of argv) as critical
        end run
    ' "${message}" >/dev/null 2>&1 || true
    exit 1
}

cleanup() {
    if [ -n "${TEMP_DIRECTORY}" ] && [ -d "${TEMP_DIRECTORY}" ]; then
        rm -rf "${TEMP_DIRECTORY}"
    fi

    if [ -n "${NPM_CONFIG_FILE}" ] && [ -f "${NPM_CONFIG_FILE}" ]; then
        rm -f "${NPM_CONFIG_FILE}"
    fi

    if [ "${RELEASE_COMMITTED}" -eq 0 ] && [ "${RELEASE_STAGED}" -eq 0 ] && [ -n "${CREATED_RELEASE_DIRECTORY}" ] && [ -d "${CREATED_RELEASE_DIRECTORY}" ]; then
        rm -rf "${CREATED_RELEASE_DIRECTORY}"
    fi
}

trap cleanup EXIT HUP INT TERM

read_version() {
    /usr/bin/plutil -extract '0.version' raw "${VERSION_FILE}"
}

read_deployment_target() {
    build_settings=$(xcodebuild \
        -workspace "${WORKSPACE}" \
        -scheme "${FRAMEWORK_NAME}" \
        -configuration Release \
        -destination "generic/platform=iOS" \
        -showBuildSettings) || return 1

    printf '%s\n' "${build_settings}" | awk -F ' = ' '/^[[:space:]]*IPHONEOS_DEPLOYMENT_TARGET = / { print $2; exit }'
}

preflight_pod_specs_repository() {
    if [ -n "$(git -C "${POD_SPECS_REPO}" status --porcelain)" ]; then
        alert_and_fail "检测到 Pod Specs 仓库有其他未提交的内容，请手动提交、推送或清理后再发布。"
    fi

    CURRENT_BRANCH=$(git -C "${POD_SPECS_REPO}" symbolic-ref --quiet --short HEAD) || \
        alert_and_fail "Pod Specs 仓库当前不在本地分支上，请切换到需要发布的分支后再试。"
    PUSH_REMOTE=$(git -C "${POD_SPECS_REPO}" config --get "branch.${CURRENT_BRANCH}.remote") || \
        alert_and_fail "当前分支 ${CURRENT_BRANCH} 没有配置远端跟踪分支，请手动配置后再发布。"
    UPSTREAM_BRANCH_REF=$(git -C "${POD_SPECS_REPO}" config --get "branch.${CURRENT_BRANCH}.merge") || \
        alert_and_fail "当前分支 ${CURRENT_BRANCH} 没有配置远端跟踪分支，请手动配置后再发布。"

    case "${UPSTREAM_BRANCH_REF}" in
        refs/heads/*)
            PUSH_BRANCH=${UPSTREAM_BRANCH_REF#refs/heads/}
            ;;
        *)
            alert_and_fail "当前分支 ${CURRENT_BRANCH} 的远端跟踪配置无效，请手动检查后再发布。"
            ;;
    esac

    [ "${PUSH_REMOTE}" != "." ] || \
        alert_and_fail "当前分支 ${CURRENT_BRANCH} 使用本地跟踪分支，无法自动推送，请手动处理后再发布。"

    if ! git -C "${POD_SPECS_REPO}" fetch --quiet "${PUSH_REMOTE}"; then
        alert_and_fail "无法获取 Pod Specs 远端分支状态，请手动检查网络和远端仓库后再发布。"
    fi

    UPSTREAM_REF=$(git -C "${POD_SPECS_REPO}" rev-parse --abbrev-ref --symbolic-full-name '@{upstream}') || \
        alert_and_fail "无法解析当前分支的远端跟踪分支，请手动检查后再发布。"
    AHEAD_COUNT=$(git -C "${POD_SPECS_REPO}" rev-list --count "${UPSTREAM_REF}..HEAD")
    BEHIND_COUNT=$(git -C "${POD_SPECS_REPO}" rev-list --count "HEAD..${UPSTREAM_REF}")

    if [ "${AHEAD_COUNT}" -ne 0 ]; then
        alert_and_fail "检测到当前分支有 ${AHEAD_COUNT} 个未推送提交，请手动推送后再发布。"
    fi

    if [ "${BEHIND_COUNT}" -ne 0 ]; then
        alert_and_fail "检测到远端有 ${BEHIND_COUNT} 个未拉取提交，请手动同步并处理后再发布。"
    fi
}

validate_paths_belong_to_release() {
    paths="$1"

    [ -n "${paths}" ] || fail "当前版本目录没有可提交的文件：${RELEASE_RELATIVE_PATH}"
    while IFS= read -r path; do
        case "${path}" in
            "${RELEASE_RELATIVE_PATH}"/*)
                ;;
            *)
                fail "检测到不属于当前版本目录的 Git 变更：${path}"
                ;;
        esac
    done <<EOF
${paths}
EOF
}

validate_dotted_number() {
    case "$1" in
        '' | .* | *..* | *[!0-9.]*)
            return 1
            ;;
        *)
            return 0
            ;;
    esac
}

read_expo_package_field() {
    manifest_path="${EXPO_PACKAGE_DIR}/package.json"
    field_name="$1"

    node -e '
        const fs = require("fs");
        const manifest = JSON.parse(fs.readFileSync(process.argv[1], "utf8"));
        const value = manifest[process.argv[2]];
        if (typeof value !== "string" || value.length === 0) {
            process.exit(1);
        }
        process.stdout.write(value);
    ' "${manifest_path}" "${field_name}"
}

validate_expo_package() {
    [ -f "${EXPO_PACKAGE_DIR}/package.json" ] || fail "找不到 Expo npm 包清单：${EXPO_PACKAGE_DIR}/package.json"
    [ -f "${EXPO_PACKAGE_DIR}/SATagSDKExpo.podspec" ] || fail "找不到 Expo iOS Podspec"
    command -v node >/dev/null 2>&1 || fail "未找到 Node.js，无法校验 Expo npm 包"
    command -v npm >/dev/null 2>&1 || fail "未找到 npm，无法发布 Expo npm 包"

    EXPO_PACKAGE_MANIFEST_NAME=$(read_expo_package_field name) || fail "无法读取 Expo npm 包名"
    EXPO_PACKAGE_VERSION=$(read_expo_package_field version) || fail "无法读取 Expo npm 包版本"
    [ "${EXPO_PACKAGE_MANIFEST_NAME}" = "${EXPO_PACKAGE_NAME}" ] || \
        fail "Expo npm 包名必须为 ${EXPO_PACKAGE_NAME}，当前为 ${EXPO_PACKAGE_MANIFEST_NAME}"
    [ "${EXPO_PACKAGE_VERSION}" = "${VERSION}" ] || \
        alert_and_fail "Expo npm 包版本 ${EXPO_PACKAGE_VERSION} 与 SDK 版本 ${VERSION} 不一致，请先同步版本后再发布。"

    case "${NPM_REGISTRY}" in
        http://* | https://*)
            ;;
        *)
            fail "npm Registry 地址必须以 http:// 或 https:// 开头：${NPM_REGISTRY}"
            ;;
    esac

    case "${NPM_REGISTRY}" in
        */)
            ;;
        *)
            NPM_REGISTRY="${NPM_REGISTRY}/"
            ;;
    esac
}

prepare_expo_package() {
    (
        cd "${EXPO_PACKAGE_DIR}"
        if [ -f package-lock.json ]; then
            npm ci --ignore-scripts
        else
            npm install --ignore-scripts
        fi
        npm run build
        npm run test
        npm pack --dry-run --ignore-scripts --json >/dev/null
    ) || fail "Expo npm 包构建或打包校验失败"
}

resolve_npm_token() {
    if [ -n "${GITEA_NPM_TOKEN:-}" ]; then
        return 0
    fi

    GITEA_NPM_TOKEN=$(/bin/launchctl getenv GITEA_NPM_TOKEN 2>/dev/null || true)
    export GITEA_NPM_TOKEN
}

prepare_npm_publish_config() {
    resolve_npm_token
    [ -n "${GITEA_NPM_TOKEN:-}" ] || \
        alert_and_fail "未设置 GITEA_NPM_TOKEN，无法发布 ${EXPO_PACKAGE_NAME}。请在启动 Xcode 前配置该内网 npm Token。"

    NPM_AUTH_PATH=${NPM_REGISTRY#http://}
    NPM_AUTH_PATH=${NPM_AUTH_PATH#https://}
    NPM_CONFIG_FILE=$(mktemp "${TMPDIR:-/tmp}/SATagSDK-npmrc.XXXXXX")
    cat > "${NPM_CONFIG_FILE}" <<EOF
@starsdk:registry=${NPM_REGISTRY}
//${NPM_AUTH_PATH}:_authToken=${GITEA_NPM_TOKEN}
always-auth=true
EOF

    if (
        cd "${EXPO_PACKAGE_DIR}"
        NPM_CONFIG_USERCONFIG="${NPM_CONFIG_FILE}" npm view "${EXPO_PACKAGE_NAME}@${VERSION}" version --registry "${NPM_REGISTRY}" >/dev/null 2>&1
    ); then
        alert_and_fail "npm 包 ${EXPO_PACKAGE_NAME}@${VERSION} 已存在，npm 版本不可覆盖，请提升 SDK 版本后再发布。"
    fi
}

publish_expo_package() {
    if ! (
        cd "${EXPO_PACKAGE_DIR}"
        NPM_CONFIG_USERCONFIG="${NPM_CONFIG_FILE}" npm publish --ignore-scripts --registry "${NPM_REGISTRY}" --tag latest
    ); then
        alert_and_fail "SATagSDK Pod 已发布，但 npm 包 ${EXPO_PACKAGE_NAME}@${VERSION} 推送失败。请检查 Token 和内网 Registry 后手动重试 npm publish。"
    fi
}

write_podspec() {
    podspec_path="$1"

    cat > "${podspec_path}" <<PODSPEC
# SATagSDK 以 XCFramework 形式提供 AppsFlyer、Facebook、TikTok、Firebase 聚合打点能力。
# 二进制已嵌入三方渠道实现，消费者不要再单独添加这些渠道的 CocoaPods 依赖。
Pod::Spec.new do |s|
  s.name = '${POD_NAME}'
  s.version = '${VERSION}'
  s.summary = '聚合 AppsFlyer、Facebook、TikTok、Firebase 的打点 SDK。'

  s.description = <<-DESC
    SATagSDK 以 XCFramework 形式提供统一 Objective-C / Swift 打点入口。
    二进制已包含 AppsFlyer、Facebook、TikTok 和 Firebase Analytics。
  DESC

  s.homepage = 'http://172.20.30.113:13000/StarSdk/star_ios_pod_specs'
  s.license = { :type => 'Proprietary', :text => 'Copyright (c) StarSdk. All rights reserved.' }
  s.author = { 'StarSdk' => 'oubu@staruniongame.com' }

  # CocoaPods 解析 Spec 后会单独拉取 source；不能引用 Specs 仓库中的相对 zip 路径。
  # 因此二进制文件与 Spec 一同通过带版本的 Git tag 获取，发布时必须创建此 tag。
  s.source = {
    :git => 'http://172.20.30.113:13000/StarSdk/star_ios_pod_specs.git',
    :tag => '${TAG_NAME}'
  }

  s.ios.deployment_target = '${DEPLOYMENT_TARGET}'
  s.requires_arc = true
  s.vendored_frameworks = '${POD_NAME}/${VERSION}/Frameworks/${FRAMEWORK_NAME}.xcframework'
end
PODSPEC
}

validate_release_directory() {
    release_directory="$1"
    framework_directory="${release_directory}/Frameworks/${FRAMEWORK_NAME}.xcframework"

    [ -f "${framework_directory}/Info.plist" ] || fail "XCFramework 缺少 Info.plist：${framework_directory}"
    [ -f "${framework_directory}/ios-arm64/${FRAMEWORK_NAME}.framework/${FRAMEWORK_NAME}" ] || fail "XCFramework 缺少真机 arm64 slice"

    simulator_binary=$(find "${framework_directory}" -path "*-simulator/${FRAMEWORK_NAME}.framework/${FRAMEWORK_NAME}" -type f -print -quit)
    [ -n "${simulator_binary}" ] || fail "XCFramework 缺少模拟器 slice"

    /usr/bin/plutil -lint "${framework_directory}/Info.plist" >/dev/null
    pod ipc spec "${release_directory}/${POD_NAME}.podspec" >/dev/null
}

[ -f "${VERSION_FILE}" ] || fail "找不到 SDK 版本文件：${VERSION_FILE}"
[ -f "${WORKSPACE}/contents.xcworkspacedata" ] || fail "找不到 Workspace：${WORKSPACE}"
[ -d "${XCFRAMEWORK_PATH}" ] || fail "找不到 BuildSATagSDKXCFramework 产物：${XCFRAMEWORK_PATH}"
command -v pod >/dev/null 2>&1 || fail "未找到 CocoaPods 命令 pod，无法校验 Podspec"

VERSION=$(read_version) || fail "无法读取 SDK 版本号：${VERSION_FILE}"
validate_dotted_number "${VERSION}" || fail "SDK 版本号格式无效：${VERSION}"
DEPLOYMENT_TARGET=$(read_deployment_target) || fail "无法读取 ${FRAMEWORK_NAME} 的最低 iOS 版本"
validate_dotted_number "${DEPLOYMENT_TARGET}" || fail "最低 iOS 版本格式无效：${DEPLOYMENT_TARGET}"
validate_expo_package
prepare_expo_package

RELEASE_RELATIVE_PATH="${POD_NAME}/${VERSION}"
RELEASE_DIRECTORY="${POD_SPECS_REPO}/${RELEASE_RELATIVE_PATH}"
TAG_NAME="${POD_NAME}-${VERSION}"

if [ "${DRY_RUN}" = "1" ]; then
    TEMP_DIRECTORY=$(mktemp -d "${TMPDIR:-/tmp}/SATagSDK-release.XXXXXX")
    RELEASE_DIRECTORY="${TEMP_DIRECTORY}/${RELEASE_RELATIVE_PATH}"
elif [ "${DRY_RUN}" != "0" ]; then
    fail "SATAG_RELEASE_DRY_RUN / SDK_RELEASE_DRY_RUN 仅支持 0 或 1"
else
    [ -d "${POD_SPECS_REPO}/.git" ] || fail "找不到 Pod Specs Git 仓库：${POD_SPECS_REPO}"
    git -C "${POD_SPECS_REPO}" rev-parse --is-inside-work-tree >/dev/null || fail "Pod Specs 路径不是 Git 仓库"
    preflight_pod_specs_repository
    prepare_npm_publish_config

    if git -C "${POD_SPECS_REPO}" rev-parse -q --verify "refs/tags/${TAG_NAME}" >/dev/null; then
        fail "发布 tag 已存在：${TAG_NAME}"
    fi
    if [ -e "${RELEASE_DIRECTORY}" ]; then
        fail "版本目录已存在，拒绝覆盖已发布内容：${RELEASE_DIRECTORY}"
    fi
fi

echo "开始发布 ${POD_NAME} ${VERSION}"
echo "XCFramework：${XCFRAMEWORK_PATH}"
echo "最低 iOS 版本：${DEPLOYMENT_TARGET}"
echo "版本目录：${RELEASE_DIRECTORY}"
echo "Expo npm 包：${EXPO_PACKAGE_NAME}@${VERSION}"

mkdir -p "${RELEASE_DIRECTORY}/Frameworks"
if [ "${DRY_RUN}" = "0" ]; then
    CREATED_RELEASE_DIRECTORY="${RELEASE_DIRECTORY}"
fi
cp -R "${XCFRAMEWORK_PATH}" "${RELEASE_DIRECTORY}/Frameworks/"
write_podspec "${RELEASE_DIRECTORY}/${POD_NAME}.podspec"
validate_release_directory "${RELEASE_DIRECTORY}"

if [ "${DRY_RUN}" = "1" ]; then
    echo "预演通过：将提交 ${RELEASE_RELATIVE_PATH}、创建 tag ${TAG_NAME}，并发布 npm 包 ${EXPO_PACKAGE_NAME}@${VERSION}"
    exit 0
fi

git -C "${POD_SPECS_REPO}" add -- "${RELEASE_RELATIVE_PATH}"
RELEASE_STAGED=1
STAGED_PATHS=$(git -C "${POD_SPECS_REPO}" diff --cached --name-only)
validate_paths_belong_to_release "${STAGED_PATHS}"
git -C "${POD_SPECS_REPO}" diff --cached --check -- "${RELEASE_RELATIVE_PATH}/${POD_NAME}.podspec"
git -C "${POD_SPECS_REPO}" commit --only -m "发布 SATagSDK ${VERSION}" -- "${RELEASE_RELATIVE_PATH}"
RELEASE_COMMITTED=1
COMMIT_PATHS=$(git -C "${POD_SPECS_REPO}" diff-tree --no-commit-id --name-only -r HEAD)
validate_paths_belong_to_release "${COMMIT_PATHS}"
git -C "${POD_SPECS_REPO}" tag -a "${TAG_NAME}" -m "发布 ${POD_NAME} ${VERSION}"
if ! git -C "${POD_SPECS_REPO}" push --atomic "${PUSH_REMOTE}" "HEAD:refs/heads/${PUSH_BRANCH}" "refs/tags/${TAG_NAME}:refs/tags/${TAG_NAME}"; then
    alert_and_fail "发布提交和 tag 已在本地创建，但推送失败。请手动检查并推送后再继续。"
fi
publish_expo_package

echo "发布完成：${POD_NAME} ${VERSION}"
echo "提交：$(git -C "${POD_SPECS_REPO}" rev-parse --short HEAD)"
echo "Tag：${TAG_NAME}"
echo "npm：${EXPO_PACKAGE_NAME}@${VERSION}"
