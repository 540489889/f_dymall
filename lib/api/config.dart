/// APP 全局配置接口
library;

import 'package:flutter/foundation.dart' show kDebugMode;
import '../utils/request.dart';

class ConfigApi {
  /// 获取 APP 全局配置(/api/config/init)
  /// * 返回业务 data(Map): 含分享配置/版本/开关等,具体字段随后端
  /// * 失败返回空 Map(不抛异常,首启网络异常不应阻塞启动)
  static Future<Map<String, dynamic>> init() async {
    try {
      final dynamic res = await Request().get('/api/config/init');
      if (res is Map) return Map<String, dynamic>.from(res);
      return <String, dynamic>{};
    } catch (e) {
      if (kDebugMode) print('[config] /api/config/init 失败: $e');
      return <String, dynamic>{};
    }
  }
}
