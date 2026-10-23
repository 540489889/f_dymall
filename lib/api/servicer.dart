/// 在线客服(AI 智能客服 + 人工客服)接口封装
/// 对齐文档: aiservicer-frontend-api v1.0
/// 前缀: /aiservicer/api/servicer/{action}
/// 通信方式: HTTP 轮询(无 WebSocket / 无 SSE)
library;

import 'package:dio/dio.dart' show DioException, MultipartFile, FormData, RequestOptions;
import '../utils/request.dart';

class ServicerApi {
  /// 初始化会话(每次进入都调用, 必须用品返回覆盖本地 session_id / human_session_id)
  static Future<Map<String, dynamic>> init() async {
    final dynamic data = await Request().post('/aiservicer/api/servicer/init');
    if (data is Map) return data.cast<String, dynamic>();
    return <String, dynamic>{};
  }

  /// 发送消息
  /// * [messageType] 1 文本 / 2 图片 / 3 视频
  /// * [messageUrl] 多媒体地址(图片/视频必填, 原样回传上传返回值)
  static Future<Map<String, dynamic>> say({
    required String sessionId,
    required String message,
    int messageType = 1,
    String messageUrl = '',
  }) async {
    final Map<String, dynamic> body = <String, dynamic>{
      'session_id': sessionId,
      'message': message,
      'message_type': messageType,
    };
    if (messageType != 1) body['message_url'] = messageUrl;
    final dynamic data = await Request().post('/aiservicer/api/servicer/say', data: body);
    if (data is Map) return data.cast<String, dynamic>();
    return <String, dynamic>{};
  }

  /// 拉取消息(轮询 / 恢复历史)
  /// * [lastId] 增量游标, 0 表示全量/首屏
  static Future<Map<String, dynamic>> chatLog({
    required String sessionId,
    int lastId = 0,
    int page = 1,
    int pageSize = 20,
  }) async {
    final dynamic data = await Request().get(
      '/aiservicer/api/servicer/chatLog',
      queryParameters: <String, dynamic>{
        'session_id': sessionId,
        'last_id': lastId,
        'page': page,
        'page_size': pageSize,
      },
    );
    if (data is Map) return data.cast<String, dynamic>();
    return <String, dynamic>{};
  }

  /// 主动转人工
  static Future<Map<String, dynamic>> transferToHuman({required String sessionId}) async {
    final dynamic data = await Request().post(
      '/aiservicer/api/servicer/transferToHuman',
      data: <String, dynamic>{'session_id': sessionId},
    );
    if (data is Map) return data.cast<String, dynamic>();
    return <String, dynamic>{};
  }

  /// 结束会话(推荐)
  static Future<Map<String, dynamic>> endSession({
    required String sessionId,
    String humanSessionId = '',
  }) async {
    final Map<String, dynamic> body = <String, dynamic>{'session_id': sessionId};
    if (humanSessionId.isNotEmpty) body['human_session_id'] = humanSessionId;
    final dynamic data = await Request().post('/aiservicer/api/servicer/endSession', data: body);
    if (data is Map) return data.cast<String, dynamic>();
    return <String, dynamic>{};
  }

  /// 提交满意度评价
  /// * [score] 1~5 星; [content] 选填; [humanSessionId] 强烈建议传
  static Future<Map<String, dynamic>> evaluate({
    required int score,
    String content = '',
    String humanSessionId = '',
    String sessionId = '',
  }) async {
    final Map<String, dynamic> body = <String, dynamic>{'score': score};
    if (content.isNotEmpty) body['content'] = content;
    if (humanSessionId.isNotEmpty) body['human_session_id'] = humanSessionId;
    if (sessionId.isNotEmpty) body['session_id'] = sessionId;
    final dynamic data = await Request().post('/aiservicer/api/servicer/evaluate', data: body);
    if (data is Map) return data.cast<String, dynamic>();
    return <String, dynamic>{};
  }

  /// 上传聊天图片 -> 返回 pic_path(原样回传为 message_url)
  static Future<String> uploadChatImg(String filePath) async {
    final FormData formData = FormData.fromMap(<String, dynamic>{
      'file': await MultipartFile.fromFile(filePath),
    });
    final Map<String, dynamic> res = await Request().postRaw('/api/upload/chatimg', data: formData);
    final int code = int.tryParse('${res['code'] ?? -1}') ?? -1;
    if (code < 0) {
      throw DioException(requestOptions: RequestOptions(path: ''), message: '${res['message'] ?? '图片上传失败'}');
    }
    final dynamic data = res['data'];
    if (data is Map) {
      final dynamic pic = data['pic_path'] ?? data['path'];
      if (pic is String && pic.isNotEmpty) return pic;
    }
    throw DioException(requestOptions: RequestOptions(path: ''), message: '${res['message'] ?? '图片上传失败'}');
  }

  /// 上传聊天视频(≤30MB) -> 返回 path
  static Future<String> uploadChatVideo(String filePath) async {
    final FormData formData = FormData.fromMap(<String, dynamic>{
      'file': await MultipartFile.fromFile(filePath),
    });
    final Map<String, dynamic> res = await Request().postRaw('/api/upload/chatvideo', data: formData);
    final int code = int.tryParse('${res['code'] ?? -1}') ?? -1;
    if (code < 0) {
      throw DioException(requestOptions: RequestOptions(path: ''), message: '${res['message'] ?? '视频上传失败'}');
    }
    final dynamic data = res['data'];
    if (data is Map) {
      final dynamic path = data['path'] ?? data['pic_path'];
      if (path is String && path.isNotEmpty) return path;
    }
    throw DioException(requestOptions: RequestOptions(path: ''), message: '${res['message'] ?? '视频上传失败'}');
  }
}
