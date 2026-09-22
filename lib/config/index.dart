/// 全局配置
library;

class Config {
  /// api请求地址
  static const String baseUrl = 'https://lehuilife.chongloutech.com';
  // static const String baseUrl = 'https://lehui.chongloutech.com';
  /// 接口前缀
  static const String apiPrefix = '/api';

  /// 图片地址前缀(与H5的 imgDomain 一致: 相对路径需拼接该域名)
  static const String imgDomain = 'https://lehuilife.chongloutech.com';
    // static const String imgDomain = 'https://lehui.chongloutech.com';

  /// websocket连接地址
  static const String socketUrl = 'wss://lehuilife.chongloutech.com//wss';

  /// 商品图片代理前缀(web端图片跨域无法解码时配置,如 'https://xxx.com/img?url=')
  /// 留空则直接使用原图地址
  static const String imageProxy = '';

  /// 是否打印请求/响应日志(仅debug模式生效,排查接口参数用)
  static const bool httpLog = true;

  /// 请求超时时间(秒)
  static const int connectTimeout = 15;
  static const int receiveTimeout = 15;
  static const int sendTimeout = 15;
}
