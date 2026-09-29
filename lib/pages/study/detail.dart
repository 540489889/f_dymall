/// 视频详情页 + 评论(对应参考 trainingVideo/detail.vue)
/// * 视频播放使用 media_kit(Player + Video),评论接口与发评论复用 MaterialsApi
/// * 弹幕: media_kit 原生不支持,本期先不做弹幕 UI(保留 commentBarrage 接口待用)
library;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import '../../api/materials.dart';
import '../../controller/auth_store.dart';

class StudyDetailPage extends StatefulWidget {
  const StudyDetailPage({super.key});
  @override
  State<StudyDetailPage> createState() => _StudyDetailPageState();
}

class _StudyDetailPageState extends State<StudyDetailPage> {
  int materialId = 0;
  String title = '';
  String videoUrl = '';

  // 视频播放器
  Player? _player;
  VideoController? _controller;
  bool _videoError = false;

  final Map<String, dynamic> _course = <String, dynamic>{
    'cover': '',
    'title': ''
  };
  String _teacherName = '';
  int _watchNum = 0;
  String _createTime = '';

  // 评论
  final List<Map<String, dynamic>> _commentList = <Map<String, dynamic>>[];
  int _commentPage = 1;
  int _commentPageCount = 1;
  bool _commentLoading = false;
  bool _commentNoMore = false;
  final TextEditingController _commentController = TextEditingController();

  // 评论时间戳格式化(兼容 10 位秒级 / 13 位毫秒级)
  String _fmtTime(dynamic ts) {
    final int v = int.tryParse('$ts') ?? 0;
    if (v == 0) return '';
    final DateTime d =
        DateTime.fromMillisecondsSinceEpoch(v < 1000000000000 ? v * 1000 : v);
    String pad(int n) => n < 10 ? '0$n' : '$n';
    return '${d.year}-${pad(d.month)}-${pad(d.day)} ${pad(d.hour)}:${pad(d.minute)}';
  }

  @override
  void initState() {
    super.initState();
    final Map? args = Get.arguments as Map?;
    materialId = int.tryParse('${args?['id'] ?? 0}') ?? 0;
    title = '${args?['title'] ?? ''}';
    videoUrl = '${args?['videoUrl'] ?? ''}';
    _loadDetail();
    _loadComments(true);
  }

  Future<void> _loadDetail() async {
    if (materialId == 0) return;
    final Map<String, dynamic> d =
        await MaterialsApi.materialDetail(materialId);
    if (!mounted) return;
    final String v = '${d['video_url'] ?? ''}';
    setState(() {
      if (v.isNotEmpty) videoUrl = v;
      _course['cover'] =
          MaterialsApi.fixUrl(d['thumb'] ?? d['cover']);
      _course['title'] = '${d['title'] ?? ''}';
      if ('${_course['title']}'.isNotEmpty) title = '${_course['title']}';
      _teacherName = '${d['author'] ?? ''}';
      _watchNum = int.tryParse('${d['watch_num'] ?? 0}') ?? 0;
      _createTime = '${d['create_time'] ?? ''}';
    });
    if (videoUrl.isNotEmpty) _initPlayer();
  }

  void _initPlayer() {
    _player = Player();
    _controller = VideoController(_player!);
    _player!.stream.error.listen((dynamic e) {
      if (mounted) setState(() => _videoError = true);
    });
    _player!.open(Media(videoUrl), play: false).catchError((dynamic e) {
      if (mounted) setState(() => _videoError = true);
    });
  }

  Future<void> _loadComments(bool reset) async {
    if (materialId == 0 || _commentLoading) return;
    if (!reset && _commentNoMore) return;
    setState(() => _commentLoading = true);
    if (reset) {
      _commentPage = 1;
      _commentNoMore = false;
      _commentList.clear();
    }
    final Map<String, dynamic> data = await MaterialsApi.commentList(
      materialId: materialId,
      page: _commentPage,
      pageSize: 10,
    );
    if (!mounted) return;
    final List raw = data['list'] as List? ?? <dynamic>[];
    final List<Map<String, dynamic>> mapped =
        raw.map((dynamic e) => _adaptComment(e)).toList();
    setState(() {
      _commentList.addAll(mapped);
      _commentPage++;
      _commentPageCount = data['page_count'] as int? ?? 1;
      if (_commentPage > _commentPageCount || mapped.isEmpty) {
        _commentNoMore = true;
      }
      _commentLoading = false;
    });
  }

  Map<String, dynamic> _adaptComment(dynamic item) {
    final Map<String, dynamic> m = item as Map<String, dynamic>;
    final String avatar = MaterialsApi.fixUrl(m['member_headimg'] ??
        m['avatar'] ??
        m['head_img'] ??
        m['user_avatar']);
    final String nickname = '${m['member_nickname'] ?? m['nickname'] ?? m['user_name'] ?? m['nick_name'] ?? '匿名用户'}';
    final String time = '${m['create_time'] ?? m['time'] ?? m['comment_time'] ?? ''}';
    final String content = '${m['content'] ?? m['comment'] ?? ''}';
    return <String, dynamic>{
      'avatar': avatar,
      'nickname': nickname,
      'time': time,
      'content': content,
    };
  }

  Future<void> _sendComment() async {
    final String text = _commentController.text.trim();
    if (text.isEmpty) return;
    if (AuthStore.to.authorization.value.isEmpty) {
      Get.toNamed('/login');
      return;
    }
    final bool ok = await MaterialsApi.addComment(
      materialId: materialId,
      content: text,
    );
    if (!mounted) return;
    if (ok) {
      _commentController.clear();
      _loadComments(true);
      Get.snackbar('提示', '评论已发送');
    } else {
      Get.snackbar('提示', '发送失败，请重试');
    }
  }

  @override
  void dispose() {
    _player?.dispose();
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title.isEmpty ? '视频详情' : title,
            style: const TextStyle(fontSize: 16)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0.5,
      ),
      backgroundColor: Colors.white,
      body: Column(
        children: <Widget>[
          // 视频区
          Container(
            color: Colors.black,
            height: 220,
            child: _controller != null
                ? Video(controller: _controller!)
                : (_course['cover'] != null && '${_course['cover']}'.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: '${_course['cover']}',
                        fit: BoxFit.cover)
                    : const Center(
                        child: CircularProgressIndicator(
                            color: Colors.white))),
          ),
          if (_videoError)
            const Padding(
                padding: EdgeInsets.all(8),
                child: Text('视频加载失败，请重试',
                    style: TextStyle(color: Colors.red))),
          // 信息区
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                    '${_course['title']}'.isEmpty
                        ? title
                        : '${_course['title']}',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w700, height: 1.5)),
                const SizedBox(height: 8),
                Row(
                  children: <Widget>[
                    if (_teacherName.isNotEmpty)
                      Expanded(
                          child: Text(_teacherName,
                              style: const TextStyle(
                                  color: Color(0xFFFF2C55), fontSize: 12))),
                    if (_watchNum > 0)
                      Text('$_watchNum人观看',
                          style: const TextStyle(
                              color: Colors.grey, fontSize: 12)),
                    if (_createTime.isNotEmpty)
                      Text(' $_createTime',
                          style: const TextStyle(
                              color: Colors.grey, fontSize: 12)),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 0.5, color: Color(0xFFF0F0F0)),
          // 评论区
          Expanded(
            child: _commentList.isEmpty && !_commentLoading
                ? const Center(
                    child: Text('暂无评论，快来抢沙发~',
                        style: TextStyle(color: Colors.grey)))
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    itemCount: _commentList.length + (_commentLoading ? 1 : 0),
                    itemBuilder: (BuildContext ctx, int i) {
                      if (i == _commentList.length) {
                        return const Padding(
                            padding: EdgeInsets.all(16),
                            child: Center(
                                child: CircularProgressIndicator(
                                    strokeWidth: 2)));
                      }
                      final Map<String, dynamic> c = _commentList[i];
                      return Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: const BoxDecoration(
                            border: Border(
                                bottom: BorderSide(
                                    color: Color(0xFFF2F3F5), width: 0.5))),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            ClipOval(
                              child: SizedBox(
                                width: 32,
                                height: 32,
                                child: '${c['avatar']}'.isEmpty
                                    ? Container(color: const Color(0xFFF5F5F5))
                                    : CachedNetworkImage(
                                        imageUrl: '${c['avatar']}',
                                        fit: BoxFit.cover,
                                        errorWidget: (_, __, ___) =>
                                            Container(
                                                color:
                                                    const Color(0xFFF5F5F5))),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: <Widget>[
                                      Text('${c['nickname']}',
                                          style: const TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600)),
                                      Text(_fmtTime(c['time']),
                                          style: const TextStyle(
                                              fontSize: 11,
                                              color: Colors.grey)),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text('${c['content']}',
                                      style: const TextStyle(
                                          fontSize: 13,
                                          color: Color(0xFF60687E),
                                          height: 1.5)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
          // 评论输入
          Container(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
            decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: Color(0xFFF2F3F5)))),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Container(
                    height: 36,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                        color: const Color(0xFFF4F5F7),
                        borderRadius: BorderRadius.circular(18)),
                    child: Center(
                      child: TextField(
                        controller: _commentController,
                        decoration: const InputDecoration.collapsed(
                            hintText: '快来一起互动吧~',
                            hintStyle: TextStyle(
                                fontSize: 13, color: Colors.grey)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                GestureDetector(
                    onTap: _sendComment,
                    child: const Text('发送',
                        style: TextStyle(
                            fontSize: 15, color: Color(0xFFFF2C55)))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
