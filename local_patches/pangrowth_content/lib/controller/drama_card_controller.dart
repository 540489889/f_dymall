import 'package:flutter/foundation.dart';
import '../pangrowth_content.dart';

/// 短剧卡片控制器
///
/// 封装卡片ID管理和控制方法,简化使用。
/// 配合 DramaCardNativeView 使用,自动处理卡片生命周期。
///
/// 使用示例:
/// ```dart
/// final controller = DramaCardController();
///
/// DramaCardNativeView(
///   config: DramaCardConfig(...),
///   controller: controller,
/// )
///
/// // 控制播放
/// controller.play();    // 播放
/// controller.pause();   // 暂停
/// controller.stop();    // 停止
/// controller.setMute(true);  // 静音
///
/// // 销毁时自动调用
/// controller.dispose();
/// ```
class DramaCardController {
  String? _cardId;

  /// 初始化卡片ID(由 Widget 内部调用)
  void initialize(String cardId) {
    _cardId = cardId;
    debugPrint('DramaCardController: 卡片ID已初始化 - $cardId');
  }

  /// 清除卡片ID
  Future<void> dispose() async {
    if (_cardId != null && _cardId!.isNotEmpty) {
      debugPrint('DramaCardController: 清除卡片ID - $_cardId');
    }
    _cardId = null;
  }

  /// 卡片是否已准备就绪
  bool get isReady => _cardId != null && _cardId!.isNotEmpty;

  /// 获取卡片ID(如果需要直接访问)
  String? get cardId => _cardId;

  /// 私有方法:检查卡片是否就绪
  void _ensureReady() {
    if (!isReady) {
      throw StateError('卡片未初始化或已销毁,无法调用控制方法');
    }
  }

  /// 播放卡片视频
  ///
  /// 调用 SDK 的 `playDramaCard` 方法,原生层会调用卡片的 play/start 方法。
  Future<void> play() async {
    _ensureReady();
    try {
      final result = await PangrowthContent.playDramaCard(_cardId!);
      if (result) {
        debugPrint('DramaCardController: 卡片开始播放 - $_cardId');
      }
    } catch (e) {
      debugPrint('DramaCardController: 播放卡片失败 - $e');
      rethrow;
    }
  }

  /// 暂停卡片视频
  ///
  /// 调用 SDK 的 `pauseDramaCard` 方法,原生层会调用卡片的 pause 方法。
  Future<void> pause() async {
    _ensureReady();
    try {
      final result = await PangrowthContent.pauseDramaCard(_cardId!);
      if (result) {
        debugPrint('DramaCardController: 卡片已暂停 - $_cardId');
      }
    } catch (e) {
      debugPrint('DramaCardController: 暂停卡片失败 - $e');
      rethrow;
    }
  }

  /// 停止卡片视频
  ///
  /// 调用 SDK 的 `stopDramaCard` 方法,原生层会调用卡片的 stop 方法。
  Future<void> stop() async {
    _ensureReady();
    try {
      final result = await PangrowthContent.stopDramaCard(_cardId!);
      if (result) {
        debugPrint('DramaCardController: 卡片已停止 - $_cardId');
      }
    } catch (e) {
      debugPrint('DramaCardController: 停止卡片失败 - $e');
      rethrow;
    }
  }

  /// 设置卡片静音状态
  ///
  /// 调用 SDK 的 `setDramaCardMute` 方法,原生层会调用卡片的 setMute 方法。
  ///
  /// [mute] true-静音, false-取消静音
  Future<void> setMute(bool mute) async {
    _ensureReady();
    try {
      final result = await PangrowthContent.setDramaCardMute(_cardId!, mute);
      if (result) {
        debugPrint('DramaCardController: 卡片静音状态 - $mute (cardId: $_cardId)');
      }
    } catch (e) {
      debugPrint('DramaCardController: 设置静音失败 - $e');
      rethrow;
    }
  }

  /// 刷新卡片数据
  ///
  /// 调用 SDK 的 `refreshDramaCard` 方法,原生层会重新加载卡片数据。
  /// 适用于网络错误重试、内容更新等场景。
  Future<void> refresh() async {
    _ensureReady();
    try {
      final result = await PangrowthContent.refreshDramaCard(_cardId!);
      if (result) {
        debugPrint('DramaCardController: 卡片数据已刷新 - $_cardId');
      }
    } catch (e) {
      debugPrint('DramaCardController: 刷新卡片失败 - $e');
      rethrow;
    }
  }

  /// 上报卡片曝光埋点
  ///
  /// 调用 SDK 的 `reportDramaCardShow` 方法,上报卡片曝光数据。
  ///
  /// [duration] 曝光时长,单位毫秒
  Future<void> reportShow(int duration) async {
    _ensureReady();
    try {
      final result = await PangrowthContent.reportDramaCardShow(
        _cardId!,
        duration,
      );
      if (result) {
        debugPrint(
          'DramaCardController: 曝光已上报 - duration:${duration}ms (cardId: $_cardId)',
        );
      }
    } catch (e) {
      debugPrint('DramaCardController: 上报曝光失败 - $e');
      rethrow;
    }
  }

  /// 获取卡片播放状态
  ///
  /// 返回 true 表示正在播放, false 表示未播放或已暂停。
  Future<bool> isPlaying() async {
    _ensureReady();
    try {
      final result = await PangrowthContent.isDramaCardPlaying(_cardId!);
      return result;
    } catch (e) {
      debugPrint('DramaCardController: 获取播放状态失败 - $e');
      return false;
    }
  }

  /// 获取卡片短剧信息
  ///
  /// 返回包含 id, title, coverImage, desc 等字段的 Map。
  /// 如果数据未加载完成,可能返回 null。
  Future<Map<String, dynamic>?> getDramaInfo() async {
    _ensureReady();
    try {
      final result = await PangrowthContent.getDramaCardInfo(_cardId!);
      return result;
    } catch (e) {
      debugPrint('DramaCardController: 获取短剧信息失败 - $e');
      return null;
    }
  }

  /// 获取卡片短剧 GID
  Future<String?> getGid() async {
    _ensureReady();
    try {
      final result = await PangrowthContent.getDramaCardGid(_cardId!);
      return result;
    } catch (e) {
      debugPrint('DramaCardController: 获取GID失败 - $e');
      return null;
    }
  }

  /// 获取卡片短剧标题
  Future<String?> getTitle() async {
    _ensureReady();
    try {
      final result = await PangrowthContent.getDramaCardTitle(_cardId!);
      return result;
    } catch (e) {
      debugPrint('DramaCardController: 获取标题失败 - $e');
      return null;
    }
  }

  /// 重新加载数据
  ///
  /// 当数据加载失败或出现错误时,调用此方法重新请求数据。
  ///
  /// **平台支持**:
  /// - ✅ iOS: `DJXPlayletCard.retryLoadData()`
  /// - ❌ Android: 无对应方法,建议使用 `refresh()` 方法
  ///
  /// 🔵 iOS 独有方法
  ///
  /// **使用场景**:
  /// - 网络请求失败后重试
  /// - 数据解析错误后重新加载
  /// - 配合 listener 的 onCardError 回调使用
  ///
  /// **示例**:
  /// ```dart
  /// DramaCardListener(
  ///   onCardError: (error) {
  ///     print('加载失败: $error');
  ///     // 1秒后重试
  ///     Future.delayed(Duration(seconds: 1), () {
  ///       controller.retryLoadData();
  ///     });
  ///   },
  /// )
  /// ```
  Future<bool> retryLoadData() async {
    _ensureReady();
    try {
      final result = await PangrowthContent.retryLoadDataDramaCard(_cardId!);
      if (result) {
        debugPrint('DramaCardController: 重新加载数据 - $_cardId');
      }
      return result;
    } catch (e) {
      debugPrint('DramaCardController: 重新加载数据失败 - $e');
      rethrow;
    }
  }
}
