/// 弹幕/聊天字体缩放设置(与 H5 liveFooter 的 zoomSize 一致)
/// * 档位: 1 标 / 1.3 中 / 1.6 大; 设置写本地缓存(key 与 H5 同名为 zoomSize), 下次进直播间自动生效
/// * 单独抽一个文件: 直播间弹幕区与字体设置弹窗都要用, 避免两边互相 import
library;

import 'package:flutter/material.dart';

import 'storage.dart';

/// 本地缓存键(与 H5 uni.setStorageSync('zoomSize', val) 同键)
const String danmuZoomKey = 'zoomSize';

/// 可选档位(与 H5 setZoom 的取值一致)
const List<double> danmuZoomOptions = <double>[1.0, 1.3, 1.6];

/// 档位文案(与 H5 zoomText 一致)
String danmuZoomText(double zoom) {
  if (zoom <= 1.0) return '标';
  if (zoom <= 1.3) return '中';
  return '大';
}

/// 读取本地缓存的缩放值(没设置过/脏值按 1 处理)
double loadDanmuZoom() {
  final dynamic val = Storage.read(danmuZoomKey);
  final double? zoom = val is num ? val.toDouble() : double.tryParse('${val ?? ''}');
  if (zoom == null || zoom <= 0) return 1.0;
  return zoom;
}

/// 当前缩放: 弹幕区监听它, 改档位后自动重建(不用整页 setState)
final ValueNotifier<double> danmuZoom = ValueNotifier<double>(loadDanmuZoom());

/// 设置缩放并写入本地缓存
void setDanmuZoom(double zoom) {
  Storage.write(danmuZoomKey, zoom);
  danmuZoom.value = zoom;
}
