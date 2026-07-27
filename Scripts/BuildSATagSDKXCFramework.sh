#!/bin/bash
#
# SATagSDK XCFramework 发布包构建脚本
#
# 说明：
# 1. 通过 CocoaPods Workspace 构建 SDK，确保三方依赖参与构建。
# 2. 真机和模拟器使用不同 DerivedData，避免嵌套 xcodebuild 争用 build.db。
# 3. 将三方动态 Framework 嵌入 SATagSDK.framework/Frameworks，最终用户只需要
#    引入一个 SATagSDK.xcframework；宿主 App 仍需要按 Apple 规则签名/嵌入该包。
# 4. 所有中间产物写入系统临时目录，Build 目录最终只保留版本化 ZIP。
# 5. ZIP 只包含 SATagSDK.xcframework、开发者 HTML 和模型 Markdown。
#

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORKSPACE_PATH="${ROOT_DIR}/SATagSDKDemo.xcworkspace"
SCHEME_NAME="SATagSDK"
CONFIGURATION="${CONFIGURATION:-Release}"
OUTPUT_ROOT="${ROOT_DIR}/Build"
VERSION="$(sed -nE "s/^[[:space:]]*s\\.version[[:space:]]*=[[:space:]]*['\"]([^'\"]+)['\"].*/\\1/p" \
  "${ROOT_DIR}/SATagSDK.podspec" | head -n 1)"

if [[ -z "$VERSION" ]]; then
  printf '[SATagSDK] error: 无法从 SATagSDK.podspec 读取版本号\n' >&2
  exit 1
fi

TEMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/SATagSDK-build.XXXXXX")"
trap 'rm -rf "$TEMP_ROOT"' EXIT

BUILD_ROOT="${TEMP_ROOT}/XCFramework"
DEVICE_DERIVED_DATA="${BUILD_ROOT}/DerivedData-iphoneos"
SIMULATOR_DERIVED_DATA="${BUILD_ROOT}/DerivedData-iphonesimulator"
OUTPUT_PATH="${BUILD_ROOT}/SATagSDK.xcframework"
PACKAGE_ROOT="${TEMP_ROOT}/SATagSDK-${VERSION}"
OUTPUT_ZIP="${OUTPUT_ROOT}/SATagSDK-${VERSION}.zip"

DEVICE_PRODUCTS="${DEVICE_DERIVED_DATA}/Build/Products/${CONFIGURATION}-iphoneos"
SIMULATOR_PRODUCTS="${SIMULATOR_DERIVED_DATA}/Build/Products/${CONFIGURATION}-iphonesimulator"

log() {
  printf '[SATagSDK] %s\n' "$1"
}

fail() {
  printf '[SATagSDK] error: %s\n' "$1" >&2
  exit 1
}

require_directory() {
  if [[ ! -d "$1" ]]; then
    fail "找不到目录：$1"
  fi
}

require_file() {
  if [[ ! -f "$1" ]]; then
    fail "找不到文件：$1"
  fi
}

find_framework() {
  local products_path="$1"
  local framework_name="$2"
  find "$products_path" -type d -name "${framework_name}.framework" -print -quit
}

build_platform() {
  local sdk="$1"
  local destination="$2"
  local derived_data="$3"

  log "开始构建 ${sdk}：${derived_data}"
  rm -rf "$derived_data"
  xcodebuild \
    -workspace "$WORKSPACE_PATH" \
    -scheme "$SCHEME_NAME" \
    -configuration "$CONFIGURATION" \
    -sdk "$sdk" \
    -destination "$destination" \
    -derivedDataPath "$derived_data" \
    BUILD_LIBRARY_FOR_DISTRIBUTION=YES \
    SKIP_INSTALL=NO \
    CODE_SIGNING_ALLOWED=NO \
    build
}

copy_embedded_framework() {
  local source_framework="$1"
  local target_framework="$2"
  local framework_name
  framework_name="$(basename "$source_framework")"

  mkdir -p "${target_framework}/Frameworks"
  rm -rf "${target_framework}/Frameworks/${framework_name}"
  ditto "$source_framework" "${target_framework}/Frameworks/${framework_name}"
}

copy_resource_bundles() {
  local products_path="$1"
  local target_framework="$2"
  local bundle_path
  local bundle_name

  while IFS= read -r bundle_path; do
    [[ -z "$bundle_path" ]] && continue
    bundle_name="$(basename "$bundle_path")"
    [[ -e "${target_framework}/${bundle_name}" ]] && continue
    ditto "$bundle_path" "${target_framework}/${bundle_name}"
  done < <(find "$products_path" -type d -name '*.bundle' -print)
}

package_release() {
  require_directory "$OUTPUT_PATH"
  require_directory "${OUTPUT_PATH}/ios-arm64"
  require_directory "${OUTPUT_PATH}/ios-arm64_x86_64-simulator"
  require_file "$ROOT_DIR/SATagSDK-Integration.html"
  require_file "$ROOT_DIR/SATagSDK-Integration.md"

  rm -rf "$PACKAGE_ROOT"
  mkdir -p "$PACKAGE_ROOT"
  ditto "$OUTPUT_PATH" "${PACKAGE_ROOT}/SATagSDK.xcframework"
  ditto "${ROOT_DIR}/SATagSDK-Integration.html" "${PACKAGE_ROOT}/SATagSDK-Integration.html"
  ditto "${ROOT_DIR}/SATagSDK-Integration.md" "${PACKAGE_ROOT}/SATagSDK-Integration.md"

  mkdir -p "$OUTPUT_ROOT"
  rm -f "$OUTPUT_ZIP"
  log "生成发布包 ${OUTPUT_ZIP}"
  (
    cd "$PACKAGE_ROOT"
    /usr/bin/zip -qry "$OUTPUT_ZIP" \
      "SATagSDK.xcframework" \
      "SATagSDK-Integration.html" \
      "SATagSDK-Integration.md"
  )

  /usr/bin/unzip -t "$OUTPUT_ZIP" >/dev/null
  ZIP_TOP_LEVEL_ENTRIES="$(
    /usr/bin/unzip -Z1 "$OUTPUT_ZIP" |
      awk -F/ 'NF { print $1 }' |
      sort -u
  )"
  EXPECTED_TOP_LEVEL_ENTRIES=$'SATagSDK-Integration.html\nSATagSDK-Integration.md\nSATagSDK.xcframework'
  [[ "$ZIP_TOP_LEVEL_ENTRIES" == "$EXPECTED_TOP_LEVEL_ENTRIES" ]] \
    || fail "发布包顶层内容不符合预期：${ZIP_TOP_LEVEL_ENTRIES}"
  /usr/bin/unzip -Z1 "$OUTPUT_ZIP" | grep -qx "SATagSDK-Integration.html" \
    || fail "发布包缺少 SATagSDK-Integration.html"
  /usr/bin/unzip -Z1 "$OUTPUT_ZIP" | grep -qx "SATagSDK-Integration.md" \
    || fail "发布包缺少 SATagSDK-Integration.md"
  /usr/bin/unzip -Z1 "$OUTPUT_ZIP" | grep '^SATagSDK\.xcframework/' >/dev/null \
    || fail "发布包缺少 SATagSDK.xcframework"
}

require_directory "$WORKSPACE_PATH"
require_file "$ROOT_DIR/SATagSDK-Integration.html"
require_file "$ROOT_DIR/SATagSDK-Integration.md"
rm -rf "$OUTPUT_ROOT"
mkdir -p "$OUTPUT_ROOT"

build_platform \
  iphoneos \
  "generic/platform=iOS" \
  "$DEVICE_DERIVED_DATA"
build_platform \
  iphonesimulator \
  "generic/platform=iOS Simulator" \
  "$SIMULATOR_DERIVED_DATA"

require_directory "$DEVICE_PRODUCTS"
require_directory "$SIMULATOR_PRODUCTS"

DEVICE_SDK_FRAMEWORK="${DEVICE_PRODUCTS}/SATagSDK.framework"
SIMULATOR_SDK_FRAMEWORK="${SIMULATOR_PRODUCTS}/SATagSDK.framework"
require_directory "$DEVICE_SDK_FRAMEWORK"
require_directory "$SIMULATOR_SDK_FRAMEWORK"

DEPENDENCY_NAMES=(
  "AppsFlyerLib"
  "FBAEMKit"
  "FBSDKCoreKit"
  "FBSDKCoreKit_Basics"
  "TikTokBusinessSDK"
  "FirebaseAnalytics"
  "FirebaseCore"
  "FirebaseCoreInternal"
  "FirebaseInstallations"
  "GoogleAdsOnDeviceConversion"
  "GoogleAppMeasurement"
  "GoogleAppMeasurementIdentitySupport"
  "GoogleUtilities"
  "FBLPromises"
  "nanopb"
)

for dependency_name in "${DEPENDENCY_NAMES[@]}"; do
  device_dependency="$(find_framework "$DEVICE_PRODUCTS" "$dependency_name")"
  simulator_dependency="$(find_framework "$SIMULATOR_PRODUCTS" "$dependency_name")"

  [[ -n "$device_dependency" ]] || fail "真机缺少 ${dependency_name}.framework"
  [[ -n "$simulator_dependency" ]] || fail "模拟器缺少 ${dependency_name}.framework"

  copy_embedded_framework "$device_dependency" "$DEVICE_SDK_FRAMEWORK"
  copy_embedded_framework "$simulator_dependency" "$SIMULATOR_SDK_FRAMEWORK"
done

# CocoaPods 资源脚本通常会把隐私资源复制到各自的产品目录；
# 统一复制到 SATagSDK.framework 根目录，便于单包集成时随框架分发。
copy_resource_bundles "$DEVICE_PRODUCTS" "$DEVICE_SDK_FRAMEWORK"
copy_resource_bundles "$SIMULATOR_PRODUCTS" "$SIMULATOR_SDK_FRAMEWORK"

log "生成 ${OUTPUT_PATH}"
xcodebuild -create-xcframework \
  -framework "$DEVICE_SDK_FRAMEWORK" \
  -framework "$SIMULATOR_SDK_FRAMEWORK" \
  -output "$OUTPUT_PATH"

package_release

log "构建完成：${OUTPUT_ZIP}"
log "Build 目录仅保留最终发布包，临时构建目录已清理"
