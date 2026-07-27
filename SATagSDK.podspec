#
# SATagSDK.podspec
# 聚合 AppsFlyer、Facebook、TikTok 的 Objective-C 打点 SDK。
#

Pod::Spec.new do |s|
  s.name             = 'SATagSDK'
  s.version          = '1.1.0'
  s.summary          = 'SATagSDK 聚合 AppsFlyer、Facebook、TikTok、Firebase 打点'
  s.description      = <<-DESC
  SATagSDK provides a unified Objective-C and Swift-compatible API for AppsFlyer,
  Facebook, TikTok and Firebase Analytics custom events.
                       DESC
  s.homepage         = 'https://github.com/iamgang520/SATagSDK'
  s.license          = { :type => 'Commercial', :text => 'Copyright Star Fortune.' }
  s.author           = { 'Star Fortune' => 'sdk@starfortune.com' }

  # 正式提交 CocoaPods Trunk 前通过环境变量注入真实公开仓库地址。
  source_url = ENV['SATAG_SOURCE_URL'] || 'https://github.com/iamgang520/SATagSDK.git'
  s.source = { :git => source_url, :tag => s.version.to_s }

  s.ios.deployment_target = '13.0'
  s.requires_arc = true
  s.frameworks = 'Foundation', 'UIKit'
  s.static_framework = true
  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'CLANG_ENABLE_MODULES' => 'YES',
    'OTHER_LDFLAGS' => '$(inherited) -ObjC'
  }

  s.default_subspecs = 'All'

  s.subspec 'Core' do |ss|
    ss.source_files = 'SATagSDK/**/*.{h,m}'
    ss.public_header_files = [
      'SATagSDK/SATagSDK.h',
      'SATagSDK/Models/SATagTypes.h',
      'SATagSDK/Models/SATagInitializationResult.h',
      'SATagSDK/Models/SATagEventResult.h'
    ]
    ss.resource_bundles = {
      'SATagSDK_Privacy' => ['SATagSDK/Resources/PrivacyInfo.xcprivacy']
    }
  end

  s.subspec 'AppsFlyer' do |ss|
    ss.dependency 'SATagSDK/Core'
    ss.dependency 'AppsFlyerFramework', '7.0.1'
  end

  s.subspec 'Facebook' do |ss|
    ss.dependency 'SATagSDK/Core'
    ss.dependency 'FBSDKCoreKit', '18.0.1'
  end

  s.subspec 'TikTok' do |ss|
    ss.dependency 'SATagSDK/Core'
    ss.dependency 'TikTokBusinessSDK', '1.7.1'
  end

  s.subspec 'Firebase' do |ss|
    ss.dependency 'SATagSDK/Core'
    # Firebase 12.x 的最低 iOS 版本已高于本 SDK 的 iOS 13 约束；
    # 11.15.0 是已验证可用于 iOS 13 的 Firebase Analytics 版本。
    ss.dependency 'FirebaseAnalytics', '11.15.0'
  end

  s.subspec 'All' do |ss|
    ss.dependency 'SATagSDK/AppsFlyer'
    ss.dependency 'SATagSDK/Facebook'
    ss.dependency 'SATagSDK/TikTok'
    ss.dependency 'SATagSDK/Firebase'
  end
end
