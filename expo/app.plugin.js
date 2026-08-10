const { withPodfile } = require('@expo/config-plugins');

const firebaseModularHeadersMarker = '# SATagSDK Firebase modular headers';

/**
 * 为 Firebase Core 依赖链生成模块映射。
 *
 * Expo 使用静态链接时，FirebaseCoreInternal、FirebaseInstallations 会以
 * 模块方式导入 FirebaseCore 和 GoogleUtilities。该配置必须出现在宿主 App
 * 的 target 内，由插件自动写入，接入方无需维护 Podfile。
 */
function withFirebaseModularHeaders(config) {
  return withPodfile(config, (podfileConfig) => {
    const contents = podfileConfig.modResults.contents;
    if (contents.includes(firebaseModularHeadersMarker)) {
      return podfileConfig;
    }

    const targetDeclaration = contents.match(/^target ['"][^'"]+['"] do/m);
    if (!targetDeclaration) {
      throw new Error('SATagSDK 无法在 Podfile 中找到 iOS target，无法配置 Firebase 模块映射。');
    }

    const modularHeadersDeclaration = [
      firebaseModularHeadersMarker,
      "  pod 'FirebaseCore', :modular_headers => true",
      "  pod 'FirebaseCoreInternal', :modular_headers => true",
      "  pod 'FirebaseInstallations', :modular_headers => true",
      "  pod 'GoogleUtilities', :modular_headers => true",
    ].join('\n');
    podfileConfig.modResults.contents = contents.replace(
      targetDeclaration[0],
      `${targetDeclaration[0]}\n  ${modularHeadersDeclaration}`,
    );
    return podfileConfig;
  });
}

/**
 * SATagSDK Expo Config Plugin。
 *
 * Expo 的 ios.googleServicesFile 会在 prebuild/EAS iOS 构建阶段把
 * GoogleService-Info.plist 加入宿主 App。这里允许接入方把该路径放到
 * SATagSDK 插件参数中，避免在 app.json 和 plugins 中重复声明。
 */
module.exports = function withSATagSDK(config, options = {}) {
  const googleServicesFile = options.googleServicesFile;
  let updatedConfig = config;
  if (googleServicesFile) {
    updatedConfig = {
      ...updatedConfig,
      ios: {
        ...(updatedConfig.ios || {}),
        googleServicesFile,
      },
    };
  }

  return withFirebaseModularHeaders(updatedConfig);
};
