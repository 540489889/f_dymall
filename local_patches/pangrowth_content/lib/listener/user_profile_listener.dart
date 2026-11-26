/// 个人主页事件监听器
///
/// 用于监听个人主页的各种事件，包括生命周期和交互事件。
/// 与 gromore_ads 和 flutter_adcontent 保持一致的Listener模式。
class UserProfileListener {
  /// 个人主页创建完成并准备就绪
  /// [profileId] 个人主页唯一标识
  final void Function(String profileId)? onProfileReady;

  /// 个人主页发生错误
  /// [error] 错误信息
  final void Function(String error)? onProfileError;

  /// 个人主页销毁
  final void Function()? onProfileDisposed;

  const UserProfileListener({
    this.onProfileReady,
    this.onProfileError,
    this.onProfileDisposed,
  });
}
