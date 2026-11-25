/// GroMore 聚合广告配置(gromore_ads)
/// * appId / 广告位ID 在 GroMore(穿山甲) 后台创建应用与广告位后获取
/// * 重要: iOS 与 Android 是两套独立的应用/广告位,ID 不能混用!
///   之前 iOS 一直复用 Android 的 appId(5888700),拿不到广告填充;
///   需把下面 iOS 的 4 个 ID 换成 GroMore 后台 iOS 应用下的真实 ID。
/// * 聚合场景必须填"广告位ID"(GroMore 广告位), 不能填"代码位ID",
///   否则请求会报 20001(聚合代码位只能在聚合场景使用) / 40034(非服务端竞价)
/// * 任一 id 留空时对应广告不展示, 业务照常跑(iOS ID 未填时广告静默跳过,不报错)
library;

class AdsConfig {
  // ===== Android(已配置,线上在用) =====
  // 应用ID: 必填, 留空则不初始化SDK
  static const String androidAppId = '5888700';
  // 激励视频广告位: 赚钱页"看视频获取金币"看完发金币
  static const String androidRewardVideoId = '104584610';
  // 插屏广告位: 其他任务"去领取"前弹出
  static const String androidInterstitialId = '';
  // Banner 广告位: 赚钱页每日任务下方
  static const String androidBannerId = '104581489';

  // ===== iOS(待填: GroMore 后台 iOS 应用下的 appId 与广告位ID) =====
  // 拿到后替换下面的空串;留空时 iOS 端不初始化广告,不展示广告位,业务照常跑
  static const String iosAppId = '5886132';
  static const String iosRewardVideoId = '104583846';
  static const String iosInterstitialId = '';
  static const String iosBannerId = '';

  // 开发调试总开关: 临时关掉穿山甲(GroMore 广告SDK + 内容SDK), 避免调试时被大量广告日志/初始化干扰
  // * 置为 true 时 SDK 不初始化、不请求广告、Banner 不渲染, 业务照常跑
  // * 调试完把这里改回 false 即可恢复
  static const bool debugDisable = false;

  /// 实际生效的开关(业务统一判这个): 由 ads.dart 按平台把 appId 写入 currentAppId
  static bool get enabled => currentAppId.isNotEmpty;

  /// 当前平台实际使用的 ID(由 ads.dart 在初始化时按 Platform 赋值)
  static String currentAppId = '';
  static String currentRewardVideoId = '';
  static String currentInterstitialId = '';
  static String currentBannerId = '';

  static bool get usable => enabled && !debugDisable;
}
