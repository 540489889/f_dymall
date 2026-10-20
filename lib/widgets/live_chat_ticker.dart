import 'dart:async';
import 'package:flutter/material.dart';

/// 直播聊天飘屏: 在直播画面左下角循环向上滚动展示历史聊天消息
/// * [messages] 已解析的消息列表(按时间正序), 每条含 content / nickname / headimg / level
/// * 消息数超过 [maxVisible] 时自动循环滚动(内容重复拼接实现无缝); 不足则静态显示在底部
class LiveChatTicker extends StatefulWidget {
  final List<Map<String, dynamic>> messages;
  final int maxVisible;
  final double itemHeight;
  final Color nicknameColor;
  final Color contentColor;
  final double fontSize;

  const LiveChatTicker({
    super.key,
    required this.messages,
    this.maxVisible = 3,
    this.itemHeight = 22.0,
    this.nicknameColor = const Color(0xFF8FD0FF),
    this.contentColor = Colors.white,
    this.fontSize = 12.0,
  });

  @override
  State<LiveChatTicker> createState() => _LiveChatTickerState();
}

class _LiveChatTickerState extends State<LiveChatTicker> {
  late final ScrollController _controller;
  Timer? _timer;
  late final List<Map<String, dynamic>> _items;

  double get _step => widget.itemHeight + 4.0;
  double get _viewport => widget.maxVisible * _step;

  @override
  void initState() {
    super.initState();
    _items = widget.messages
        .where((Map<String, dynamic> m) => '${m['content'] ?? ''}'.trim().isNotEmpty)
        .toList();
    final bool scrollable = _items.length > widget.maxVisible;
    _controller = ScrollController();
    if (scrollable) {
      // 等首帧布局完成再启动定时器, 避免 hasClients 为 false
      WidgetsBinding.instance.addPostFrameCallback((_) => _start());
    }
  }

  void _start() {
    if (!mounted) return;
    _timer = Timer.periodic(const Duration(milliseconds: 2200), (_) => _tick());
  }

  void _tick() {
    if (!_controller.hasClients || !mounted) return;
    final double seg = _items.length * _step; // 一份内容的总长度
    double next = _controller.offset + _step;
    // 滚过第一份时无缝跳回(第二份与第一份内容相同, 视觉连续)
    if (next >= seg) {
      _controller.jumpTo(next - seg);
      next = _controller.offset + _step;
    }
    _controller.animateTo(
      next,
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_items.isEmpty) return const SizedBox.shrink();

    final bool scrollable = _items.length > widget.maxVisible;
    if (!scrollable) {
      // 消息少: 直接底部对齐静态展示
      return SizedBox(
        height: _viewport,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: _items.map(_buildRow).toList(),
        ),
      );
    }

    return SizedBox(
      height: _viewport,
      child: ListView.builder(
        controller: _controller,
        padding: EdgeInsets.zero,
        physics: const NeverScrollableScrollPhysics(),
        itemExtent: _step,
        itemCount: _items.length * 2, // 重复一份, 用于无缝循环
        itemBuilder: (BuildContext ctx, int i) => _buildRow(_items[i % _items.length]),
      ),
    );
  }

  Widget _buildRow(Map<String, dynamic> m) {
    final String nickname = '${m['nickname'] ?? ''}'.trim();
    final String content = '${m['content'] ?? ''}'.trim();
    return SizedBox(
      height: widget.itemHeight,
      // 单条气泡: 每行独立半透明圆角背景, 宽度贴合文字(不再整块共用一个底)
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 2.0),
            decoration: BoxDecoration(
              color: Colors.black.withAlpha(70),
              borderRadius: BorderRadius.circular(10.0),
            ),
            child: Text.rich(
              TextSpan(
                children: <InlineSpan>[
                  if (nickname.isNotEmpty)
                    TextSpan(
                      text: '$nickname：',
                      style: TextStyle(
                        color: widget.nicknameColor,
                        fontSize: widget.fontSize,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  TextSpan(
                    text: content,
                    style: TextStyle(color: widget.contentColor, fontSize: widget.fontSize),
                  ),
                ],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
