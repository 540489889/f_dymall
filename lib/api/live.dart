/// 直播相关接口
library;

import 'package:flutter/foundation.dart' show debugPrint, kDebugMode;

import '../config/index.dart';
import '../utils/request.dart';

class LiveApi {
  /// 直播列表(/live/api/shop/roomPage)
  /// * [page] 页码(从 1 开始); [pageSize] 每页条数
  /// * [status] 列表筛选: 1 直播中 / 2 直播预告; 不传为全部(接口默认)
  /// * [keywords] 搜索关键字(直播间标题/主播昵称),为空不传
  /// * 返回 {list: 房间列表(已用 [roomItem] 归一化), count: 总数, pageCount: 总页数, hasMore: 是否还有下一页}
  /// * 失败/无数据返回空结果(list 为空),页面据此显示空态
  static Future<Map<String, dynamic>> roomPage({int page = 1, int pageSize = 10, int? status, String keywords = ''}) async {
    try {
      final Map<String, dynamic> query = <String, dynamic>{'page': page, 'page_size': pageSize};
      // 只传了筛选才带上 status(不传时按接口默认: 全部)
      if (status != null) query['status'] = status;
      // 搜索关键字: 有输入才带(空串不传,避免把空参数当条件)
      final String kw = keywords.trim();
      if (kw.isNotEmpty) query['keywords'] = kw;
      final Map<String, dynamic> res = await Request().getRaw(
        '/live/api/shop/roomPage',
        queryParameters: query,
      );
      if ('${res['code']}' != '0') {
        debugPrint('[live]直播列表返回异常: ${res['code']} ${res['message']}');
        return _emptyRoomPage();
      }
      final dynamic data = res['data'];
      final dynamic raw = data is Map ? (data['list'] ?? data['data']) : data;
      if (raw is! List) return _emptyRoomPage();
      final List<Map<String, dynamic>> list = <Map<String, dynamic>>[];
      for (final dynamic one in raw) {
        final Map<String, dynamic>? room = roomItem(one);
        if (room != null) list.add(room);
      }
      final int pageCount = data is Map ? intOf(data['page_count'] ?? data['pageCount']) : 0;
      return <String, dynamic>{
        'list': list,
        'count': data is Map ? intOf(data['count'] ?? data['total']) : list.length,
        'pageCount': pageCount,
        // 还有下一页: 有总页数按页数比; 没有就按本次是否拿满一页
        'hasMore': pageCount > 0 ? page < pageCount : list.length >= pageSize,
      };
    } catch (e) {
      debugPrint('[live]直播列表加载失败: $e');
      return _emptyRoomPage();
    }
  }

  /// 直播列表空结果(请求失败/无数据时返回,避免页面判空)
  static Map<String, dynamic> _emptyRoomPage() => <String, dynamic>{
        'list': <Map<String, dynamic>>[],
        'count': 0,
        'pageCount': 0,
        'hasMore': false,
      };

  /// 直播列表单条归一化(roomPage / 首页推荐共用)
  /// * 输出字段: sn(房间号) / name(标题) / feeds_img(封面) / anchor_img(主播头像)
  ///   anchor_name(主播名) / status(1 直播中) status_name(状态文案) / push_link(拉流地址)
  ///   online(在线人数) / type(横竖屏) / start_time(开播时间)
  /// * 房间号/标题/封面都取不到视为脏数据,直接丢弃
  static Map<String, dynamic>? roomItem(dynamic raw) {
    if (raw is! Map) return null;
    final String sn = '${raw['sn'] ?? ''}'.trim();
    final String name = '${raw['name'] ?? ''}'.trim();
    final String cover = imageOf(raw['feeds_img'] ?? raw['cover'] ?? raw['image']);
    if (sn.isEmpty && name.isEmpty && cover.isEmpty) return null;
    final int status = raw['status'] == null ? 1 : intOf(raw['status']);
    String statusName2 = '${raw['status_name'] ?? ''}'.trim();
    if (statusName2.isEmpty) statusName2 = statusTexts[status] ?? '直播中';
    return <String, dynamic>{
      'sn': sn,
      'name': name,
      'feeds_img': cover,
      'anchor_img': imageOf(raw['anchor_img'] ?? raw['anchorImg'] ?? raw['headimg']),
      'anchor_name': '${raw['anchor_name'] ?? raw['anchorName'] ?? ''}'.trim(),
      'status': status,
      'status_name': statusName2,
      'push_link': '${raw['push_link'] ?? raw['pushLink'] ?? ''}'.trim(),
      'online': intOf(raw['online'] ?? raw['online_num']),
      'type': '${raw['type'] ?? ''}'.trim(),
      'start_time': '${raw['start_time'] ?? ''}'.trim(),
      // 新版直播列表页扩展字段（后端下发时透传）
      'desc': '${raw['desc'] ?? raw['subtitle'] ?? raw['summary'] ?? ''}'.trim(),
      'tags': _parseTags(raw['tags'] ?? raw['labels'] ?? raw['tag']),
      'community': '${raw['community'] ?? raw['community_name'] ?? raw['area'] ?? ''}'.trim(),
      'is_verified': raw['is_verified'] == true || '${raw['is_verified'] ?? ''}' == '1',
    };
  }

  /// 标签字段归一化（逗号/竖线/数组）
  static List<String> _parseTags(dynamic val) {
    if (val is List) {
      return val.map((dynamic e) => '${e ?? ''}'.trim()).where((String s) => s.isNotEmpty).take(3).toList();
    }
    if (val is String && val.isNotEmpty) {
      return val.split(RegExp(r'[,，|/]')).map((String e) => e.trim()).where((String s) => s.isNotEmpty).take(3).toList();
    }
    return const <String>[];
  }

  /// 首页直播信息(/live/api/shop/getTopRoom)
  /// * 返回顶部直播间数据;无直播间(code != 0)或非直播中(status != 1: 0 预告 / 2 暂停 / 3 已结束)
  ///   或请求失败返回 null,页面据此隐藏直播板块
  /// * 直播间字段: sn(房间号) / name(标题) / feeds_img(封面) / anchor_img(主播头像)
  ///   anchor_name(主播名) / status(1直播中) / push_link(拉流地址) / online(在线人数)
  static Future<Map<String, dynamic>?> topRoom() async {
    try {
      final Map<String, dynamic> res = await Request().getRaw('/live/api/shop/getTopRoom');
      if ('${res['code']}' != '0') return null;
      final dynamic data = res['data'];
      Map<dynamic, dynamic>? room;
      if (data is Map) {
        room = data;
      } else if (data is List && data.isNotEmpty && data.first is Map) {
        room = data.first as Map;
      }
      if (room == null) return null;
      // status: 1 直播中,其它(未开播/已结束)按无直播处理
      if ('${room['status'] ?? 1}' != '1') return null;
      return room.cast<String, dynamic>();
    } catch (e) {
      debugPrint('[live]首页直播信息加载失败: $e');
      return null;
    }
  }

  /// 直播间信息(/live/api/shop/getRoomInfo)
  /// * [no] 房间号 sn(直播间id),进入直播间时先查该接口再起播
  /// * 返回字段: sn(房间号) / name(标题) / feeds_img(封面) / anchor_img(主播头像)
  ///   anchor_name(主播名) / status(1直播中) status_name(状态文案) / live_bg(背景图,相对路径)
  ///   type / push_type / site_id / start_time / share_href(分享链接)
  ///   status_like / status_goods / status_comment / status_record(功能开关) / subscribe 订阅
  /// * 注意: 该接口不返回拉流地址(无 push_link),拉流地址请另行调 [pullUrl] 获取
  /// * 查询失败返回 null,由页面回落到传入的 push_link / 本地数据
  static Future<Map<String, dynamic>?> roomInfo(String no) async {
    if (no.isEmpty) return null;
    try {
      final Map<String, dynamic> res = await Request().getRaw(
        '/live/api/shop/getRoomInfo',
        queryParameters: <String, dynamic>{'no': no},
      );
      if ('${res['code']}' != '0') {
        debugPrint('[live]直播间信息返回异常: ${res['code']} ${res['message']}');
        return null;
      }
      final dynamic data = res['data'];
      if (data is Map) return data.cast<String, dynamic>();
      return null;
    } catch (e) {
      debugPrint('[live]直播间信息加载失败: $e');
      return null;
    }
  }

  /// 按直播码查直播间(/live/api/shop/getRoomType)
  /// * [no] 直播码/房间号 sn(扫码解析或手动输入的结果),与 getRoomInfo 同一个参数名
  /// * 返回 data 原始字段(sn / name / type / feeds_img / push_link 等,以后端下发为准)
  ///   查询不到或请求失败返回 null,由页面提示而不是带着错误的码进直播间
  static Future<Map<String, dynamic>?> roomType(String no) async {
    final String code = no.trim();
    if (code.isEmpty) return null;
    try {
      final Map<String, dynamic> res = await Request().getRaw(
        '/live/api/shop/getRoomType',
        queryParameters: <String, dynamic>{'no': code},
      );
      if ('${res['code']}' != '0') {
        debugPrint('[live]直播码查询返回异常: ${res['code']} ${res['message']}');
        return null;
      }
      final dynamic data = res['data'];
      // 排查字段用: 打印原始返回(各端下发字段不统一, 展示异常时先看这条日志)
      if (kDebugMode) debugPrint('[live]直播码查询($code): $data');
      if (data is Map) return data.cast<String, dynamic>();
      return null;
    } catch (e) {
      debugPrint('[live]直播码查询失败: $e');
      return null;
    }
  }

  /// 直播拉流地址(/live/api/shop/getPullUrl)
  /// * [no] 房间号 sn(与 getRoomInfo 同一个参数),房间需在直播中
  /// * 返回字段: url(拉流地址, m3u8/HLS, 带 auth_key 时效) / sn(房间号) / name(标题)
  ///   feeds_img(封面) / mute_status(0 非静音) / share_href(分享链接)
  ///   streamer{nickname(主播名), headimg(主播头像)}
  /// * 未开播/已结束或请求失败返回空字符串,由页面回落到其它来源
  static Future<String> pullUrl(String no) async {
    if (no.isEmpty) return '';
    try {
      final Map<String, dynamic> res = await Request().getRaw(
        '/live/api/shop/getPullUrl',
        queryParameters: <String, dynamic>{'no': no},
      );
      if ('${res['code']}' != '0') {
        debugPrint('[live]拉流地址返回异常: ${res['code']} ${res['message']}');
        return '';
      }
      return pullUrlOf(res['data']);
    } catch (e) {
      debugPrint('[live]拉流地址加载失败: $e');
      return '';
    }
  }

  /// 预约直播接口路径(预告房间点"预约直播"时调用, 与 H5 this.$api.sendRequest 的路径一致)
  static const String subscribePath = '/live/api/shop/subscribeRoom';

  /// 预约直播
  /// * [no] 房间号 sn(与 getRoomInfo 同一个参数)
  /// * 成功(接口 code==0)返回 true, 失败/异常返回 false(页面据此外显提示)
  static Future<bool> subscribeRoom(String no) async {
    if (no.isEmpty) return false;
    try {
      final Map<String, dynamic> res = await Request().postRaw(
        subscribePath,
        data: <String, dynamic>{'no': no},
      );
      if ('${res['code']}' != '0') {
        debugPrint('[live]预约直播返回异常: ${res['code']} ${res['message']}');
        return false;
      }
      return true;
    } catch (e) {
      debugPrint('[live]预约直播失败: $e');
      return false;
    }
  }

  /// 关注/取消关注主播(/live/api/shop/collectLive)
  /// * [memberId] 主播会员ID(直播间/列表接口下发的主播会员 id)
  /// * 接口是"切换"语义: 未关注 -> 关注, 已关注 -> 取消关注
  /// * 返回 {ok: 是否成功, message: 提示文案, followed: 关注后的状态(true 已关注)}
  ///   followed 服务端没下发时为 null, 由调用方按"原来取反"处理
  static Future<Map<String, dynamic>> collectLive({required String memberId}) async {
    final String mid = memberId.trim();
    if (mid.isEmpty) {
      return <String, dynamic>{'ok': false, 'message': '缺少主播信息', 'followed': null};
    }
    try {
      final Map<String, dynamic> res = await Request().postRaw(
        '/live/api/shop/collectLive',
        data: <String, dynamic>{'member_id': mid},
      );
      final bool ok = '${res['code']}' == '0';
      String message = '${res['message'] ?? ''}'.trim();
      final dynamic data = res['data'];
      if (data is String && data.trim().isNotEmpty) message = data.trim();
      bool? followed;
      // 关注状态: 服务端可能直接下发 is_collect / is_follow / status 等
      final dynamic src = data is Map ? data : res;
      for (final String key in const <String>[
        'is_collect', 'isCollect', 'is_follow', 'isFollow', 'collect', 'follow', 'collect_status', 'status',
      ]) {
        final dynamic val = src is Map ? src[key] : null;
        if (val == null) continue;
        followed = val == true || '$val' == '1';
        break;
      }
      // 少数端直接返回文案: 关注成功 / 取消关注
      if (data is String) {
        final String s = data.trim().toLowerCase();
        if (s.contains('取消') || s == 'cancel' || s == 'unfollow') followed = false;
        if (s.contains('关注成功') || s == 'follow' || s == 'collect') followed = true;
      }
      if (message.isEmpty) message = ok ? '操作成功' : '操作失败，请稍后再试';
      if (!ok) debugPrint('[live]关注主播返回异常: ${res['code']} ${res['message']}');
      return <String, dynamic>{'ok': ok, 'message': message, 'followed': followed};
    } catch (e) {
      debugPrint('[live]关注主播失败: $e');
      return <String, dynamic>{'ok': false, 'message': '操作失败，请稍后再试', 'followed': null};
    }
  }

  /// 主播会员ID(关注主播时传给 collectLive 的 member_id)
  /// * 各端字段名不统一(member_id / anchor_id / uid 等), 逐个候选取第一个有效值
  /// * 取不到返回空字符串, 由调用方提示"未获取到主播信息"
  static String anchorMemberIdOf(Map<String, dynamic>? room) {
    if (room == null) return '';
    for (final String key in const <String>[
      'member_id', 'memberId', 'anchor_id', 'anchorId', 'anchor_member_id',
      'anchor_member', 'anchor_uid', 'user_id', 'uid',
    ]) {
      final String val = '${room[key] ?? ''}'.trim();
      if (val.isEmpty || val == 'null' || val == '0') continue;
      return val;
    }
    return '';
  }

  /// 是否已关注该主播(接口下发 is_collect / is_follow 等), 没下发返回 null
  static bool? followStatusOf(Map<String, dynamic>? room) {
    if (room == null) return null;
    for (final String key in const <String>[
      'is_collect', 'isCollect', 'is_follow', 'isFollow', 'collect_status', 'collect',
    ]) {
      final dynamic val = room[key];
      if (val == null) continue;
      return val == true || '$val' == '1';
    }
    return null;
  }

  /// 举报直播间(/live/api/shop/complaint)
  /// * [no] 房间号 sn; [type] 举报原因(举报弹窗里选的文案); [content] 举报描述(选填)
  /// * 返回 {ok: 是否成功(code==0), message: 提示文案}
  /// * 提示文案优先取 data(接口直接下发字符串, 与 H5 toast res 一致), 取不到再回落 message
  static Future<Map<String, dynamic>> complaint({
    required String no,
    required String type,
    String content = '',
  }) async {
    if (no.isEmpty || type.isEmpty) {
      return <String, dynamic>{'ok': false, 'message': '缺少举报信息'};
    }
    try {
      final Map<String, dynamic> res = await Request().postRaw(
        '/live/api/shop/complaint',
        data: <String, dynamic>{'no': no, 'type': type, 'content': content},
      );
      final bool ok = '${res['code']}' == '0';
      String message = '${res['message'] ?? ''}'.trim();
      final dynamic data = res['data'];
      if (data is String && data.trim().isNotEmpty) message = data.trim();
      if (message.isEmpty) message = ok ? '举报已提交' : '举报失败，请稍后再试';
      if (!ok) debugPrint('[live]举报返回异常: ${res['code']} ${res['message']}');
      return <String, dynamic>{'ok': ok, 'message': message};
    } catch (e) {
      debugPrint('[live]举报失败: $e');
      return <String, dynamic>{'ok': false, 'message': '举报失败，请稍后再试'};
    }
  }

  /// 是否横屏直播间: 直播间数据里的 type 字段
  /// * 直播间以 getRoomInfo(/live/api/shop/getRoomInfo) 返回的 type 为准:
  ///   'horizontal' 横屏直播; 'vertical' / 空 / 其它值都按竖屏处理(容错大小写与首尾空格)
  static bool isHorizontalRoom(Map<String, dynamic>? room) =>
      '${room?['type'] ?? ''}'.trim().toLowerCase() == 'horizontal';

  /// 从接口返回的 data 中取拉流地址: 字段 url(兼容直接返回字符串)
  static String pullUrlOf(dynamic data) {
    if (data is String) return data.trim();
    if (data is Map) return '${data['url'] ?? ''}'.trim();
    return '';
  }

  /// 直播间带货商品(/live/api/shop/onlineGoods)
  /// * [no] 房间号 sn(与 getRoomInfo 同一个参数), 底部购物弹窗展示用
  /// * [categoryId] 商品分类 id(购物弹窗切分类 tab 时带上, 由后端按分类返回; 空串表示「全部」不传)
  /// * 返回 data.list 商品数组(元素已按 [goodsItem] 归一化); 无数据/失败返回空列表
  static Future<List<Map<String, dynamic>>> onlineGoods(String no, {String categoryId = ''}) async {
    if (no.isEmpty) return const <Map<String, dynamic>>[];
    try {
      // POST: 参数走请求体(与直播其它接口 subscribeRoom / complaint 等一致)
      final Map<String, dynamic> body = <String, dynamic>{'no': no};
      // 分类筛选: 只在选中具体分类时带(「全部」= 空串, 不带参数, 按接口默认返回全部)
      final String cid = categoryId.trim();
      if (cid.isNotEmpty && cid != '0') body['category_id'] = cid;
      final Map<String, dynamic> res = await Request().postRaw(
        '/live/api/shop/onlineGoods',
        data: body,
      );
      if ('${res['code']}' != '0') {
        debugPrint('[live]带货商品返回异常: ${res['code']} ${res['message']}');
        return const <Map<String, dynamic>>[];
      }
      final dynamic data = res['data'];
      final dynamic list = data is Map ? (data['list'] ?? data['data']) : data;
      if (list is! List) return const <Map<String, dynamic>>[];
      // 排查字段用: 打印第一条原始商品(不同房间下发的字段名可能不一样, 展示异常时先看这条日志)
      if (kDebugMode && list.isNotEmpty) debugPrint('[live]带货商品样例: ${list.first}');
      final List<Map<String, dynamic>> items = <Map<String, dynamic>>[];
      for (final dynamic raw in list) {
        final Map<String, dynamic>? item = goodsItem(raw);
        if (item != null) items.add(item);
      }
      // 排查分类筛选用: 打印请求参数与返回条数(切 tab 列表没变化时先看这条)
      if (kDebugMode) {
        debugPrint('[live]带货商品 no=$no category_id=${cid.isEmpty ? '(全部)' : cid} -> ${items.length} 条');
      }
      return items;
    } catch (e) {
      debugPrint('[live]带货商品加载失败: $e');
      return const <Map<String, dynamic>>[];
    }
  }

  /// 商品数据归一化(讲解中商品 socket goods 与带货列表共用)
  /// * 入参可能是单个商品 / 商品数组(取第一条) / 被 {goods:{...}} 再包一层
  /// * 输出字段: id / title / image(已补全域名) / tips / price / mprice / saleNum(热卖数, 兼容 hot)
  ///   各端字段命名不统一, 逐个多候选兼容; 无有效内容时返回 null
  static Map<String, dynamic>? goodsItem(dynamic raw) {
    if (raw is List) {
      for (final dynamic one in raw) {
        final Map<String, dynamic>? item = goodsItem(one);
        if (item != null) return item;
      }
      return null;
    }
    if (raw is! Map) return null;
    Map<dynamic, dynamic> goods = raw;
    // 部分返回会把商品再包一层: {goods: {...}} / {info: {...}}
    for (final String key in const <String>['goods', 'good', 'info', 'goods_info', 'goodsInfo', 'sku']) {
      final dynamic inner = raw[key];
      if (inner is Map) {
        goods = inner;
        break;
      }
      if (inner is List && inner.isNotEmpty && inner.first is Map) {
        goods = inner.first as Map;
        break;
      }
    }
    // 依次取多候选字段, 返回第一个非空值(URL 与超长串不会出现在文案里, 解析时直接跳过)
    String text(List<String> keys, {int maxLen = 120}) {
      for (final String key in keys) {
        final String val = '${goods[key] ?? ''}'.trim();
        if (val.isEmpty || val == 'null' || val.contains('http')) continue;
        return val.length > maxLen ? val.substring(0, maxLen) : val;
      }
      return '';
    }

    // 金额/数量: 只取数字部分
    // * 接口有的带 ¥ 前缀、单位或多余文案, 原样展示会撑爆卡片布局(甚至 RenderFlex overflow)
    String num(List<String> keys) {
      for (final String key in keys) {
        final String val = '${goods[key] ?? ''}'.trim();
        if (val.isEmpty || val == 'null') continue;
        final RegExpMatch? match = RegExp(r'\d+(?:\.\d+)?').firstMatch(val);
        if (match != null) return match.group(0)!;
      }
      return '';
    }

    // 商品id: 跳详情(/api/goodssku/detail)与下单用的是商城商品id, 即 goods_id
    // * 接口同时下发两个 id: id(直播商品记录主键, 如 897) 与 goods_id(商城商品id, 如 38)
    // * 拿 id 去查详情会查到别的商品(后端返回 code != 0), 所以 goods_id 优先
    final String liveId = text(const <String>['id'], maxLen: 32);
    final String goodsId = text(const <String>['goods_id', 'goodsId'], maxLen: 32);
    final String id = goodsId.isNotEmpty ? goodsId : liveId;
    final String title = text(const <String>['title', 'name', 'goods_name', 'goodsName', 'goods_title']);
    final String tips = text(const <String>['tips', 'sale_tips', 'sales_tips', 'sale_text'], maxLen: 40);
    final String price = num(const <String>['price', 'goods_price', 'shop_price', 'sale_price', 'sell_price']);
    String mprice = num(const <String>['mprice', 'market_price', 'line_price', 'original_price', 'old_price']);
    // 划线价为 0 视为没下发(接口 market_price 常见 0), 否则卡片上会显示一个 "¥0"
    // * 这里不能用 num.tryParse: num 是上面那个取数字的局部函数, 会遮住 num 类型
    if ((double.tryParse(mprice) ?? 0) <= 0) mprice = '';
    // 热卖数: 服务端字段命名不统一, hot 系(讲解中商品常用)排在销量系之后兜底
    final String saleNum = num(const <String>[
      'sale_num', 'sales_num', 'sales', 'sale', 'sold', 'sale_count',
      'hot', 'hot_num', 'hotNum', 'hot_count', 'hotCount', 'hot_sale', 'hotSale',
    ]);
    // 图片: 候选字段逐个用 [imageOf] 取第一张(兼容多图拼接串/图片数组)
    String image = '';
    for (final String key in const <String>[
      'image', 'images', 'goods_image', 'goods_images', 'goods_img', 'cover', 'logo', 'thumb', 'pic', 'img',
    ]) {
      image = imageOf(goods[key]);
      if (image.isNotEmpty) break;
    }
    // 标题/图片/id 都取不到视为无效数据(避免渲染空卡片)
    if (id.isEmpty && title.isEmpty && image.isEmpty) return null;
    return <String, dynamic>{
      // 商城商品id(跳详情/下单用这个): 没有 goods_id 时才与 live_id 相同
      'id': id,
      'goods_id': goodsId,
      // 商品分类id(购物车弹窗按分类 tab 筛选时用; 接口没下发为空串, 此时弹窗不过滤)
      'category_id': text(const <String>['category_id', 'cate_id', 'cid', 'categoryId'], maxLen: 32),
      // 直播商品记录主键(如 897): 只作兜底/排查用, 不能拿去查商品详情
      'live_id': liveId,
      'title': title,
      'image': image,
      'tips': tips,
      'price': price,
      'mprice': mprice,
      'saleNum': saleNum,
    };
  }

  /// POST 取 data: 统一判 code / 异常兜底 / 日志, 失败返回 null
  /// * H5 的 $H.post 也是把业务数据放在 data 里返回, 这里统一拆出来
  /// * 活动类接口(福袋/红包/签到/集章)会用非 0 code 表达业务状态(如未参与时
  ///   code=-10001 "您还未参与红包活动"), 但 data 里依然下发了 type: 这时按业务
  ///   数据返回, 由弹窗按 type 展示, 不能当成加载失败(否则红包弹窗打不开)
  static Future<Map<String, dynamic>?> _postData(String path, Map<String, dynamic> data) async {
    try {
      final Map<String, dynamic> res = await Request().postRaw(path, data: data);
      final dynamic result = res['data'];
      if ('${res['code']}' != '0') {
        final String bizType = result is Map ? '${result['type'] ?? ''}'.trim() : '';
        if (bizType.isNotEmpty) {
          debugPrint('[live]$path 业务码 ${res['code']}(${res['message']}), 按 data.type=$bizType 处理');
          return (result as Map).cast<String, dynamic>();
        }
        debugPrint('[live]$path 返回异常: ${res['code']} ${res['message']}');
        return null;
      }
      if (result is Map) return result.cast<String, dynamic>();
      return null;
    } catch (e) {
      debugPrint('[live]$path 请求失败: $e');
      return null;
    }
  }

  /// 福袋活动状态查询(/live/api/shop/luckybag)
  /// * [gameId] activity 下发的 game_id
  /// * 返回 data 字段: type(ing-nojoin 进行中未参与 / ing-join 进行中已参与
  ///   / end-nojoin 已结束未参与 / end-noaward 已结束未中奖 / end-award 已结束中奖)
  ///   joinnum(参与人数) / time(剩余秒数) / award{num, type_name}(中奖结果)
  /// * 失败或无数据返回 null,由页面提示而不是弹空窗
  static Future<Map<String, dynamic>?> luckybagDetail(String gameId) async {
    if (gameId.isEmpty) return null;
    return _postData('/live/api/shop/luckybag', <String, dynamic>{'game_id': gameId});
  }

  /// 红包活动状态查询(/live/api/shop/hongbao)
  /// * 返回 data: type(ing-nojoin 未参与, 其余为已参与/已结束) + 活动对象(info 等)
  static Future<Map<String, dynamic>?> hongbaoDetail(String gameId) async {
    if (gameId.isEmpty) return null;
    return _postData('/live/api/shop/hongbao', <String, dynamic>{'game_id': gameId});
  }

  /// 开红包(/live/api/shop/hongbaoJoin)
  /// * 返回 data: type(award 中奖 / join-award 参与即中奖 / noaward 未中奖 / end 已结束)
  ///   award_typename(单位,如"元") / data{award_num}(金额) / no_winning_desc(未中奖文案)
  static Future<Map<String, dynamic>?> hongbaoJoin(String gameId) async {
    if (gameId.isEmpty) return null;
    return _postData('/live/api/shop/hongbaoJoin', <String, dynamic>{'game_id': gameId});
  }

  /// 签到活动状态查询(/live/api/shop/sign)
  /// * 返回 data: type(ing-nojoin 未签到 / ing-join 已签到 / award 已领奖
  ///   / end-nojoin / end-join / end 已结束) + title 标题 + notice 说明 + time 剩余秒数
  static Future<Map<String, dynamic>?> signDetail(String gameId) async {
    if (gameId.isEmpty) return null;
    return _postData('/live/api/shop/sign', <String, dynamic>{'game_id': gameId});
  }

  /// 立即签到(/live/api/shop/signJoin)
  /// * 返回 data: type 签到后的状态(award 签到成功 / ing-join 已签到), 失败返回 null
  static Future<Map<String, dynamic>?> signJoin(String gameId) async {
    if (gameId.isEmpty) return null;
    return _postData('/live/api/shop/signJoin', <String, dynamic>{'game_id': gameId});
  }

  /// 集章活动信息(/live/api/shop/stamp)
  /// * 返回 data: title 标题 / msg 说明 / imgs 图片 / award 奖励文案
  static Future<Map<String, dynamic>?> stampDetail(String gameId) async {
    if (gameId.isEmpty) return null;
    return _postData('/live/api/shop/stamp', <String, dynamic>{'game_id': gameId});
  }

  /// 集章上报(/live/api/shop/sendStampLog): 收集奖章
  /// * [roomId] 直播间 sn; [stampId] 集章活动 id(game_id)
  /// * 接口只要 code==0 即算成功
  static Future<bool> stampLog({required String roomId, required String stampId}) async {
    if (stampId.isEmpty) return false;
    try {
      final Map<String, dynamic> res = await Request().postRaw(
        '/live/api/shop/sendStampLog',
        data: <String, dynamic>{'room_id': roomId, 'stamp_id': stampId},
      );
      if ('${res['code']}' != '0') {
        debugPrint('[live]集章上报返回异常: ${res['code']} ${res['message']}');
        return false;
      }
      return true;
    } catch (e) {
      debugPrint('[live]集章上报失败: $e');
      return false;
    }
  }

  /// 活动中奖名单(福袋 luckybagWinlist / 红包 hongbaoWinlist)
  /// * [type] luckybag 福袋 / hongbao 红包; [gameId] 活动 id; [page] 页码(从1开始)
  /// * 返回 {count: 总人数, list: [{nickname, headimg, awardNum, awardTypeName}]}
  /// * 失败返回空结果,由弹窗展示空态
  static Future<Map<String, dynamic>> activityWinList({
    required String gameId,
    required String type,
    int page = 1,
    int pageSize = 10,
  }) async {
    final Map<String, dynamic> empty = <String, dynamic>{'count': 0, 'list': <Map<String, dynamic>>[]};
    if (gameId.isEmpty) return empty;
    final Map<String, dynamic>? data = await _postData(
      type == 'hongbao' ? '/live/api/shop/hongbaoWinlist' : '/live/api/shop/luckybagWinlist',
      <String, dynamic>{'game_id': gameId, 'page': page, 'page_size': pageSize},
    );
    if (data == null) return empty;
    final dynamic raw = data['list'] ?? data['data'];
    final List<Map<String, dynamic>> list = <Map<String, dynamic>>[];
    if (raw is List) {
      for (final dynamic one in raw) {
        if (one is! Map) continue;
        list.add(<String, dynamic>{
          'nickname': '${one['nickname'] ?? one['user_name'] ?? one['name'] ?? '神秘观众'}',
          'headimg': fixImage(imageOf(one['headimg'] ?? one['head_img'] ?? one['avatar'])),
          'awardNum': '${one['award_num'] ?? one['num'] ?? ''}'.trim(),
          'awardTypeName': '${one['award_typename'] ?? one['type_name'] ?? ''}'.trim(),
        });
      }
    }
    return <String, dynamic>{'count': intOf(data['count'] ?? data['total']), 'list': list};
  }

  /// 集章信息归一化(stamp_award 推送 / stamp 接口返回)
  /// * 输出: title 标题 / msg 说明 / award 奖励文案 / imgs 图片(已补域名)
  static Map<String, dynamic> stampInfoItem(dynamic raw) {
    if (raw is! Map) return <String, dynamic>{};
    String text(List<String> keys, {int maxLen = 200}) {
      for (final String key in keys) {
        final String val = '${raw[key] ?? ''}'.trim();
        if (val.isEmpty || val == 'null') continue;
        return val.length > maxLen ? val.substring(0, maxLen) : val;
      }
      return '';
    }
    return <String, dynamic>{
      'title': text(const <String>['title', 'name'], maxLen: 24),
      'msg': text(const <String>['msg', 'notice', 'desc', 'content']),
      'award': text(const <String>['award', 'award_desc'], maxLen: 60),
      'imgs': fixImage(imageOf(raw['imgs'] ?? raw['img'] ?? raw['image'])),
    };
  }

  /// 活动列表归一化(socket activity 下发, 与H5 bagInfor 一致)
  /// * 入参支持数组, 或 {list:[...]} / {activity:[...]} / {data:[...]} 包一层
  /// * 条目输出字段见 [activityItem]; 解析不出的条目直接丢弃
  static List<Map<String, dynamic>> activityItems(dynamic raw) {
    List<dynamic> list = const <dynamic>[];
    if (raw is List) {
      list = raw;
    } else if (raw is Map) {
      for (final String key in const <String>['list', 'activity', 'data', 'items']) {
        final dynamic inner = raw[key];
        if (inner is List) {
          list = inner;
          break;
        }
      }
    }
    final List<Map<String, dynamic>> items = <Map<String, dynamic>>[];
    for (final dynamic one in list) {
      final Map<String, dynamic>? item = activityItem(one);
      if (item != null) items.add(item);
    }
    return items;
  }

  /// 单个活动归一化
  /// * 输出字段: type(luckybag 福袋 / hongbao 红包 / stamp 集章 / sign 签到) / gameId(活动id)
  ///   time(剩余秒数) / joinNum(参与人数) / title(奖励标题) / awardNum(奖励数量)
  ///   awardTypeName(奖励单位,如"积分") / awardType(奖励类型,score 等)
  ///   bagNum(福袋个数) / joinContent(参与口令: 需要发送的评论内容)
  /// * 详情字段多数端放在 info 里(对象或数组), 少数端平铺; 活动类型和 id 都取不到返回 null
  static Map<String, dynamic>? activityItem(dynamic raw) {
    if (raw is! Map) return null;
    final Map<dynamic, dynamic> data = raw;
    Map<dynamic, dynamic> info = data;
    final dynamic rawInfo = data['info'];
    if (rawInfo is Map) {
      info = rawInfo;
    } else if (rawInfo is List && rawInfo.isNotEmpty && rawInfo.first is Map) {
      info = rawInfo.first as Map;
    }
    // 文案: 取第一个非空值(超长串截断, 避免脏数据撑爆弹窗)
    String text(Map<dynamic, dynamic> src, List<String> keys, {int maxLen = 40}) {
      for (final String key in keys) {
        final String val = '${src[key] ?? ''}'.trim();
        if (val.isEmpty || val == 'null') continue;
        return val.length > maxLen ? val.substring(0, maxLen) : val;
      }
      return '';
    }

    final String type = text(data, const <String>['type', 'activity_type', 'event'], maxLen: 16).toLowerCase();
    final String gameId = text(data, const <String>['game_id', 'gameId', 'activity_id'], maxLen: 32);
    if (type.isEmpty && gameId.isEmpty) return null;
    return <String, dynamic>{
      'type': type,
      'gameId': gameId,
      'time': numOf(data, const <String>['time', 'times', 'remain', 'remain_time', 'left_time', 'countdown']),
      'joinNum': numOf(data, const <String>['joinnum', 'join_num', 'joinNum', 'join_count', 'join_num_count']),
      'title': text(info, const <String>['title', 'award_title', 'award_name'], maxLen: 24),
      'awardNum': text(info, const <String>['award_num', 'awardNum'], maxLen: 12),
      'awardTypeName': text(info, const <String>['award_typename', 'award_type_name', 'awardTypeName'], maxLen: 12),
      'awardType': text(info, const <String>['award_type', 'awardType'], maxLen: 16),
      'bagNum': text(info, const <String>['num', 'bag_num', 'bagNum'], maxLen: 12),
      'joinContent': text(info, const <String>['join_content', 'joinContent', 'keyword', 'content'], maxLen: 40),
    };
  }

  /// 取整数(兼容 12 / "12" / "12人")
  static int intOf(dynamic val) {
    if (val == null) return 0;
    if (val is num) return val.toInt();
    final RegExpMatch? match = RegExp(r'\d+').firstMatch('$val');
    return match == null ? 0 : int.parse(match.group(0)!);
  }

  /// 从 map 的多候选字段里取第一个数字(字段为空则看下一个)
  static int numOf(Map<dynamic, dynamic> src, List<String> keys) {
    for (final String key in keys) {
      final dynamic val = src[key];
      if (val == null) continue;
      if ('$val'.trim().isEmpty) continue;
      return intOf(val);
    }
    return 0;
  }

  /// 直播状态文案(与接口 status 枚举对应)
  /// * 0 直播预告 / 1 直播中 / 2 直播暂停中 / 3 直播已结束
  static const Map<int, String> statusTexts = <int, String>{
    0: '直播预告',
    1: '直播中',
    2: '直播暂停中',
    3: '直播已结束',
  };

  /// 直播间状态: 取不到按"直播中"处理(兼容无该字段的接口/Mock 数据)
  static int statusOf(Map<String, dynamic>? room) {
    if (room == null) return 1;
    return int.tryParse('${room['status'] ?? 1}') ?? 1;
  }

  /// 直播间状态文案: 优先用接口 status_name,取不到再按 status 映射
  static String statusName(Map<String, dynamic>? room) {
    final String name = '${room?['status_name'] ?? ''}'.trim();
    if (name.isNotEmpty) return name;
    return statusTexts[statusOf(room)] ?? '直播中';
  }

  /// 从各种下发格式里取第一张图片地址
  /// * 兼容: 单图字符串 / "url1,url2,..." 多图拼接串 / 图片数组 / [{url:...}] 数组套对象 / {url:...}
  /// * 多图拼接串必须只取第一张: 整串当 URL 请求会 404(接口就是 "url1,url2,..." 这种下发)
  static String imageOf(dynamic val) {
    if (val is Map) {
      for (final String key in const <String>['url', 'image', 'src', 'path', 'img', 'pic']) {
        final String one = imageOf(val[key]);
        if (one.isNotEmpty) return one;
      }
      return '';
    }
    if (val is List) {
      for (final dynamic one in val) {
        final String url = imageOf(one);
        if (url.isNotEmpty) return url;
      }
      return '';
    }
    final String raw = '${val ?? ''}'.trim();
    if (raw.isEmpty || raw == 'null') return '';
    // 逗号/空格/竖线分隔的多图串: 取第一个合法地址
    for (final String part in raw.split(RegExp(r'[,\s|]+'))) {
      final String url = part.trim();
      if (url.startsWith('http')) return fixImage(url);
    }
    return fixImage(raw);
  }

  /// 图片地址补全: 相对路径拼接图片域名
  static String fixImage(dynamic val) {
    final String url = '${val ?? ''}'.trim();
    if (url.isEmpty) return '';
    if (url.startsWith('http')) return url;
    return '${Config.imgDomain}/$url';
  }

  /// 看播记录(/live/api/shop/getLiveLog, 与 H5 pages_tool/watching_record 同一接口)
  /// * [page] 页码(从 1 开始); [pageSize] 每页条数; [keyword] 搜索直播标题,为空不传
  /// * 返回 {list: 记录列表(已用 [liveLogItem] 归一化), count: 总数, pageCount: 总页数, hasMore: 是否还有下一页}
  /// * 失败/无数据返回空结果(list 为空),页面据此显示空态
  static Future<Map<String, dynamic>> liveLog({int page = 1, int pageSize = 10, String keyword = ''}) async {
    try {
      final Map<String, dynamic> query = <String, dynamic>{'page': page, 'page_size': pageSize};
      final String kw = keyword.trim();
      if (kw.isNotEmpty) query['keyword'] = kw;
      final Map<String, dynamic> res = await Request().getRaw(
        '/live/api/shop/getLiveLog',
        queryParameters: query,
      );
      if ('${res['code']}' != '0') {
        debugPrint('[live]看播记录返回异常: ${res['code']} ${res['message']}');
        return _emptyLiveLog();
      }
      final dynamic data = res['data'];
      // 该接口可能直接返回数组,也可能包成 {list: [...]}
      final dynamic raw = data is Map ? (data['list'] ?? data['data']) : data;
      if (raw is! List) return _emptyLiveLog();
      final List<Map<String, dynamic>> list = <Map<String, dynamic>>[];
      for (final dynamic one in raw) {
        final Map<String, dynamic>? item = liveLogItem(one);
        if (item != null) list.add(item);
      }
      final int pageCount = data is Map ? intOf(data['page_count'] ?? data['pageCount']) : 0;
      return <String, dynamic>{
        'list': list,
        'count': data is Map ? intOf(data['count'] ?? data['total']) : list.length,
        'pageCount': pageCount,
        'hasMore': pageCount > 0 ? page < pageCount : list.length >= pageSize,
      };
    } catch (e) {
      debugPrint('[live]看播记录加载失败: $e');
      return _emptyLiveLog();
    }
  }

  /// 看播记录空结果(请求失败/无数据时返回,避免页面判空)
  static Map<String, dynamic> _emptyLiveLog() => <String, dynamic>{
        'list': <Map<String, dynamic>>[],
        'count': 0,
        'pageCount': 0,
        'hasMore': false,
      };

  /// 看播记录单条归一化
  /// * 输出字段: room_id(直播间号,进直播间当 sn 用) / name(直播标题) / feeds_img(封面)
  ///   anchor_img(主播头像) / anchor_name(主播昵称) / start_time / end_time(秒级时间戳或时间串)
  ///   finished(是否完播) / award_name / award_num(完播奖励)
  /// * 房间号/标题/封面都取不到视为脏数据,直接丢弃
  static Map<String, dynamic>? liveLogItem(dynamic raw) {
    if (raw is! Map) return null;
    final String name = '${raw['name'] ?? raw['title'] ?? raw['room_name'] ?? ''}'.trim();
    final String cover = imageOf(raw['feeds_img'] ?? raw['cover'] ?? raw['image']);
    final String roomId = '${raw['room_id'] ?? raw['roomId'] ?? raw['sn'] ?? raw['roomid'] ?? ''}'.trim();
    if (roomId.isEmpty && name.isEmpty && cover.isEmpty) return null;
    return <String, dynamic>{
      'room_id': roomId,
      'name': name,
      'feeds_img': cover,
      'anchor_img': imageOf(raw['anchor_img'] ?? raw['anchorImg'] ?? raw['headimg']),
      'anchor_name': '${raw['anchor_name'] ?? raw['anchorName'] ?? raw['nickname'] ?? ''}'.trim(),
      'start_time': '${raw['start_time'] ?? ''}'.trim(),
      'end_time': '${raw['end_time'] ?? ''}'.trim(),
      'finished': isFinished(raw),
      'award_name': '${raw['award_name'] ?? ''}'.trim(),
      'award_num': '${raw['award_num'] ?? ''}'.trim(),
    };
  }

  /// 是否完播: status / is_finish 字段,兼容 1 / '1' / true / yes(与 H5 isFinished 一致)
  static bool isFinished(Map<dynamic, dynamic> raw) {
    dynamic val = raw['status'];
    if (val == null || '$val'.trim().isEmpty || '$val' == 'null') val = raw['is_finish'] ?? raw['isFinish'];
    if (val == null) return false;
    if (val is bool) return val;
    if (val is num) return val == 1;
    final String s = '$val'.trim().toLowerCase();
    return s == '1' || s == 'true' || s == 'y' || s == 'yes';
  }

  /// 看播记录时间格式化: 兼容秒级/毫秒级时间戳与时间字符串,截取到分钟(与 H5 formatTime 一致)
  /// * 解析不了时原样返回,方便排查后端下发格式
  static String formatRecordTime(dynamic val) {
    final String raw = '${val ?? ''}'.trim();
    if (raw.isEmpty) return '';
    DateTime date;
    if (RegExp(r'^\d+$').hasMatch(raw)) {
      int ts = int.tryParse(raw) ?? 0;
      if (ts <= 0) return '';
      // 秒级时间戳补成毫秒
      if (ts < 100000000000) ts *= 1000;
      date = DateTime.fromMillisecondsSinceEpoch(ts);
    } else {
      final DateTime? parsed = DateTime.tryParse(raw);
      // 不是合法时间串(如后端直接下发"已结束"之类)就原样展示
      if (parsed == null) return raw;
      date = parsed;
    }
    String pad(int n) => n < 10 ? '0$n' : '$n';
    return '${date.year}-${pad(date.month)}-${pad(date.day)} ${pad(date.hour)}:${pad(date.minute)}';
  }

  /// 看播详情里的记录列表(/live/api/shop/getLiveLogList)
  /// * [roomId] 直播间号(列表页的 room_id); [type] hongbao 红包 / sign 签到 / luckybag 福袋
  /// * 返回记录数组(元素已用 [liveLogListItem] 归一化); 无数据/失败返回空数组
  static Future<List<Map<String, dynamic>>> liveLogList({required String roomId, required String type}) async {
    final String rid = roomId.trim();
    final String t = type.trim();
    if (rid.isEmpty || t.isEmpty) return const <Map<String, dynamic>>[];
    try {
      final Map<String, dynamic> res = await Request().getRaw(
        '/live/api/shop/getLiveLogList',
        queryParameters: <String, dynamic>{'room_id': rid, 'type': t},
      );
      if ('${res['code']}' != '0') {
        debugPrint('[live]看播记录明细返回异常($t): ${res['code']} ${res['message']}');
        return const <Map<String, dynamic>>[];
      }
      final dynamic data = res['data'];
      // 该接口可能直接返回数组,也可能包成 {list: [...]}
      final dynamic raw = data is Map ? (data['list'] ?? data['data']) : data;
      if (raw is! List) return const <Map<String, dynamic>>[];
      final List<Map<String, dynamic>> list = <Map<String, dynamic>>[];
      for (final dynamic one in raw) {
        final Map<String, dynamic>? item = liveLogListItem(one);
        if (item != null) list.add(item);
      }
      return list;
    } catch (e) {
      debugPrint('[live]看播记录明细加载失败($t): $e');
      return const <Map<String, dynamic>>[];
    }
  }

  /// 看播记录明细单条归一化
  /// * 输出字段: title(标题,如"开播红包"/"签到第 1 天") / typeName(奖励类型,如"现金红包")
  ///   time(时间,原样或格式化到分钟) / num(奖励数量,空表示未下发)
  /// * 标题/时间/数量都取不到视为脏数据,直接丢弃
  static Map<String, dynamic>? liveLogListItem(dynamic raw) {
    if (raw is! Map) return null;
    final String title = '${raw['title'] ?? raw['name'] ?? raw['day'] ?? ''}'.trim();
    final String timeText = formatRecordTime(raw['create_time'] ?? raw['time'] ?? raw['add_time']);
    final String typeName = '${raw['award_type_name'] ?? raw['type_name'] ?? raw['award_name'] ?? ''}'.trim();
    final String awardNum = '${raw['award_num'] ?? raw['amount'] ?? raw['num'] ?? ''}'.trim();
    if (title.isEmpty && timeText.isEmpty && awardNum.isEmpty) return null;
    return <String, dynamic>{
      'title': title,
      'time': timeText,
      'typeName': typeName,
      'num': awardNum,
    };
  }

  /// 看播时间段文案: 起 ~ 止(两端任一为空时只显示有值的那一端)
  static String recordTimeText(Map<String, dynamic> item) {
    final String start = formatRecordTime(item['start_time']);
    final String end = formatRecordTime(item['end_time']);
    if (start.isEmpty) return end;
    if (end.isEmpty) return start;
    return '$start ~ $end';
  }
}
