/// 在线客服(AI 智能客服 + 人工客服)
/// 对齐文档: aiservicer-frontend-api v1.0
/// 仅实现文档覆盖的能力: 文本/图片/视频消息、AI 自动应答、转人工、轮询拉取、
/// 结束会话、满意度评价。未覆盖的功能(语音/表情/红包/位置/转账等)已在界面中移除。
library;

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:dio/dio.dart' show DioException;
import 'package:image_picker/image_picker.dart';
import 'package:shirne_dialog/shirne_dialog.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import '../../api/servicer.dart';
import '../../config/index.dart';
import '../../controller/auth_store.dart';

class Chat extends StatefulWidget {
  const Chat({super.key});
  @override
  State<Chat> createState() => _ChatState();
}

class _ChatState extends State<Chat> with WidgetsBindingObserver {
  static const Color primary = Color(0xFFFF2C55);
  static const Color memberBubble = Color(0xFFFFE9EE); // 会员气泡(浅主题粉)
  static const Color serviceBubble = Color(0xFFFFFFFF); // 客服气泡(白)

  // 路由参数(从「消息」进来可能带 title, 兜底为在线客服)
  dynamic get arguments =>
      (Get.arguments is Map) ? (Get.arguments as Map).cast<String, dynamic>() : <String, dynamic>{};

  // 会话状态
  String sessionId = '';
  String humanSessionId = '';
  String mode = 'ai'; // ai | human
  int status = 0; // 0 仅 AI / 1 人工进行中 / 3 已结束
  String servicerName = '';
  int lastId = 0;
  bool canEvaluate = false;
  bool evaluated = false;

  // 本地消息列表(按时间正序, 最新在底部)
  List<Map<String, dynamic>> messages = <Map<String, dynamic>>[];
  final Set<int> _loadedIds = <int>{};

  // UI 状态
  bool loading = true;
  String initError = '';
  bool thinking = false; // AI 正在思考占位
  bool appPaused = false;
  Timer? _pollTimer;
  bool _polling = false;

  // 输入
  final TextEditingController editorController = TextEditingController();
  final FocusNode editorFocusNode = FocusNode();
  final ScrollController chatController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initSession();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    appPaused = state != AppLifecycleState.resumed;
    if (!appPaused && mode == 'human' && status == 1 && !loading) _startPolling();
  }

  @override
  void dispose() {
    _stopPolling();
    WidgetsBinding.instance.removeObserver(this);
    editorController.dispose();
    editorFocusNode.dispose();
    chatController.dispose();
    super.dispose();
  }

  /* ----------------------------- 会话生命周期 ----------------------------- */

  /// 初始化会话(每次进入/重新咨询都调)
  Future<void> _initSession() async {
    setState(() {
      loading = true;
      initError = '';
    });
    try {
      final Map<String, dynamic> data = await ServicerApi.init();
      sessionId = '${data['session_id'] ?? ''}';
      final String type = '${data['type'] ?? 'ai'}'; // ai | human
      humanSessionId = '${data['human_session_id'] ?? ''}';
      mode = type;
      status = (type == 'human') ? (int.tryParse('${data['status'] ?? 1}') ?? 1) : 0;
      servicerName = '';
      lastId = 0;
      canEvaluate = false;
      evaluated = false;
      messages.clear();
      _loadedIds.clear();
      final String welcome = '${data['welcome_message'] ?? ''}';
      if (welcome.isNotEmpty) {
        _appendMessage(<String, dynamic>{
          'id': -999,
          'isMe': false,
          'type': 'text',
          'content': welcome,
          'temp': false,
        });
      }
      if (type == 'human') {
        _loadHistory();
      }
    } catch (e) {
      initError = _errMsg(e);
    } finally {
      loading = false;
      setState(() {});
    }
  }

  /// 全量拉取历史(转人工/恢复人工会话后调用)
  Future<void> _loadHistory() async {
    if (sessionId.isEmpty) return;
    try {
      final Map<String, dynamic> data = await ServicerApi.chatLog(
        sessionId: sessionId,
        lastId: 0,
        page: 1,
        pageSize: 100,
      );
      final String t = '${data['type'] ?? ''}';
      if (t.isNotEmpty) mode = t;
      status = int.tryParse('${data['status'] ?? 1}') ?? 1;
      servicerName = '${data['servicer_name'] ?? ''}';
      if ('${data['can_evaluate']}' == '1') canEvaluate = true;
      final dynamic lid = data['last_id'];
      if (lid != null) lastId = int.tryParse('$lid') ?? lastId;
      final List<dynamic> list = data['list'] is List ? data['list'] as List<dynamic> : <dynamic>[];
      for (final dynamic e in list) {
        if (e is Map) _upsertFromServer(e.cast<String, dynamic>());
      }
      setState(() {});
      if (status == 3) {
        _stopPolling();
        if (canEvaluate && !evaluated) _showEvaluate();
      } else {
        _startPolling();
      }
    } catch (e) {
      _stopPolling();
    }
  }

  /// 轮询: 人工模式每 3 秒拉取客服消息
  void _startPolling() {
    _stopPolling();
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) => _poll());
  }

  void _stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  Future<void> _poll() async {
    if (!mounted || mode != 'human' || status == 3 || appPaused || _polling) return;
    _polling = true;
    try {
      final Map<String, dynamic> data = await ServicerApi.chatLog(sessionId: sessionId, lastId: lastId);
      if (!mounted) return;
      final String t = '${data['type'] ?? ''}';
      if (t.isNotEmpty) mode = t;
      status = int.tryParse('${data['status'] ?? status}') ?? status;
      servicerName = '${data['servicer_name'] ?? servicerName}';
      if ('${data['can_evaluate']}' == '1') canEvaluate = true;
      final dynamic lid = data['last_id'];
      if (lid != null) lastId = int.tryParse('$lid') ?? lastId;
      final List<dynamic> list = data['list'] is List ? data['list'] as List<dynamic> : <dynamic>[];
      for (final dynamic e in list) {
        if (e is Map) _upsertFromServer(e.cast<String, dynamic>());
      }
      setState(() {});
      if (status == 3) {
        _stopPolling();
        if (canEvaluate && !evaluated) _showEvaluate();
      }
    } catch (e) {
      _stopPolling();
    } finally {
      _polling = false;
    }
  }

  /// 进入人工模式(转人工成功 / AI 触发转人工 / 恢复人工会话)
  void _enterHuman(String humanSid) {
    if (humanSid.isNotEmpty) humanSessionId = humanSid;
    mode = 'human';
    status = 1;
    messages.clear();
    _loadedIds.clear();
    _loadHistory();
  }

  /// 结束会话
  Future<void> _endSession() async {
    try {
      final Map<String, dynamic> data = await ServicerApi.endSession(
        sessionId: sessionId,
        humanSessionId: humanSessionId,
      );
      status = int.tryParse('${data['status'] ?? 3}') ?? 3;
      if ('${data['human_session_id']}'.isNotEmpty) humanSessionId = '${data['human_session_id']}';
      if ('${data['can_evaluate']}' == '1') canEvaluate = true;
      _stopPolling();
      setState(() {});
      if (canEvaluate && !evaluated) {
        _showEvaluate();
      } else {
        MyDialog.toast('会话已结束');
      }
    } catch (e) {
      MyDialog.toast(_errMsg(e));
    }
  }

  /// 重新咨询
  void _reConsult() {
    _stopPolling();
    mode = 'ai';
    status = 0;
    servicerName = '';
    humanSessionId = '';
    lastId = 0;
    canEvaluate = false;
    evaluated = false;
    _initSession();
  }

  /* ----------------------------- 发送消息 ----------------------------- */

  /// 发送文本(AI 同步应答 / 人工进入轮询)
  Future<void> _sendText() async {
    final String text = editorController.text.trim();
    if (text.isEmpty) return;
    editorController.clear();
    _hideKeyboard();
    _appendMessage(<String, dynamic>{
      'id': -DateTime.now().millisecondsSinceEpoch,
      'isMe': true,
      'type': 'text',
      'content': text,
      'temp': true,
    });
    if (mode == 'ai') {
      setState(() => thinking = true);
      try {
        final Map<String, dynamic> res = await ServicerApi.say(
          sessionId: sessionId,
          message: text,
          messageType: 1,
        );
        if ('${res['need_transfer']}' == 'true') {
          // 触发转人工: 服务端已把 AI 历史复制进人工消息表, 全量重拉
          final String hs = '${res['human_session_id'] ?? ''}';
          _enterHuman(hs);
        } else {
          final String answer = '${res['answer'] ?? ''}';
          if (answer.isNotEmpty) {
            _appendMessage(<String, dynamic>{
              'id': -998,
              'isMe': false,
              'type': 'text',
              'content': answer,
              'temp': false,
            });
          }
        }
      } catch (e) {
        MyDialog.toast(_errMsg(e));
      } finally {
        thinking = false;
        setState(() {});
      }
    } else {
      // 人工模式: say 仅回执, 客服回复靠轮询
      try {
        await ServicerApi.say(sessionId: sessionId, message: text, messageType: 1);
        _poll();
      } catch (e) {
        MyDialog.toast(_errMsg(e));
      }
    }
  }

  /// 选择并发送图片/视频(AI 模式发媒体会自动转人工)
  Future<void> _pickMedia(ImageSource source, bool isVideo) async {
    final ImagePicker picker = ImagePicker();
    XFile? file;
    try {
      file = isVideo
          ? await picker.pickVideo(source: source)
          : await picker.pickImage(source: source);
    } catch (e) {
      MyDialog.toast('选择失败: ${_errMsg(e)}');
      return;
    }
    if (file == null) return;
    String url;
    try {
      url = isVideo
          ? await ServicerApi.uploadChatVideo(file.path)
          : await ServicerApi.uploadChatImg(file.path);
    } catch (e) {
      MyDialog.toast(_errMsg(e));
      return;
    }
    _sendMedia(url, isVideo);
  }

  Future<void> _sendMedia(String url, bool isVideo) async {
    _appendMessage(<String, dynamic>{
      'id': -DateTime.now().millisecondsSinceEpoch,
      'isMe': true,
      'type': isVideo ? 'video' : 'image',
      'content': url,
      'temp': true,
    });
    if (mode == 'ai') {
      try {
        final Map<String, dynamic> res = await ServicerApi.say(
          sessionId: sessionId,
          message: '',
          messageType: isVideo ? 3 : 2,
          messageUrl: url,
        );
        if ('${res['need_transfer']}' == 'true') {
          _enterHuman('${res['human_session_id'] ?? ''}');
        } else {
          final String answer = '${res['answer'] ?? ''}';
          if (answer.isNotEmpty && answer != 'null') {
            _appendMessage(<String, dynamic>{
              'id': -997,
              'isMe': false,
              'type': 'text',
              'content': answer,
              'temp': false,
            });
          }
        }
      } catch (e) {
        MyDialog.toast(_errMsg(e));
      }
    } else {
      try {
        await ServicerApi.say(
          sessionId: sessionId,
          message: '',
          messageType: isVideo ? 3 : 2,
          messageUrl: url,
        );
        _poll();
      } catch (e) {
        MyDialog.toast(_errMsg(e));
      }
    }
  }

  /* ----------------------------- 消息渲染辅助 ----------------------------- */

  /// 追加本地消息(无 time 时补当前时分)
  void _appendMessage(Map<String, dynamic> msg) {
    if ('${msg['time'] ?? ''}'.isEmpty) {
      final DateTime now = DateTime.now();
      msg['time'] = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    }
    messages.add(msg);
    setState(() {});
    _scrollToBottom();
  }

  /// 合并服务端消息(去重 + 替换乐观消息)
  void _upsertFromServer(Map<String, dynamic> m) {
    final int id = int.tryParse('${m['id']}') ?? 0;
    final int senderType = int.tryParse('${m['sender_type'] ?? 1}') ?? 1;
    final bool isMe = senderType == 1;
    final int mType = int.tryParse('${m['message_type'] ?? 1}') ?? 1;
    final String content = '${m['message'] ?? ''}';
    final String url = _fixUrl('${m['message_url'] ?? ''}');
    final String time = '${m['create_time'] ?? ''}';
    final String body = mType == 1 ? content : url;
    // 用内容一致(且同向)的乐观消息替换
    messages.removeWhere((Map<String, dynamic> e) =>
        e['temp'] == true && e['isMe'] == isMe && '${e['content']}' == body);
    if (_loadedIds.contains(id)) return;
    _loadedIds.add(id);
    final String type = mType == 2 ? 'image' : (mType == 3 ? 'video' : 'text');
    _appendMessage(<String, dynamic>{
      'id': id,
      'isMe': isMe,
      'type': type,
      'content': body,
      'temp': false,
      'time': time,
    });
  }

  /// 相对路径补全资源域名
  static String _fixUrl(String url) {
    if (url.isEmpty) return url;
    if (url.startsWith('http')) return url;
    return '${Config.imgDomain}${url.startsWith('/') ? '' : '/'}$url';
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (chatController.hasClients) {
        chatController.jumpTo(chatController.position.maxScrollExtent);
      }
    });
  }

  void _hideKeyboard() {
    if (editorFocusNode.hasFocus) editorFocusNode.unfocus();
  }

  static String _errMsg(dynamic e) => e is DioException ? (e.message ?? '网络异常') : '$e';

  /* ----------------------------- 满意度评价 ----------------------------- */

  void _showEvaluate() {
    const List<String> scoreLabels = <String>['非常不满意', '不满意', '一般', '满意', '非常满意'];
    int score = 5;
    final TextEditingController contentCtl = TextEditingController();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext ctx) => StatefulBuilder(
        builder: (BuildContext ctx, void Function(void Function()) setD) {
          return Dialog(
            backgroundColor: Colors.transparent,
            elevation: 0,
            insetPadding: const EdgeInsets.symmetric(horizontal: 32),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const Text('服务评价',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: Color(0xFF222222))),
                  const SizedBox(height: 18),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List<Widget>.generate(5, (int i) {
                      final bool on = i < score;
                      return GestureDetector(
                        onTap: () => setD(() => score = i + 1),
                        behavior: HitTestBehavior.opaque,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Icon(
                            on ? Icons.star_rounded : Icons.star_outline_rounded,
                            color: on ? const Color(0xFFFFB400) : Colors.grey.shade300,
                            size: 30,
                          ),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 6),
                  Text(scoreLabels[score - 1],
                      style: const TextStyle(fontSize: 13, color: Color(0xFFFFB400))),
                  const SizedBox(height: 16),
                  TextField(
                    controller: contentCtl,
                    maxLines: 3,
                    maxLength: 200,
                    decoration: InputDecoration(
                      hintText: '说说您的感受（选填）',
                      hintStyle: const TextStyle(fontSize: 13, color: Colors.grey),
                      filled: true,
                      fillColor: const Color(0xFFF5F5F5),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.all(12),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: TextButton(
                          onPressed: () => Get.back(),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.grey,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: const Text('稍后再说', style: TextStyle(fontSize: 15)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () async {
                            Get.back();
                            try {
                              await ServicerApi.evaluate(
                                score: score,
                                content: contentCtl.text.trim(),
                                humanSessionId: humanSessionId,
                                sessionId: sessionId,
                              );
                              evaluated = true;
                              MyDialog.toast('感谢您的评价');
                              // 评价已完成(会话也已结束), 直接退出客服页回到来路页面,
                              // 不再停留在空会话里
                              if (mounted) Get.back();
                            } catch (e) {
                              MyDialog.toast(_errMsg(e));
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primary,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
                          ),
                          child: const Text('提交', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  /// 视频预览
  void _showVideoDialog(String url) {
    final Player player = Player();
    final VideoController controller = VideoController(player);
    player.open(Media(url));
    Navigator.of(context)
        .push(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          body: Stack(
            children: <Widget>[
              Center(child: Video(controller: controller)),
              Positioned(
                top: 40,
                right: 16,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ],
          ),
        ),
      ),
    )
        .then((_) => player.dispose());
  }

  /* ----------------------------- 顶部状态文案 ----------------------------- */

  String _statusText() {
    // 界面上不出现「AI」字眼, 统一叫「智能客服」
    if (mode == 'ai') return '智能客服为您服务';
    if (status == 3) return '会话已结束';
    if (servicerName.isEmpty) return '正在为您转接，请稍候…';
    return '客服 $servicerName 为您服务';
  }

  /* ----------------------------- 构建 ----------------------------- */

  @override
  Widget build(BuildContext context) {
    final String title = '${arguments['title'] ?? '在线客服'}'; // 标题参数兜底
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        foregroundColor: const Color(0xFF222222),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, size: 18, color: Color(0xFF222222)),
          onPressed: () => Get.back(),
        ),
        title: Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: Color(0xFF222222))),
        centerTitle: true,
        actions: <Widget>[
          if (mode == 'human' && status == 1)
            TextButton(
              onPressed: _endSession,
              child: const Text('结束', style: TextStyle(fontSize: 14, color: primary)),
            ),
        ],
      ),
      body: Column(
        children: <Widget>[
          // 状态条
          Container(
            width: double.infinity,
            color: const Color(0xFFFFF1F2),
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            child: Row(
              children: <Widget>[
                Icon(Icons.headset_mic, size: 16, color: primary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(_statusText(), style: const TextStyle(fontSize: 13, color: Color(0xFF666666))),
                ),
              ],
            ),
          ),
          // 消息区
          Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : initError.isNotEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Text(initError, style: const TextStyle(color: Colors.grey)),
                            const SizedBox(height: 12),
                            ElevatedButton(onPressed: _initSession, child: const Text('重新加载')),
                          ],
                        ),
                      )
                    : ListView.builder(
                        controller: chatController,
                        padding: const EdgeInsets.all(12),
                        itemCount: messages.length + (thinking ? 1 : 0),
                        itemBuilder: (BuildContext context, int index) {
                          if (thinking && index == messages.length) {
                            return _thinkingBubble();
                          }
                          return _bubble(messages[index]);
                        },
                      ),
          ),
          // 底部: 已结束 -> 重新咨询; 否则 -> 输入栏
          status == 3 ? _endedBar() : _inputBar(),
        ],
      ),
    );
  }

  /// AI 思考占位气泡
  Widget _thinkingBubble() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _serviceAvatar(),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: serviceBubble,
              borderRadius: BorderRadius.circular(10),
              boxShadow: const <BoxShadow>[BoxShadow(color: Color(0x14000000), blurRadius: 6, offset: Offset(0, 2))],
            ),
            child: const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(primary)),
            ),
          ),
        ],
      ),
    );
  }

  /// 单条消息气泡
  Widget _bubble(Map<String, dynamic> m) {
    final bool isMe = m['isMe'] as bool? ?? false;
    final String type = '${m['type']}';
    final String content = '${m['content'] ?? ''}';
    final String msgTime = '${m['time'] ?? ''}';
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        textDirection: isMe ? TextDirection.rtl : TextDirection.ltr,
        children: <Widget>[
          isMe ? _memberAvatar() : _serviceAvatar(),
          const SizedBox(width: 10),
          Flexible(
            child: Column(
              crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: <Widget>[
                Container(
                  constraints: const BoxConstraints(maxWidth: 240),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isMe ? memberBubble : serviceBubble,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: const <BoxShadow>[BoxShadow(color: Color(0x14000000), blurRadius: 6, offset: Offset(0, 2))],
                  ),
                  child: _bubbleContent(type, content, isMe),
                ),
                if (msgTime.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(msgTime, style: const TextStyle(fontSize: 10, color: Colors.grey)),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _bubbleContent(String type, String content, bool isMe) {
    if (type == 'image') {
      return GestureDetector(
        onTap: () => _previewImage(content),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: Image.network(content, width: 160, height: 160, fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(width: 160, height: 160, color: const Color(0xFFF0F0F0))),
        ),
      );
    }
    if (type == 'video') {
      return GestureDetector(
        onTap: () => _showVideoDialog(content),
        child: Container(
          width: 160,
          height: 160,
          decoration: BoxDecoration(
            color: Colors.black12,
            borderRadius: BorderRadius.circular(6),
          ),
          child: const Center(child: Icon(Icons.play_circle_fill, size: 44, color: Colors.white70)),
        ),
      );
    }
    return Text(
      content,
      style: TextStyle(fontSize: 14, height: 1.4, color: isMe ? primary : const Color(0xFF333333)),
    );
  }

  void _previewImage(String url) {
    showDialog(
      context: context,
      builder: (_) => Scaffold(
        backgroundColor: Colors.black87,
        body: Stack(
          children: <Widget>[
            Center(child: Image.network(url, fit: BoxFit.contain)),
            Positioned(
              top: 40,
              right: 16,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Get.back(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _serviceAvatar() {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: primary,
        borderRadius: BorderRadius.circular(18),
      ),
      child: const Icon(Icons.headset_mic, color: Colors.white, size: 20),
    );
  }

  Widget _memberAvatar() {
    final String url = AuthStore.to.headimg;
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: const Color(0xFFD9D9D9),
        borderRadius: BorderRadius.circular(18),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: url.isNotEmpty
            ? Image.network(
                url,
                width: 36,
                height: 36,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const Center(
                  child: Text('我', style: TextStyle(color: Colors.white, fontSize: 14)),
                ),
              )
            : const Center(
                child: Text('我', style: TextStyle(color: Colors.white, fontSize: 14)),
              ),
      ),
    );
  }

  /// 已结束: 重新咨询
  Widget _endedBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      child: SizedBox(
        width: double.infinity,
        height: 44,
        child: ElevatedButton(
          onPressed: _reConsult,
          style: ElevatedButton.styleFrom(
            backgroundColor: primary,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          ),
          child: const Text('重新咨询', style: TextStyle(color: Colors.white, fontSize: 15)),
        ),
      ),
    );
  }

  /// 输入栏(文本 + 附件 + 发送)
  Widget _inputBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
      child: SafeArea(
        top: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            IconButton(
              icon: const Icon(Icons.add_circle_outline, size: 28, color: Color(0xFF333333)),
              onPressed: _showMediaSheet,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Container(
                constraints: const BoxConstraints(maxHeight: 100),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F5F5),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: TextField(
                  controller: editorController,
                  focusNode: editorFocusNode,
                  maxLines: null,
                  style: const TextStyle(fontSize: 15),
                  decoration: const InputDecoration.collapsed(hintText: '请输入您的问题', hintStyle: TextStyle(fontSize: 14, color: Colors.grey)),
                  onSubmitted: (_) => _sendText(),
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _sendText,
              child: Container(
                height: 36,
                width: 36,
                decoration: BoxDecoration(
                  color: primary,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(Icons.arrow_upward, color: Colors.white, size: 20),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 附件选择(图片/拍摄/视频) — 文档仅支持文本/图片/视频
  void _showMediaSheet() {
    Get.bottomSheet<void>(
      SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              // 操作项卡片
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12.0),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    _sheetBtn('相册', () {
                      Get.back<void>();
                      _pickMedia(ImageSource.gallery, false);
                    }),
                    const Divider(height: 0.5, color: Color(0xFFEEEEEE)),
                    _sheetBtn('拍摄', () {
                      Get.back<void>();
                      _pickMedia(ImageSource.camera, false);
                    }),
                    const Divider(height: 0.5, color: Color(0xFFEEEEEE)),
                    _sheetBtn('视频', () {
                      Get.back<void>();
                      _pickMedia(ImageSource.gallery, true);
                    }),
                  ],
                ),
              ),
              const SizedBox(height: 10.0),
              // 取消
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12.0),
                ),
                child: _sheetBtn('取消', () => Get.back<void>(), isCancel: true),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 底部面板按钮(与个人信息头像更换一致)
  Widget _sheetBtn(String text, VoidCallback onTap, {bool isCancel = false}) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: double.infinity,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(vertical: 16.0),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 16.0,
            color: isCancel ? const Color(0xFF333333) : Colors.black87,
            fontWeight: isCancel ? FontWeight.w500 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}
