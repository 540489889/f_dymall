/// 直播模板
library;

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import '../../router/fade_route.dart';
import '../../behavior/custom_scroll_behavior.dart';
import './mock/live_json.dart';
import './components/animation_join.dart';
import './components/animation_gift.dart';
import './components/popup_comment.dart';
import './components/popup_goods.dart';
import './components/popup_gift.dart';
import './components/popup_more.dart';
import './components/popup_recharge.dart';
import './components/popup_redpacket.dart';

class Live extends StatefulWidget {
  const Live({super.key});

  @override
  State<Live> createState() => _LiveState();
}

class _LiveState extends State<Live> {
  // 接收参数
dynamic arguments = Get.arguments;
// 垂直滑动页面controller
late PageController pageVerticalController;
// 水平滑动controller
late PageController pageHorizontalController;

late Player player = Player();
late VideoController liveVideoController = VideoController(player);

// 当前索引
final ValueNotifier<int> liveIndexNotifier = ValueNotifier(0);
// 当前时长
final ValueNotifier<Duration> positionNotifier = ValueNotifier(Duration.zero);
bool goodsTalkVisible = true;

  @override
  void initState() {
  super.initState();

  liveIndexNotifier.value = liveJson.indexWhere((item) => item['id'] == arguments['id']);
  pageVerticalController = PageController(initialPage: liveIndexNotifier.value, viewportFraction: 1.0);
  pageHorizontalController = PageController(initialPage: 1, viewportFraction: 1.0);
  player.open(Media(arguments['src']));
  player.setPlaylistMode(PlaylistMode.loop);
  // 监听视频播放进度
  player.stream.position.listen((event) {
    positionNotifier.value = event;
    });
  }

  @override
  void setState(VoidCallback fn) {
    if (mounted) {
      super.setState(fn);
    }
  }

  @override
  void dispose() {
  player.dispose();
  pageVerticalController.dispose();
  pageHorizontalController.dispose();
  super.dispose();
}

// 弹幕列表
List<Widget> danmuList(dynamic list) {
  List<Widget> danmu = [];
  for(var item in list) {
    // 公告
  if(item['type'] == 'notice') {
    danmu.add(
    Container(
        margin: EdgeInsets.symmetric(vertical: 2.0),
        padding: EdgeInsets.all(8.0),
        decoration: BoxDecoration(
          color: Colors.black26,
          borderRadius: BorderRadius.circular(12.0),
        ),
        child: Text('${item['content']}', style: TextStyle(color: Color(0xFF8CE7FF), fontSize: 13.0),),
      ),
    );
  }
  // 礼物消息
  else if(item['type'] == 'gift') {
    danmu.add(
      Container(),
      );
    }
    // 其它消息（直播聊天弹幕消息自适应布局: Flexible配合Text.rich / TextSpan）
    else {
      danmu.add(
      Row(
        children: [
        Flexible(
          child: Container(
        margin: EdgeInsets.symmetric(vertical: 2.0),
        padding: EdgeInsets.symmetric(horizontal: 8.0, vertical: 2.0),
        decoration: BoxDecoration(
          color: Colors.black26,
          borderRadius: BorderRadius.circular(12.0),
        ),
        child: Text.rich(
          TextSpan(
          children: [
          WidgetSpan(
            child: Visibility(
            visible: item['tag'] != null,
          child: Container(
            margin: EdgeInsets.only(right: 5.0,),
            padding: EdgeInsets.symmetric(horizontal: 5.0),
            decoration: BoxDecoration(
              color: Color(0xFFD631F3),
              borderRadius: BorderRadius.circular(12.0),
              ),
              child: Text('${item['tag']}', style: TextStyle(color: Colors.white, fontSize: 13.0),),
            ),
          ),
        ),
        TextSpan(text: '${item['user']}：', style: TextStyle(color: Color(0xFF8CE7FF), fontSize: 13.0),),
        TextSpan(text: '${item['isbuy'] != null ? '下单1号商品' : item['content']}', style: TextStyle(color: item['isbuy'] != null ? Colors.yellow : Colors.white, fontSize: 13.0),),
        WidgetSpan(
          child: Visibility(
            visible: item['isbuy'] != null,
            child: Container(
            margin: EdgeInsets.only(left: 5.0,),
            padding: EdgeInsets.symmetric(horizontal: 5.0),
                decoration: BoxDecoration(
                  color: Color(0xFFFF2C55),
                  borderRadius: BorderRadius.circular(12.0),
                ),
                child: Text('去购买', style: TextStyle(color: Colors.white, fontSize: 13.0),),
              ),
            ),
            ),
            ],
          ),
        ),
      ),
      ),
    ],
      ),
      );
    }
    }
    return danmu;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
    appBar: AppBar(
      forceMaterialTransparency: true,
      backgroundColor: Colors.black,
      foregroundColor: Colors.white,
      toolbarHeight: 0,
    ),
    body: Column(
      children: [
        Expanded(
          child: Stack(
          children: [
          PageView.builder(
            scrollBehavior: CustomScrollBehavior().copyWith(scrollbars: false),
            scrollDirection: Axis.vertical,
            controller: pageVerticalController,
            onPageChanged: (index) async {
              await player.open(Media(liveJson[index]['src']));
              liveIndexNotifier.value = index;
              positionNotifier.value = Duration.zero;
            },
            itemCount: liveJson.length,
            itemBuilder: (context, index) {
            final item = liveJson[index];
            return Stack(
              children: [
                Positioned.fill(
                child: ImageFiltered(
                  imageFilter: ImageFilter.blur(sigmaX: 50.0, sigmaY: 50.0),
                  child: CachedNetworkImage(imageUrl: '${item['poster']}', fit: BoxFit.cover,),
                ),
              ),
              // 视频区域
              Positioned.fill(
                child: Stack(
                    children: [
                    ValueListenableBuilder(
                      valueListenable: liveIndexNotifier,
                    builder: (context, liveIndex, child) {
                      return ValueListenableBuilder(
                        valueListenable: positionNotifier,
                      builder: (context, position, child) {
                        return Visibility(
                          visible: liveIndex == index && position > Duration.zero,
                            child: Video(
                              controller: liveVideoController,
                              fit: BoxFit.cover,
                                // 无控制条
                                controls: NoVideoControls,
                              ),
                              );
                            }
                            );
                          },
                          ),
                        ],
                      ),
                    ),
                    /// 水平滚动模块(清屏/浮层)
                    PageView(
                      scrollBehavior: CustomScrollBehavior().copyWith(scrollbars: false),
                      scrollDirection: Axis.horizontal,
                    controller: pageHorizontalController,
                    onPageChanged: (index) {
                      // ...
                    },
                    children: [
                      // 直播清屏
                      Container(
                      alignment: Alignment.bottomRight,
                      padding: EdgeInsets.all(7.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        spacing: 7.0,
                        children: [
                            Container(
                                alignment: Alignment.center,
                                height: 35.0,
                                width: 35.0,
                              decoration: BoxDecoration(
                                color: Colors.black26,
                                borderRadius: BorderRadius.circular(50.0),
                              ),
                              child: Icon(Icons.help, color: Colors.white,),
                            ),
                            Container(
                              alignment: Alignment.center,
                              height: 35.0,
                              width: 35.0,
                              decoration: BoxDecoration(
                                color: Colors.black26,
                                borderRadius: BorderRadius.circular(50.0),
                              ),
                              child: Icon(Icons.clear_all_rounded, color: Colors.white,),
                            ),
                            ],
                          ),
                          ),
                          // 直播浮层
                          Stack(
                            children: [
                              Positioned(
                              top: MediaQuery.of(context).padding.top + 7,
                              left: 10.0,
                              right: 0,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                              // 直播间头像
                              Container(
                                margin: const EdgeInsets.only(bottom: 7.0, right: 10.0),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(1.0),
                                  decoration: BoxDecoration(
                                  color: Colors.black12,
                                  borderRadius: BorderRadius.circular(50.0),
                                ),
                                child: Row(
                                  children: [
                                    ClipOval(child: Image.network('${item['logo']}', height: 30.0,),),
                                    SizedBox(width: 3.0,),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('${item['name']}', style: TextStyle(color: Colors.white, fontSize: 12.0),),
                                        Text('${item['likeNum']}万本场点赞', style: TextStyle(color: Colors.white70, fontSize: 8.0),),
                                      ],
                                    ),
                                    GestureDetector(
                                      child: Container(
                                        height: 26.0,
                                        width: 50.0,
                                        margin: EdgeInsets.all(2.0),
                                        alignment: Alignment.center,
                                        decoration: BoxDecoration(
                                          color: item['isFollow'] ? Colors.white : Color(0xFFFF2C55),
                                            borderRadius: BorderRadius.circular(50.0),
                                          ),
                                          child: Text(item['isFollow'] ? '已关注' : '关注', style: TextStyle(color: item['isFollow'] ? Color(0xFFFF2C55) : Colors.white, fontSize: 12.0),),
                                        ),
                                        onTap: () {
                                          setState(() {
                                            item['isFollow'] = !item['isFollow'];
                                              });
                                            },
                                          )
                                        ],
                                        ),
                                      ),
                                    Expanded(
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.end,
                                          children: [
                                            Container(
                                              height: 25.0,
                                              width: 25.0,
                                              alignment: Alignment.center,
                                              child: IconButton(
                                                icon: const Icon(Icons.close, color: Colors.white70, size: 16.0),
                                                style: ButtonStyle(backgroundColor: WidgetStateProperty.all(Colors.black12)),
                                                padding: EdgeInsets.zero,
                                                onPressed: () {Get.back();},
                                              ),
                                            )
                                          ],
                                            ),
                                          ),
                                          ],
                                        ),
                                      ),
                                      // 排名统计
                                    Container(
                                      margin: const EdgeInsets.only(bottom: 7.0),
                                    child: Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.fromLTRB(3.0, 1.0, 7.0, 1.0),
                                          decoration: BoxDecoration(
                                            color: Colors.black12,
                                            borderRadius: BorderRadius.circular(50.0),
                                          ),
                                          child: const Row(
                                            children: [
                                              Icon(Icons.military_tech_outlined, color: Colors.yellow, size: 14.0,),
                                              Text('带货总榜第1名', style: TextStyle(color: Colors.white, fontSize: 12.0),),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 5.0,),
                                        Container(
                                          padding: const EdgeInsets.fromLTRB(3.0, 1.0, 7.0, 1.0),
                                          decoration: BoxDecoration(
                                          color: Colors.black12,
                                          borderRadius: BorderRadius.circular(50.0),
                                        ),
                                        child: const Row(
                                          children: [
                                            Icon(Icons.bar_chart_rounded, color: Colors.yellow, size: 14.0,),
                                            Text('人气榜', style: TextStyle(color: Colors.white, fontSize: 12.0),),
                                          ],
                                        ),
                                        ),
                                      ],
                                      ),
                                    ),
                                    // 红包活动
                                  Container(
                                    margin: const EdgeInsets.only(bottom: 7.0),
                                  child: Row(
                                    spacing: 5.0,
                                    children: [
                                      Stack(
                                        children: [
                                        GestureDetector(
                                          child: Container(
                                        height: 36.0,
                                        width: 36.0,
                                        decoration: BoxDecoration(
                                          color: Colors.black12,
                                          borderRadius: BorderRadius.circular(6.0),
                                        ),
                                        child: Align(
                                          alignment: Alignment.bottomCenter,
                                          child: Image.asset('assets/images/icon-hb.png', width: 36.0,),
                                        ),
                                      ),
                                      onTap: () {
                                        showDialog(
                                          context: context,
                                          builder: (context) {
                                            return PopupRedpacket();
                                            },
                                          );
                                          },
                                        ),
                                        Positioned(
                                          bottom: 0,
                                          left: 3.0,
                                        right: 3.0,
                                        child: Container(
                                          alignment: Alignment.center,
                                          decoration: BoxDecoration(
                                              color: Colors.black38,
                                              borderRadius: BorderRadius.circular(6.0),
                                            ),
                                            child: const Text('03:25', style: TextStyle(color: Colors.white, fontSize: 8.0),),
                                          ),
                                          )
                                          ],
                                        ),
                                        Stack(
                                        children: [
                                          Container(
                                            height: 36.0,
                                          width: 36.0,
                                          decoration: BoxDecoration(
                                            color: Colors.black12,
                                            borderRadius: BorderRadius.circular(6.0),
                                          ),
                                          child: Align(
                                            alignment: Alignment.bottomCenter,
                                            child: Image.asset('assets/images/icon-fudai.png', width: 36.0,),
                                          ),
                                        ),
                                        Positioned(
                                          bottom: 0,
                                          left: 3.0,
                                          right: 3.0,
                                          child: Container(
                                            alignment: Alignment.center,
                                              decoration: BoxDecoration(
                                                color: Colors.black38,
                                                borderRadius: BorderRadius.circular(6.0),
                                              ),
                                              child: const Text('01:30', style: TextStyle(color: Colors.white, fontSize: 8.0),),
                                            ),
                                          )
                                          ],
                                        ),
                                        ],
                                      ),
                                      ),
                                    ],
                                  ),
                                ),
                              // 底部区域
                              Positioned(
                                bottom: 7.0,
                                left: 10.0,
                              right: 10.0,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                              // 商品购买动效
                              Container(
                              margin: EdgeInsets.only(top: 7.0),
                              clipBehavior: Clip.antiAlias,
                              decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                                colors: [
                                  Color(0xFFFF00B3), Colors.transparent
                                ],
                              ),
                              border: Border.all(color: Colors.white, width: .1),
                              borderRadius: BorderRadius.circular(10.0)
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                              ClipRRect(
                              borderRadius: BorderRadius.horizontal(left: Radius.circular(10.0)),
                              child: Image.network('${item['poster']}', height: 50.0, width: 50.0, fit: BoxFit.cover,),
                            ),
                            Container(
                              margin: EdgeInsets.symmetric(horizontal: 5.0),
                              constraints: BoxConstraints(
                                maxWidth: 160.0,
                                ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                        Text('Andy', style: TextStyle(color: Colors.yellow, fontSize: 16.0),),
                                        Text(' 等${item['saleNum']}人在购买', style: TextStyle(color: Colors.white, fontSize: 14.0),),
                                      ],
                                    ),
                                    Text('${item['desc']}', style: TextStyle(color: Colors.white70, fontSize: 10.0), overflow: TextOverflow.ellipsis,),
                                  ],
                                    ),
                                  ),
                                  Container(
                                    height: 26.0,
                                  width: 60.0,
                                margin: EdgeInsets.all(5.0),
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(50.0),
                                  ),
                                  child: Text('去购买', style: TextStyle(color: Color(0xFFFF2C55), fontSize: 12.0),),
                                ),
                                ],
                                ),
                              ),
                              AnimationLiveGift(
                                giftQueryList: [
                                {'label': '小心心', 'gift': 'assets/images/gift/gift1.png', 'user': '岁月如梭', 'avatar': 'assets/images/avatar/img01.jpg', 'num': 6},
                                {'label': '棒棒糖', 'gift': 'assets/images/gift/gift2.png', 'user': 'Andy', 'avatar': 'assets/images/avatar/img02.jpg', 'num': 75},
                                {'label': '大啤酒', 'gift': 'assets/images/gift/gift3.png', 'user': '白昼流星', 'avatar': 'assets/images/avatar/img03.jpg', 'num': 211},
                                {'label': '人气票', 'gift': 'assets/images/gift/gift4.png', 'user': 'Luck', 'avatar': 'assets/images/avatar/img04.jpg', 'num': 68},
                                {'label': '鲜花', 'gift': 'assets/images/gift/gift5.png', 'user': '时过境迁', 'avatar': 'assets/images/avatar/img05.jpg', 'num': 12},
                                {'label': '捏捏小脸', 'gift': 'assets/images/gift/gift6.png', 'user': 'Apple', 'avatar': 'assets/images/avatar/img06.jpg', 'num': 38},
                                {'label': '你真好看', 'gift': 'assets/images/gift/gift7.png', 'user': '竹叶青', 'avatar': 'assets/images/avatar/img07.jpg', 'num': 119},
                                {'label': '亲吻', 'gift': 'assets/images/gift/gift8.png', 'user': '娜娜', 'avatar': 'assets/images/avatar/img08.jpg', 'num': 100},
                                {'label': '玫瑰', 'gift': 'assets/images/gift/gift12.png', 'user': '颜如玉', 'avatar': 'assets/images/avatar/img09.jpg', 'num': 2},
                                {'label': '私人飞机', 'gift': 'assets/images/gift/gift16.png', 'user': 'Davi', 'avatar': 'assets/images/avatar/img10.jpg', 'num': 168},
                              ],
                              ),
                              AnimationLiveJoin(
                                joinQueryList: [
                                {'avatar': 'assets/images/logo.png', 'name': 'Andy'},
                                {'avatar': 'assets/images/logo.png', 'name': 'Tom'},
                                {'avatar': 'assets/images/logo.png', 'name': '平安喜乐'},
                                {'avatar': 'assets/images/logo.png', 'name': '简单的幸福'},
                                {'avatar': 'assets/images/logo.png', 'name': '生如夏花'},
                                {'avatar': 'assets/images/logo.png', 'name': 'alice'},
                                  {'avatar': 'assets/images/logo.png', 'name': '小喵'},
                                  {'avatar': 'assets/images/logo.png', 'name': '沐浴阳光'},
                                  {'avatar': 'assets/images/logo.png', 'name': '给生活加点糖'},
                                  {'avatar': 'assets/images/logo.png', 'name': 'Victor'},
                                ],
                              ),
                              Container(
                                margin: EdgeInsets.only(top: 7.0),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                Expanded(
                                  child: ScrollConfiguration(
                                  behavior: CustomScrollBehavior(),
                                  child: SizedBox(
                                    height: 200.0,
                                    child: ListView.builder(
                                      padding: EdgeInsets.zero,
                                      itemCount: item['message']?.length,
                                      itemBuilder: (context, i) => danmuList(item['message'])[i],
                                    ),
                                  ),
                                  ),
                                ),
                                SizedBox(
                                  width: goodsTalkVisible ? 7 : 35,
                                ),
                                // 商品讲解
                                Visibility(
                                  visible: goodsTalkVisible,
                                  child: Column(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                  Container(
                                    margin: EdgeInsets.only(bottom: 7.0),
                                padding: EdgeInsets.symmetric(horizontal: 7.0),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.centerLeft,
                                    end: Alignment.centerRight,
                                    colors: [
                                      Color(0xFFFFBB00), Color.fromARGB(0, 255, 238, 0)
                                    ],
                                      ),
                                      borderRadius: BorderRadius.circular(10.0)
                                    ),
                                    child: Row(
                                      spacing: 3.0,
                                      children: [
                                        Image.asset('assets/images/icon-hot.png', height: 15.0, width: 15.0, fit: BoxFit.cover,),
                                        Text('热卖 x${item['saleNum']}', style: TextStyle(color: Colors.white, fontSize: 14.0),),
                                      ],
                                      ),
                                    ),
                                    GestureDetector(
                                      child: Container(
                                      width: 110.0,
                                      padding: EdgeInsets.all(2.0),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(10.0),
                                      ),
                                      clipBehavior: Clip.antiAlias,
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                        Stack(
                                          children: [
                                            ClipRRect(
                                          borderRadius: BorderRadius.vertical(top: Radius.circular(10.0)),
                                          child: Image.network('${item['poster']}', height: 110.0, width: 110.0, fit: BoxFit.cover,),
                                        ),
                                        Positioned(
                                          left: 3.0,
                                          top: 3.0,
                                          child: Container(
                                            padding: EdgeInsets.symmetric(horizontal: 3.0, vertical: 1.0),
                                            decoration: BoxDecoration(
                                              color: Colors.black38,
                                              borderRadius: BorderRadius.circular(10.0),
                                            ),
                                            child: Text('•讲解中', style: TextStyle(color: Colors.white, fontSize: 10.0),),
                                            ),
                                          ),
                                          Positioned(
                                            right: 3.0,
                                            top: 3.0,
                                            child: InkWell(
                                              child: Icon(Icons.close, color: Colors.white, size: 12.0),
                                              onTap: () {
                                                setState(() {
                                                goodsTalkVisible = false;
                                              });
                                            },
                                                ),
                                              )
                                            ],
                                              ),
                                          SizedBox(height: 3.0,),
                                          Text(' ${item['desc']}', style: TextStyle(color: Colors.black, fontSize: 12.0), overflow: TextOverflow.ellipsis,),
                                          Text(' 7天无理由退货', style: TextStyle(color: Color(0xFFFF2C55), fontSize: 10.0), overflow: TextOverflow.ellipsis,),
                                          SizedBox(height: 3.0,),
                                          Container(
                                            margin: EdgeInsets.all(2.0),
                                            padding: EdgeInsets.symmetric(horizontal: 8.0),
                                            decoration: BoxDecoration(
                                              color: Color(0xFFFF2C55),
                                              borderRadius: BorderRadius.circular(6.0),
                                            ),
                                            child: Row(
                                              children: [
                                                Expanded(
                                                  child: Text('¥520', style: TextStyle(color: Colors.white, fontSize: 16.0, fontFamily: 'Arial'),),
                                                ),
                                                Text('抢', style: TextStyle(color: Colors.white, fontSize: 16.0, fontWeight: FontWeight.bold),),
                                              ],
                                            ),
                                          ),
                                          ],
                                        ),
                                      ),
                                      onTap: () {
                                          Get.toNamed('/goods');
                                        },
                                      ),
                                        ],
                                      ),
                                      ),
                                    ],
                                    ),
                                  ),
                                  // 底部工具栏
                                  Container(
                                    margin: const EdgeInsets.only(top: 7.0),
                                    child: Row(
                                  children: [
                                    Expanded(
                                      child: InkWell(
                                    child: Container(
                                      alignment: Alignment.centerLeft,
                                    height: 35.0,
                                    padding: const EdgeInsets.symmetric(horizontal: 15.0),
                                    decoration: BoxDecoration(
                                      color: Colors.black26,
                                      borderRadius: BorderRadius.circular(50.0),
                                    ),
                                    child: const Text('说点什么...', style: TextStyle(color: Colors.white, fontSize: 14.0,),),
                                  ),
                                  onTap: () {
                                    navigator?.push(FadeRoute(
                                      child: PopupComment(
                                        onChanged: (value) {
                                          debugPrint('接收消息 ---$value');
                                          },
                                          )
                                        ));
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 10.0,),
                                    Wrap(
                                        spacing: 7.0,
                                    children: [
                                    InkWell(
                                      child: Container(
                                          alignment: Alignment.center,
                                          height: 35.0,
                                          width: 35.0,
                                          decoration: BoxDecoration(
                                            color: Colors.black26,
                                            borderRadius: BorderRadius.circular(50.0),
                                          ),
                                          child: Image.asset('assets/images/icon-cart.png', width: 20.0,),
                                        ),
                                        onTap: () {
                                          navigator?.push(FadeRoute(
                                            effect: 'bottom',
                                            child: PopupGoods(
                                            goodsList: [
                                              {'image': 'https://img12.360buyimg.com/jdcms/s240x240_jfs/t1/276851/40/403/125841/67ce85b7Fc7fb4cff/271d67aaea189a66.jpg', 'title': '茅台生肖系列酒 53度 老酒 收藏投资 春节送礼 2025年', 'tips': '销量超10万', 'price': '699.9', 'mprice': '999.9'},
                                              {'image': 'https://img14.360buyimg.com/jdcms/s240x240_jfs/t1/351318/40/12365/75748/68ee092bF4b501684/81f47e3e9ed16754.jpg', 'title': '罗蒙（ROMON）夹克男士秋冬季户外防风连帽保暖冲锋衣', 'tips': '好评1000+', 'price': '319.9', 'mprice': '359.9'},
                                            ],
                                            )
                                          ));
                                            goodsTalkVisible = true;
                                          }
                                        ),
                                        InkWell(
                                      child: Container(
                                        alignment: Alignment.center,
                                        height: 35.0,
                                        width: 35.0,
                                        decoration: BoxDecoration(
                                          color: Colors.black26,
                                          borderRadius: BorderRadius.circular(50.0),
                                        ),
                                        child: Image.asset('assets/images/icon-aixin.png', width: 20.0,),
                                      ),
                                      onTap: () {}
                                    ),
                                    InkWell(
                                      child: Container(
                                        alignment: Alignment.center,
                                      height: 35.0,
                                      width: 35.0,
                                      decoration: BoxDecoration(
                                        color: Colors.black26,
                                        borderRadius: BorderRadius.circular(50.0),
                                      ),
                                      child: Image.asset('assets/images/icon-gift.png', width: 20.0,),
                                    ),
                                    onTap: () {
                                      navigator?.push(FadeRoute(
                                      effect: 'bottom',
                                      child: PopupGift(
                                      onChanged: (value) {
                                        // debugPrint('coins ---$value');
                                      // 钻石不足充值弹窗
                                      navigator?.push(FadeRoute(
                                        effect: 'bottom',
                                        child: PopupRecharge(
                                          onChanged: (value) {
                                            // debugPrint('recharge ---$value');
                                          },
                                        )
                                      ));
                                      },
                                      )
                                    ));
                                    }
                                  ),
                                  InkWell(
                                    child: Container(
                                    alignment: Alignment.center,
                                    height: 36.0,
                                    width: 36.0,
                                  decoration: BoxDecoration(
                                    color: Colors.black26,
                                    borderRadius: BorderRadius.circular(50.0),
                                  ),
                                  child: const Icon(Icons.more_horiz_outlined, color: Colors.white, size: 20),
                                ),
                                onTap: () {
                                      navigator?.push(FadeRoute(
                                        effect: 'bottom',
                                        child: const PopupMore(),
                                      ));
                                    }
                                  ),
                                  ],
                                ),
                              ],
                            ),
                            ),
                          ],
                            ),
                          ),
                        ],
                      ),
                      ],
                      ),
                    ],
                  );
                },
              ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
