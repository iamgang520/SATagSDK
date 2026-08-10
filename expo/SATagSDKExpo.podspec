Pod::Spec.new do |s|
  s.name = 'SATagSDKExpo'
  s.version = '1.1.3'
  s.summary = 'Expo bridge for SATagSDK'
  s.description = 'Objective-C React Native bridge and Expo Config Plugin for SATagSDK.'
  s.homepage = 'https://github.com/iamgang520/SATagSDK'
  s.license = { :type => 'Commercial', :text => 'Copyright Star Fortune.' }
  s.author = { 'Star Fortune' => 'sdk@starfortune.com' }
  s.source = {
    :git => 'https://github.com/iamgang520/SATagSDK.git',
    :tag => s.version.to_s
  }
  s.platform = :ios, '13.0'

  # podspec 位于 npm 包根目录，原生桥接源码位于 ios 子目录。
  s.source_files = 'ios/**/*.{h,m}'
  s.requires_arc = true
  s.dependency 'React-Core'
  s.dependency 'SATagSDK/All', '1.1.0'
end
