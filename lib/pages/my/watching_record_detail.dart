/// 看播详情(看播记录 -> 点击列表进)
/// * 入参(arguments): 列表页那条记录(room_id / feeds_img / name / anchor_name / anchor_img
///   start_time / end_time / finished / award_name / award_num),与 H5 detail.vue 从列表带入一致
/// * 顶部: 直播间封面 + 完播状态 + 标题 + 主播 + 时间段 + 完播奖励
/// * 面板: 红包记录 / 签到记录 / 福袋记录 三个 tab,数据来自 /live/api/shop/getLiveLogList
library;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../api/live.dart';
import '../../behavior/custom_scroll_behavior.dart';
import '../../components/loading.dart';

class WatchingRecordDetailPage extends StatefulWidget {
  const WatchingRecordDetailPage({super.key});

  @override
  State<WatchingRecordDetailPage> createState() => _WatchingRecordDetailPageState();
}

class _WatchingRecordDetailPageState extends State<WatchingRecordDetailPage> {
  /// tab 定义: name 展示名 / key 接口 type(红包 / 签到 / 福袋)
  static const List<Map<String, String>> tabs = <Map<String, String>>[
    <String, String>{'name': '红包记录', 'key': 'hongbao'},
    <String, String>{'name': '签到记录', 'key': 'sign'},
    <String, String>{'name': '福袋记录', 'key': 'luckybag'},
  ];

  /// 列表页带入的直播间信息
  Map<String, dynamic> roomInfo = <String, dynamic>{};
  int tabIndex = 0;
  /// 每个 tab 的记录(切回来直接用缓存,不再重复请求)
  final Map<String, List<Map<String, dynamic>>> recordData = <String, List<Map<String, dynamic>>>{};
  /// 已请求过的 tab(空结果也只请求一次)
  final Set<String> loaded = <String>{};
  bool loading = false;

  @override
  void initState() {
    super.initState();
    final dynamic args = Get.arguments;
    if (args is Map) roomInfo = args.cast<String, dynamic>();
    loadRecords();
  }

  /// 当前 tab 的记录
  List<Map<String, dynamic>> get currentList =>
      recordData[tabs[tabIndex]['key']] ?? const <Map<String, dynamic>>[];

  /// 拉当前 tab 的记录(room_id + type)
  Future<void> loadRecords() async {
    final String key = tabs[tabIndex]['key']!;
    if (loaded.contains(key)) return;
    setState(() => loading = true);
    final List<Map<String, dynamic>> list = await LiveApi.liveLogList(
      roomId: '${roomInfo['room_id'] ?? ''}',
      type: key,
    );
    if (!mounted) return;
    setState(() {
      recordData[key] = list;
      loaded.add(key);
      loading = false;
    });
  }

  void switchTab(int index) {
    if (tabIndex == index) return;
    setState(() => tabIndex = index);
    loadRecords();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: <Widget>[
          // 滚动条关掉(与项目其它列表一致)
          ScrollConfiguration(
            behavior: CustomScrollBehavior().copyWith(scrollbars: false),
            child: ListView(
            padding: EdgeInsets.zero,
            children: <Widget>[
              _buildRoomHeader(),
              // 面板上移 16 盖住封面底部
              // * 不能用负 margin: Container 的 margin 内部走 Padding,
              //   RenderPadding 有 assert(padding.isNonNegative), debug 下会直接断言失败红屏
              Transform.translate(
                offset: const Offset(0.0, -16.0),
                child: _buildPanel(),
              ),
            ],
            ),
          ),
          // 返回按钮: 悬浮在封面上(与 H5 的半透明圆形返回键一致)
          Positioned(
            top: MediaQuery.of(context).padding.top + 4.0,
            left: 12.0,
            child: GestureDetector(
              onTap: () => Get.back(),
              child: Container(
                width: 32.0,
                height: 32.0,
                decoration: BoxDecoration(
                  color: const Color(0x40000000),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0x40FFFFFF), width: 0.5),
                ),
                child: const Icon(Icons.arrow_back_ios_new, size: 15.0, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 顶部直播间信息(封面 + 遮罩 + 完播状态 + 标题 + 主播 + 时间 + 完播奖励)
  Widget _buildRoomHeader() {
    final bool finished = roomInfo['finished'] == true;
    final String cover = '${roomInfo['feeds_img'] ?? ''}';
    final String name = '${roomInfo['name'] ?? ''}'.trim();
    final String anchorName = '${roomInfo['anchor_name'] ?? ''}'.trim();
    final String anchorImg = '${roomInfo['anchor_img'] ?? ''}';
    final String timeText = LiveApi.recordTimeText(roomInfo);
    final String awardName = '${roomInfo['award_name'] ?? ''}'.trim();
    final String awardNum = '${roomInfo['award_num'] ?? ''}'.trim();
    return SizedBox(
      height: 260.0,
      width: double.infinity,
      child: Stack(
        children: <Widget>[
          Positioned.fill(
            child: cover.isEmpty
                ? Container(color: const Color(0xFFF2F3F5))
                : CachedNetworkImage(
                    imageUrl: cover,
                    fit: BoxFit.cover,
                    placeholder: (BuildContext c, String u) => Container(color: const Color(0xFFF2F3F5)),
                    errorWidget: (BuildContext c, String u, Object e) => Container(color: const Color(0xFFF2F3F5)),
                  ),
          ),
          // 底部渐变遮罩: 亮色封面下白色文字也能看清
          Positioned.fill(
            child: const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: <Color>[Color(0x00000000), Color(0xB3000000)],
                ),
              ),
            ),
          ),
          Positioned(
            left: 16.0,
            right: 16.0,
            bottom: 30.0,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                // 完播 / 未完播
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 3.0),
                  decoration: BoxDecoration(
                    color: finished ? const Color(0xFF07C160) : const Color(0x73000000),
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                  child: Text(
                    finished ? '完播' : '未完播',
                    style: const TextStyle(fontSize: 11.0, color: Colors.white),
                  ),
                ),
                const SizedBox(height: 10.0),
                Text(
                  name.isEmpty ? '直播间' : name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 18.0, fontWeight: FontWeight.w600, color: Colors.white),
                ),
                const SizedBox(height: 10.0),
                Row(
                  children: <Widget>[
                    ClipOval(
                      child: anchorImg.isEmpty
                          ? Container(
                              width: 22.0,
                              height: 22.0,
                              color: const Color(0x33FFFFFF),
                              alignment: Alignment.center,
                              child: const Icon(Icons.person, size: 14.0, color: Colors.white70),
                            )
                          : CachedNetworkImage(
                              imageUrl: anchorImg,
                              width: 22.0,
                              height: 22.0,
                              fit: BoxFit.cover,
                              errorWidget: (BuildContext c, String u, Object e) => Container(
                                width: 22.0,
                                height: 22.0,
                                color: const Color(0x33FFFFFF),
                                alignment: Alignment.center,
                                child: const Icon(Icons.person, size: 14.0, color: Colors.white70),
                              ),
                            ),
                    ),
                    const SizedBox(width: 6.0),
                    Flexible(
                      child: Text(
                        anchorName.isEmpty ? '主播' : anchorName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13.0, color: Colors.white),
                      ),
                    ),
                  ],
                ),
                if (timeText.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 6.0),
                  Row(
                    children: <Widget>[
                      const Icon(Icons.access_time, size: 12.0, color: Colors.white70),
                      const SizedBox(width: 4.0),
                      Flexible(
                        child: Text(
                          timeText,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12.0, color: Colors.white70),
                        ),
                      ),
                    ],
                  ),
                ],
                // 完播奖励: 完播且后台下发了奖励才展示
                if (finished && awardName.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 10.0),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 5.0),
                    decoration: BoxDecoration(
                      color: const Color(0x33FFFFFF),
                      borderRadius: BorderRadius.circular(14.0),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        const Text(
                          '完播奖励',
                          style: TextStyle(fontSize: 12.0, color: Colors.white70),
                        ),
                        const SizedBox(width: 6.0),
                        Text(
                          awardName,
                          style: const TextStyle(fontSize: 12.0, color: Colors.white, fontWeight: FontWeight.w500),
                        ),
                        if (awardNum.isNotEmpty) ...<Widget>[
                          const SizedBox(width: 6.0),
                          Text(
                            awardNum,
                            style: const TextStyle(fontSize: 13.0, color: Color(0xFFFFD34D), fontWeight: FontWeight.w600),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 白色内容面板(顶部圆角,上移盖住封面底部)
  Widget _buildPanel() {
    return Container(
      // 底部补 16: 面板整体上移了 16,补上后白色能铺到内容底部,不露灰色
      padding: const EdgeInsets.only(bottom: 16.0),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16.0)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          _buildTabs(),
          _buildRecordList(),
        ],
      ),
    );
  }

  /// 三个 tab(红包 / 签到 / 福袋)
  Widget _buildTabs() {
    return Row(
      children: List<Widget>.generate(tabs.length, (int index) {
        final bool active = index == tabIndex;
        return Expanded(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => switchTab(index),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12.0),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: active ? const Color(0xFFFF2C55) : Colors.transparent,
                    width: 2.0,
                  ),
                ),
              ),
              child: Text(
                tabs[index]['name']!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14.0,
                  fontWeight: active ? FontWeight.w600 : FontWeight.normal,
                  color: active ? const Color(0xFFFF2C55) : const Color(0xFF666666),
                ),
              ),
            ),
          ),
        );
      }),
    );
  }

  /// 记录列表: 加载中 / 空态 / 卡片
  Widget _buildRecordList() {
    if (loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 40.0),
        child: Center(child: Loading(title: '加载中...')),
      );
    }
    final List<Map<String, dynamic>> list = currentList;
    if (list.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 40.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              '暂无${tabs[tabIndex]['name']}',
              style: const TextStyle(fontSize: 14.0, color: Color(0xFF999999)),
            ),
            const SizedBox(height: 6.0),
            const Text(
              '观看直播后可在这里查看记录哦～',
              style: TextStyle(fontSize: 12.0, color: Color(0xFFBBBBBB)),
            ),
          ],
        ),
      );
    }
    // 记录条数不多,直接用 Column 展开(外层 ListView 已经在滚动了,
    // 这里再放一个滚动视图会嵌套滚动、也容易触发 viewport 高度断言)
    return Padding(
      padding: const EdgeInsets.fromLTRB(12.0, 4.0, 12.0, 16.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          for (int i = 0; i < list.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 10.0),
              child: _buildRecordCard(list[i]),
            ),
        ],
      ),
    );
  }

  /// 单条记录卡片: 图标 + 标题(奖励类型) + 时间 + 右侧数量
  Widget _buildRecordCard(Map<String, dynamic> item) {
    final String title = '${item['title'] ?? ''}'.trim();
    final String timeText = '${item['time'] ?? ''}'.trim();
    final String typeName = '${item['typeName'] ?? ''}'.trim();
    final String awardNum = '${item['num'] ?? ''}'.trim();
    // 现金类带单位"元",其余只显示数量(与 H5 一致)
    final bool withUnit = typeName == '现金红包';
    return Container(
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAFA),
        borderRadius: BorderRadius.circular(10.0),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 38.0,
            height: 38.0,
            decoration: const BoxDecoration(color: Color(0xFFFFF1F2), shape: BoxShape.circle),
            child: Padding(
              padding: const EdgeInsets.all(7.0),
              child: Image.asset(_tabIconAsset(), fit: BoxFit.contain),
            ),
          ),
          const SizedBox(width: 10.0),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Flexible(
                      child: Text(
                        title.isEmpty ? '--' : title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 14.0, fontWeight: FontWeight.w500, color: Color(0xFF333333)),
                      ),
                    ),
                    if (typeName.isNotEmpty) ...<Widget>[
                      const SizedBox(width: 6.0),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 2.0),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF0F3),
                          borderRadius: BorderRadius.circular(4.0),
                        ),
                        child: Text(
                          typeName,
                          style: const TextStyle(fontSize: 10.0, color: Color(0xFFFF2C55)),
                        ),
                      ),
                    ],
                  ],
                ),
                if (timeText.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 4.0),
                  Row(
                    children: <Widget>[
                      const Icon(Icons.access_time, size: 12.0, color: Color(0xFF999999)),
                      const SizedBox(width: 4.0),
                      Flexible(
                        child: Text(
                          timeText,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 11.0, color: Color(0xFF999999)),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8.0),
          Text(
            awardNum.isEmpty ? '--' : '+$awardNum${withUnit ? '元' : ''}',
            style: const TextStyle(fontSize: 15.0, fontWeight: FontWeight.w600, color: Color(0xFFFF2C55)),
          ),
        ],
      ),
    );
  }

  /// 当前 tab 的记录图标: 直接用直播间活动那套图(红包 icon-hb / 签到 sign-icon / 福袋 icon-fudai)
  /// * 与直播间左上角活动入口(_activityIcon)同一批资源,风格统一,不再用 Material 图标
  String _tabIconAsset() {
    switch (tabs[tabIndex]['key']) {
      case 'sign':
        return 'assets/images/sign-icon.png';
      case 'luckybag':
        return 'assets/images/icon-fudai.png';
      default:
        return 'assets/images/icon-hb.png';
    }
  }
}
