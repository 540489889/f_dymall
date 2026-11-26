import 'package:flutter/foundation.dart';
import '../pangrowth_content.dart';

/// 短剧播放器控制器
///
/// 封装 playerId 管理和播放器控制方法，简化使用。
/// 配合 DramaPlayerNativeView 使用，自动处理播放器生命周期。
///
/// 使用示例：
/// ```dart
/// final controller = DramaPlayerController();
///
/// DramaPlayerNativeView(
///   config: DramaPlayerConfig(...),
///   controller: controller,
/// )
///
/// // 控制播放
/// await controller.setSpeed(150); // 1.5x 倍速
/// await controller.openDramaGallery();
/// ```
class DramaPlayerController {
  String? _playerId;

  /// 初始化播放器ID（由 Widget 内部调用）
  void initialize(String playerId) {
    _playerId = playerId;
    debugPrint('DramaPlayerController: 播放器ID已初始化 - $playerId');
  }

  /// 清除播放器ID（销毁时调用）
  void dispose() {
    debugPrint('DramaPlayerController: 播放器ID已清除 - $_playerId');
    _playerId = null;
  }

  /// 播放器是否已准备就绪
  bool get isReady => _playerId != null && _playerId!.isNotEmpty;

  /// 获取播放器ID（如果需要直接访问）
  String? get playerId => _playerId;

  /// 私有方法：检查播放器是否就绪
  void _ensureReady() {
    if (!isReady) {
      throw StateError('播放器未初始化或已销毁，无法调用控制方法');
    }
  }

  /// 设置播放倍速
  /// [speed] 播放速度（100表示1.0x，150表示1.5x，200表示2.0x）
  /// [scope] 倍速作用范围，`episode` 表示当前集、`drama` 表示整部短剧
  Future<bool> setSpeed(int speed, {String scope = 'episode'}) async {
    _ensureReady();
    final double speedValue = speed / 100.0;
    return await PangrowthContent.setSpeedPlay(
      _playerId!,
      speedValue,
      scope: scope,
    );
  }

  /// 打开选集面板
  Future<bool> openDramaGallery() async {
    _ensureReady();
    return await PangrowthContent.openDramaGallery(_playerId!);
  }

  /// 打开更多弹窗（举报、设置等）
  Future<Map<String, dynamic>> openMoreDialog() async {
    _ensureReady();
    return await PangrowthContent.openMoreDialog(_playerId!);
  }

  /// 设置当前播放集数
  /// [episode] 集数（从1开始）
  Future<Map<String, dynamic>> setCurrentEpisode(int episode) async {
    _ensureReady();
    return await PangrowthContent.setCurrentEpisode(_playerId!, episode);
  }

  /// 获取当前播放集数
  Future<Map<String, dynamic>> getCurrentEpisode() async {
    _ensureReady();
    return await PangrowthContent.getCurrentEpisode(_playerId!);
  }

  /// 获取当前播放索引（当前集数在列表中的位置）
  /// 返回 Map 包含 'currentIndex' 字段
  Future<Map<String, dynamic>> getCurrentIndex() async {
    _ensureReady();
    final result = await PangrowthContent.getCurrentEpisode(_playerId!);
    return result;
  }

  /// 跳转到指定播放位置
  /// [duration] 跳转位置（毫秒）
  Future<Map<String, dynamic>> seekTo(int duration) async {
    _ensureReady();
    return await PangrowthContent.seekTo(_playerId!, duration);
  }

  /// 通知SDK自定义广告已开始展示
  /// [cpm] 广告CPM，传'custom'表示自定义广告
  Future<bool> setCustomAdOnShow({String? cpm}) async {
    _ensureReady();
    return await PangrowthContent.setCustomAdOnShow(
      _playerId!,
      cpm: cpm ?? '0',
    );
  }

  /// 通知SDK自定义广告奖励结果
  /// [verify] 是否验证通过（广告播放完成）
  /// [extraData] 额外数据（如dramaId、episode等）
  Future<bool> setCustomAdOnReward({
    required bool verify,
    Map<String, dynamic>? extraData,
  }) async {
    _ensureReady();
    return await PangrowthContent.setCustomAdOnReward(
      _playerId!,
      verify: verify,
      extraData: extraData,
    );
  }

  /// 解锁短剧
  /// [episodeId] 集数ID
  /// [lockSet] 解锁集数
  /// [cancel] 是否取消解锁
  Future<bool> unlockDrama({
    required int episodeId,
    required int lockSet,
    bool cancel = false,
  }) async {
    _ensureReady();
    return await PangrowthContent.unLockDrama(
      _playerId!,
      episodeId,
      lockSet,
      cancel: cancel,
    );
  }

  /// 刷新播放页
  Future<Map<String, dynamic>> refresh() async {
    _ensureReady();
    return await PangrowthContent.refreshPlayer(_playerId!);
  }

  /// 确认解锁（Common模式下使用自定义弹窗时调用）
  ///
  /// 仅在 adMode='common' 且使用自定义解锁弹窗时调用。
  /// 调用此方法表示用户确认观看广告来解锁剧集。
  ///
  /// 使用场景：
  /// - 当 onUnlockStart 回调触发时，展示自定义弹窗
  /// - 用户点击"观看广告"按钮时，调用此方法
  /// - SDK会自动展示广告并处理解锁流程
  Future<bool> confirmUnlock() async {
    _ensureReady();
    return await PangrowthContent.confirmUnlock(_playerId!);
  }

  /// 取消解锁（Common模式下使用自定义弹窗时调用）
  ///
  /// 仅在 adMode='common' 且使用自定义解锁弹窗时调用。
  /// 调用此方法表示用户取消观看广告，不进行解锁。
  ///
  /// 使用场景：
  /// - 当 onUnlockStart 回调触发时，展示自定义弹窗
  /// - 用户点击"取消"或关闭弹窗时，调用此方法
  /// - SDK会取消解锁流程
  Future<bool> cancelUnlock() async {
    _ensureReady();
    return await PangrowthContent.cancelUnlock(_playerId!);
  }

  /// 进入播放页（iOS专用）
  ///
  /// **平台支持**:
  /// - ✅ iOS: `DJXDrawVideoViewController.enterPlayPage()`
  /// - ❌ Android: 无对应方法
  ///
  /// 🔵 iOS 独有方法
  ///
  /// **使用场景**:
  /// - 主动触发进入播放页面
  /// - 从详情页或其他页面跳转到播放页
  ///
  /// **示例**:
  /// ```dart
  /// final controller = DramaPlayerController();
  /// // 初始化后调用
  /// await controller.enterPlayPage();
  /// ```
  Future<Map<String, dynamic>> enterPlayPage() async {
    _ensureReady();
    return await PangrowthContent.enterPlayPage(_playerId!);
  }
}
