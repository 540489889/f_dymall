/// 推荐模块
library;

import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:media_kit_video/media_kit_video_controls/src/controls/extensions/duration.dart';
import '../../../controller/video_store.dart';
import '../../../behavior/custom_scroll_behavior.dart';
import '../../../router/fade_route.dart';
import '../components/ads.dart';
import '../components/popup_reply.dart';
class RecommendModule extends StatefulWidget {
  const RecommendModule({super.key});
  @override
  State<RecommendModule> createState() => _RecommendModuleState();
}

class _RecommendModuleState extends State<RecommendModule> {
  final videoStore = VideoStore.to;
  late PageController pageController;
  late Player player = Player();
  late VideoController videoController = VideoController(player);
// 当前视频索引
late int videoIndex = videoStore.videoPlayIndex.value;
late Worker _worker;

final List<StreamSubscription> subscriptions = [];
// 进度条slider当前阈值
bool sliderDraging = false;
double sliderValue = 0.0;
late Duration position = Duration.zero; // 当前时长
late Duration duration = Duration.zero; // 总时长

// 视频模拟数据
List videoList = [
  {
    'avatar': 'https://tx2.a.yximgs.com/upic/2021/01/22/09/BMjAyMTAxMjIwOTU5MzRfMzI3NDc4MjUwXzQyNzc0Mjg1MTQzXzFfMw==_B69ad663ba1334613aa637bfd1d352ce8.jpg',
    'author': '翠花',
    'src': 'https://txmov2.a.yximgs.com/upic/2021/01/22/09/BMjAyMTAxMjIwOTU5MzRfMzI3NDc4MjUwXzQyNzc0Mjg1MTQzXzFfMw==_b_B698a01bbbdfb0314733cfc38c0d7b6d0.mp4',
    'desc': '是否有个人愿意一直陪你走下去。',
  'playNum': 8764,
  'likeNum': 1232,
  'replyNum': 635,
  'starNum': 327,
    'shareNum': 180,
    'isLike': true,
    'isFollow': true,
  },
  {
    'avatar': 'https://tx2.a.yximgs.com/uhead/AB/2020/11/04/14/BMjAyMDExMDQxNDMxNTFfNDE1MTczMTMxXzFfaGQ0MzlfNTI3_s.jpg',
    'author': 'Tony',
    'src': 'https://txmov2.a.yximgs.com/upic/2021/01/10/12/BMjAyMTAxMTAxMjM0NDJfODg1MjU5ODI3XzQyMTUyOTAwNjk3XzFfMw==_b_B2b9080434057fed1f908f8c11bdf9bae.mp4',
    'desc': '你们猜中了开头，但绝对猜不到结尾~',
    'playNum': 9875,
    'likeNum': 3563,
    'replyNum': 1328,
  'starNum': 852,
  'shareNum': 672,
    'isLike': false,
    'isFollow': false,
  },
  {
    'avatar': 'https://tx2.a.yximgs.com/upic/2020/12/06/17/BMjAyMDEyMDYxNzUyNDNfMjcwMDc0N180MDMxOTU2OTA4NV8xXzM=_Bbba80c48e42e5b4a15c1f52d18b5d048.jpg',
    'author': '精致女孩',
    'src': 'https://txmov2.a.yximgs.com/upic/2020/12/06/17/BMjAyMDEyMDYxNzUyNDNfMjcwMDc0N180MDMxOTU2OTA4NV8xXzM=_b_B904c563f7f8af19d277be03e2398028d.mp4',
    'desc': '这样的我，你喜欢吗，可盐可甜可咸~',
    'playNum': 5355,
    'likeNum': 8536,
    'replyNum': 4324,
    'starNum': 437,
    'shareNum': 658,
    'isLike': false,
    'isFollow': true,
  },
  {
    'avatar': 'https://p66-pro.a.yximgs.com/uhead/AB/2023/04/14/09/BMjAyMzA0MTQwOTIzMjJfMjQ3MDYzODYyNV8yX2hkNDI4XzU2NA==_s.jpg',
    'author': '馋宝宝',
    'src': 'https://txmov2.a.yximgs.com/upic/2021/03/20/13/BMjAyMTAzMjAxMzA3MzNfMjEyNTMxNzU2MF80NjMwNzU0NTMxNV8wXzM=_b_B6717ec232dac71a529a19a0e4ac64b97.mp4',
    'desc': '#生活美食，美食艺术，美食视频记录。',
  'playNum': 5218,
  'likeNum': 638,
  'replyNum': 249,
  'starNum': 312,
  'shareNum': 248,
    'isLike': true,
    'isFollow': false,
  },
  {
    'avatar': 'https://tx2.a.yximgs.com/upic/2021/02/21/15/BMjAyMTAyMjExNTM4MzJfMTQ1NDUyNjQ0Nl80NDc1OTAwNTkxNF8xXzM=_B97043a25c8bc7a3329924b59820ddded.jpg',
    'author': '美女与咖啡',
    'src': 'https://txmov2.a.yximgs.com/upic/2021/02/21/15/BMjAyMTAyMjExNTM4MzJfMTQ1NDUyNjQ0Nl80NDc1OTAwNTkxNF8xXzM=_b_B7e05b07c97ac7047f2440041368f10a0.mp4',
    'desc': '惬意的午后，享受一杯温馨的咖啡时光~',
    'playNum': 8240,
  'likeNum': 5645,
  'replyNum': 2454,
  'starNum': 654,
  'shareNum': 769,
  'isLike': true,
  'isFollow': true,
},
{
    'avatar': 'https://p66-pro.a.yximgs.com/uhead/AB/2024/04/20/13/BMjAyNDA0MjAxMzA4MTZfMzAxMDE5MzQ3OF8yX2hkNjQ1XzgxOQ==_s.jpg',
  'author': '小甜心',
  'src': 'https://txmov2.a.yximgs.com/upic/2021/01/24/19/BMjAyMTAxMjQxOTEyNTBfMTgzMDE5NzE5XzQyOTI0MjcyMjExXzFfMw==_b_B2eae5c4e5052d727e53eeee3f86c49d5.mp4',
  'desc': '无敌晚霞美景 #美景 #忒好看 #别滑了下一个没我好看',
  'playNum': 6847,
  'likeNum': 2155,
  'replyNum': 626,
  'starNum': 429,
  'shareNum': 238,
    'isLike': true,
    'isFollow': true,
  }
];
  // 评论数据
List commentList = [
  {'avatar': 'assets/images/avatar/img01.jpg', 'name': 'Alice', 'desc': '用汗水浇灌希望，让努力铸就辉煌，你付出的每一刻，都是在靠近成功的彼岸。'},
  {'avatar': 'assets/images/avatar/img02.jpg', 'name': '悟空', 'desc': '黑暗遮不住破晓的曙光，困境困不住奋进的脚步，勇往直前，你定能冲破阴霾。'},
  {'avatar': 'assets/images/avatar/img03.jpg', 'name': '木棉花', 'desc': '每一次跌倒都是为了下一次更有力地跃起，别放弃~！'},
  {'avatar': 'assets/images/avatar/img04.jpg', 'name': '狗仔', 'desc': '人生没有白走的路，每一步都算数，那些辛苦的过往，会在未来化作最美的勋章。'},
  {'avatar': 'assets/images/avatar/img05.jpg', 'name': '向日葵', 'desc': '以梦为马，不负韶华，握紧手中的笔，书写属于自己的热血传奇，让青春绽放光芒。'},
  {'avatar': 'assets/images/avatar/img06.jpg', 'name': '健身女神', 'desc': '哪怕身处谷底，只要抬头仰望，便能看见漫天繁星，心怀希望，就能找到出路，奔赴美好。'},
];
// 分享列表
List shareList = [
  {'icon': 'assets/images/share-wx.png', 'label': '微信'},
  {'icon': 'assets/images/share-pyq.png', 'label': '朋友圈'},
  {'icon': 'assets/images/share-qq.png', 'label': 'QQ'},
  {'icon': 'assets/images/share-qzone.png', 'label': 'QQ空间'},
  {'icon': 'assets/images/share-weibo.png', 'label': '微博'},
  {'icon': 'assets/images/share-shipin.png', 'label': '视频号'},
  {'icon': 'assets/images/share-link.png', 'label': '复制链接'},
  {'icon': 'assets/images/share-download.png', 'label': '下载'},
];

@override
void initState() {
  super.initState();
  pageController = PageController(initialPage: videoIndex, viewportFraction: 1.0);
  player.open(Media(videoList[videoIndex]['src']));
  player.setPlaylistMode(PlaylistMode.loop);

  _worker = everAll([videoStore.bottomNavigationIndex, videoStore.videoTabIndex], (_) {
    bool isInRecommendPage = videoStore.bottomNavigationIndex.value == 1 && videoStore.videoTabIndex.value == 7;
    if (isInRecommendPage) {
    if (mounted && !player.state.playing) {
      player.play();
    }
  } else {
    if (mounted && player.state.playing) {
      player.pause();
    }
    }
  });
}

 @override
 void setState(VoidCallback fn) {
  if (mounted) {
    super.setState(fn);
  }
 }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if(subscriptions.isEmpty) {
    subscriptions.addAll([
     player.stream.duration.listen((event) {
      if(mounted) {
        duration = event;
      }
     }),
     player.stream.position.listen((event) {
      setState(() {
       position = event;
        if(event > Duration.zero && !sliderDraging) {
         sliderValue = (event.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0);
        }
      });
      }),
    ],
    );
  }
}

  @override
  void dispose() {
   for (final subscription in subscriptions) {
     subscription.cancel();
   }
   player.dispose();
  pageController.dispose();
   _worker.dispose();
  super.dispose();
}

void handleComment(int index) {
  showModalBottomSheet(
   backgroundColor: Colors.white,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(10.0))),
   showDragHandle: false,
    clipBehavior: Clip.antiAlias,
   isScrollControlled: true,
   constraints: BoxConstraints(
    maxHeight: MediaQuery.of(context).size.height * 3 / 4,
  ),
  context: context,
  builder: (context) {
    return Material(
     color: Colors.white,
     child: Column(
      children: [
       Container(
         padding: EdgeInsets.fromLTRB(15.0, 10.0, 10.0, 5.0),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: Color(0xFFFAFAFA)))
         ),
        child: Column(
          spacing: 10.0,
            children: [
            Row(
              children: [
              Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(text: '大家都在搜: ', style: TextStyle(color: Colors.grey),),
                  TextSpan(text: '中日关系最新局势', style: TextStyle(color: const Color(0xFF496D80)),),
                ]
                )
              )
            ),
            GestureDetector(
              child: Container(
                height: 22.0,
              width: 22.0,
              decoration: BoxDecoration(
                color:Colors.grey[100],
                borderRadius: BorderRadius.circular(100.0),
              ),
              child: UnconstrainedBox(
                child: Icon(Icons.close, color: Colors.black54, size: 14.0)
                )
              ),
              onTap: () {
                Get.back();
              },
              ),
              ],
            ),
            Text('168条评论', style: TextStyle(fontSize: 12.0, fontWeight: FontWeight.w600),)
              ],
              ),
            ),
           Expanded(
             child: ScrollConfiguration(
            behavior: CustomScrollBehavior().copyWith(scrollbars: false),
             child: ListView.builder(
            physics: BouncingScrollPhysics(),
             shrinkWrap: true,
             itemCount: commentList.length,
            itemBuilder: (context, index) {
             return ListTile(
              isThreeLine: true,
              leading: ClipRRect(
               borderRadius: BorderRadius.circular(50.0),
                child: Image.asset('${commentList[index]['avatar']}', width: 30.0, fit: BoxFit.contain,),
              ),
              title: Row(
                children: [
                  Text('${commentList[index]['name']}', style: TextStyle(color: Colors.grey, fontSize: 12.0,),),
                ],
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                Container(
                  margin: EdgeInsets.symmetric(vertical: 5.0),
                  child: Text('${commentList[index]['desc']}', style: TextStyle(fontSize: 14.0,),),
                ),
                Row(
                  spacing: 15.0,
                children: [
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8.0, vertical: 3.0),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(20.0),
                      ),
                      child: Row(
                        children: [Text('12回复', style: TextStyle(fontSize: 12.0),), Icon(Icons.arrow_forward_ios, size: 10.0,)]
                      ),
                    ),
                    Text('01-15 · 浙江', style: TextStyle(color: Colors.grey, fontSize: 12.0),),
                    Spacer(),
                    Row(
                      children: [
                        Icon(Icons.favorite_border_outlined, color: Colors.black54, size: 16.0,), Text('99', style: TextStyle(color: Colors.black54, fontSize: 12.0),),
                      ],
                    ),
                    Row(
                      children: [
                        Icon(Icons.heart_broken_outlined, color: Colors.black54, size: 16.0,),
                      ],
                    ),
                    ],
                    ),
                  ],
                    ),
                  );
                },
                ),
              ),
          ),
        GestureDetector(
          child: Container(
          margin: EdgeInsets.all(10.0),
          height: 40.0,
          decoration: BoxDecoration(
            color: Colors.grey[100],
          borderRadius: BorderRadius.circular(30.0),
        ),
        child: Row(
          children: [
            SizedBox(width: 15.0,),
            Icon(Icons.edit_note, color: Colors.black54, size: 16.0,),
            SizedBox(width: 5.0,),
            Text('说点什么...', style: TextStyle(color: Colors.black54, fontSize: 14.0),),
          ],
        ),
        ),
        onTap: () {
          navigator?.push(FadeRoute(
            child: PopupReply(
              onChanged: (value) {
                debugPrint('评论内容: $value');
                },
              )
            ));
            },
          ),
          ],
        ),
      );
      },
    );
  }

  // 分享弹框
  void handleShare(int index) {
    showModalBottomSheet(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(10.0))),
      clipBehavior: Clip.antiAlias,
      context: context,
      builder: (context) {
      return Material(
        color: Colors.white,
      child: SizedBox(
        height: 170,
      width: double.infinity,
      child: Column(
        children: [
          Expanded(
          child: ScrollConfiguration(
          behavior: CustomScrollBehavior().copyWith(scrollbars: false),
          child: ListView.builder(
          shrinkWrap: true,
          scrollDirection: Axis.horizontal,
          padding: EdgeInsets.symmetric(vertical: 20.0, horizontal: 10.0),
          itemCount: shareList.length,
          itemBuilder: (context, index) {
            return Container(
              padding: EdgeInsets.symmetric(horizontal: 12.0),
              child: Column(
                spacing: 5.0,
                children: [
                  Image.asset('${shareList[index]['icon']}', width: 48.0),
                  Text('${shareList[index]['label']}', style: TextStyle(fontSize: 12.0),)
                ],
                ),
              );
              },
            ),
          ),
        ),
        InkWell(
          child: Container(
            alignment: Alignment.center,
          width: double.infinity,
          height: 50.0,
          color: Colors.grey[50],
          child: Text('取消', style: TextStyle(color: Colors.black87),),
          ),
          onTap: () {
            Get.back();
            },
            ),
          ],
        ),
        ),
      );
    },
  );
}

@override
Widget build(BuildContext context) {
  return Container(
    color: Colors.black,
    child: Column(
      children: [
        Expanded(
        child: Stack(
            children: [
              PageView.builder(
                scrollBehavior: CustomScrollBehavior().copyWith(scrollbars: false),
                scrollDirection: Axis.vertical,
                controller: pageController,
                onPageChanged: (index) async {
                await player.open(Media(videoList[index]['src']));
                setState(() {
                  videoIndex = index;
                  duration = Duration.zero;
                  position = Duration.zero;
                  sliderDraging = false;
                  sliderValue = 0.0;
                });
                videoStore.updateVideoPlayIndex(index);
              },
              itemCount: videoList.length,
              itemBuilder: (context, index) {
                final item = videoList[index];
                  return Stack(
                    children: [
                    Positioned.fill(
                    child: ImageFiltered(
                      imageFilter: ImageFilter.blur(sigmaX: 50.0, sigmaY: 50.0),
                      child: CachedNetworkImage(imageUrl: '${item['avatar']}', fit: BoxFit.cover,),
                    ),
                  ),
                  // 视频区域
                  Positioned.fill(
                  child: GestureDetector(
                    child: Stack(
                      children: [
                      Visibility(
                      visible: videoIndex == index && position > Duration(milliseconds: 100),
                      child: Video(
                      controller: videoController,
                      fit: BoxFit.cover,
                          controls: NoVideoControls,
                        ),
                      ),
                      StreamBuilder(
                        stream: player.stream.playing,
                        builder: (context, playing) {
                          return Visibility(
                          visible: playing.data == false && position > Duration(milliseconds: 100),
                          child: Center(
                            child: IconButton(
                              padding: EdgeInsets.zero,
                              onPressed: () {
                              player.playOrPause();
                            },
                            icon: Icon(
                              playing.data == true ? Icons.pause : Icons.play_arrow_rounded,
                              color: Colors.white60,
                              size: 80,
                            ),
                            style: ButtonStyle(
                              backgroundColor: WidgetStateProperty.all(Colors.transparent),
                              overlayColor: WidgetStateProperty.all(Colors.transparent),
                                ),
                              ),
                              ),
                            );
                              },
                            ),
                          ],
                        ),
                        onTap: () {
                          player.playOrPause();
                        },
                      ),
                    ),
                    // 右侧操作栏
                    Positioned(
                      bottom: 15.0,
                        right: 6.0,
                      child: Column(
                      spacing: 15.0,
                      children: [
                        // 头像
                        Stack(
                          children: [
                          SizedBox(
                            height: 55.0,
                            width: 48.0,
                            child: UnconstrainedBox(
                            alignment: Alignment.topCenter,
                            child: Container(
                              height: 48.0,
                              width: 48.0,
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.white, width: 2.0),
                              borderRadius: BorderRadius.circular(100.0),
                            ),
                            child: ClipOval(
                              child: CachedNetworkImage(imageUrl: '${item['avatar']}', fit: BoxFit.cover,),
                            ),
                          ),
                          ),
                        ),
                          Positioned(
                            bottom: 0,
                            left: 15.0,
                          child: InkWell(
                            child: Container(
                            height: 18.0,
                            width: 18.0,
                            decoration: BoxDecoration(
                              color: item['isFollow'] ? Colors.white : Color(0xFFFF2C55),
                              borderRadius: BorderRadius.circular(100.0),
                            ),
                            child: Icon(item['isFollow'] ? Icons.check : Icons.add, color: item['isFollow'] ? Color(0xFFFF2C55) : Colors.white, size: 14.0,),
                          ),
                          onTap: () {
                            setState(() {
                            item['isFollow'] = !item['isFollow'];
                            });
                            },
                            ),
                          ),
                        ],
                      ),
                      GestureDetector(
                        child: Column(
                          children: [
                          SvgPicture.asset('assets/images/svg/heart.svg', colorFilter: ColorFilter.mode(item['isLike'] ? Color(0xFFFF2C55) : Colors.white, BlendMode.srcIn), height: 40.0, width: 40.0,),
                          Text('${item['likeNum']+(item['isLike'] ? 1 : 0)}', style: TextStyle(color: Colors.white, fontSize: 12.0),),
                        ],
                      ),
                      onTap: () {
                        setState(() {
                          item['isLike'] = !item['isLike'];
                          });
                        },
                      ),
                        GestureDetector(
                        child: Column(
                          children: [
                            SvgPicture.asset('assets/images/svg/reply.svg', colorFilter: ColorFilter.mode(Colors.white, BlendMode.srcIn), height: 40.0, width: 40.0,),
                            Text('${item['replyNum']}', style: TextStyle(color: Colors.white, fontSize: 12.0),),
                          ],
                        ),
                        onTap: () {
                          handleComment(index);
                        },
                      ),
                      Column(
                      children: [
                          SvgPicture.asset('assets/images/svg/favor.svg', colorFilter: ColorFilter.mode(Colors.white, BlendMode.srcIn), height: 40.0, width: 40.0,),
                          Text('${item['starNum']}', style: TextStyle(color: Colors.white, fontSize: 12.0),),
                        ],
                      ),
                      GestureDetector(
                        child: Column(
                          children: [
                          SvgPicture.asset('assets/images/svg/share.svg', colorFilter: ColorFilter.mode(Colors.white, BlendMode.srcIn), height: 40.0, width: 40.0,),
                          Text('${item['shareNum']}', style: TextStyle(color: Colors.white, fontSize: 12.0),),
                        ],
                      ),
                      onTap: () {
                        handleShare(index);
                      },
                      ),
                    ],
                  ),
                ),
                  Positioned(
                      bottom: 15.0,
                      left: 10.0,
                    right: 80.0,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      spacing: 5.0,
                      children: [
                        Text('@${item['author']}', style: TextStyle(color: Colors.white, fontSize: 17.0, fontWeight: FontWeight.w700),),
                        Text('${item['desc']}', style: TextStyle(color: Colors.white, fontSize: 15.0),),
                      ],
                    ),
                  ),
                  Positioned(
                    bottom: 0.0,
                      left: 0.0,
                      right: 0.0,
                    child: Visibility(
                    visible: videoIndex == index && position > Duration(milliseconds: 100),
                    child: SliderTheme(
                      data: SliderThemeData(
                        trackHeight: sliderDraging ? 8.0 : 2.0,
                        thumbShape: RoundSliderThumbShape(enabledThumbRadius: 5.0),
                        overlayShape: RoundSliderOverlayShape(overlayRadius: 0),
                        inactiveTrackColor: Colors.white24,
                          activeTrackColor: Colors.white,
                          thumbColor: Colors.white,
                          overlayColor: Colors.transparent,
                        ),
                        child: Slider(
                          value: sliderValue.clamp(0.0, 1.0),
                          onChanged: (value) {
                            setState(() {
                              sliderValue = value;
                            });
                          },
                          onChangeStart: (value) {
                            sliderDraging = true;
                          },
                          onChangeEnd: (value) async {
                            sliderDraging = false;
                            await player.seek(duration * value);
                            if(!player.state.playing) {
                              await player.play();
                            }
                          },
                          ),
                        ),
                        ),
                      ),
                      // 播放位置指示器
                      Positioned(
                      bottom: 100.0,
                      left: 10.0,
                      right: 10.0,
                    child: Visibility(
                    visible: sliderDraging,
                    child: DefaultTextStyle(
                    style: TextStyle(color: Colors.white54, fontSize: 18.0, fontFamily: 'arial'),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      spacing: 8.0,
                      children: [
                        Text((duration * sliderValue.clamp(0.0, 1.0)).label(reference: duration), style: TextStyle(color: Colors.white)),
                        Text('/', style: TextStyle(fontSize: 14.0)),
                        Text(duration.label(reference: duration)),
                      ],
                      ),
                    )
                    ),
                  ),
                    ],
                  );
                },
              ),
              /// 固定层
              // 红包广告
              Ads(),
            ],
          ),
        ),
      ],
      ),
    );
  }
}
