/// 学习课程 / 素材库 接口(materials 模块,对应参考项目 trainingVideo)
library;

import '../config/index.dart';
import '../utils/request.dart';

class MaterialsApi {
  /// 把图片相对路径拼接成完整 url(对齐 H5 config.imgDomain)
  static String fixUrl(dynamic src) {
    final String s = '${src ?? ''}'.trim();
    if (s.isEmpty) return '';
    if (s.startsWith('http') || s.startsWith('data:image')) return s;
    return Config.imgDomain + (s.startsWith('/') ? s : '/$s');
  }

  /// 分类列表(含 id=0 全部)
  static Future<List<Map<String, dynamic>>> typeList() async {
    try {
      final dynamic res = await Request().get('/materials/api/materials/typeList');
      if (res is List) return res.cast<Map<String, dynamic>>();
    } catch (_) {
      // 接口异常时返回空列表,页面走空态
    }
    return const [];
  }

  /// 全部(id=0)顶层数据: 兼容 {videos, article} / {list}混合 / 外层 data 包裹 / 纯数组
  static Future<Map<String, dynamic>> materialTop({String search = ''}) async {
    try {
      final Map<String, dynamic> body = <String, dynamic>{};
      if (search.isNotEmpty) body['search'] = search;
      final dynamic res =
          await Request().postRaw('/materials/api/materials/materialTop', data: body);

      final List<dynamic> videos = <dynamic>[];
      final List<dynamic> articles = <dynamic>[];

      void splitMixed(List<dynamic> mixed) {
        for (final dynamic e in mixed) {
          if (e is! Map) continue;
          final Map<String, dynamic> item = e as Map<String, dynamic>;
          final String t = '${item['type'] ?? ''}';
          if (t == 'text' || t == 'article') {
            articles.add(item);
          } else {
            videos.add(item);
          }
        }
      }

      if (res is Map) {
        final Map<String, dynamic> m = res as Map<String, dynamic>;
        // 方式1: 直接 {videos:[], article:[]}
        List<dynamic> v = (m['videos'] ?? <dynamic>[]) as List<dynamic>;
        List<dynamic> a = (m['article'] ?? <dynamic>[]) as List<dynamic>;
        // 兼容外层 data 包裹
        if (v.isEmpty && a.isEmpty && m['data'] is Map) {
          final Map<String, dynamic> d = m['data'] as Map<String, dynamic>;
          v = (d['videos'] ?? <dynamic>[]) as List<dynamic>;
          a = (d['article'] ?? <dynamic>[]) as List<dynamic>;
        }
        if (v.isNotEmpty || a.isNotEmpty) {
          videos.addAll(v);
          articles.addAll(a);
        } else {
          // 方式2: 混合列表 {list:[]} / {data:{list:[]}}, 按 type 拆视频/文章
          List<dynamic> mixed = <dynamic>[];
          if (m['list'] is List) {
            mixed = m['list'] as List<dynamic>;
          } else if (m['data'] is Map &&
              (m['data'] as Map)['list'] is List) {
            mixed = ((m['data'] as Map)['list']) as List<dynamic>;
          }
          splitMixed(mixed);
        }
        return <String, dynamic>{'videos': videos, 'article': articles};
      } else if (res is List) {
        // 直接是混合数组
        splitMixed(res);
        return <String, dynamic>{'videos': videos, 'article': articles};
      }
    } catch (_) {}
    return <String, dynamic>{'videos': const [], 'article': const []};
  }

  /// 分类 / 搜索列表: {page_count, count, list}
  /// * [typeId] 分类 id(0 表示全部)
  /// * [type] 'video' / 'text'(更多页按类型筛选)
  /// * [search] 关键词
  static Future<Map<String, dynamic>> materialList({
    int typeId = 0,
    String type = '',
    String search = '',
    int page = 1,
    int pageSize = 10,
  }) async {
    try {
      final Map<String, dynamic> data = <String, dynamic>{
        'page': page,
        'page_size': pageSize,
      };
      if (typeId > 0) data['type_id'] = typeId;
      if (type.isNotEmpty) data['type'] = type;
      if (search.isNotEmpty) data['search'] = search;
      final dynamic res = await Request().post('/materials/api/materials/materialList', data: data);
      if (res is Map) {
        return <String, dynamic>{
          'page_count': res['page_count'] ?? 1,
          'count': res['count'] ?? 0,
          'list': (res['list'] ?? <dynamic>[]) as List,
        };
      }
    } catch (_) {}
    return <String, dynamic>{'page_count': 1, 'count': 0, 'list': const []};
  }

  /// 详情(视频 / 文章共用)
  static Future<Map<String, dynamic>> materialDetail(int id) async {
    try {
      final dynamic res = await Request().post(
        '/materials/api/materials/materialDetail',
        data: <String, dynamic>{'id': id},
      );
      if (res is Map) return res.cast<String, dynamic>();
    } catch (_) {}
    return const {};
  }

  /// 评论分页
  static Future<Map<String, dynamic>> commentList({
    required int materialId,
    int page = 1,
    int pageSize = 10,
  }) async {
    try {
      final dynamic res = await Request().post(
        '/materials/api/materials/commentList',
        data: <String, dynamic>{
          'page': page,
          'page_size': pageSize,
          'meterial_id': materialId,
        },
      );
      if (res is Map) {
        return <String, dynamic>{
          'page_count': res['page_count'] ?? 1,
          'list': (res['list'] ?? <dynamic>[]) as List,
        };
      }
    } catch (_) {}
    return <String, dynamic>{'page_count': 1, 'list': const []};
  }

  /// 弹幕列表(视频详情可选展示)
  static Future<List<Map<String, dynamic>>> commentBarrage(int materialId) async {
    try {
      final dynamic res = await Request().post(
        '/materials/api/materials/commentBarrage',
        data: <String, dynamic>{'meterial_id': materialId},
      );
      if (res is List) return res.cast<Map<String, dynamic>>();
      if (res is Map && res['list'] is List) {
        return (res['list'] as List).cast<Map<String, dynamic>>();
      }
    } catch (_) {}
    return const [];
  }

  /// 发表评论(未登录后端会拦截,页面层先引导登录)
  static Future<bool> addComment({
    required int materialId,
    required String content,
    int barrageTime = 0,
  }) async {
    try {
      await Request().post(
        '/materials/api/materials/addComment',
        data: <String, dynamic>{
          'meterial_id': materialId,
          'content': content,
          'barrage_time': barrageTime,
        },
      );
      return true;
    } catch (_) {
      return false;
    }
  }
}
