import 'privacy_config.dart';

/// 内容 SDK 初始化配置
///
/// 参数平台支持说明：
/// - ✅ 完全支持：在该平台上完全可用
/// - ⚠️ 部分支持：在该平台上部分可用或通过其他方式实现
/// - ❌ 不支持：该平台SDK暂不支持此配置
class ContentConfig {
  /// 是否接入短剧能力（默认为 true）
  ///
  /// **平台支持**:
  /// - Android: ✅ 支持
  /// - iOS: ✅ 支持
  final bool enableDrama;

  /// 是否接入短故事能力（默认为 false）
  ///
  /// **平台支持**:
  /// - Android: ✅ 支持
  /// - iOS: ✅ 支持
  final bool enableStory;

  /// 是否接入小视频能力（默认为 true）
  ///
  /// **平台支持**:
  /// - Android: ✅ 支持
  /// - iOS: ⚠️ 部分支持（部分小视频功能iOS暂不可用）
  final bool enableVideo;

  /// 是否开启调试日志（null 表示使用 SDK 默认值）
  ///
  /// **平台支持**:
  /// - Android: ✅ 完全支持
  /// - iOS: ✅ 完全支持
  final bool? debugLog;

  /// 图片缓存大小（单位 MB）
  ///
  /// **平台支持**:
  /// - Android: ⚠️ SDK可能不直接支持，通过系统缓存管理
  /// - iOS: ⚠️ SDK可能不直接支持，通过系统缓存管理
  ///
  /// 注意：此参数会被记录但可能不会直接影响SDK行为
  final int? imageCacheSize;

  /// 是否禁用 A/B 实验
  ///
  /// **平台支持**:
  /// - Android: ⚠️ 可能需要通过其他SDK方法设置
  /// - iOS: ✅ 完全支持
  final bool? disableAbTest;

  /// 是否判断为新用户（配合 [newUserAliveSeconds] 使用）
  ///
  /// **平台支持**:
  /// - Android: ⚠️ 可能在用户系统中管理
  /// - iOS: ✅ 完全支持
  final bool? isNewUser;

  /// 新用户保护时长（单位秒）
  ///
  /// **平台支持**:
  /// - Android: ⚠️ 可能在用户系统中管理
  /// - iOS: ✅ 完全支持
  final int? newUserAliveSeconds;

  /// 个性化推荐开关（null 表示沿用 SDK 默认）
  ///
  /// **平台支持**:
  /// - Android: ⚠️ 通过setPersonalization方法单独设置
  /// - iOS: ❌ 暂无公开API
  ///
  /// 注意：iOS端暂未提供公开的个性化开关API
  final bool? personalizationEnabled;

  /// 登录态关联的用户 ID
  ///
  /// **平台支持**:
  /// - Android: ⚠️ 可能通过用户登录接口设置
  /// - iOS: ⚠️ 可能通过用户登录接口设置
  ///
  /// 注意：可能需要在初始化后通过专门的用户登录接口设置
  final String? userId;

  /// 媒体自定义渠道标识
  ///
  /// **平台支持**:
  /// - Android: ⚠️ 可能通过渠道配置或统计SDK设置
  /// - iOS: ⚠️ 可能通过渠道配置设置
  ///
  /// 注意：可能需要通过其他渠道配置方式设置
  final String? channel;

  /// 隐私合规配置
  ///
  /// **平台支持**:
  /// - Android: ⚠️ 需要通过privacyController设置
  /// - iOS: ⚠️ 需要通过privacyDelegate设置
  ///
  /// 注意：具体实现取决于SDK提供的隐私合规API
  final PrivacyConfig? privacy;

  /// 额外透传信息（例如自定义配置）
  ///
  /// **平台支持**:
  /// - Android: ⚠️ 自定义扩展参数
  /// - iOS: ⚠️ 自定义扩展参数
  ///
  /// 注意：用于特殊场景的自定义配置
  final Map<String, dynamic>? extra;

  const ContentConfig({
    this.enableDrama = true,
    this.enableStory = false,
    this.enableVideo = false,
    this.debugLog,
    this.imageCacheSize,
    this.disableAbTest,
    this.isNewUser,
    this.newUserAliveSeconds,
    this.personalizationEnabled,
    this.userId,
    this.channel,
    this.privacy,
    this.extra,
  });

  /// 从 Map 反序列化配置
  factory ContentConfig.fromMap(Map<String, dynamic> map) {
    return ContentConfig(
      enableDrama: map['enableDrama'] as bool? ?? true,
      enableStory: map['enableStory'] as bool? ?? false,
      enableVideo: map['enableVideo'] as bool? ?? true,
      debugLog: map['debugLog'] as bool?,
      imageCacheSize: _coerceInt(map['imageCacheSize']),
      disableAbTest: map['disableAbTest'] as bool?,
      isNewUser: map['isNewUser'] as bool?,
      newUserAliveSeconds: _coerceInt(map['newUserAliveSeconds']),
      personalizationEnabled: map['personalizationEnabled'] as bool?,
      userId: map['userId'] as String?,
      channel: map['channel'] as String?,
      privacy: map['privacy'] is Map<String, dynamic>
          ? PrivacyConfig.fromMap(map['privacy'] as Map<String, dynamic>)
          : null,
      extra: map['extra'] as Map<String, dynamic>?,
    );
  }

  /// 转换为 Map，自动过滤掉 null 值
  Map<String, dynamic> toMap() {
    final Map<String, dynamic> result = {
      'enableDrama': enableDrama,
      'enableStory': enableStory,
      'enableVideo': enableVideo,
    };

    void put(String key, dynamic value) {
      if (value != null) {
        result[key] = value;
      }
    }

    put('debugLog', debugLog);
    put('imageCacheSize', imageCacheSize);
    put('disableAbTest', disableAbTest);
    put('isNewUser', isNewUser);
    put('newUserAliveSeconds', newUserAliveSeconds);
    put('personalizationEnabled', personalizationEnabled);
    put('userId', userId);
    put('channel', channel);
    put('privacy', privacy?.toMap());

    if (extra != null && extra!.isNotEmpty) {
      result['extra'] = extra;
    }

    return result;
  }

  static int? _coerceInt(dynamic value) {
    if (value == null) {
      return null;
    }
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    return int.tryParse(value.toString());
  }

  @override
  String toString() {
    return 'ContentConfig(enableDrama: $enableDrama, enableStory: $enableStory, enableVideo: $enableVideo, debugLog: $debugLog)';
  }
}
