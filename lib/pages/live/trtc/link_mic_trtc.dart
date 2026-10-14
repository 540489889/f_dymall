/// 连麦音视频实现的入口: 按平台二选一(条件导出)
///
/// * 默认(Android / iOS / Windows / macOS)走 TRTC(native 实现)
/// * Web 编译(dart.library.js_interop / js / html 存在)时用空实现:
///   TRTC SDK 走 dart:ffi, Web 上一 import 就是 "dart:ffi is not available", 整包编译不过
/// * 两个实现暴露同名的 [LinkMicVideoView] / [createLinkMicEngine], 上层无感知
export 'link_mic_trtc_native.dart'
    if (dart.library.js_interop) 'link_mic_trtc_web.dart'
    if (dart.library.js) 'link_mic_trtc_web.dart'
    if (dart.library.html) 'link_mic_trtc_web.dart';
