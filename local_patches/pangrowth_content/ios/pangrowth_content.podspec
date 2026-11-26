#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint pangrowth_content.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'pangrowth_content'
  s.version          = '0.0.1'
  s.summary          = '穿山甲内容输出插件，支持短剧和小视频'
  s.description      = <<-DESC
穿山甲内容输出Flutter插件，基于PanGrowth SDK实现短剧播放、小视频等内容功能。
支持iOS 13.0+，提供完整的内容管理和播放能力。
                       DESC
  s.homepage         = 'https://www.zhecent.com'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'lightcore' => '369620805@qq.com' }
  s.source           = { :path => '.' }
  s.source_files = 'Classes/**/*.{swift,h,m}'
  s.dependency 'Flutter'
  s.platform = :ios, '13.0'

  # 穿山甲内容SDK依赖 - 升级到官方推荐的最新稳定版本
  # 注意：需要在Podfile中添加source 'https://github.com/volcengine/volcengine-specs.git'

  # 点播引擎 - 必须依赖，播放性能更好，版本必须带-premium
  # s.dependency 'TTSDKFramework/Player-SR', '1.42.3.4-premium'

  # 短视频SDK - 提供短视频能力
  s.dependency 'Pangrowth/media', '5.4.0.0'

  # 内容SDK - 短剧和短故事功能，使用最新版本
  s.dependency 'PangrowthX/shortplay', '2.8.0.0'
  s.dependency 'PangrowthX/ministory', '2.8.0.0'

  # 注意：广告SDK依赖已移除，避免与gromore_ads插件冲突
  # 如需广告功能，请通过gromore_ads插件使用

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386',
    'OTHER_LDFLAGS' => '-ObjC'
  }
  s.swift_version = '5.0'

  # Privacy manifest for App Store compliance
  s.resource_bundles = {'pangrowth_content_privacy' => ['Resources/PrivacyInfo.xcprivacy']}
end
