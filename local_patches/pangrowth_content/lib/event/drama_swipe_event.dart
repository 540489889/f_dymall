/// 短剧滑滑流事件类型
enum DramaSwipeEventType {
  /// 页面切换
  pageChange,

  /// 视频播放
  videoPlay,

  /// 视频暂停
  videoPause,

  /// 视频继续
  videoContinue,

  /// 视频完成
  videoCompletion,

  /// 视频结束
  videoOver,

  /// 界面关闭
  close,

  /// 举报结果
  reportResult,

  /// 请求开始
  requestStart,

  /// 请求失败
  requestFail,

  /// 请求成功
  requestSuccess,

  /// 频道切换
  channelTabChange,

  /// 视频进度
  durationChange,

  /// 刷新完成
  refreshFinish,

  /// 用户拖动进度条
  seekTo,
}

/// 短剧滑滑流事件
class DramaSwipeEvent {
  /// 事件类型
  final DramaSwipeEventType type;

  /// 事件参数
  final Map<String, dynamic> params;

  const DramaSwipeEvent({required this.type, required this.params});

  /// 从Map创建事件
  factory DramaSwipeEvent.fromMap(Map<String, dynamic> map) {
    final String typeStr = map['type'] as String;
    final DramaSwipeEventType type = _parseEventType(typeStr);
    final Map<String, dynamic> params = Map<String, dynamic>.from(
      map['params'] ?? {},
    );

    return DramaSwipeEvent(type: type, params: params);
  }

  /// 转换为Map
  Map<String, dynamic> toMap() {
    return {'type': type.toString().split('.').last, 'params': params};
  }

  /// 解析事件类型
  static DramaSwipeEventType _parseEventType(String typeStr) {
    switch (typeStr) {
      case 'pageChange':
        return DramaSwipeEventType.pageChange;
      case 'videoPlay':
        return DramaSwipeEventType.videoPlay;
      case 'videoPause':
        return DramaSwipeEventType.videoPause;
      case 'videoContinue':
        return DramaSwipeEventType.videoContinue;
      case 'videoCompletion':
        return DramaSwipeEventType.videoCompletion;
      case 'videoOver':
        return DramaSwipeEventType.videoOver;
      case 'close':
        return DramaSwipeEventType.close;
      case 'reportResult':
        return DramaSwipeEventType.reportResult;
      case 'requestStart':
        return DramaSwipeEventType.requestStart;
      case 'requestFail':
        return DramaSwipeEventType.requestFail;
      case 'requestSuccess':
        return DramaSwipeEventType.requestSuccess;
      case 'channelTabChange':
        return DramaSwipeEventType.channelTabChange;
      case 'durationChange':
        return DramaSwipeEventType.durationChange;
      case 'refreshFinish':
        return DramaSwipeEventType.refreshFinish;
      case 'seekTo':
        return DramaSwipeEventType.seekTo;
      default:
        throw ArgumentError('Unknown event type: $typeStr');
    }
  }

  @override
  String toString() {
    return 'DramaSwipeEvent{type: $type, params: $params}';
  }
}

/// 滑滑流事件监听器
typedef OnDramaSwipeEventListener = void Function(DramaSwipeEvent event);
