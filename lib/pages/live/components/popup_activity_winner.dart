/// 活动中奖名单弹窗(福袋 / 红包共用)
/// * 两个接口返回结构一致: {count 总人数, list:[{nickname, headimg, award_num, award_typename}]}
/// * 与H5 livepull.nvue 的 winner(福袋) / winnerHongbao(红包) 弹窗对应
library;

import 'package:flutter/material.dart';

import '../../../api/live.dart';

/// 名单归属的活动类型(决定调用的接口与标题)
enum ActivityWinnerType {
  /// 福袋: luckybagWinlist
  luckybag('luckybag', '幸运观众'),
  /// 红包: hongbaoWinlist
  hongbao('hongbao', '幸运观众名单');

  const ActivityWinnerType(this.api, this.title);

  /// 接口类型标识(LiveApi.activityWinList 的 type)
  final String api;
  /// 弹窗标题
  final String title;
}

/// 中奖名单弹窗: 每页 10 条, 滚到底自动取下一页
class PopupActivityWinner extends StatefulWidget {
  const PopupActivityWinner({super.key, required this.gameId, required this.type});

  /// 活动 id
  final String gameId;
  /// 福袋 / 红包
  final ActivityWinnerType type;

  @override
  State<PopupActivityWinner> createState() => _PopupActivityWinnerState();
}

class _PopupActivityWinnerState extends State<PopupActivityWinner> {
  static const int pageSize = 10;
  final ScrollController scrollController = ScrollController();
  final List<Map<String, dynamic>> winners = <Map<String, dynamic>>[];
  int page = 0;
  int total = 0;
  bool loading = false;
  bool finished = false;

  @override
  void initState() {
    super.initState();
    scrollController.addListener(_onScroll);
    _loadMore();
  }

  @override
  void dispose() {
    scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!scrollController.hasClients) return;
    if (scrollController.position.pixels >= scrollController.position.maxScrollExtent - 30) {
      _loadMore();
    }
  }

  // 分页加载: 每页 pageSize 条, 到底或已取完不再请求
  Future<void> _loadMore() async {
    if (loading || finished) return;
    setState(() {
      loading = true;
    });
    final Map<String, dynamic> res = await LiveApi.activityWinList(
      gameId: widget.gameId,
      type: widget.type.api,
      page: page + 1,
      pageSize: pageSize,
    );
    if (!mounted) return;
    final List<Map<String, dynamic>> list = (res['list'] as List).cast<Map<String, dynamic>>();
    setState(() {
      page += 1;
      total = LiveApi.intOf(res['count']);
      winners.addAll(list);
      loading = false;
      if (list.length < pageSize || (total > 0 && winners.length >= total)) finished = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 265.0,
            padding: const EdgeInsets.fromLTRB(20.0, 20.0, 20.0, 20.0),
            decoration: BoxDecoration(
              // 与福袋弹窗同一底色(淡粉), 两个弹窗视觉保持一套
              color: Color(0xFFFFF5F6),
              borderRadius: BorderRadius.circular(16.0),
            ),
            child: Column(
              children: [
                Text(
                  widget.type.title,
                  style: const TextStyle(color: Color(0xFF333333), fontSize: 16.0, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4.0),
                Text('共$total人', style: const TextStyle(color: Colors.black38, fontSize: 12.0)),
                const SizedBox(height: 8.0),
                // 名单区矮一点: 弹窗整体别顶得太高(小屏上也能留出上下留白)
                SizedBox(
                  height: 168.0,
                  child: winners.isEmpty
                      ? Center(
                          child: Text(
                            loading ? '加载中...' : '还没有幸运观众',
                            style: const TextStyle(color: Colors.black38, fontSize: 12.0),
                          ),
                        )
                      : ListView.separated(
                          controller: scrollController,
                          padding: EdgeInsets.zero,
                          itemCount: winners.length,
                          // 分隔线用福袋同套淡粉, 在淡粉底上不发灰
                          separatorBuilder: (BuildContext context, int index) =>
                              const Divider(height: 12.0, color: Color(0xFFFFE6EB)),
                          itemBuilder: (BuildContext context, int index) {
                            final Map<String, dynamic> item = winners[index];
                            final String headimg = '${item['headimg'] ?? ''}';
                            return Row(
                              children: [
                                ClipOval(
                                  child: headimg.isEmpty
                                      ? Container(height: 30.0, width: 30.0, color: Colors.black12)
                                      : Image.network(
                                          headimg,
                                          height: 30.0,
                                          width: 30.0,
                                          fit: BoxFit.cover,
                                          // 用户没设头像时服务端会给默认图路径(可能 404), 加载失败回落灰底圆
                                          errorBuilder: (_, __, ___) =>
                                              Container(height: 30.0, width: 30.0, color: Colors.black12),
                                        ),
                                ),
                                const SizedBox(width: 8.0),
                                Expanded(
                                  child: Text(
                                    '${item['nickname'] ?? ''}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(color: Color(0xFF333333), fontSize: 13.0),
                                  ),
                                ),
                                Text(
                                  '${item['awardNum'] ?? ''}${item['awardTypeName'] ?? ''}',
                                  style: const TextStyle(color: Color(0xFFFF2C55), fontSize: 12.0),
                                ),
                              ],
                            );
                          },
                        ),
                ),
                const SizedBox(height: 15.0),
                FilledButton(
                  style: ButtonStyle(
                    backgroundColor: WidgetStateProperty.all(const Color(0xFFFF2C55)),
                    minimumSize: WidgetStateProperty.all(const Size(double.infinity, 40.0)),
                    shape: WidgetStatePropertyAll(
                      RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.0)),
                    ),
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('知道了', style: TextStyle(fontSize: 14.0)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
