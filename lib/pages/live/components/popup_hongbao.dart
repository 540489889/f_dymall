/// 直播红包活动弹窗(对应H5 livepull.nvue: hongbaoNoJoin 开红包 + hongbaoWinlist 名单)
/// * 未参与: 先展示可点开的红包封面, 点「开」调 /live/api/shop/hongbaoJoin 拆红包
/// * 已参与/已开过: 打开即自动拆(与H5 showBagDetail 的 else 分支一致)
/// * 结果: award/join-award 中奖 / noaward 未中奖 / end 已结束
library;

import 'package:flutter/material.dart';

import '../../../api/live.dart';

class PopupHongbao extends StatefulWidget {
  const PopupHongbao({
    super.key,
    required this.item,
    this.avatar = '',
    this.nickname = '',
    this.autoOpen = false,
    this.onLookWinner,
  });

  /// 活动数据(LiveApi.activityItem 归一化结果)
  final Map<String, dynamic> item;
  /// 主播头像(红包封面上展示)
  final String avatar;
  /// 主播昵称(展示"xxx的红包")
  final String nickname;
  /// 已参与/已开过: 打开即自动拆红包
  final bool autoOpen;
  /// 查看中奖名单(页面负责关掉本弹窗再打开名单)
  final VoidCallback? onLookWinner;

  @override
  State<PopupHongbao> createState() => _PopupHongbaoState();
}

class _PopupHongbaoState extends State<PopupHongbao> {
  // 是否已拆开(拆开后展示结果卡)
  bool opened = false;
  // 请求中, 防重复点击
  bool loading = false;
  // 接口异常提示
  String error = '';
  // 开红包结果(hongbaoJoin 返回的 data)
  Map<String, dynamic> result = <String, dynamic>{};

  @override
  void initState() {
    super.initState();
    if (widget.autoOpen) _open();
  }

  String get gameId => '${widget.item['gameId'] ?? ''}';

  // 结果类型: award / join-award 中奖, noaward 未中奖, end 已结束
  String get resultType => '${result['type'] ?? ''}'.trim();

  bool get isAward => resultType == 'award' || resultType == 'join-award';

  // 中奖金额: 接口不同端放在 data.award_num 或顶层 award_num
  String get awardNum {
    final dynamic nested = result['data'];
    final String inner = nested is Map ? '${nested['award_num'] ?? ''}'.trim() : '';
    if (inner.isNotEmpty) return inner;
    return '${result['award_num'] ?? ''}'.trim();
  }

  // 奖励单位(如"元"), 开奖结果优先, 其次活动数据
  String get awardUnit {
    final String unit = '${result['award_typename'] ?? ''}'.trim();
    return unit.isNotEmpty ? unit : '${widget.item['awardTypeName'] ?? ''}'.trim();
  }

  // 未中奖文案(接口没给时兜底)
  String get noWinDesc {
    final String desc = '${result['no_winning_desc'] ?? ''}'.trim();
    return desc.isEmpty ? '很遗憾未中奖' : desc;
  }

  // 拆红包: 与H5 handleOpen 一致, 成功后展示结果卡
  Future<void> _open() async {
    if (loading) return;
    setState(() {
      loading = true;
      error = '';
    });
    final Map<String, dynamic>? res = await LiveApi.hongbaoJoin(gameId);
    if (!mounted) return;
    if (res == null) {
      setState(() {
        loading = false;
        error = '红包开失败了，稍后再试试';
      });
      return;
    }
    setState(() {
      loading = false;
      opened = true;
      result = res;
    });
  }

  // 查看中奖名单: 先关本弹窗, 再由页面打开名单(与H5 handleAwardMd 一致)
  void _lookWinner() {
    if (!mounted) return;
    Navigator.of(context).pop();
    widget.onLookWinner?.call();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        spacing: 12.0,
        children: [
          // 顶部情绪文案(旧版红包模板样式): 只有还没拆开时才说"被幸运选中", 免得和结果文案打架
          if (!opened)
            const Text(
              '”哇~被幸运选中啦~“',
              style: TextStyle(color: Color(0xFFFFFEBD), fontSize: 16.0),
            ),
          Container(
            width: 240.0,
            // 顶部标签要跟着卡片圆角裁掉, 否则会露出直角
            clipBehavior: Clip.antiAlias,
            decoration: const BoxDecoration(
              color: Color(0xFFFF2C55),
              borderRadius: BorderRadius.all(Radius.circular(30.0)),
            ),
            child: opened ? _resultView() : _coverView(),
          ),
          // 关闭: 白描边圆形按钮(与其它弹窗一致)
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              height: 30.0,
              width: 30.0,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white, width: 1.0),
                borderRadius: BorderRadius.circular(50.0),
              ),
              child: const Icon(Icons.close_outlined, color: Colors.white, size: 18.0),
            ),
          ),
        ],
      ),
    );
  }

  /// 红包封面: 顶部标签(活动标题) / 主播头像昵称 / 奖励单位 / 「开」
  Widget _coverView() {
    final String title = '${widget.item['title'] ?? ''}'.trim();
    return Column(
      children: [
        // 顶部白色半透标签(旧模板样式): 贴在卡片顶边, 下缘倒圆角
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 15.0, vertical: 2.0),
          decoration: const BoxDecoration(
            color: Colors.white30,
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(12.0)),
          ),
          child: Text(
            title.isEmpty ? '直播惊喜红包' : title,
            style: const TextStyle(color: Colors.white, fontSize: 12.0),
          ),
        ),
        const SizedBox(height: 18.0),
        ClipOval(
          child: widget.avatar.isEmpty
              ? Container(height: 40.0, width: 40.0, color: Colors.white24, child: const Icon(Icons.person, color: Colors.white70, size: 22.0))
              : Image.network(
                  widget.avatar,
                  height: 40.0,
                  width: 40.0,
                  fit: BoxFit.cover,
                  // 头像加载失败(服务端默认头像 404 等)仍回落灰底人像, 不抛图片异常
                  errorBuilder: (_, __, ___) => Container(
                    height: 40.0,
                    width: 40.0,
                    color: Colors.white24,
                    child: const Icon(Icons.person, color: Colors.white70, size: 22.0),
                  ),
                ),
        ),
        const SizedBox(height: 6.0),
        Text(
          widget.nickname.isEmpty ? '主播的红包' : '${widget.nickname} 的红包',
          style: const TextStyle(color: Colors.white, fontSize: 12.0),
        ),
        if (awardUnit.isNotEmpty) ...[
          const SizedBox(height: 4.0),
          Text(awardUnit, style: const TextStyle(color: Color(0xFFFFFEBD), fontSize: 12.0)),
        ],
        const SizedBox(height: 22.0),
        // 「开」: 金色圆形按钮
        GestureDetector(
          onTap: loading ? null : _open,
          child: Container(
            height: 62.0,
            width: 62.0,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFFFFFEBD), Color(0xFFFFC64B)],
              ),
            ),
            child: Center(
              child: Text(
                loading ? '开…' : '开',
                style: const TextStyle(color: Color(0xFFC8102E), fontSize: 24.0, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ),
        if (error.isNotEmpty) ...[
          const SizedBox(height: 8.0),
          Text(error, style: const TextStyle(color: Color(0xFFFFFEBD), fontSize: 11.0)),
        ],
        // 底部说明(旧模板位置): 告诉用户红包是点「开」领取的
        const SizedBox(height: 10.0),
        Text(
          loading ? '正在开启…' : '点「开」拆红包',
          style: const TextStyle(color: Colors.white70, fontSize: 11.0),
        ),
        const SizedBox(height: 16.0),
      ],
    );
  }

  /// 开奖结果: 中奖 / 未中奖 / 已结束(顶部标签 + 大号金额, 与旧模板一致)
  Widget _resultView() {
    final bool ended = resultType == 'end';
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 15.0, vertical: 2.0),
          decoration: const BoxDecoration(
            color: Colors.white30,
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(12.0)),
          ),
          child: Text(
            isAward ? '— 恭喜您获得 —' : (ended ? '— 活动已结束 —' : '— 很遗憾 —'),
            style: const TextStyle(color: Colors.white, fontSize: 12.0),
          ),
        ),
        const SizedBox(height: 22.0),
        if (isAward)
          Text.rich(
            TextSpan(
              style: const TextStyle(color: Color(0xFFFFFEBD), fontFamily: 'arial'),
              children: [
                TextSpan(text: awardNum.isEmpty ? '0' : awardNum, style: const TextStyle(fontSize: 45.0)),
                TextSpan(text: awardUnit.isEmpty ? '' : ' $awardUnit', style: const TextStyle(fontSize: 16.0)),
              ],
            ),
          )
        else
          Text(
            ended ? '红包活动已结束' : noWinDesc,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontSize: 15.0),
          ),
        const SizedBox(height: 6.0),
        if (!ended)
          Text(
            isAward ? '已存入钱包' : '未中奖',
            style: const TextStyle(color: Colors.white70, fontSize: 11.0),
          ),
        const SizedBox(height: 24.0),
        FilledButton(
          style: ButtonStyle(
            backgroundColor: WidgetStateProperty.all(const Color(0xFFFFFEBD)),
            padding: WidgetStateProperty.all(EdgeInsets.zero),
            minimumSize: WidgetStateProperty.all(const Size(120.0, 40.0)),
          ),
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('开心收下', style: TextStyle(color: Color(0xFFF07604), fontSize: 13.0)),
        ),
        if (widget.onLookWinner != null)
          TextButton(
            onPressed: _lookWinner,
            child: const Text('查看中奖名单', style: TextStyle(color: Color(0xFFFFFEBD), fontSize: 12.0)),
          ),
        const SizedBox(height: 12.0),
      ],
    );
  }
}
