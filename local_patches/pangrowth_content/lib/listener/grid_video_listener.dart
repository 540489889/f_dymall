/// 宫格/双Feed小视频事件监听器
///
/// 用于监听宫格视频的各种事件，包括生命周期和交互事件。
/// 与 gromore_ads 和 flutter_adcontent 保持一致的Listener模式。
class GridVideoListener {
  // ==================== 生命周期事件 ====================

  /// 宫格视图创建完成并准备就绪
  /// [gridId] 宫格视图唯一标识
  final void Function(String gridId)? onGridReady;

  /// 宫格视图发生错误
  /// [error] 错误信息
  final void Function(String error)? onGridError;

  /// 宫格视图销毁
  final void Function()? onGridDisposed;

  // ==================== 播放控制事件 ====================

  /// 视频开始播放
  /// [extraInfo] SDK传递的附加信息
  ///
  /// **平台**: Android+iOS
  final void Function(Map<String, dynamic>? extraInfo)? onVideoPlay;

  /// 视频暂停
  /// [extraInfo] SDK传递的附加信息
  ///
  /// **平台**: Android+iOS
  final void Function(Map<String, dynamic>? extraInfo)? onVideoPause;

  /// 视频恢复播放
  /// [extraInfo] SDK传递的附加信息
  ///
  /// **平台**: Android+iOS
  final void Function(Map<String, dynamic>? extraInfo)? onVideoContinue;

  /// 视频播放完成
  /// [extraInfo] SDK传递的附加信息
  ///
  /// **平台**: Android+iOS
  final void Function(Map<String, dynamic>? extraInfo)? onVideoCompletion;

  /// 视频播放结束
  /// [extraInfo] SDK传递的附加信息
  ///
  /// **平台**: Android+iOS
  final void Function(Map<String, dynamic>? extraInfo)? onVideoOver;

  // ==================== 交互事件 ====================

  /// 视频项点击
  /// [extraInfo] 视频信息
  ///
  /// **平台**: Android+iOS
  final void Function(Map<String, dynamic>? extraInfo)? onItemClick;

  /// 视频项展示（曝光）
  /// [extraInfo] 视频信息
  ///
  /// **平台**: Android+iOS
  final void Function(Map<String, dynamic>? extraInfo)? onItemShow;

  /// 点击作者头像
  /// [extraInfo] 作者信息
  ///
  /// **平台**: Android+iOS
  final void Function(Map<String, dynamic>? extraInfo)? onClickAuthorAvatar;

  /// 点击作者名称
  /// [extraInfo] 作者信息
  ///
  /// **平台**: Android+iOS
  final void Function(Map<String, dynamic>? extraInfo)? onClickAuthorName;

  /// 点击评论按钮
  /// [extraInfo] 视频信息
  ///
  /// **平台**: Android+iOS
  final void Function(Map<String, dynamic>? extraInfo)? onClickComment;

  /// 点击点赞按钮
  /// [extraInfo] 视频信息
  ///
  /// **平台**: Android+iOS
  final void Function(Map<String, dynamic>? extraInfo)? onClickLike;

  // ==================== 数据请求事件 ====================

  /// 开始请求视频数据
  /// [extraInfo] 附加参数
  ///
  /// **平台**: Android+iOS
  final void Function(Map<String, dynamic>? extraInfo)? onRequestStart;

  /// 请求视频数据失败
  /// [code] 错误码
  /// [message] 错误信息
  /// [extraInfo] 附加参数
  ///
  /// **平台**: Android+iOS
  final void Function(
    int code,
    String message,
    Map<String, dynamic>? extraInfo,
  )?
  onRequestFail;

  /// 请求视频数据成功
  /// [list] 返回的视频列表数据
  ///
  /// **平台**: Android+iOS
  final void Function(List<Map<String, dynamic>> list)? onRequestSuccess;

  /// 刷新完成
  ///
  /// **平台**: Android+iOS
  final void Function()? onRefreshComplete;

  const GridVideoListener({
    // 生命周期
    this.onGridReady,
    this.onGridError,
    this.onGridDisposed,
    // 播放控制
    this.onVideoPlay,
    this.onVideoPause,
    this.onVideoContinue,
    this.onVideoCompletion,
    this.onVideoOver,
    // 交互事件
    this.onItemClick,
    this.onItemShow,
    this.onClickAuthorAvatar,
    this.onClickAuthorName,
    this.onClickComment,
    this.onClickLike,
    // 数据请求
    this.onRequestStart,
    this.onRequestFail,
    this.onRequestSuccess,
    this.onRefreshComplete,
  });
}
