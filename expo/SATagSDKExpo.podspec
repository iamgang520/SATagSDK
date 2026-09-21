require 'json'

package = JSON.parse(File.read(File.join(__dir__, 'package.json')))

Pod::Spec.new do |s|
  s.name = 'SATagSDKExpo'
  s.version = package['version']
  s.summary = 'Expo bridge for SATagSDK'
  s.description = 'Objective-C React Native bridge and Expo Config Plugin for SATagSDK.'
  s.homepage = 'http://172.20.30.113:13000/StarSdk/star_ios_pod_specs'
  s.license = { :type => 'Proprietary', :text => 'Copyright (c) StarSdk. All rights reserved.' }
  s.author = { 'StarSdk' => 'oubu@staruniongame.com' }
  s.source = {
    :git => 'http://172.20.30.113:13000/StarSdk/star_ios_pod_specs.git',
    :tag => "SATagSDK-#{s.version}"
  }
  s.platform = :ios, '13.0'

  # podspec 位于 npm 包根目录，原生桥接源码位于 ios 子目录。
  s.source_files = 'ios/**/*.{h,m}'
  s.requires_arc = true
  s.dependency 'React-Core'
  s.dependency 'SATagSDK'
end
