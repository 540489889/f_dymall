/// 网络请求封装
library;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:get/get.dart' hide Response, FormData;
import '../config/index.dart';
import '../controller/auth_store.dart';
import 'platform.dart';

class Request {
  static final Request _instance = Request._internal();
  factory Request() => _instance;

  late final Dio dio;

  Request._internal() {
    dio = Dio(
      BaseOptions(
        baseUrl: Config.baseUrl,
        connectTimeout: Duration(seconds: Config.connectTimeout),
        receiveTimeout: Duration(seconds: Config.receiveTimeout),
        sendTimeout: Duration(seconds: Config.sendTimeout),
        headers: const {'Content-Type': 'application/json'},
        responseType: ResponseType.json,
      ),
    );

    // 排查接口参数用: 打印 url / 请求体 / 响应
    if (kDebugMode && Config.httpLog) {
      dio.interceptors.add(
        LogInterceptor(
          request: true,
          requestHeader: false,
          requestBody: true,
          responseHeader: false,
          responseBody: true,
          error: true,
        ),
      );
    }

    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (RequestOptions options, RequestInterceptorHandler handler) {
          // header 携带token(所有端统一)
          final String token = currentToken;
          if (token.isNotEmpty) {
            options.headers['token'] = token;
          }
          // 公共参数: GET -> query, POST -> body
          _injectCommonParams(options);
          return handler.next(options);
        },
      ),
    );
  }

  /// 当前token(未登录为空)
  static String get currentToken {
    if (!Get.isRegistered<AuthStore>()) return '';
    return AuthStore.to.authorization.value;
  }

  /// 公共请求参数(对齐H5 request.js: os_type/app_type/app_type_name/token/store_id)
  /// * [storeId] 为空时取已绑定门店
  static Map<String, dynamic> commonParams({int? storeId}) {
    final Map<String, dynamic> params = <String, dynamic>{
      'os_type': PlatformInfo.osType,
      'os_name': PlatformInfo.osName,
      'app_type': PlatformInfo.appType,
      'app_type_name': PlatformInfo.appTypeName,
    };
    final String token = currentToken;
    if (token.isNotEmpty) params['token'] = token;
    int sid = storeId ?? 0;
    if (sid == 0 && Get.isRegistered<AuthStore>()) sid = AuthStore.to.storeId.value;
    if (sid != 0) params['store_id'] = sid;
    return params;
  }

  /// 把公共参数注入请求(业务参数优先,与H5 Object.assign(data, params.data)顺序一致)
  static void _injectCommonParams(RequestOptions options) {
    final Map<String, dynamic> common = commonParams();
    final String method = options.method.toUpperCase();
    if (method == 'GET' || method == 'DELETE' || method == 'HEAD') {
      final Map<String, dynamic> query = Map<String, dynamic>.from(options.queryParameters);
      common.forEach((String key, dynamic value) {
        query.putIfAbsent(key, () => value);
      });
      options.queryParameters = query;
      return;
    }
    final dynamic data = options.data;
    if (data == null) {
      options.data = common;
    } else if (data is Map) {
      options.data = <String, dynamic>{
        ...common,
        ...Map<String, dynamic>.from(data),
      };
    } else if (data is FormData) {
      common.forEach((String key, dynamic value) {
        if (data.fields.any((MapEntry<String, String> e) => e.key == key)) return;
        data.fields.add(MapEntry<String, String>(key, '$value'));
      });
    }
  }

  /// post请求
  /// * [path] 接口地址
  /// * [data] 请求体
  /// * [form] true 时用 application/x-www-form-urlencoded 编码
  ///   (秒杀/插件类接口只解析表单参数, 传 json 会报"缺少参数xxx")
  Future<dynamic> post(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    bool form = false,
  }) {
    Options? opt = options;
    if (form) {
      opt = (opt ?? Options()).copyWith(contentType: Headers.formUrlEncodedContentType);
    }
    return _request(() => dio.post(path, data: data, queryParameters: queryParameters, options: opt));
  }

  /// get请求
  Future<dynamic> get(String path, {Map<String, dynamic>? queryParameters, Options? options}) {
    return _request(() => dio.get(path, queryParameters: queryParameters, options: options));
  }

  /// get请求(原始响应: 含 code / message / data),如 /api/pay/type
  Future<Map<String, dynamic>> getRaw(String path, {Map<String, dynamic>? queryParameters}) async {
    final dynamic body = await _handle(await dio.get(path, queryParameters: queryParameters));
    if (body is Map) return body.cast<String, dynamic>();
    return <String, dynamic>{'code': -1, 'message': '返回数据格式错误', 'data': null};
  }

  /// post请求(原始响应: 含 code / message / data)
  /// * 用于 code >= 0 即视为成功的接口,如 /api/pay/pay、/api/pay/info、/api/pay/status
  /// * [form] true 时用表单编码(秒杀类接口需要)
  Future<Map<String, dynamic>> postRaw(String path, {dynamic data, Map<String, dynamic>? queryParameters, bool form = false}) async {
    Options? opt;
    if (form) opt = Options(contentType: Headers.formUrlEncodedContentType);
    final dynamic body = await _handle(await dio.post(path, data: data, queryParameters: queryParameters, options: opt));
    if (body is Map) return body.cast<String, dynamic>();
    return <String, dynamic>{'code': -1, 'message': '返回数据格式错误', 'data': null};
  }

  /// 统一处理: code == 0 时返回业务data,否则抛异常
  Future<dynamic> _request(Future<Response<dynamic>> Function() task) async {
    final dynamic body = await _handle(await task());
    if (body is Map) {
      if ('${body['code']}' == '0') return body['data'];
      throw DioException(
        requestOptions: RequestOptions(path: ''),
        message: '${body['message'] ?? '请求失败'}',
      );
    }
    return body;
  }

  /// 响应预处理: token续期 + 登录失效处理(与H5一致),返回原始body
  Future<dynamic> _handle(Response<dynamic> res) async {
    final dynamic body = res.data;
    if (body is Map) {
      // token续期(与H5 res.data.refreshtoken 一致)
      final dynamic refreshToken = body['refreshtoken'];
      if (refreshToken != null && '$refreshToken'.isNotEmpty && Get.isRegistered<AuthStore>()) {
        AuthStore.to.setAuthorization('$refreshToken');
      }
      final String code = '${body['code']}';
      // 登录失效(-10009/-10010): 清空登录态,与H5一致
      if (code == '-10009' || code == '-10010') {
        if (Get.isRegistered<AuthStore>()) AuthStore.to.logout();
      }
    }
    return body;
  }
}
