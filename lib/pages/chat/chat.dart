/// 聊天模板
library;

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shirne_dialog/shirne_dialog.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import '../../router/fade_route.dart';
import '../../behavior/custom_scroll_behavior.dart';
import '../../utils/index.dart';
import '../../components/image_group.dart';
import '../../components/waves.dart';
import './components/richtext.dart';
import './components/redpacket.dart';
import 'mock/chat_json.dart';
import 'mock/emoj_json.dart';

class Chat extends StatefulWidget {
  const Chat({super.key});
  @override
  State<Chat> createState() => _ChatState();
}

class _ChatState extends State<Chat> with SingleTickerProviderStateMixin {
  // 接收参数
 dynamic arguments = Get.arguments;
 List chatJson = chatData; // 聊天json
  List get chatList => renderChatList(); // 聊天消息列表
  // 表情json
 List emoJson = emotionData;
  // 底部操作栏模块
  TextEditingController editorController = TextEditingController();
  FocusNode editorFocusNode = FocusNode();
  bool voiceBtnEnable = false; // 语音按钮
  bool voicePanelEnable = false; // 语音操作面板
  bool voiceToTransfer = false; // 语音转文字中
  int voiceType = 0; // 语音操作类型
  Map voiceTypeMap = {
   0: '按住 说话', // 按住说话
    1: '松开 发送', // 松开发送
   2: '松开 取消', // 松开取消(左滑)
   3: '语音转文字', // 语音转文字(右滑)
  };
  bool toolbarEnable = false; // 显示表情/选择区域
  int toolbarIndex = 0; // 0 表情 1 选择
  double keyboardHeight = 307.6; // 键盘高度
  List chooseOptions = [
   {'key': 'photo', 'name': '相册', 'icon': 'assets/images/icon_photo.webp'},
    {'key': 'camera', 'name': '拍摄', 'icon': 'assets/images/icon_camera.webp'},
   {'key': 'media', 'name': '视频通话', 'icon': 'assets/images/icon_media.webp'},
    {'key': 'location', 'name': '位置', 'icon': 'assets/images/icon_location.webp'},
   {'key': 'redpacket', 'name': '红包', 'icon': 'assets/images/icon_hb.webp'},
    {'key': 'transfer', 'name': '转账', 'icon': 'assets/images/icon_transfer.webp'},
   {'key': 'voice', 'name': '语音输入', 'icon': 'assets/images/icon_voice.webp'},
  {'key': 'favorite', 'name': '收藏', 'icon': 'assets/images/icon_favorite.webp'},
 ];
  ScrollController chatController = ScrollController();
  ScrollController emojController = ScrollController();

  // 模拟開红包按钮动画
  late AnimationController animController = AnimationController(
   vsync: this,
    duration: Duration(milliseconds: 500),
  );
  // 创建一个从 0 到 π 的旋转动画
 late Animation<double> animTurns = Tween<double>(begin: 0, end: 3.1415926).animate(animController);

  // 播放器
 late final Player player = Player();
  late final VideoController controller = VideoController(player);

 String? currentPlayingAudioId;

  // 初始化状态
  @override
  void initState() {
    super.initState();
    // 编辑框获取焦点
    editorFocusNode.addListener(() {
    if(editorFocusNode.hasFocus) {
      setState(() {
        toolbarEnable = false;
      });
      scrollToBottom();
    }
  });
  }

  @override
  void dispose() {
  chatController.dispose();
  emojController.dispose();
  editorFocusNode.dispose();
  player.dispose();
  super.dispose();
}

// 渲染聊天消息
List<Widget> renderChatList() {
  List<Widget> msgtpl = [];
for(var item in chatJson) {
  if(item['contentType'] == 1 || item['contentType'] == 2) {
    msgtpl.add(
    Container(
    margin: const EdgeInsets.only(bottom: 15.0),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(item['content'], style: TextStyle(color: Colors.grey[600], fontSize: 12.0),),
      ],
    ),
    )
    );
  }
  else if(item['contentType'] == 3) {
    msgtpl.add(
      RenderChatItem(
        data: item,
      child: InkWell(
        overlayColor: WidgetStateProperty.all(Colors.transparent),
      borderRadius: BorderRadius.circular(4.0),
      child: Container(
        decoration: BoxDecoration(
          color: !item['isme'] ? Color(0xFFFFFFFF) : Color(0xFF89E45B),
          borderRadius: BorderRadius.circular(4.0),
        ),
        padding: const EdgeInsets.all(10.0),
        child: RichTextUtil.getRichText(item['content']), // 可自定义解析emoj/网址/电话
      ),
      onLongPress: () {
        contextMenuDialog(item);
      },
    ),
    )
    );
    }
    else if(item['contentType'] == 4) {
      msgtpl.add(
       RenderChatItem(
        data: item,
        child: InkWell(
          overlayColor: WidgetStateProperty.all(Colors.transparent),
          child: Container(
            constraints: const BoxConstraints(
              maxHeight: 100.0,
              maxWidth: 100.0,
            ),
            child: Image.asset(item['image']),
          ),
          onLongPress: () {
            contextMenuDialog(item);
          },
        ),
        )
        );
      }
      else if(item['contentType'] == 5) {
       msgtpl.add(
        RenderChatItem(
          data: item,
          child: InkWell(
          overlayColor: WidgetStateProperty.all(Colors.transparent),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4.0),
            child: ImageGroup(images: [item['image']], width: 125,),
          ),
          onLongPress: () {
            contextMenuDialog(item);
            },
          ),
          )
        );
      }
      else if(item['contentType'] == 6) {
      msgtpl.add(
       RenderChatItem(
         data: item,
        child: InkWell(
          overlayColor: WidgetStateProperty.all(Colors.transparent),
        child: SizedBox(
          width: 100.0,
          child: Stack(
           alignment: Alignment.center,
            children: [
          ClipRRect(
             borderRadius: BorderRadius.circular(4.0),
            child: Image.network(item['image'],),
           ),
          Container(
             height: 30.0,
            width: 30.0,
             decoration: BoxDecoration(
              color: Colors.black26,
               border: Border.all(color: Colors.white70),
              borderRadius: BorderRadius.circular(50.0)
             ),
            child: Icon(Icons.play_arrow, color: Colors.white, size: 20.0, ),
           ),
           ],
          ),
          ),
          onTap: () {
            showVideoDialog(item['video']);
          },
          onLongPress: () {
            contextMenuDialog(item);
            },
          ),
          ),
        );
      }
      else if(item['contentType'] == 7) {
       List<Widget> audiobody = [
        InkWell(
          overlayColor: WidgetStateProperty.all(Colors.transparent),
          borderRadius: BorderRadius.circular(4.0),
          child: Container(
            decoration: BoxDecoration(
            color: !item['isme'] ? const Color(0xFFFFFFFF) : const Color(0xFF89E45B),
            borderRadius: BorderRadius.circular(4.0),
          ),
          padding: const EdgeInsets.all(10.0),
          constraints: BoxConstraints(
            // maxWidth: 120.0,
            maxWidth: item['content']['duration'] / 60 * 230,
          ),
          child: Row(
            mainAxisAlignment: !item['isme'] ? MainAxisAlignment.start : MainAxisAlignment.end,
          children: !item['isme'] ? 
          [
            const Icon(Icons.multitrack_audio, size: 20.0,),
            const SizedBox(width: 5.0,),
            Text('${item['content']['duration']}"'),
          ]
          :
          [
            Text('${item['content']['duration']}"'),
            const SizedBox(width: 5.0,),
            const Icon(Icons.multitrack_audio, size: 20.0,),
            ],
          ),
        ),
        onTap: () async {
          final currentItemId = item['id'];
          if(player.state.playing && currentPlayingAudioId == currentItemId) {
          await player.stop();
            setState(() {
              currentPlayingAudioId = null;
            });
          }else {
          await player.open(Media('asset:///${item['content']['audio']}'));
          await player.play();
          setState(() {
            currentPlayingAudioId = currentItemId;
            final index = chatJson.indexWhere((item) => item['id'] == currentItemId);
            chatJson[index]['content']['unread'] = false;
          });
          }
        },
        onLongPress: () {
          contextMenuDialog(item);
        },
      ),
      const SizedBox(width: 5.0,),
      if (item['content']['unread'])
      Badge(backgroundColor: Colors.redAccent, smallSize: 8.0,)
    ];

    if(item['isme']) {
      // 内容反转
      audiobody = audiobody.reversed.toList();
     }else {
       audiobody = audiobody;
      }
     msgtpl.add(
       RenderChatItem(
        data: item,
         child: Row(
           mainAxisAlignment: !item['isme'] ? MainAxisAlignment.start : MainAxisAlignment.end,
            children: audiobody,
         )
        )
        );
      }
      else if(item['contentType'] == 8) {
       msgtpl.add(
        RenderChatItem(
          data: item,
          child: InkWell(
            overlayColor: WidgetStateProperty.all(Colors.transparent),
          borderRadius: BorderRadius.circular(4.0),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFFFFA52F),
            borderRadius: BorderRadius.circular(4.0),
          ),
          constraints: const BoxConstraints(
            maxWidth: 210.0,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            Container(
              padding: const EdgeInsets.all(10.0),
            child: Row(
              spacing: 10.0,
              children: <Widget>[
                Image.asset('assets/images/hbico.png', width: 23.0, fit: BoxFit.contain,),
                Text(item['content'], style: const TextStyle(color: Colors.white, fontSize: 15.0)),
              ],
            ),
          ),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 10.0),
            padding: const EdgeInsets.symmetric(vertical: 5.0),
            width: double.infinity,
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: Colors.white30, width: .5))
              ),
              child: const Text('拼手气红包', style: TextStyle(color: Colors.white70, fontSize: 11.0),),
            ),
            ],
            ),
          ),
          onTap: () {
            receiveRedPacketDialog(item);
          },
          onLongPress: () {
            contextMenuDialog(item);
          },
         ),
       )
       );
      }
      else if(item['contentType'] == 9) {
       msgtpl.add(
        RenderChatItem(
         data: item,
        child: InkWell(
          overlayColor: WidgetStateProperty.all(Colors.transparent),
          borderRadius: BorderRadius.circular(4.0),
          child: Container(
          decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(4.0),
        ),
        constraints: const BoxConstraints(
          maxWidth: 210.0,
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
           padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 5.0,),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(item['content']['address'], style: const TextStyle(fontSize: 15.0), overflow: TextOverflow.ellipsis,),
                Text(item['content']['location'], style: const TextStyle(color: Colors.grey, fontSize: 12.0), overflow: TextOverflow.ellipsis,),
              ],
              ),
            ),
            Image.asset(item['image'], width: 210.0, height: 70.0, fit: BoxFit.cover),
          ],
        ),
      ),
        onTap: () {
          MyDialog.toast('该功能暂未支持~', icon: Icon(Icons.warning), style: ToastStyle(backgroundColor: Colors.red.withAlpha(200)));
        },
        onLongPress: () {
          contextMenuDialog(item);
          },
          ),
        )
        );
      }
    }
    return msgtpl;
  }

  // 表情列表集合
  List<Widget> renderEmojWidget() {
    return [
      Container(
      padding: const EdgeInsets.symmetric(horizontal: 5.0),
      child: Row(
        children: emoJson.map((item) {
        return InkWell(
          child: Container(
          margin: const EdgeInsets.all(5.0),
          alignment: Alignment.center,
          height: 40.0,
          width: 40.0,
          decoration: BoxDecoration(
            color: item['selected'] ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(8.0)
          ),
          child: item['index'] == 0 ? Text(item['pathLabel'], style: const TextStyle(fontSize: 20.0),) : Image.asset(item['pathLabel'], height: 24.0, width: 24.0, fit: BoxFit.cover),
        ),
        onTap: () {
          handleEmojTab(item['index']);
          },
          );
        }).toList(),
        ),
      ),
      Expanded(
        child: Container(
          decoration: BoxDecoration(
          color: Colors.grey[200],
          border: const Border(top: BorderSide(color: Colors.black38, width: .1)),
        ),
        child: ListView(
          controller: emojController,
          padding: const EdgeInsets.all(10.0),
          children: emoJson.map((item) {
            return Visibility(
              visible: item['selected'],
              child: GridView(
                shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                // 横轴元素个数
                crossAxisCount: item['type'] == 'emoj' ? 8 : 5,
                // 纵轴间距
                mainAxisSpacing: 5.0,
                // 横轴间距
                crossAxisSpacing: 5.0,
                // 子组件宽高比例
                childAspectRatio: 1,
              ),
              children: item['nodes'].map<Widget>((emoj) {
                if(item['type'] == 'emoj') {
                  return Material(
                  type: MaterialType.transparency,
                child: InkWell(
                  borderRadius: BorderRadius.circular(4.0),
                  child: Container(
                    alignment: Alignment.center,
                    height: 40.0,
                    width: 40.0,
                    child: Text(emoj, style: const TextStyle(fontSize: 24.0),),
                  ),
                  onTap: () {
                    handleEmojClick(emoj);
                  },
                  ),
                );
              }else {
                return Material(
                type: MaterialType.transparency,
                child: InkWell(
                  borderRadius: BorderRadius.circular(4.0),
                child: Container(
                    alignment: Alignment.center,
                  padding: const EdgeInsets.all(5.0),
                    height: 68.0,
                    width: 68.0,
                    child: Image.asset(emoj),
                  ),
                  onTap: () {
                    handleGIFClick(emoj);
                  },
                ),
                );
              }
              }).toList(),
            ),
          );
          }).toList(),
        ),
        ),
      ),
    ];
  }
  // 选择功能列表
  List<Widget> renderChooseWidget() {
    return [
      Expanded(
        child: Container(
          padding: const EdgeInsets.fromLTRB(30.0, 35.0, 30.0, 15.0),
        decoration: BoxDecoration(
          color: Colors.grey[200],
          border: const Border(top: BorderSide(color: Colors.black38, width: .1)),
        ),
        child: GridView(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          // 横轴元素个数
          crossAxisCount: 4,
          // 纵轴间距
          mainAxisSpacing: 30.0,
          // 横轴间距
          crossAxisSpacing: 25.0,
          // 子组件宽高比例
          childAspectRatio: .8,
        ),
        children: chooseOptions.map((item) {
        return Column(
          children: [
          Expanded(
            child: Material(
            type: MaterialType.transparency,
            child: Ink(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(15.0),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(15.0),
                child: Image.asset(item['icon'], height: 40.0, fit: BoxFit.cover),
                onTap: () {
                  handleChooseAction(item['key']);
                  },
                ),
              ),
                ),
              ),
              const SizedBox(height: 5.0),
              Text(item['name'], style: const TextStyle(color: Colors.black87, fontSize: 12.0),)
            ],
          );
        }).toList(),
      ),
      ),
      ),
    ];
  }
  // 聊天消息滚动到底部
  void scrollToBottom({bool animated = false}) async {
    WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!chatController.hasClients) {
      return;
    }
    if(animated){
      chatController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }else {
      chatController.jumpTo(0);
    }
  });
  }

  // 点击消息区域
  void handleClickChatArea() {
    hideKeyboard();
  setState(() {
    toolbarEnable = false;
  });
  }

  /* ---------- { 底部Toolbar模块 } ---------- */
  // 光标处插入内容
  void insertTextAtCursor(String html) {
  var editorNotifier = editorController.value;
  var start = editorNotifier.selection.baseOffset;
  var end = editorNotifier.selection.extentOffset;
  if (editorNotifier.selection.isValid) {
    String newText = '';
    if (editorNotifier.selection.isCollapsed) {
    if (end > 0) {
      newText += editorNotifier.text.substring(0, end);
    }
    newText += html;
    if (editorNotifier.text.length > end) {
      newText += editorNotifier.text.substring(end, editorNotifier.text.length);
    }
  } else {
    newText = editorNotifier.text.replaceRange(start, end, html);
    end = start;
  }
  editorController.value = editorNotifier.copyWith(
    text: newText,
    selection: editorNotifier.selection.copyWith(
      baseOffset: end + html.length,
      extentOffset: end + html.length
    )
  );
} else {
  editorController.value = TextEditingValue(
    text: html,
    selection: TextSelection.fromPosition(TextPosition(offset: html.length)),
    );
    }
  }

  // 发送消息队列
 void sendMessage(dynamic message) {
   setState(() {
    chatJson.add(message);
  });
  scrollToBottom();
}
// 隐藏键盘
void hideKeyboard() {
  if(editorFocusNode.hasFocus) {
    editorFocusNode.unfocus();
  }
}
// 表情/选择切换
void handleEmojChooseState(int index) {
  hideKeyboard();
  setState(() {
   toolbarEnable = true;
    toolbarIndex = index;
    voiceBtnEnable = false;
   });
    scrollToBottom();
  }

  // 表情Tab切换
   void handleEmojTab(int index) {
    var emols = emoJson;
    for(var i = 0, len = emols.length; i < len; i++) {
      emols[i]['selected'] = false;
    }
    emols[index]['selected'] = true;
    setState(() {
     emoJson = emols;
    });
   emojController.jumpTo(0);
  }

  // 点击表情
  void handleEmojClick(dynamic emoj) {
  insertTextAtCursor(emoj);
}

// 点击Gif大图
void handleGIFClick(dynamic gifpath) {
   Map message = {
  'id': Utils.uuid(),
  'contentType': 4,
  'isme': true,
  'avatar': 'assets/images/avatar/img14.jpg',
  'author': 'Andy',
  'content': '',
  'image': gifpath,
  'video': '',
};
sendMessage(message);
}

 // 提交消息
  void handleSubmit() {
   final editorValue = editorController.text.trim();
    if(editorValue.isEmpty) return;
   Map message = {
    'id': Utils.uuid(),
    'contentType': 3,
    'isme': true,
    'avatar': 'assets/images/avatar/img14.jpg',
    'author': 'Andy',
    'content': editorValue,
    'image': '',
    'video': '',
  };
  sendMessage(message);
  editorController.clear();
 }
  // 选择区操作
 void handleChooseAction(String key) {
    MyDialog.toast(key);
   switch(key) {
    case 'photo':
      // ....
      break;
    case 'camera':
      // ....
      break;
    case 'redpacket':
      sendRedPacketDialog();
      break;
    }
  }
  // 红包弹窗
  void receiveRedPacketDialog(dynamic data) {
    showDialog(
      context: context,
      builder: (context) {
        return Material(
        type: MaterialType.transparency,
      child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
      Container(
        width: double.infinity,
        margin: const EdgeInsets.symmetric(horizontal: 50.0),
        padding: const EdgeInsets.symmetric(vertical: 50.0),
        decoration: const BoxDecoration(
        color: Color(0xFFDB5F46),
        borderRadius: BorderRadius.all(Radius.circular(10.0)),
      ),
      child: Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(4.0),
            child: Image.asset(data['avatar'], height: 40.0, width: 40.0, fit: BoxFit.cover),
          ),
          const SizedBox(height: 5.0,),
          Text(data['author'], style: const TextStyle(color: Color(0xFFFFF9C7), fontWeight: FontWeight.w600),),
          Text(data['content'], style: const TextStyle(color: Color(0xFFFFF9C7), fontWeight: FontWeight.w500, fontSize: 18.0),),
          SizedBox(height: 100.0,),
          AnimatedBuilder(
            animation: animTurns,
          builder:(context, child) {
          return Transform(
            transform: Matrix4.rotationY(animTurns.value),
          alignment: Alignment.center,
          child: FilledButton(
            style: ButtonStyle(
            backgroundColor: WidgetStateProperty.all(const Color(0xFFFFF9C7)),
            padding: WidgetStateProperty.all(EdgeInsets.zero),
            minimumSize: WidgetStateProperty.all(const Size(80.0, 80.0)),
              shape: WidgetStateProperty.all(const CircleBorder()),
              elevation: WidgetStateProperty.all(3.0),
            ),
            child: Text('開', style: TextStyle(color: Color(0xFF3B3B3B), fontSize: 28.0),),
            onPressed: () {
              // 开始动画
                animController.repeat();
                // 模拟开红包逻辑，1 秒后停止动画
                Future.delayed(Duration(seconds: 1), () {
                  animController.stop();
                  animController.reset();
                  Get.back();
                  });
                  },
                ),
                );
              },
              ),
              ],
            ),
          ),
          GestureDetector(
            child: Container(
            margin: const EdgeInsets.only(top: 20.0),
            height: 30.0,
            width: 30.0,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.white, width: 1.5),
              borderRadius: BorderRadius.circular(50.0),
            ),
            child: const Icon(Icons.close_outlined, color: Colors.white, size: 18.0,),
          ),
          onTap: () {
            Get.back();
            },
          )
        ],
        )
      );
      }
    );
  }
  // 视频弹窗
 void showVideoDialog(dynamic video) {
    player.open(Media(video));
    navigator?.push(FadeRoute(
      child: Scaffold(
      backgroundColor: Colors.black,
    extendBodyBehindAppBar: true,
    appBar: AppBar(
      backgroundColor: Colors.transparent,
      foregroundColor: Colors.white,
      automaticallyImplyLeading: false,
      leading: IconButton(
        icon: Icon(Icons.close, size: 20.0,),
        onPressed: () {
          controller.player.stop();
          Get.back();
        },
      ),
      actions: [
        IconButton(icon: const Icon(Icons.download), onPressed: () {},),
        IconButton(icon: const Icon(Icons.share), onPressed: () {},),
      ],
    ),
    body: Video(
      controller: controller,
      fill: Colors.black,
      fit: BoxFit.cover,
      ),
    )
  )).then((value) {
    controller.player.stop();
    });
  }

  // 长按消息菜单
  void contextMenuDialog(dynamic data) {
    showDialog(
      context: context,
      builder: (context) {
      return SimpleDialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(vertical: 7.5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0)),
      children: [
      SimpleDialogOption(
        child: Text('复制'),
        onPressed: () {},
      ),
      SimpleDialogOption(
        child: Text('发送给朋友'),
        onPressed: () {},
      ),
      SimpleDialogOption(
        child: Text('收藏'),
        onPressed: () {},
      ),
      SimpleDialogOption(
        child: Text('撤回'),
        onPressed: () {},
      ),
      SimpleDialogOption(
        child: Text('删除'),
        onPressed: () {
          setState(() {
            chatJson.removeWhere((item) => item['id'] == data['id']);
          });
          Get.back();
        },
        ),
      ],
      );
      },
    );
  }
  void sendRedPacketDialog() {
    showModalBottomSheet(
      backgroundColor: Colors.grey[100],
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(10.0))),
    showDragHandle: true,
    clipBehavior: Clip.hardEdge,
    isScrollControlled: true, // 屏幕最大高度
    constraints: BoxConstraints(
      maxHeight: MediaQuery.of(context).size.height - 180, // 自定义最大高度
    ),
    context: context,
    builder: (context) {
      return RedPacket(
      onChanged: (data) {
        // 消息队列
       Map message = {
         'id': Utils.uuid(),
          'contentType': 8,
         'isme': true,
          'avatar': 'assets/images/avatar/img14.jpg',
         'author': 'Andy',
          'content': data?['msg'],
         'image': '',
          'video': '',
       };
       sendMessage(message);
      },
      );
    },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
      // 页面主体(聊天消息区/底部操作区)
      Scaffold(
        backgroundColor: Colors.grey[200],
        appBar: AppBar(
      backgroundColor: Colors.transparent,
      foregroundColor: Colors.white,
      leading: IconButton(
        icon: Icon(Icons.arrow_back_ios_rounded, size: 20.0,),
        onPressed: () {
          Get.back();
        },
      ),
      titleSpacing: 1.0,
      title: Text('${arguments['title']}', style: TextStyle(fontSize: 18.0),),
      flexibleSpace: Container(
        decoration: const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFF00ADFD), Color(0xFF00EE8B)
        ],
      )
      ),
    ),
    actions: [
      IconButton(icon: const Icon(Icons.more_horiz, color: Colors.white,), onPressed: () {},),
    ],
    ),
    body: Flex(
      direction: Axis.vertical,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(
        child: ScrollConfiguration(
        behavior: CustomScrollBehavior(),
      child: GestureDetector(
        child: SingleChildScrollView(
          controller: chatController,
        reverse: true,
        child: ListView.builder(
          physics: NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.all(10.0),
            shrinkWrap: true,
            itemCount: chatList.length,
            itemBuilder: (context, index) => chatList[index],
          ),
        ),
        onTap: () {
          handleClickChatArea();
          },
          ),
          ),
        ),
        // 底部操作栏
        Container(
          decoration: BoxDecoration(
            color: Colors.grey[100],
            border: const Border(top: BorderSide(color: Colors.black38, width: .1)),
          ),
          child: Column(
            children: [
              // 输入框编辑器模块
              Container(
              padding: const EdgeInsets.all(10.0),
              child: Row(
                children: [
                  InkWell(
                child: Icon(voiceBtnEnable ? Icons.keyboard_outlined : Icons.contactless_outlined, color: const Color(0xFF3B3B3B), size: 30.0,),
                onTap: () {
                  setState(() {
                    toolbarEnable = false;
                    if(voiceBtnEnable) {
                    voiceBtnEnable = false;
                    editorFocusNode.requestFocus();
                  }else {
                    voiceBtnEnable = true;
                    editorFocusNode.unfocus();
                    }
                      });
                    },
                  ),
                  const SizedBox(width: 10.0,),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        padding: EdgeInsets.symmetric(vertical: 8.0),
                        child: Stack(
                          children: [
                          // 输入框
                          Offstage(
                            offstage: voiceBtnEnable,
                                child: ConstrainedBox(
                                constraints: BoxConstraints(maxHeight: 300.0),
                            child: TextField(
                              decoration: const InputDecoration(
                                isDense: true,
                                hoverColor: Colors.transparent,
                                border: OutlineInputBorder(borderSide: BorderSide.none),
                                contentPadding: EdgeInsets.fromLTRB(8.0, 0, 8.0, 0),
                              ),
                              style: const TextStyle(fontSize: 16.0,),
                              maxLines: null,
                              controller: editorController,
                              focusNode: editorFocusNode,
                              cursorColor: const Color(0xFF07C160),
                                onChanged: (value) {},
                                ),
                              ),
                            ),
                            // 语音
                            Offstage(
                              offstage: !voiceBtnEnable,
                              child: GestureDetector(
                                child: Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(4.0),
                              ),
                              alignment: Alignment.center,
                              height: 24.0,
                              width: double.infinity,
                              child: Text(voiceTypeMap[voiceType], style: const TextStyle(fontSize: 15.0),),
                            ),
                            onPanStart: (details) {
                              setState(() {
                                voiceType = 1;
                                voicePanelEnable = true;
                              });
                                },
                                onPanUpdate: (details) {
                                Offset pos = details.globalPosition;
                                double swipeY = MediaQuery.of(context).size.height - 120;
                                double swipeX = MediaQuery.of(context).size.width / 2 + 50;
                                setState(() {
                                  if(pos.dy >= swipeY) {
                                    voiceType = 1; // 松开发送
                                  }else if (pos.dy < swipeY && pos.dx < swipeX) {
                                    voiceType = 2; // 左滑松开取消
                                  }else if (pos.dy < swipeY && pos.dx >= swipeX) {
                                      voiceType = 3; // 右滑语音转文字
                                    }
                                  });
                                },
                                  onPanEnd: (details) {
                                  setState(() {
                                    switch(voiceType) {
                                      case 1:
                                        MyDialog.toast('发送录音文件');
                                        voicePanelEnable = false;
                                        break;
                                      case 2:
                                        MyDialog.toast('取消发送');
                                        voicePanelEnable = false;
                                        break;
                                      case 3:
                                        MyDialog.toast('语音转文字');
                                        voicePanelEnable = true;
                                        voiceToTransfer = true;
                                        break;
                                      }
                                      voiceType = 0;
                                      });
                                    },
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 10.0,),
                          InkWell(
                          child: const Icon(Icons.emoji_emotions_outlined, color: Color(0xFF3B3B3B), size: 30.0,),
                          onTap: () {
                            handleEmojChooseState(0);
                          },
                        ),
                        const SizedBox(width: 8.0,),
                        InkWell(
                          child: const Icon(Icons.add_circle_outline, color: Color(0xFF3B3B3B), size: 30.0,),
                          onTap: () {
                            handleEmojChooseState(1);
                          },
                        ),
                        const SizedBox(width: 8.0,),
                        InkWell(
                          child: Container(
                          height: 25.0,
                          width: 25.0,
                          decoration: BoxDecoration(
                            color: const Color(0xFF07C160),
                            borderRadius: BorderRadius.circular(20.0),
                          ),
                          child: const Icon(Icons.arrow_upward, color: Colors.white, size: 20.0,),
                        ),
                        onTap: () {
                            handleSubmit();
                          },
                        ),
                      ],
                    ),
                  ),

                  // 表情+选择模块
                  Visibility(
                    visible: toolbarEnable,
                    child: SizedBox(
                      height: keyboardHeight,
                      child: Column(
                        children: toolbarIndex == 0 ? renderEmojWidget() : renderChooseWidget(),
                      ),
                    ),
                  )
                  ],
                ),
              )
            ],
          ),
        ),
        IgnorePointer(
          ignoring: false,
          child: Visibility(
          visible: voicePanelEnable,
          child: Material(
            color: const Color(0xDD1B1B1B),
            child: Stack(
            children: [
            Positioned(
              bottom: 120,
              left: 30,
              right: 30,
              child: Visibility(
                visible: !voiceToTransfer,
              child: Column(
                crossAxisAlignment: voiceType == 2 ? CrossAxisAlignment.start : CrossAxisAlignment.center,
              children: [
                // 语音动画层
                Stack(
                  alignment: Alignment.bottomCenter,
                children: [
                  Container(
                    decoration: BoxDecoration(
                    color: voiceType == 2 ? Colors.red : Color(0xFF89E45B),
                    borderRadius: BorderRadius.circular(10.0),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: AnimatedContainer(
                    duration: Duration(milliseconds: 200),
                    height: 70.0,
                  width: voiceType == 2 ? 70.0 : voiceType == 3 ? 320.0 : 200.0,
                  child: FittedBox(
                    alignment: voiceType == 3 ? Alignment.bottomRight : Alignment.center,
                    fit: BoxFit.scaleDown,
                    child: Padding(
                      padding: EdgeInsets.all(10.0),
                      child: Waves(waveCount: voiceType == 2 ? 10 : voiceType == 3 ? 10 : 20),
                    ),
                    ),
                  ),
                  ),
                  Positioned(
                    right: voiceType == 3 ? 35.0 : null,
                    bottom: 1,
                    child: RotatedBox(
                      quarterTurns: 0,
                      child: CustomPaint(painter: ArrowShape(arrowColor: voiceType == 2 ? Colors.red : Color(0xFF89E45B), arrowSize: 10.0)),
                    ),
                    ),
                    ],
                  ),
                    const SizedBox(height: 50.0,),
                    // 操作项
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // 取消发送
                      Transform.rotate(
                      angle: -10 * (pi / 180),
                      child: Container(
                        height: 60.0,
                        width: 60.0,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(50.0),
                          color: voiceType == 2 ? Colors.red : Colors.black38,
                        ),
                        child: Icon(Icons.close, color: Colors.white54,),
                      ),
                    ),
                    // 语音转文字
                    Transform.rotate(
                      angle: 10 * (pi / 180),
                    child: Container(
                      height: 60.0,
                      width: 60.0,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(50.0),
                        color: voiceType == 3 ? Color(0xFF89E45B) : Colors.black38,
                      ),
                      child: Icon(Icons.translate, color: Colors.white54,),
                        ),
                      ),
                    ],
                    ),
                  ],
                  ),
                ),
              ),
              // 语音转文字(识别结果状态)
              Positioned(
                bottom: 120,
                left: 30,
                right: 30,
                child: Visibility(
                  visible: voiceToTransfer,
              child: Column(
                  children: [
                  // 提示结果
                  Stack(
                  children: [
                  Container(
                  height: 100.0,
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(10.0),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.info_outlined, color: Colors.white,),
                      Text('未识别到文字。', style: TextStyle(color: Colors.white),),
                    ],
                    ),
                  ),
                  Positioned(
                    right: 35.0,
                    bottom: 1,
                  child: RotatedBox(
                      quarterTurns: 0,
                      child: CustomPaint(painter: ArrowShape(arrowColor: Colors.red, arrowSize: 10.0)),
                      )
                    ),
                    ],
                  ),
                  const SizedBox(height: 50.0,),
                  // 操作项
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    GestureDetector(
                    child: Container(
                      height: 60.0,
                      width: 60.0,
                      decoration: const BoxDecoration(
                        color: Colors.transparent,
                      ),
                      child: const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.undo, color: Colors.white54,),
                          Text('取消', style: TextStyle(color: Colors.white70),)
                        ],
                      ),
                    ),
                    onTap: () {
                      setState(() {
                        voicePanelEnable = false;
                        voiceToTransfer = false;
                        });
                      },
                    ),
                    GestureDetector(
                    child: Container(
                        height: 60.0,
                        width: 100.0,
                        decoration: const BoxDecoration(
                        color: Colors.transparent,
                      ),
                      child: const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.graphic_eq_rounded, color: Colors.white54,),
                          Text('发送原语音', style: TextStyle(color: Colors.white70),)
                        ],
                        ),
                        ),
                        onTap: () {},
                      ),
                    GestureDetector(
                      child: Container(
                      height: 60.0,
                      width: 60.0,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(50.0),
                          color: Colors.white12,
                        ),
                        child: const Icon(Icons.check, color: Colors.white12,),
                      ),
                      onTap: () {},
                    ),
                    ],
                    ),
                  ],
                ),
                ),
              ),
              // 提示文字(操作状态)
            Positioned(
              bottom: 120,
              left: 0,
            width: MediaQuery.of(context).size.width,
          child: Visibility(
              visible: !voiceToTransfer,
              child: Align(
                child: Text(voiceTypeMap[voiceType], style: const TextStyle(color: Colors.white70),),
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Visibility(
              visible: !voiceToTransfer,
              child: Image.asset('assets/images/voice_bg.webp', width: double.infinity, height: 100.0, fit: BoxFit.fill),
            ),
            ),
            Positioned(
              bottom: 25,
              left: 0,
            width: MediaQuery.of(context).size.width,
            child: Visibility(
              visible: !voiceToTransfer,
              child: const Align(
                child: Icon(Icons.graphic_eq_rounded, color: Colors.black54,),
              ),
            ),
          ),
          ],
        ),
        ),
      ),
      )
    ],
    );
  }
}

// 渲染聊天消息公共部分
class RenderChatItem extends StatelessWidget {
  const RenderChatItem({
    super.key,
    required this.data,
  required this.child,
});
final dynamic data; // 消息数据
final Widget? child; // 消息体

// 设置箭头颜色
Color arrowColor(dynamic data) {
  Color color = Colors.transparent;
  if([8].contains(data['contentType'])) {
    // 红包箭头颜色
    color = const Color(0xFFFFA52F);
  }else if([9].contains(data['contentType'])) {
    // 位置箭头颜色
    color = const Color(0xFFFFFFFF);
  }else {
    color = !data['isme'] ? const Color(0xFFFFFFFF) : const Color(0xFF89E45B);
  }
  return color;
}

@override
Widget build(BuildContext context){
    return RepaintBoundary(
    child: Container(
      margin: const EdgeInsets.only(bottom: 10.0),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
      !data['isme'] ? SizedBox(height: 35.0, width: 35.0, child: ClipRRect(borderRadius: const BorderRadius.all(Radius.circular(20.0)), child: Image.asset(data['avatar']),),) : const SizedBox.shrink(),
    Expanded(
      child: Padding(
      padding: !data['isme'] ? const EdgeInsets.only(left: 10.0, right: 40.0) : const EdgeInsets.only(left: 40.0, right: 10.0),
      child: Column(
        crossAxisAlignment: !data['isme'] ? CrossAxisAlignment.start : CrossAxisAlignment.end,
      children: [
        Text(data['author'], style: const TextStyle(color: Colors.grey, fontSize: 12.0),),
      const SizedBox(height: 3.0,),
      Stack(
        children: [
        Visibility(
          // 显示箭头(消息+语音+红包+位置)
          visible: [3, 7, 8, 9].contains(data['contentType']),
          child: Positioned(
            left: !data['isme'] ? 1 : null,
            right: data['isme'] ? 1 : null,
            top: 19.0,
            child: RotatedBox(
              quarterTurns: !data['isme'] ? 1 : -1,
              child: CustomPaint(painter: ArrowShape(arrowColor: arrowColor(data))),
              )
            ),
          ),
          Container(
              child: child,
            ),
          ],
          ),
        ],
          ),
        ),
      ),
      data['isme'] ? SizedBox(height: 35.0, width: 35.0, child: ClipRRect(borderRadius: const BorderRadius.all(Radius.circular(20.0)), child: Image.asset(data['avatar']),),) : const SizedBox.shrink(),
    ],
      ),
    ),
    );
  }
}

// 绘制气泡箭头
class ArrowShape extends CustomPainter {
 ArrowShape({
  required this.arrowColor,
 this.arrowSize = 7,
});
final Color arrowColor;
final double arrowSize;

@override
void paint(Canvas canvas, Size size) {
 var paint = Paint()..color = arrowColor;
  var path = Path();
  path.lineTo(-arrowSize, 0);
  path.lineTo(0, arrowSize);
  path.lineTo(arrowSize, 0);
  canvas.drawPath(path, paint);
}

@override
bool shouldRepaint(CustomPainter oldDelegate) {
  return false;
}
}
