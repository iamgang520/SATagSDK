#!/bin/bash
#
# SATagSDK XCFramework 构建脚本
#
# 说明：
# 1. 通过 CocoaPods Workspace 构建 SDK，确保三方依赖参与构建。
# 2. 真机和模拟器使用不同 DerivedData，避免嵌套 xcodebuild 争用 build.db。
# 3. 将三方动态 Framework 嵌入 SATagSDK.framework/Frameworks，最终用户只需要
#    引入一个 SATagSDK.xcframework；宿主 App 仍需要按 Apple 规则签名/嵌入该包。
# 4. 所有关键产物都在打包前校验，任一渠道缺失时立即失败，不生成不完整包。
#

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORKSPACE_PATH="${ROOT_DIR}/SATagSDKDemo.xcworkspace"
SCHEME_NAME="SATagSDK"
CONFIGURATION="${CONFIGURATION:-Release}"
BUILD_ROOT="${ROOT_DIR}/Build/XCFramework"
DEVICE_DERIVED_DATA="${BUILD_ROOT}/DerivedData-iphoneos"
SIMULATOR_DERIVED_DATA="${BUILD_ROOT}/DerivedData-iphonesimulator"
OUTPUT_PATH="${ROOT_DIR}/Build/SATagSDK.xcframework"

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

require_directory "$WORKSPACE_PATH"
mkdir -p "$BUILD_ROOT"

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

rm -rf "$OUTPUT_PATH"
mkdir -p "$(dirname "$OUTPUT_PATH")"

log "生成 ${OUTPUT_PATH}"
xcodebuild -create-xcframework \
  -framework "$DEVICE_SDK_FRAMEWORK" \
  -framework "$SIMULATOR_SDK_FRAMEWORK" \
  -output "$OUTPUT_PATH"

require_directory "$OUTPUT_PATH"
require_directory "${OUTPUT_PATH}/ios-arm64"
require_directory "${OUTPUT_PATH}/ios-arm64_x86_64-simulator"

log "XCFramework 构建完成：${OUTPUT_PATH}"
