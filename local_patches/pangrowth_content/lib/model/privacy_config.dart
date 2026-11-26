/// 隐私合规配置选项
class PrivacyConfig {
  /// 是否允许 SDK 主动读取手机状态（IMEI/IMSI）
  final bool? allowPhoneState;

  /// 当主动读取被禁用时，开发者可手动传入 IMEI
  final String? imei;

  /// 当主动读取被禁用时，开发者可手动传入 IMSI
  final String? imsi;

  /// 是否允许 SDK 主动获取 AndroidId
  final bool? allowAndroidId;

  /// 当主动读取被禁用时，开发者可手动传入 AndroidId
  final String? androidId;

  /// 是否允许 SDK 主动获取 Mac 地址
  final bool? allowMac;

  /// 是否允许 SDK 主动获取 OAID
  final bool? allowOaid;

  /// 是否允许 SDK 主动获取 ICCID
  final bool? allowIccid;

  /// 是否允许 SDK 主动获取设备序列号
  final bool? allowSerialNumber;

  /// 是否允许 SDK 主动获取 GAID（默认关闭）
  final bool? allowGaid;

  /// 是否允许 SDK 主动获取运营商信息
  final bool? allowOperatorInfo;

  /// 是否启用青少年模式（启用后短剧内容会受限）
  final bool? teenagerMode;

  /// 是否仅返回有备案号的内容
  final bool? onlyIcpNumber;

  const PrivacyConfig({
    this.allowPhoneState,
    this.imei,
    this.imsi,
    this.allowAndroidId,
    this.androidId,
    this.allowMac,
    this.allowOaid,
    this.allowIccid,
    this.allowSerialNumber,
    this.allowGaid,
    this.allowOperatorInfo,
    this.teenagerMode,
    this.onlyIcpNumber,
  });

  factory PrivacyConfig.fromMap(Map<String, dynamic> map) {
    return PrivacyConfig(
      allowPhoneState: map['allowPhoneState'] as bool?,
      imei: map['imei'] as String?,
      imsi: map['imsi'] as String?,
      allowAndroidId: map['allowAndroidId'] as bool?,
      androidId: map['androidId'] as String?,
      allowMac: map['allowMac'] as bool?,
      allowOaid: map['allowOaid'] as bool?,
      allowIccid: map['allowIccid'] as bool?,
      allowSerialNumber: map['allowSerialNumber'] as bool?,
      allowGaid: map['allowGaid'] as bool?,
      allowOperatorInfo: map['allowOperatorInfo'] as bool?,
      teenagerMode: map['teenagerMode'] as bool?,
      onlyIcpNumber: map['onlyIcpNumber'] as bool?,
    );
  }

  Map<String, dynamic> toMap() {
    final Map<String, dynamic> result = {};
    void put(String key, dynamic value) {
      if (value != null) {
        result[key] = value;
      }
    }

    put('allowPhoneState', allowPhoneState);
    put('imei', imei);
    put('imsi', imsi);
    put('allowAndroidId', allowAndroidId);
    put('androidId', androidId);
    put('allowMac', allowMac);
    put('allowOaid', allowOaid);
    put('allowIccid', allowIccid);
    put('allowSerialNumber', allowSerialNumber);
    put('allowGaid', allowGaid);
    put('allowOperatorInfo', allowOperatorInfo);
    put('teenagerMode', teenagerMode);
    put('onlyIcpNumber', onlyIcpNumber);

    return result;
  }
}
