import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import '../../behavior/custom_scroll_behavior.dart';

class ChatPage extends StatefulWidget {
  const ChatPage({super.key});
  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  // 模拟聊天记录
  List chatList = [
    {
    'uid': 202605152241,
    'type': 'system',
    'avatar': const Icon(Icons.tips_and_updates_outlined, color: Colors.white,),
    'title': '客服消息',
    'subtitle': '智能小助手: 帮助你更快涨粉~',
    'arrow': true,
  },
  {
    'uid': 202605152245,
    'type': 'chat',
    'avatar': 'assets/images/flutter.png',
    'title': 'Flutter3.41抖音商城',
    'subtitle': '原创flutter3.41仿抖音短视频+直播商城。',
    'time': '5月18日',
    'badge': 2,
    // 'topMost': true,
    'disturb': true
  },
  {
    'uid': 202605152248,
    'type': 'chat',
    'avatar': 'assets/images/avatar/img01.jpg',
    'title': 'Flutter交流群',
    'subtitle': 'flutter3.41项目实战案例。',
    'time': '22:47',
    'dot': true
    },
  ];

  // 记录按压位置
  Offset? longPressPosition;
  // 长按菜单
void showContextMenu() {
  showMenu(
  context: context,
  position: RelativeRect.fromRect(
    Rect.fromPoints(longPressPosition!, longPressPosition!),
    Offset.zero & MediaQuery.of(context).size,
  ),
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4.0)),
  elevation: 2.0,
  color: Colors.white,
  constraints: BoxConstraints(minWidth: 125.0),
  items: [
    PopupMenuItem(
      height: 36.0,
      child: Text('设为免打扰', style: TextStyle(fontWeight: FontWeight.normal),),
    ),
    PopupMenuItem(
      height: 36.0,
      child: Text('置顶消息', style: TextStyle(fontWeight: FontWeight.normal),),
    ),
    PopupMenuItem(
      height: 36.0,
      child: Text('不显示该消息', style: TextStyle(fontWeight: FontWeight.normal),),
    ),
    PopupMenuItem(
      height: 36.0,
      child: Text('删除', style: TextStyle(fontWeight: FontWeight.normal),),
    ),
    ]
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
    appBar: AppBar(
      backgroundColor: Colors.transparent,
      foregroundColor: Colors.white,
      title: Text('消息', style: TextStyle(fontSize: 18.0),),
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
        IconButton(icon: const Icon(Icons.search, color: Colors.white,), onPressed: () {},),
        IconButton(icon: const Icon(Icons.settings_outlined, color: Colors.white,), onPressed: () {},),
      ],
    ),
    body: ScrollConfiguration(
      behavior: CustomScrollBehavior().copyWith(scrollbars: false),
      child: Column(
        children: [
        Container(
          margin: EdgeInsets.all(15.0),
        padding: EdgeInsets.all(10.0),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10.0),
          boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(10),
            offset: Offset(0.0, 1.0),
            blurRadius: 1.0,
            spreadRadius: 0.0,
          ),
          ]
        ),
        child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
          Column(
            spacing: 5.0,
            children: [
             SvgPicture.asset('assets/images/svg/order.svg', height: 36.0, width: 36.0,),
              Text('订单交易', style: TextStyle(fontSize: 13.0),),
            ],
          ),
          Column(
            spacing: 5.0,
            children: [
             SvgPicture.asset('assets/images/svg/kefu.svg', height: 36.0, width: 36.0,),
              Text('客服消息', style: TextStyle(fontSize: 13.0),),
            ],
          ),
            Column(
              spacing: 5.0,
              children: [
                SvgPicture.asset('assets/images/svg/comment.svg', height: 36.0, width: 36.0,),
               Text('评价通知', style: TextStyle(fontSize: 13.0),),
              ],
            ),
            Column(
              spacing: 5.0,
              children: [
               SvgPicture.asset('assets/images/svg/coupon.svg', height: 36.0, width: 36.0,),
                Text('优惠券', style: TextStyle(fontSize: 13.0),),
             ],
             ),
            ],
            ),
          ),
          Expanded(
           child: ListView.builder(
            shrinkWrap: true,
           physics: BouncingScrollPhysics(),
            itemCount: chatList.length,
             itemBuilder: (context, index) {
             final item = chatList[index];
            return Ink(
             color: item['topMost'] == null ? Colors.white : Colors.grey[100], //置顶颜色
              child: InkWell(
             splashColor: Colors.grey[200],
              child: Container(
               padding: const EdgeInsets.symmetric(horizontal: 15.0, vertical: 10.0),
                child: Row(
               spacing: 10.0,
               children: <Widget>[
                 ClipOval(
                    child: item['type'] == 'system' ?
                    Container(
                      alignment: Alignment.center,
                      height: 50.0,
                      width: 50.0,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(50.0),
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                             Color(0xFFFFD7B3), Color(0xFFFF2C55)
                            ],
                         )
                        ),
                        child: item['avatar'],
                       )
                        :
                       Image.asset('${item['avatar']}', height: 50.0, width: 50.0, fit: BoxFit.cover,)
                      ,
                    ),
                    // 消息
                    Expanded(
                      child: Column(
                       crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(item['title'], style: const TextStyle(fontSize: 16.0),),
                         const SizedBox(height: 2.0),
                        Text(item['subtitle'], style: const TextStyle(color: Colors.grey, fontSize: 13.0), overflow: TextOverflow.ellipsis,),
                        ],
                       ),
                       ),
                        // 右侧
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: <Widget>[
                        Visibility(visible: item['time'] != null, child: Text('${item['time']}', style: const TextStyle(color: Colors.grey, fontSize: 12.0),),),
                        const SizedBox(height: 5.0),
                        // 数字角标
                        Badge.count(
                          isLabelVisible: item['badge'] != null,
                          count: 2,
                          backgroundColor: Colors.redAccent,
                        ),
                        // 圆点角标
                        Badge(
                          isLabelVisible: item['dot'] != null,
                          backgroundColor: Colors.redAccent,
                          smallSize: 8.0,
                        ),
                      ],
                    ),
                      Visibility(visible: item['arrow'] != null, child: const Icon(Icons.arrow_forward_ios, color: Colors.grey, size: 12.0,),),
                    ],
                  ),
                ),
                onTap: () {
                  if(item['type'] == 'chat') {
                    Get.toNamed('/chat', arguments: item);
                  }
                },
                onTapDown: (TapDownDetails details) {
                  longPressPosition = details.globalPosition;
                },
                onLongPress: () {
                  showContextMenu();
                },
              ),
              );
            },
            ),
          ),
        ],
      ),
    ),
    );
  }
}
