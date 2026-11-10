# ==================== 阿里云移动推送 (alicloud-android-push 3.10.1) ====================
# 背景: release 包启动即崩, 堆栈为
#   java.lang.ExceptionInInitializerError
#   Caused by: java.lang.IllegalStateException: Fail to load ams-spi-services for j2.a
#   Caused by: java.lang.InstantiationException: java.lang.Class<j2.a> cannot be instantiated
# 用 mapping.txt 还原后: v1.a = com.alibaba.sdk.android.ams.common.c.b(SPI 加载器),
#   j2.a = com.alibaba.sdk.android.push.d.a.c(SPI 实现类)。
# 原因: 阿里云推送通过 SPI 机制反射 newInstance 加载服务, 这些类的无参构造函数只被反射调用,
#   R8 静态分析看不到, 当成"未使用"移除 -> 运行时 newInstance 失败。debug 不混淆, 故不复现。
# 处理: 整包 keep 阿里云推送及其依赖(含构造函数), 不再让 R8 动它们。
-keep class com.alibaba.sdk.android.** { *; }
-keep class com.aliyun.ams.** { *; }
-keep class com.ut.** { *; }
-keep class com.ta.** { *; }
-keep class com.taobao.accs.** { *; }
-keep class org.android.spdy.** { *; }
-keep class anet.** { *; }
-keep class anetwork.** { *; }

# 保险: 显式保留阿里云相关类的无参构造(SPI 反射实例化入口)
-keepclassmembers class com.alibaba.sdk.android.** { public <init>(); }
-keepclassmembers class com.aliyun.ams.** { public <init>(); }

# ==================== 通用 ====================
# 反射 / 注解 / 泛型签名信息: 被移除会导致各类 SDK 通过反射拿不到成员
-keepattributes Signature
-keepattributes *Annotation*
-keepattributes InnerClasses,EnclosingMethod

# JNI / native 方法
-keepclasseswithmembernames class * {
    native <methods>;
}
