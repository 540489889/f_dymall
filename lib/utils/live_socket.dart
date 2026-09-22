/// 直播间 WebSocket 客户端
/// * 对齐 H5(uni_modules/x-web-socket/js_sdk/index.js + pages_tool/live/livepull.nvue)的协议:
///   - 地址 Config.socketUrl, 进入直播间即连接, 离开页面关闭
///   - 消息体 JSON 字符串: {type: xxx, data: xxx}
///   - 心跳: 连接成功后立即发一次 {type: 'pong'}, 之后每 10s 一次; 收到 event=ping 立即回 pong
///   - 收消息过滤 event 为 ping/pong 的包(不透传给业务)
///   - 帧兼容: 文本帧与二进制帧(Uint8List)都按 UTF-8 解析, 顶层为数组时逐条分发
///   - 断线 3s 后重连, 最多 100 次; 每次(重)连成功回调 onConnected(由页面重发 join)
/// * 用法: connect() -> onConnected 里 send('join', {...}) -> onMessage 处理业务消息 -> close()
library;

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart' show debugPrint, kDebugMode;
import 'package:web_socket_channel/status.dart' as ws_status;
import 'package:web_socket_channel/web_socket_channel.dart';

class LiveSocket {
  LiveSocket({
    required this.url,
    required this.onMessage,
    this.onConnected,
    this.onReconnectFail,
  });

  /// 连接地址(Config.socketUrl)
  final String url;

  /// 业务消息回调(已过滤 ping/pong 心跳包)
  final void Function(Map<String, dynamic> msg) onMessage;

  /// (重)连成功回调: 页面在这里重发进房消息
  final void Function()? onConnected;

  /// 重连达到上限时回调(仅一次, 连接成功后重置)
  final void Function(int times, int maxTimes)? onReconnectFail;

  /// 心跳间隔(与H5一致 10s)
  static const Duration heartbeatInterval = Duration(seconds: 10);

  /// 重连延迟(与H5一致 3s)
  static const Duration reconnectDelay = Duration(seconds: 3);

  /// 最大重连次数(与H5一致)
  static const int reconnectMaxTimes = 100;

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _subscription;
  Timer? _heartbeatTimer;
  Timer? _reconnectTimer;
  int _reconnectTimes = 0;
  bool _reconnecting = false;
  /// 连接序号: 每次 connect 递增, 用来作废握手中途被取代的旧连接(切换房间时)
  int _connectSeq = 0;
  /// 主动关闭标记: true 时不再重连(与H5 closeFlag 一致, 默认已关闭)
  bool _closed = true;

  /// 是否已连接(可发送消息)
  bool get connected => _channel != null;

  /// 本次连接是否已收到过任意帧(含心跳): 用来判断服务端有没有在推, 页面据此决定要不要补发进房消息
  bool _gotAnyFrame = false;
  bool get gotAnyFrame => _gotAnyFrame;

  /// 建立连接(已连接时忽略; 主动 close 后需重新调用)
  Future<void> connect() async {
    if (connected || _reconnecting) return;
    _closed = false;
    _reconnecting = true;
    final int seq = ++_connectSeq;
    try {
      final WebSocketChannel channel = WebSocketChannel.connect(Uri.parse(url));
      await channel.ready;
      // 等待期间已被主动关闭 / 已被更新的连接取代(切换房间): 直接丢掉这条连接
      if (_closed || seq != _connectSeq) {
        await channel.sink.close(ws_status.normalClosure);
        return;
      }
      _channel = channel;
      _reconnectTimes = 0;
      _gotAnyFrame = false;
      debugPrint('[live]WebSocket 连接成功: $url');
      _subscription = channel.stream.listen(
        _onData,
        onError: (Object error) {
          debugPrint('[live]WebSocket 错误: $error');
          _disconnected();
          _scheduleReconnect();
        },
        onDone: () {
          debugPrint('[live]WebSocket 连接关闭');
          _disconnected();
          _scheduleReconnect();
        },
        cancelOnError: true,
      );
      _startHeartbeat();
      onConnected?.call();
    } catch (e) {
      debugPrint('[live]WebSocket 连接失败: $e');
      _scheduleReconnect();
    } finally {
      // 已被更新的连接取代时不要动标志: 仍由新连接自己收尾
      if (seq == _connectSeq) _reconnecting = false;
    }
  }

  /// 切换直播间: 断开当前连接并立即重连(不等 3s 重连延迟, 也不等旧握手结束)
  /// * 换房必须重连: 服务端按连接注册房间, 在旧连接上补发进房消息不会生效
  /// * 重连成功同样回调 onConnected(页面在那里带新房间的房间号进房)
  Future<void> reconnect() async {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    // 递增序号: 进行中的旧握手返回后发现自己已过期, 会自行丢弃, 不会覆盖新连接
    _connectSeq += 1;
    // 关闭最多等 2s: 服务端不响应关闭帧时不能卡住后面的连接
    await close().timeout(const Duration(seconds: 2), onTimeout: () async {});
    // close 时可能还有握手在途(其 finally 不会清标志), 这里手动清掉, 保证 connect 能进去
    _reconnecting = false;
    await connect();
  }

  /// 发送业务消息: {type: xxx, data: xxx}(data 为空时不带该字段)
  void send(String type, [dynamic data]) {
    _sendRaw(<String, dynamic>{
      'type': type,
      'data': ?data,
    });
  }

  /// 原样发送报文(不进 {type, data} 包装): 进房消息兜底格式用
  void sendRaw(Map<String, dynamic> message) => _sendRaw(message);

  /// 关闭连接(页面销毁/被踢/直播结束时调用, 不再重连)
  Future<void> close() async {
    _closed = true;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    final WebSocketChannel? channel = _channel;
    _disconnected();
    if (channel == null) return;
    try {
      await channel.sink.close(ws_status.normalClosure);
    } catch (e) {
      debugPrint('[live]WebSocket 关闭异常: $e');
    }
  }

  void _sendRaw(Map<String, dynamic> message) {
    final WebSocketChannel? channel = _channel;
    if (channel == null) {
      debugPrint('[live]WebSocket 未连接, 消息未发送: $message');
      return;
    }
    try {
      channel.sink.add(jsonEncode(message));
    } catch (e) {
      debugPrint('[live]WebSocket 发送失败: $e');
    }
  }

  void _onData(dynamic data) {
    // 服务端可能推文本帧, 也可能推二进制帧(Uint8List/List<int>): 都按 UTF-8 文本解析
    // * 早期只认 String, 二进制帧被静默丢掉, 表现就是"连上了却一条消息都没有"
    final String? text = _decodeFrame(data);
    if (text == null) {
      debugPrint('[live]WebSocket 收到无法解析的帧类型: ${data.runtimeType}');
      return;
    }
    _gotAnyFrame = true;
    // 排查用: 打印原始帧(截断), 消息展示异常时先看这行
    if (kDebugMode) {
      debugPrint('[live]WebSocket 收到: ${text.length > 300 ? '${text.substring(0, 300)}...(共${text.length}字)' : text}');
    }
    try {
      final dynamic decoded = jsonDecode(text);
      // 兼容服务端一次推多帧(顶层是数组): 逐个分发, 不要整包丢掉
      if (decoded is List) {
        for (final dynamic one in decoded) {
          if (one is Map) _dispatch(one.cast<String, dynamic>());
        }
        return;
      }
      if (decoded is! Map) return;
      _dispatch(decoded.cast<String, dynamic>());
    } catch (e) {
      debugPrint('[live]WebSocket 消息解析失败: $e');
    }
  }

  /// 帧内容转文本: 文本帧原样返回, 二进制帧按 UTF-8 解码, 其它类型返回 null
  String? _decodeFrame(dynamic data) {
    if (data is String) return data;
    if (data is List<int>) return utf8.decode(data, allowMalformed: true);
    if (data is List) {
      try {
        return utf8.decode(data.cast<int>(), allowMalformed: true);
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  /// 业务分发: 心跳包(to 服务端的 ping / 服务端回的 pong)不透传业务
  void _dispatch(Map<String, dynamic> msg) {
    final String event = '${msg['event'] ?? ''}'.trim();
    // 服务端经常用 {event:'ping'} 探活, 必须回 pong 否则连接会被判定为死连接
    if (event == 'ping') {
      _sendRaw(<String, dynamic>{'type': 'pong'});
      return;
    }
    if (event == 'pong') return;
    onMessage(msg);
  }

  /// 心跳: 立即发一次 {type:'pong'}, 之后每 10s 一次; 未连接时改为重连(与H5一致)
  void _startHeartbeat() {
    _sendRaw(<String, dynamic>{'type': 'pong'});
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(heartbeatInterval, (Timer timer) {
      if (connected) {
        _sendRaw(<String, dynamic>{'type': 'pong'});
      } else {
        _scheduleReconnect();
      }
    });
  }

  /// 断开后的清理(保留 _closed 与重连计数)
  void _disconnected() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    _subscription?.cancel();
    _subscription = null;
    _channel = null;
  }

  /// 断线重连(3s 后重试, 最多 reconnectMaxTimes 次; 重连成功会重新走 _startHeartbeat)
  void _scheduleReconnect() {
    if (_closed || _reconnectTimer != null) return;
    if (_reconnectTimes >= reconnectMaxTimes) {
      debugPrint('[live]WebSocket 重连次数已达上限, 停止重连');
      onReconnectFail?.call(_reconnectTimes, reconnectMaxTimes);
      return;
    }
    _reconnectTimer = Timer(reconnectDelay, () {
      _reconnectTimer = null;
      _reconnectTimes += 1;
      debugPrint('[live]WebSocket 第 $_reconnectTimes 次重连');
      connect();
    });
  }
}
