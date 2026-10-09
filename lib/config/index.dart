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

  // ===== 门店地图 =====
  /// 高德地图 Web服务 key(静态地图 restapi.amap.com/v3/staticmap 用)
  /// * 高德开放平台 -> 应用 -> 添加key -> 服务平台选「Web服务」
  /// * 留空时回落到 OpenStreetMap 静态图(免key), 国内加载可能偏慢
  static const String amapWebKey = '';

  // ===== 微信开放平台(APP微信登录) =====
  /// 移动应用 AppID(微信开放平台创建移动应用后获取,形如 wx1234567890)
  /// * 留空表示未接入: 登录页/个人资料页不显示微信入口,相关代码不执行
  /// * Android 还需在开放平台登记包名(com.chongloutech.lehui)与应用签名MD5
  static const String wxAppId = 'wx1ea2d457d5bba58a';
  /// iOS Universal Link(微信开放平台配置,形如 https://lehuilife.chongloutech.com/link/)
  /// * 仅 iOS 使用;留空时 iOS 端微信登录不可用(Android 不受影响)
  static const String wxUniversalLink = 'https://lehui.chongloutech.com/index/ios/';

  // ===== 阿里云号码认证(一键登录) =====
  /// Android 密钥(阿里云控制台: 号码认证服务 -> 号码认证方案 -> 方案密钥)
  /// * 留空表示未接入: 登录页不显示"本机号码一键登录"入口
  /// * 注意: 阿里云后台登记的签名必须与打包签名一致(当前用 lehui.keystore)
  static const String aliAndroidSk =
      'pt222/WED5urUhGlZOc0f682X6jxBT2SG/AChkceC81OYMR9Wh6CKNpOPYtyFfxXQYbWbionGlvatXfuk037e+knNrUjulYsmMJj/2kLZefh0QO9xe0qxD6/ZGcODMwE4ppW0JEK0AglTx6x+NsH+2tdppKhCMvGmUPaV8F96pwv+d58mJDkqEbz+8IDCLsyjnGgrrNHMhYw/zA0CeROJjHFoTJb6dD/68XQcSdVkqE9EfEbLSKv6VX/3snADe38nfHYKdc/GkpdIf8mtTOSUp3GZGcgjsoSrzg3Rof10TiRC8BkkZbbRA==';
  /// iOS 密钥(同上,取 iOS 端的方案密钥;iOS 端还需配置 BundleId)
  static const String aliIosSk = '';

  /// 请求超时时间(秒)
  static const int connectTimeout = 15;
  static const int receiveTimeout = 15;
  static const int sendTimeout = 15;
}
