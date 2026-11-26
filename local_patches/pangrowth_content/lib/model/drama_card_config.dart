/// 短剧卡片配置
class DramaCardConfig {
  /// 短剧ID
  final int dramaId;

  /// 卡片宽度（dp），Android专用，比例固定为16:9
  final int? width;

  /// 卡片frame（iOS专用）
  final Map<String, double>? frame;

  /// 是否隐藏声音按钮
  final bool? hideSoundButton;

  /// 是否隐藏重播按钮
  final bool? hideReplayButton;

  /// 是否默认静音
  final bool? isMuteDefault;

  /// 是否自动循环播放
  final bool? isLooping;

  /// 是否自动播放
  final bool? isAutoPlay;

  /// 是否隐藏所有交互UI（iOS专用）
  final bool? hideActionUI;

  /// 是否隐藏播放按钮（iOS专用）
  final bool? hidePlayButton;

  /// 是否隐藏静音按钮（iOS专用）
  final bool? hideMuteButton;

  const DramaCardConfig({
    required this.dramaId,
    this.width,
    this.frame,
    this.hideSoundButton,
    this.hideReplayButton,
    this.isMuteDefault,
    this.isLooping,
    this.isAutoPlay,
    this.hideActionUI,
    this.hidePlayButton,
    this.hideMuteButton,
  });

  Map<String, dynamic> toMap() {
    final Map<String, dynamic> map = {'dramaId': dramaId};

    if (width != null) map['width'] = width;
    if (frame != null) map['frame'] = frame;
    if (hideSoundButton != null) map['hideSoundButton'] = hideSoundButton;
    if (hideReplayButton != null) map['hideReplayButton'] = hideReplayButton;
    if (isMuteDefault != null) map['isMuteDefault'] = isMuteDefault;
    if (isLooping != null) map['isLooping'] = isLooping;
    if (isAutoPlay != null) map['isAutoPlay'] = isAutoPlay;
    if (hideActionUI != null) map['hideActionUI'] = hideActionUI;
    if (hidePlayButton != null) map['hidePlayButton'] = hidePlayButton;
    if (hideMuteButton != null) map['hideMuteButton'] = hideMuteButton;

    return map;
  }

  factory DramaCardConfig.fromMap(Map<String, dynamic> map) {
    return DramaCardConfig(
      dramaId: map['dramaId']?.toInt() ?? 0,
      width: map['width']?.toInt(),
      frame: map['frame'] != null
          ? Map<String, double>.from(map['frame'])
          : null,
      hideSoundButton: map['hideSoundButton'],
      hideReplayButton: map['hideReplayButton'],
      isMuteDefault: map['isMuteDefault'],
      isLooping: map['isLooping'],
      isAutoPlay: map['isAutoPlay'],
      hideActionUI: map['hideActionUI'],
      hidePlayButton: map['hidePlayButton'],
      hideMuteButton: map['hideMuteButton'],
    );
  }

  @override
  String toString() {
    return 'DramaCardConfig('
        'dramaId: $dramaId, '
        'width: $width, '
        'frame: $frame, '
        'hideSoundButton: $hideSoundButton, '
        'hideReplayButton: $hideReplayButton, '
        'isMuteDefault: $isMuteDefault, '
        'isLooping: $isLooping, '
        'isAutoPlay: $isAutoPlay, '
        'hideActionUI: $hideActionUI, '
        'hidePlayButton: $hidePlayButton, '
        'hideMuteButton: $hideMuteButton'
        ')';
  }
}
