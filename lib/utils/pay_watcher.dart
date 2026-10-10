/// 外部支付回 App 后的支付结果兜底检查
/// * 跳微信小程序支付 / 跳外部浏览器支付 / 原生SDK支付: App 回到前台时不会有支付回调,
///   只能自己查后台 /api/pay/status 确认是否到账
/// * 弹窗内的轮询(见 popup_pay.dart startPolling)在弹窗被关闭时就停了 —— 而支付弹窗是
///   bottomSheet(带拖拽条),用户下滑/返回键就能关掉,此时就没人再查支付状态了
/// * 这里做与页面无关的兜底: 记下待确认的支付单号,App 每次回到前台立即查一次
library;

import 'dart:async';

import 'package:flutter/foundation.dart' show debugPrint, kDebugMode;
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:shirne_dialog/shirne_dialog.dart';

import '../api/pay.dart';

class PayWatcher with WidgetsBindingObserver {
  PayWatcher._();

  static final PayWatcher instance = PayWatcher._();

  /// 待确认的支付单号(空表示当前没有进行中的外部支付)
  String _tradeNo = '';
  bool _toPayResult = true;
  /// 兜底确认到账后的通知(用于刷新调用方页面数据)
  VoidCallback? _onPaid;
  /// 支付弹窗还活着时由弹窗自己收尾(关弹窗 + 跳结果页),返回 true 表示已处理
  /// * 弹窗是原生 showModalBottomSheet 打开的,Get.isBottomSheetOpen 拿不到(watcher 关不掉它)
  bool Function()? _onFinish;
  Timer? _timer;
  int _times = 0;
  int _failed = 0;
  bool _registered = false;

  /// 是否有待确认的支付单
  bool get watching => _tradeNo.isNotEmpty;

  /// 发起外部支付后调用: 记录单号并开始监听前后台
  /// * [toPayResult] 支付成功后是否跳支付结果页(与 PopupPay.toPayResult 一致)
  /// * [onPaid] 兜底确认到账后的回调(弹窗已关时用不到它的 onChanged,由这里通知页面刷新)
  /// * [onFinish] 弹窗还活着时的收尾入口(由弹窗自己关自己并跳结果页)
  void watch(String tradeNo, {bool toPayResult = true, VoidCallback? onPaid, bool Function()? onFinish}) {
    if (tradeNo.isEmpty) return;
    _tradeNo = tradeNo;
    _toPayResult = toPayResult;
    _onPaid = onPaid;
    _onFinish = onFinish;
    _times = 0;
    _failed = 0;
    if (!_registered) {
      _registered = true;
      WidgetsBinding.instance.addObserver(this);
    }
  }

  /// 支付已完成 / 单号作废(重置支付单)后停止检查
  void stop() {
    _tradeNo = '';
    _onPaid = null;
    _onFinish = null;
    _timer?.cancel();
    _timer = null;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 回到前台: 立即查一次,不用等弹窗内的轮询周期
    if (state != AppLifecycleState.resumed || _tradeNo.isEmpty) return;
    if (kDebugMode) debugPrint('[pay][watcher] resumed -> 查状态 tradeNo=$_tradeNo');
    check();
  }

  /// 查一次支付状态
  /// * 已支付: 收尾(关弹窗 + 跳结果页)
  /// * 未支付: 后台支付回调有延迟,起一段轮询再确认;超时后放弃
  Future<void> check() async {
    final String no = _tradeNo;
    if (no.isEmpty) return;
    int payStatus = -1;
    try {
      payStatus = await PayApi.status(no);
    } catch (e) {
      if (kDebugMode) debugPrint('[pay][watcher] status 请求异常: $e');
      _startPolling();
      return;
    }
    if (kDebugMode) debugPrint('[pay][watcher] status=$payStatus tradeNo=$no');
    if (payStatus != 2) {
      if (payStatus < 0) {
        // 接口异常(App 在微信期间请求易失败): 累计多次才放弃
        _failed++;
        if (_failed >= 10) {
          stop();
          return;
        }
      } else {
        _failed = 0;
      }
      _startPolling();
      return;
    }
    final VoidCallback? onPaid = _onPaid;
    final bool Function()? onFinish = _onFinish;
    stop();
    try {
      // 支付弹窗还活着: 交给它自己收尾(它会用 Get.back() 关掉原生 showModalBottomSheet 再跳转)
      if (onFinish?.call() == true) return;
      // 弹窗已关闭: 这里兜底跳转
      if (Get.isBottomSheetOpen == true) {
        Get.back();
        // 等关闭动画结束再跳转,否则路由替换会被关闭动画吞掉
        await Future<void>.delayed(const Duration(milliseconds: 350));
      }
      onPaid?.call();
      if (_toPayResult) {
        if (kDebugMode) debugPrint('[pay][watcher] 已支付 -> 跳结果页 $no');
        Get.offNamed('/order/pay_result', arguments: <String, dynamic>{'code': no});
      } else {
        MyDialog.toast('支付成功');
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[pay][watcher] 收尾跳转失败: $e');
    }
  }

  /// 轮询(2 秒一次,最多 90 次 ≈ 3 分钟): 覆盖「回到 App 但后台还没收到支付回调」的情况
  void _startPolling() {
    if (_timer != null) return;
    _times = 0;
    _timer = Timer.periodic(const Duration(seconds: 2), (Timer t) async {
      _times++;
      if (_tradeNo.isEmpty || _times > 90) {
        stop();
        return;
      }
      await check();
    });
  }
}
