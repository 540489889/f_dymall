# 阿里云移动推送 · 厂商通道（离线推送）配置清单

> 适用：Flutter 3 + `aliyun_push: ^1.2.0`（官方包），包名 `com.chongloutech.lehui`
> 目标：App 被杀进程后，走手机厂商系统通道（小米 / 华为）仍能收到推送
> 结论：离线推送 = **代码侧（已做完）+ 控制台/后台（必填，代码改不了）** 两部分，缺一不可

---

## 一、已完成 · 代码侧（无需再改）

| 改动 | 文件 | 说明 |
|------|------|------|
| Flutter 依赖 | `pubspec.yaml` | 移除 `jpush_flutter`，加入 `aliyun_push: ^1.2.0`（官方包，兼容当前 Flutter 3.41） |
| 推送封装 | `lib/utils/push.dart` | 用 `AliyunPush()` 单例重写：`initPush(appKey,appSecret)` → `initAndroidThirdPush()`（厂商通道）→ `addMessageReceiver(...)` → 通知权限 → `getDeviceId()` 上报 → `addAlias('member_<id>')` 绑定；点击跳转沿用原 type/id 路由表 |
| 配置项 | `lib/config/index.dart` | `Config.aliPushAppKey` / `aliPushAppSecret`（EMAS 控制台获取；**留空则整体跳过**） |
| 上报接口 | `lib/api/push.dart` | `PushApi.bind/unbind`，wire 字段仍叫 `registration_id`，其值现为阿里云 `deviceId`（后端需切到阿里云 SDK 按 deviceId 下发） |
| 阿里云消息接收器 | `android/app/src/main/AndroidManifest.xml` | `com.aliyun.ams.push.AliyunPushMessageReceiver` + 三个 action 的 intent-filter（必须声明） |
| 辅助弹窗 | `android/app/src/main/AndroidManifest.xml` | `com.aliyun.ams.push.PushPopupActivity`（`exported=true`，agoo scheme，厂商点击拉起 App 用） |
| 华为 appid | `android/app/src/main/AndroidManifest.xml` | `<meta-data android:name="com.huawei.hms.client.appid" android:value="appid=118256145"/>`（`AliyunPush.HuaWeiRegister` 据此注册华为通道） |
| 小米 id/key | `android/app/src/main/AndroidManifest.xml` | `com.xiaomi.push.id` / `com.xiaomi.push.key`（值加 `id=` 前缀，长数字否则被当 long 解析失败） |
| 原生依赖 | （无需手动加） | `aliyun_push` 插件以 `api` 透传 `alicloud-android-push:3.10.1` + 各厂商 `third-push-*`（含 huawei/xiaomi），`initAndroidThirdPush()` 触发注册 |
| 华为 maven 仓 | `android/build.gradle.kts` 的 `allprojects.repositories` | `https://maven.aliyun.com/nexus/content/repositories/releases/` 与 `https://developer.huawei.com/repo/`（插件自带，这里再显式声明更稳） |
| 华为配置文件 | `android/app/src/main/assets/agconnect-services.json` | 华为 HMS push SDK 运行时读取 app_id；从原 JPush 方案沿用，保留不删（删了华为通道注册可能失败） |
| 通知权限 | `android/app/src/main/AndroidManifest.xml` | `POST_NOTIFICATIONS` 权限已声明；`lib/utils/push.dart` 进 App 主动申请 |

> ⚠️ 不再引入 `jpush_flutter` 及 `cn.jiguang.sdk.plugin:*` 依赖，相关原生配置（小米 `PushMessageHandler` service、JPush manifestPlaceholders）已全部移除。

---

## 二、必做 · 控制台 / 后台（代码改不了，漏一项就不下发）

### 2.1 阿里云 EMAS（先建应用）
1. 阿里云 EMAS 控制台 → 创建应用（包名 `com.chongloutech.lehui`）→ 拿到 **AppKey / AppSecret**
2. 填入 `lib/config/index.dart` 的 `Config.aliPushAppKey` / `aliPushAppSecret`
   - 留空时 `PushService.init()` 直接跳过，不影响其他功能（便于没配好时先发版）

### 2.2 华为（最容易漏）
1. **EMAS 控制台 → 厂商通道 → 华为**：填华为 **App ID = 118256145** 与华为 **App Secret**（取自华为 AppGallery Connect 该应用的「APP Secret」，**不是** `agconnect-services.json` 的 `client_secret`）
2. **华为 AppGallery Connect → 应用信息 → SHA256 证书指纹**：登记你 App 签名证书的 SHA256
   - 漏了 HMS 不下发 token（日志常见 `6003`）。改完华为后台后**重新构建安装**才生效。

### 2.3 小米
1. **EMAS 控制台 → 厂商通道 → 小米**：填小米开放平台该应用的 **AppID / AppKey**（即 Manifest 里的 `com.xiaomi.push.id` / `com.xiaomi.push.key`，值须一致）
2. 小米开放平台应用包名须为 `com.chongloutech.lehui`

### 2.4 通用
- 用户必须在通知授权弹窗点「允许」（代码已改成进 App 就弹）；若拒绝，离线通知栏不显示。
- EMAS 控制台发推送时目标选「厂商通道」或「所有通道」，杀进程后才会走系统通道。
- **后端必须切到阿里云推送 SDK**：用 App 上报的 `deviceId`（原 `registration_id` 字段的值）调用阿里云服务端 API 下发；极光的服务端代码不能直接发阿里云设备。

---

## 三、验证

```bash
adb logcat -c
::: 杀掉 App，从 EMAS 控制台发「厂商通道/所有通道」推送，等 10 秒
adb logcat -d > C:\Users\0\offline_push.txt
```
日志搜（不区分大小写）：
- 初始化：`initPush 结果` / `initAndroidThirdPush 结果`（来自 `lib/utils/push.dart` 的 debugPrint）
- 华为：`huawei` / `HuaWeiRegister` / `getToken` / `6003`（指纹未登记）
- 小米：`xiaomi` / `MiPushRegister`
- deviceId：`getDeviceId`
- 点击跳转：点通知后搜 `点击通知` / `解析 extras`
- 在线能收、杀进程收不到 = 仍卡在第二节某项控制台/后台配置

---

## 四、参数速查

| 项 | 值 |
|----|----|
| 包名 | `com.chongloutech.lehui` |
| 阿里云 EMAS AppKey / AppSecret | 在 `Config.aliPushAppKey` / `aliPushAppSecret` 填（控制台获取） |
| 华为 app_id | `118256145`（Manifest `com.huawei.hms.client.appid` + EMAS 厂商通道） |
| 小米 AppID | `2882303761520547654`（`com.xiaomi.push.id`，带 `id=` 前缀） |
| 小米 AppKey | `5662054722654`（`com.xiaomi.push.key`，带 `id=` 前缀） |
| 阿里云原生 SDK | `com.aliyun.ams:alicloud-android-push:3.10.1` |

---

## 五、排错速记
- **进 App 能收、杀进程收不到** → 厂商通道没通：先查第二节控制台/后台（小米 AppKey、华为 AppSecret + SHA256 指纹、EMAS 厂商通道是否启用）。
- **离线收不到且无任何报错** → EMAS 厂商通道未启用 / AppSecret 错 / 包名与厂商后台登记不一致。
- **华为 6003** → 签名 SHA256 指纹未在华为后台登记或填错。
- **构建报阿里云/HMS/push 找不到** → 确认 `android/build.gradle.kts` 的 `allprojects.repositories` 已加阿里云 + 华为 maven 仓（插件自带，这里重复声明无害）。
- **点击通知不跳转（仅冷启动偶发）** → 原生 `onNotificationOpened` 在个别机型冷启动可能早于 Flutter 注册 handler；不影响通知栏展示与离线送达（系统通道负责），仅影响「点击跳转」；如需 100% 命中可后续在 `MainActivity` 读启动 intent 兜底。
