#
# SATagSDK.podspec
# 本文件仅供本仓库本地 :path 开发使用。正式发布由 Scripts/PublishSATagSDKPod.sh
# 写入私有 Specs 仓库的二进制 Podspec，不要再推送到 CocoaPods Trunk。
#

require 'json'

version_file = File.join(__dir__, 'SATagSDK/Config/SATagVersion.json')
sdk_version = JSON.parse(File.read(version_file)).fetch(0).fetch('version')

Pod::Spec.new do |s|
  s.name             = 'SATagSDK'
  s.version          = sdk_version
  s.summary          = 'SATagSDK 聚合 AppsFlyer、Facebook、TikTok、Firebase 打点'
  s.description      = <<-DESC
  SATagSDK provides a unified Objective-C and Swift-compatible API for AppsFlyer,
  Facebook, TikTok and Firebase Analytics custom events.
                       DESC
  s.homepage         = 'http://172.20.30.113:13000/StarSdk/star_ios_pod_specs'
  s.license          = { :type => 'Proprietary', :text => 'Copyright (c) StarSdk. All rights reserved.' }
  s.author           = { 'StarSdk' => 'oubu@staruniongame.com' }
  s.source           = {
    :git => 'http://172.20.30.113:13000/StarSdk/star_ios_pod_specs.git',
    :tag => "SATagSDK-#{s.version}"
  }

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
