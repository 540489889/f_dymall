/// 我的模板
library;

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:card_swiper/card_swiper.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../controller/auth_store.dart';

class MyPage extends StatefulWidget {
  const MyPage({super.key});
  @override
  State<MyPage> createState() => _MyPageState();
}

class _MyPageState extends State<MyPage> {
  final authStore = AuthStore.to;
  void aboutAlertDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return UnconstrainedBox(
        constrainedAxis: Axis.vertical,
        child: SizedBox(
          width: 345.0,
          child: AlertDialog(
            contentPadding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 20.0),
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0)),
          content: Padding(
            padding: EdgeInsets.symmetric(horizontal: 10.0),
            child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset('assets/images/logo.png', width: 60.0, height: 60.0, fit: BoxFit.cover,),
              SizedBox(height: 10.0),
              Text('Flutter3-DYMall', style: TextStyle(color: Color(0xFFFF2C55), fontSize: 20.0, fontFamily: 'arial'),),
              SizedBox(height: 5.0),
              Text('基于flutter3.41.5+dart3.11+getx仿抖音短视频+直播+聊天App实例。', style: TextStyle(color: Colors.black54, fontSize: 13.0,),),
              SizedBox(height: 55.0),
              Text('Power by Andy ©2026/05', style: TextStyle(color: Colors.grey[400], fontSize: 12.0, fontFamily: 'arial'),),
              Text('Q: 282310962', style: TextStyle(color: Colors.grey[400], fontSize: 12.0, fontFamily: 'arial'),),
              ],
            ),
            ),
          ),
        ),
      );
      }
    );
  }
  void qrcodeAlertDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
      return UnconstrainedBox(
        constrainedAxis: Axis.vertical,
        child: SizedBox(
        width: 345.0,
        child: AlertDialog(
          contentPadding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 20.0),
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0)),
          content: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset('assets/images/qrimg.png', width: 250.0, fit: BoxFit.contain,),
                const SizedBox(height: 15.0),
                const Text('扫一扫，加我公众号', style: TextStyle(color: Colors.black38, fontSize: 14.0,),),
              ],
            ),
            ),
          ),
          ),
        );
      }
    );
  }

  // 退出登录弹窗
  void showLogoutDialog() {
    showDialog(
      context: context,
      builder: (context) {
      return AlertDialog(
        content: const Text('确认退出当前账号吗？', style: TextStyle(fontSize: 16.0),),
        backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0)),
      actionsPadding: const EdgeInsets.all(15.0),
      actions: [
        TextButton(
        onPressed: () {Get.back();},
        child: const Text('取消', style: TextStyle(color: Colors.black54),)
      ),
      TextButton(
        onPressed: () {
          // 清除存储信息
          authStore.logout();
          Get.offAllNamed('/login');
        },
        child: const Text('退出登录', style: TextStyle(color: Color(0xFFFF2C55)),)
        ),
      ],
      );
    }
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
    // 内容是否延伸到顶部,用于做半透明、毛玻璃效果
    extendBodyBehindAppBar: true,
    appBar: AppBar(
      forceMaterialTransparency: true,
      actions: [
        IconButton(icon: SvgPicture.asset('assets/images/svg/service.svg', height: 20.0, width: 20.0,), onPressed: () {},),
        IconButton(icon: SvgPicture.asset('assets/images/svg/about.svg', height: 20.0, width: 20.0,), onPressed: () {aboutAlertDialog(context);},),
        IconButton(icon: Icon(Icons.settings_outlined, size: 20.0,), onPressed: () {},),
      ],
    ),
    body: ListView(
      padding: EdgeInsets.zero,
      children: [
        // 顶部图片堆叠区域
      SizedBox(
        child: Stack(
          alignment: Alignment.topLeft,
          children: [
            Image.asset('assets/images/my_bg.png', height: 180.0, width: double.infinity, fit: BoxFit.fill,),
            Positioned(
              left: 15.0,
            bottom: 15.0,
            child: Row(
            spacing: 10.0,
              children: <Widget>[
              ClipOval(
                child: Image.asset('assets/images/avatar/img08.jpg', height: 60.0, width: 60.0, fit: BoxFit.cover),
              ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 2.0,
              children: [
                Row(
                  spacing: 5.0,
                  children: [
                  Text('134****2026', style: TextStyle(fontSize: 20.0, fontFamily: 'Arial'),),
                  InkWell(
                    onTap: () {qrcodeAlertDialog(context);},
                    child: Icon(Icons.qr_code_outlined, size: 16.0, color: Colors.grey,),
                  ),
                ],
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 5.0, vertical: 2.0),
                decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20.0),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(20),
                    offset: Offset(0.0, 1.0),
                    blurRadius: 2.0,
                      spreadRadius: 0.0,
                    ),
                  ]
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.verified_sharp, color: Colors.blue, size: 14.0,),
                      Text('铂金会员', style: TextStyle(fontSize: 12.0),),
                      SizedBox(width: 10.0),
                      Icon(Icons.sports_score, color: Colors.green, size: 14.0,),
                      Text('168经验值', style: TextStyle(fontSize: 12.0),),
                    ],
                    ),
                  )
                  ],
                ),
                ],
              ),
              )
            ],
          ),
          ),
          Container(
            padding: EdgeInsets.all(10.0),
            child: Column(
            spacing: 10.0,
            children: [
              // 权益卡片
              Container(
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
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      Color(0xFFFFE570), Color(0xFFFFAA3A)
                    ]
                  )
                ),
                  padding: EdgeInsets.all(10.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Row(
                        spacing: 5.0,
                        children: [
                          Icon(Icons.wallet, color: Color(0xFFCC7E25),),
                          Text('个人权益', style: TextStyle(color: Color(0xFFCC7E25)),),
                          SizedBox(width: 5.0,),
                          Text('¥520.00', style: TextStyle(color: Color(0xFFCC7E25)),),
                        ],
                        ),
                      ),
                        SizedBox(
                          height: 30.0,
                        child: FilledButton(
                          onPressed: () {
                            Get.toNamed('/my/wallet');
                          },
                          style: ButtonStyle(
                            backgroundColor: WidgetStateProperty.all(const Color(0xFFCC7E25)),
                            textStyle: WidgetStateProperty.all(TextStyle(fontSize: 13.0, height: 1))
                          ),
                          child: Text('钱包'),
                        ),
                      )
                      ],
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.all(10.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        Column(
                        spacing: 3.0,
                        children: [
                          Text('3', style: TextStyle(fontSize: 16.0, fontFamily: 'arial', fontWeight: FontWeight.w600),),
                          Text('优惠券'),
                        ],
                      ),
                      Column(
                        spacing: 3.0,
                        children: [
                          Text('99', style: TextStyle(fontSize: 16.0, fontFamily: 'arial', fontWeight: FontWeight.w600),),
                          Text('商品收藏'),
                        ],
                      ),
                        Column(
                          spacing: 3.0,
                          children: [
                            Text('20', style: TextStyle(fontSize: 16.0, fontFamily: 'arial', fontWeight: FontWeight.w600),),
                            Text('店铺关注'),
                          ],
                        ),
                        Column(
                          spacing: 3.0,
                          children: [
                            Text('168', style: TextStyle(fontSize: 16.0, fontFamily: 'arial', fontWeight: FontWeight.w600),),
                            Text('浏览记录'),
                          ],
                          ),
                        ],
                      ),
                      )
                    ],
                  ),
                ),
                // 广告图
                Container(
                height: 80.0,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10.0),
                ),
                child: Swiper.children(
                  autoplay: true,
                  pagination: SwiperPagination(
                    alignment: Alignment.bottomRight,
                    builder: DotSwiperPaginationBuilder(
                      color: Colors.white70,
                      activeColor: Colors.white,
                      size: 5.0,
                      activeSize: 8.0
                    )
                  ),
                  children: [
                    CachedNetworkImage(imageUrl: 'https://m.360buyimg.com/babel/jfs/t20281112/361153/38/3884/56116/6915d9e9F75c78857/e732354d88aef918.jpg', fit: BoxFit.fill),
                    CachedNetworkImage(imageUrl: 'https://m.360buyimg.com/babel/jfs/t20281110/353643/25/10471/53183/6912da91Fffbeb277/c73805494df34557.jpg', fit: BoxFit.fill),
                    CachedNetworkImage(imageUrl: 'https://m.360buyimg.com/babel/jfs/t1/359712/31/15410/152649/6923b669Fcc6d166f/01187421a2ca0f35.jpg', fit: BoxFit.fill),
                  ],
                  ),
                ),
                // 订单列表
              GestureDetector(
                child: Container(
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
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                Container(
                  padding: EdgeInsets.all(10.0),
                  child: Row(
                    children: [
                      Expanded(
                          child: Row(
                            spacing: 5.0,
                            children: [
                              Image.asset('assets/images/ico_order.png', width: 16.0,),
                              Text('我的订单', style: TextStyle(fontSize: 15.0, fontWeight: FontWeight.bold),),
                            ],
                          ),
                        ),
                        Text('全部', style: TextStyle(color: Colors.grey, fontSize: 12.0),),
                        Icon(Icons.arrow_forward_ios_rounded, color: Colors.grey, size: 12.0,)
                      ],
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.all(10.0),
                    child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                    Column(
                      spacing: 3.0,
                        children: [
                          Image.asset('assets/images/ico_dfk.png', width: 24.0,),
                          Text('待付款'),
                        ],
                      ),
                      Column(
                        spacing: 3.0,
                        children: [
                          Image.asset('assets/images/ico_dsh.png', width: 24.0,),
                          Text('待收货'),
                        ],
                      ),
                      Column(
                        spacing: 3.0,
                        children: [
                          Image.asset('assets/images/ico_pj.png', width: 24.0,),
                          Text('待评价'),
                        ],
                      ),
                      Column(
                        spacing: 3.0,
                        children: [
                          Image.asset('assets/images/ico_sh.png', width: 24.0,),
                          Text('退款/售后'),
                        ],
                        ),
                        ],
                      ),
                    ),
                    ],
                  ),
                ),
                onTap: () {
                  Get.toNamed('/order');
                  }
                ),
              FilledButton.icon(
                icon: const Icon(Icons.logout, color: Color(0xFFFF2C55), size: 14.0),
                label: const Text('退出登录', style: TextStyle(fontSize: 13.0, color: Color(0xFFFF2C55)),),
              style: ButtonStyle(
                backgroundColor: WidgetStateProperty.all(Colors.white),
                shadowColor: WidgetStateProperty.all(Colors.black26),
                padding: WidgetStateProperty.all(EdgeInsets.zero),
                minimumSize: WidgetStateProperty.all(const Size(135.0, 40.0)),
                elevation: WidgetStateProperty.all(2.0)
              ),
              onPressed: () {
                showLogoutDialog();
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
