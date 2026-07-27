/**
 * SATagSDK Expo Config Plugin。
 *
 * Expo 的 ios.googleServicesFile 会在 prebuild/EAS iOS 构建阶段把
 * GoogleService-Info.plist 加入宿主 App。这里允许接入方把该路径放到
 * SATagSDK 插件参数中，避免在 app.json 和 plugins 中重复声明。
 */
module.exports = function withSATagSDK(config, options = {}) {
  const googleServicesFile = options.googleServicesFile;
  if (!googleServicesFile) {
    return config;
  }

  return {
    ...config,
    ios: {
      ...(config.ios || {}),
      googleServicesFile
    }
  };
};
