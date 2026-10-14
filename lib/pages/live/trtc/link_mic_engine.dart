/// 连麦音视频引擎: 平台无关的接口层
///
/// 为什么要单独抽一层:
/// * 腾讯云 TRTC(tencent_rtc_sdk)底层是 dart:ffi, 而 Flutter Web 上不存在 dart:ffi,
///   页面只要顶层 import 它, H5 编译就整包失败:
///   Error: Dart library 'dart:ffi' is not available on this platform.
/// * 所以页面只依赖这里的接口 + 条件导入的实现(见 link_mic_trtc.dart):
///   移动端/桌面端走 TRTC, Web 端走空实现(页面检测到不支持就提示, 不进连麦流程)。
library;

/// 连麦默认美颜参数(基础美颜, 全部 0-9, 0 = 关闭)
/// * 风格: 0 smooth(光滑) / 1 nature(自然); 这里用自然风格, 保留面部细节,
///   秀场想要更"磨皮"可改成 0
/// * 用 int 而不是 TRTC 的枚举: 枚举来自 TRTC SDK(Web 端不能引入),
///   由 native 实现翻译成 TRTCBeautyStyle(见 link_mic_trtc_native.dart)
const int kBeautyStyle = 1;
/// 磨皮(美颜)级别
const int kBeautyLevel = 5;
/// 美白级别
const int kWhitenessLevel = 4;
/// 红润级别
const int kRuddinessLevel = 3;

/// 连麦音视频能力(平台无关)
///
/// * [supported] 为 false 时(Web)所有方法都是空操作, 页面不要进连麦流程
/// * 生命周期: [prepare](起本地预览前) -> [enterRoom](主播同意) -> [exit](退房/挂断/页面销毁)
abstract class LinkMicEngine {
  /// 当前平台是否真的支持音视频连麦
  bool get supported;

  /// 取实例并设默认美颜: 等待主播同意前就要起本地预览, 所以先于进房调用
  /// * 重复调用无副作用(实现内部复用同一个实例)
  Future<void> prepare();

  /// 本地预览起播(自己的画面)
  /// * [viewId] 由 LinkMicVideoView 回调给出; 传 -1(Web 没有真实视图)时直接忽略
  void startPreview(bool frontCamera, int viewId);

  /// 静音开关(等待期间也能切: 进房后沿用当前状态)
  void setMicMuted(bool muted);

  /// 切换前后摄像头
  void switchCamera(bool frontCamera);

  /// 进房(参数由服务端下发, 客户端不持有密钥)
  /// * [params] 见 LiveApi.trtcParamsOf: sdkAppId / userId / userSig / roomId / strRoomId / role
  Future<void> enterRoom(
    Map<String, dynamic> params, {
    required bool micMuted,
    required void Function(String userId) onRemoteEnter,
    required void Function(String userId) onRemoteLeave,
  });

  /// 远端画面渲染到指定视图(连麦中的小窗)
  void startRemoteView(String userId, int viewId);

  /// 退房并停掉预览/采集: 挂断、主播结束、页面销毁都走这里
  /// * 相机/麦克风必须在这里释放, 否则退出页面后还被一直占着
  Future<void> exit();
}
