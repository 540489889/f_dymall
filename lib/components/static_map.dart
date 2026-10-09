/// 静态地图(门店/地址位置展示用)
/// * 项目没接地图SDK(高德/百度原生插件都没引入), 页面内不能内嵌可缩放拖动的地图
/// * 两种出图方式(都不需要原生配置):
///   1) 配了 Config.amapWebKey: 高德静态图 restapi.amap.com, 一张带 marker 的图
///   2) 没配 key(或静态图失败): 直接拼高德 Web 瓦片 webrd0x.is.autonavi.com
///      —— 免 key、中文标注、国内加载快; 再叠一个中心 marker
library;

import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../config/index.dart';

class StaticMap extends StatelessWidget {
  const StaticMap({
    super.key,
    required this.latitude,
    required this.longitude,
    this.zoom = 16,
    this.marker = const Icon(Icons.location_on, color: Color(0xFFFF2C55), size: 28.0),
  });

  final double latitude;
  final double longitude;
  /// 瓦片层级(16 约街道级)
  final int zoom;
  /// 中心点标记(默认红色定位图标)
  final Widget marker;

  /// 高德静态图(需要 Web服务 key)
  String get _amapStaticUrl {
    final String pos = '$longitude,$latitude';
    return 'https://restapi.amap.com/v3/staticmap'
        '?location=$pos&zoom=$zoom&size=600*300&scale=2'
        '&markers=mid,0xFF2C55,:$pos'
        '&key=${Config.amapWebKey}';
  }

  @override
  Widget build(BuildContext context) {
    // 没配 key 直接走瓦片; 配了先用静态图, 静态图失败(key无效/超配额)再回落瓦片
    if (Config.amapWebKey.isEmpty) return _tileMap();
    return CachedNetworkImage(
      imageUrl: _amapStaticUrl,
      fit: BoxFit.cover,
      placeholder: (_, __) => Container(color: const Color(0xFFF4F5FA)),
      errorWidget: (_, __, ___) => _tileMap(),
    );
  }

  Widget _tileMap() => _TileMap(latitude: latitude, longitude: longitude, zoom: zoom, marker: marker);
}

/// 瓦片拼图: 按经纬度算出中心瓦片, 向四周铺满容器, 中心点钉在容器正中
class _TileMap extends StatelessWidget {
  const _TileMap({
    required this.latitude,
    required this.longitude,
    required this.zoom,
    required this.marker,
  });

  static const double _tileSize = 256.0;

  final double latitude;
  final double longitude;
  final int zoom;
  final Widget marker;

  /// 高德 Web 瓦片(免 key): style=8 路网+中文标注, 4 个子域轮换
  /// * scale=2 取 512px 高清瓦片(瓦片编号不变), 铺在 256 逻辑像素里, 高分屏不发虚
  /// * scale=1 只有 256px, 2x/3x 屏上就是字和图都糊
  String _tileUrl(int x, int y) {
    final int sub = (x + y) % 4 + 1;
    return 'https://webrd0$sub.is.autonavi.com/appmaptile'
        '?lang=zh_cn&size=1&scale=2&style=8&x=$x&y=$y&z=$zoom';
  }

  @override
  Widget build(BuildContext context) {
    final int n = 1 << zoom;
    // 经纬度 -> 瓦片坐标(含小数部分, 小数用来算瓦片内的像素偏移)
    final double xf = (longitude + 180.0) / 360.0 * n;
    final double latRad = latitude * math.pi / 180.0;
    final double yf = (1.0 - math.log(math.tan(latRad) + 1.0 / math.cos(latRad)) / math.pi) / 2.0 * n;

    final int centerX = xf.floor();
    final int centerY = yf.floor();
    final double offsetX = (xf - centerX) * _tileSize;
    final double offsetY = (yf - centerY) * _tileSize;

    return ClipRect(
      child: Stack(
        children: <Widget>[
          Positioned.fill(
            child: Container(color: const Color(0xFFEDEDED)),
          ),
          Positioned.fill(
            child: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints c) {
                // 中心瓦片左上角的位置: 让中心点落在容器正中
                final double originX = c.maxWidth / 2.0 - offsetX;
                final double originY = c.maxHeight / 2.0 - offsetY;
                final int iMin = ((0 - originX) / _tileSize).floor();
                final int iMax = ((c.maxWidth - originX) / _tileSize).ceil();
                final int jMin = ((0 - originY) / _tileSize).floor();
                final int jMax = ((c.maxHeight - originY) / _tileSize).ceil();

                final List<Widget> tiles = <Widget>[];
                for (int j = jMin; j < jMax; j++) {
                  final int y = centerY + j;
                  // 纬度越界没有对应瓦片(经度可绕圈)
                  if (y < 0 || y >= n) continue;
                  for (int i = iMin; i < iMax; i++) {
                    final int x = (centerX + i) % n;
                    tiles.add(Positioned(
                      left: originX + i * _tileSize,
                      top: originY + j * _tileSize,
                      width: _tileSize,
                      height: _tileSize,
                      child: Image.network(
                        _tileUrl(x, y),
                        fit: BoxFit.cover,
                        // 512 -> 256 是缩小采样, 默认 low 会丢细节(路名发虚)
                        filterQuality: FilterQuality.medium,
                        // 单块瓦片失败只留灰块, 不影响其余瓦片
                        errorBuilder: (_, __, ___) => const SizedBox.expand(),
                      ),
                    ));
                  }
                }
                return Stack(children: tiles);
              },
            ),
          ),
          Center(child: marker),
        ],
      ),
    );
  }
}
