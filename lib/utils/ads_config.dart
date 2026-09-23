/// GroMore 聚合广告配置(gromore_ads)
/// * appId / 广告位ID 在 GroMore(穿山甲) 后台创建应用与广告位后获取
/// * 重要: 聚合场景必须填"广告位ID"(GroMore 广告位), 不能填"代码位ID",
///   否则请求会报 20001(聚合代码位只能在聚合场景使用) / 40034(非服务端竞价)
/// * 任一 id 留空时对应广告不展示, 业务照常跑
library;

class AdsConfig {
  // 应用ID: 必填, 留空则不初始化SDK
  static const String appId = '5888700';
  // 激励视频广告位: 赚钱页"看视频获取金币"看完发金币
  static const String rewardVideoId = '104584610';
  // 插屏广告位: 其他任务"去领取"前弹出
  static const String interstitialId = '';
  // Banner 广告位: 赚钱页每日任务下方
  static const String bannerId = '104581489';

  // 总开关: appId 为空则不初始化SDK, 页面也不展示广告位
  static bool get enabled => appId.isNotEmpty;
}
