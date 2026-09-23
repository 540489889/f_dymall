/// 直播相关接口
library;

import 'package:flutter/foundation.dart' show debugPrint, kDebugMode;

import '../config/index.dart';
import '../utils/request.dart';

class LiveApi {
  /// 直播列表(/live/api/shop/roomPage)
  /// * [page] 页码(从 1 开始); [pageSize] 每页条数
  /// * [status] 列表筛选: 1 直播中 / 2 直播预告; 不传为全部(接口默认)
  /// * 返回 {list: 房间列表(已用 [roomItem] 归一化), count: 总数, pageCount: 总页数, hasMore: 是否还有下一页}
  /// * 失败/无数据返回空结果(list 为空),页面据此显示空态
  static Future<Map<String, dynamic>> roomPage({int page = 1, int pageSize = 10, int? status}) async {
    try {
      final Map<String, dynamic> query = <String, dynamic>{'page': page, 'page_size': pageSize};
      // 只传了筛选才带上 status(不传时按接口默认: 全部)
      if (status != null) query['status'] = status;
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
    };
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
  /// * 返回 data.list 商品数组(元素已按 [goodsItem] 归一化); 无数据/失败返回空列表
  static Future<List<Map<String, dynamic>>> onlineGoods(String no) async {
    if (no.isEmpty) return const <Map<String, dynamic>>[];
    try {
      final Map<String, dynamic> res = await Request().getRaw(
        '/live/api/shop/onlineGoods',
        queryParameters: <String, dynamic>{'no': no},
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

    final String id = text(const <String>['id', 'goods_id', 'goodsId', 'sku_id'], maxLen: 32);
    final String title = text(const <String>['title', 'name', 'goods_name', 'goodsName', 'goods_title']);
    final String tips = text(const <String>['tips', 'sale_tips', 'sales_tips', 'sale_text'], maxLen: 40);
    final String price = num(const <String>['price', 'goods_price', 'shop_price', 'sale_price', 'sell_price']);
    final String mprice = num(const <String>['mprice', 'market_price', 'line_price', 'original_price', 'old_price']);
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
      'id': id,
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
}
