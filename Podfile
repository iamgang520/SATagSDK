platform :ios, '13.0'

target 'SATagSDK' do
  use_frameworks!

  # SDK Target 使用三方 Pod 自带的二进制/源码分发，保证完整构建产物
  # 中包含 AppsFlyer、Facebook 和 TikTok 的真实实现。
  pod 'AppsFlyerFramework', '7.0.1'
  pod 'FBSDKCoreKit', '18.0.1'
  pod 'TikTokBusinessSDK', '1.7.1'
end

target 'SATagSDKDemo' do
  use_frameworks!
end

post_install do |installer|
  # Xcode 26 默认开启用户脚本沙盒，但 CocoaPods 的资源脚本需要在
  # 构建目录和 Pods 根目录写入中间文件。关闭该选项后，SDK 工程和
  # CocoaPods 生成 Target 的行为保持一致。
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |configuration|
      configuration.build_settings['ENABLE_USER_SCRIPT_SANDBOXING'] = 'NO'
    end
  end

  # CocoaPods 1.16.2 生成的错误处理脚本使用了 GNU realpath -m，
  # macOS 自带 realpath 不支持该参数。将错误位置改为可移植的脚本路径，
  # 避免每次 pod install 后手工修改生成文件。
  generated_script_paths = Dir[
    File.join(installer.sandbox.root.to_s, 'Target Support Files', '**', '*.sh')
  ]
  generated_script_paths.each do |script_path|
    content = File.read(script_path)
    next unless content.include?('realpath -mq')

    content = content.gsub(
      '$(realpath -mq "${0}")',
      '${0}'
    )
    File.write(script_path, content)
  end
end
