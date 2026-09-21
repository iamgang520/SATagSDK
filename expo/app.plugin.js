const { createRunOncePlugin, withPodfile } = require('@expo/config-plugins');

const PACKAGE_NAME = '@starsdk/ios-satagsdk-expo';
const PACKAGE_VERSION = require('./package.json').version;
const COCOAPODS_CDN_SOURCE = "source 'https://cdn.cocoapods.org/'";
const STAR_SPECS_SOURCE = "source 'http://172.20.30.113:13000/StarSdk/star_ios_pod_specs.git'";
const SATAG_POD_DECLARATION = "pod 'SATagSDK'";

/** 在 Podfile 顶部插入 source，保留原有 source 顺序且避免重复写入。 */
function ensurePodSource(contents, sourceDeclaration) {
  return contents.includes(sourceDeclaration) ? contents : `${sourceDeclaration}\n${contents}`;
}

/**
 * 将 SATagSDK 放入 Expo 应用 target；优先插在 use_expo_modules! 之后，
 * 对于非标准 Podfile 则退化为插入第一个 target 块。找不到 target 时明确失败。
 */
function ensureSATagSDKPod(contents) {
  if (new RegExp(`(^|\\n)\\s*${SATAG_POD_DECLARATION.replace(/[.*+?^${}()|[\\]\\\\]/g, '\\$&')}\\s*(\\n|$)`).test(contents)) {
    return contents;
  }

  const expoModulesPattern = /^(\s*)use_expo_modules!.*$/m;
  if (expoModulesPattern.test(contents)) {
    return contents.replace(expoModulesPattern, (line, indentation) => `${line}\n${indentation}${SATAG_POD_DECLARATION}`);
  }

  const targetPattern = /^(\s*)target\s+['"][^'"]+['"]\s+do.*$/m;
  if (targetPattern.test(contents)) {
    return contents.replace(targetPattern, (line, indentation) => `${line}\n${indentation}  ${SATAG_POD_DECLARATION}`);
  }

  throw new Error('未找到 iOS target，无法向 Podfile 注入 SATagSDK。');
}

/**
 * 将公开 CDN 与统一私有 Specs 源一起接入。
 * 私有二进制 Pod 已包含渠道依赖，不再注入旧的公网 Trunk 源或额外基础库源。
 */
function updatePodfile(contents) {
  let updatedContents = ensurePodSource(contents, STAR_SPECS_SOURCE);
  updatedContents = ensurePodSource(updatedContents, COCOAPODS_CDN_SOURCE);
  return ensureSATagSDKPod(updatedContents);
}

/**
 * 允许接入方把 GoogleService-Info.plist 路径放到插件参数中，
 * 避免在 app.json 和 plugins 中重复声明。
 */
function withGoogleServicesFile(config, options = {}) {
  const googleServicesFile = options.googleServicesFile;
  if (!googleServicesFile) {
    return config;
  }

  return {
    ...config,
    ios: {
      ...(config.ios || {}),
      googleServicesFile,
    },
  };
}

function withSATagSDK(config, options = {}) {
  return withPodfile(withGoogleServicesFile(config, options), (podfileConfig) => {
    podfileConfig.modResults.contents = updatePodfile(podfileConfig.modResults.contents);
    return podfileConfig;
  });
}

const plugin = createRunOncePlugin(withSATagSDK, PACKAGE_NAME, PACKAGE_VERSION);

plugin._internal = {
  ensurePodSource,
  ensureSATagSDKPod,
  updatePodfile,
};

module.exports = plugin;
