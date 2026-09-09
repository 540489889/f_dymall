/// 商品详情页
library;

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:card_swiper/card_swiper.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../behavior/custom_scroll_behavior.dart';
import '../../components/backtop.dart';

class Goods extends StatefulWidget {
  const Goods({ super.key });

@override
State<Goods> createState() => _GoodsState();
}

class _GoodsState extends State<Goods> {
late ScrollController scrollController = ScrollController();
// 记录滚动位置
final ValueNotifier<double> scrollOffset = ValueNotifier(0);

@override
void initState() {
  super.initState();
  scrollController.addListener(() {
    scrollOffset.value = scrollController.offset;
  });
}

@override
void dispose() {
  scrollController.dispose();
  super.dispose();
}

@override
  Widget build(BuildContext context) {
  return Scaffold(
    backgroundColor: Colors.grey[50],
    body: CustomScrollView(
      scrollBehavior: CustomScrollBehavior().copyWith(scrollbars: false),
      controller: scrollController,
      slivers: [
        SliverAppBar(
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
        pinned: true,
        expandedHeight: 280.0,
        titleSpacing: 10.0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, size: 20.0,),
          style: ButtonStyle(
          backgroundColor: WidgetStateProperty.all(Colors.black.withAlpha(20)),
        ),
        onPressed: () {
          Get.back();
        },
      ),
      actions: [
        IconButton(icon: Icon(Icons.favorite_border, size: 20.0,), onPressed: () {},),
        IconButton(icon: Icon(Icons.share, size: 20.0,), onPressed: () {},),
      ],
      // 自定义伸缩区域(轮播图)
      flexibleSpace: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFFFF2C55), Color(0xFFFF9C55)
              ]
            )
          ),
          child: FlexibleSpaceBar(
              background: ScrollConfiguration(
                behavior: CustomScrollBehavior(),
              child: Swiper.children(
            pagination: SwiperPagination(
              alignment: .bottomRight,
              builder: DotSwiperPaginationBuilder(
                color: Colors.white70,
                  activeColor: Colors.white,
                )
              ),
              indicatorLayout: PageIndicatorLayout.SCALE,
              children: [
                CachedNetworkImage(
                  imageUrl: 'https://qcloud.dpfile.com/pc/v1bIsYHx3Y87jclud6DDqfNBYql3vxbAqq-znhZU9TH6C11FNL1SypW4dSClWkDpY0q73sB2DyQcgmKUxZFQtw.jpg',
                  placeholder: (context, url) => Container(color: Colors.grey[50]),
                  fit: BoxFit.cover,
                ),
                CachedNetworkImage(
                  imageUrl: 'https://qcloud.dpfile.com/pc/yEm2MxGwYZpPUWKgqYXPn0ZI3jqPBpPh8y25s4xRQzO0UZP48IL4YPQJmSCpTA-lY0q73sB2DyQcgmKUxZFQtw.jpg',
                  placeholder: (context, url) => Container(color: Colors.grey[50]),
                  fit: BoxFit.cover,
                ),
                CachedNetworkImage(
                  imageUrl: 'https://qcloud.dpfile.com/pc/YJ4OOVWA5sj34gPWC8Nkwpc8wuTQF9y4IfNQ2cimzKkuclZKFe3DWF0_YvlhKe8mY0q73sB2DyQcgmKUxZFQtw.jpg',
                  placeholder: (context, url) => Container(color: Colors.grey[50]),
                  fit: BoxFit.cover,
                ),
              ],
                ),
              ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: ScrollConfiguration(
            behavior: CustomScrollBehavior().copyWith(scrollbars: false),
            child: Column(
              children: [
            Container(
              padding: EdgeInsets.fromLTRB(15.0, 10.0, 15.0, 25.0),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFFFF2C55), Color(0xFFFF9C55)
                ]
              )
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 5.0,
              children: [
                Row(
                spacing: 5.0,
                children: [
                  Text('¥1699.8', style: TextStyle(color: Colors.white, fontSize: 16.0,),),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8.0, vertical: 3.0),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(50.0),
                  ),
                  child: Text('券后价¥1599.8', style: TextStyle(color: Colors.red, fontSize: 12.0),),
                ),
              ],
              ),
              Text('直播间同价 已售1万 券·立减100元', style: TextStyle(color: Colors.white, fontSize: 12.0),),
                ],
                ),
              ),
              Container(
                padding: EdgeInsets.fromLTRB(10.0, 10.0, 10.0, 0),
                decoration: BoxDecoration(
                  color: Color(0xFFFAFAFA),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(15.0)),
                ),
                transform: Matrix4.translationValues(0.0, -15.0, 0.0),
                child: Column(
                  children: [
                    // 标题
                Container(
                    padding: EdgeInsets.all(5.0),
                    child: Text.rich(
                      TextSpan(
                    children: [
                      TextSpan(text: ' 品牌正品 ', style: TextStyle(fontSize: 12.0, backgroundColor: const Color(0xFFFF2C55), color: Colors.white)),
                      TextSpan(text: ' 锅气的香🔥干辣椒的焦香🌶️蔬菜混合的清香🥬 菜品很多个个都很好吃，性价比很高的一家店。', style: TextStyle(fontSize: 14.0, fontWeight: FontWeight.w700),),
                    ]
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                ),
                // 规格
                Container(
                  margin: EdgeInsets.only(top: 10.0),
                  padding: EdgeInsets.all(10.0),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10.0),
                  ),
                  child: Column(
                    spacing: 10.0,
                  children: [
                    Row(
                      spacing: 5.0,
                  children: [
                    Icon(Icons.wallet_giftcard, size: 16.0,),
                  Expanded(
                    child: Text('实付满1000元，收货后返满100元券', style: TextStyle(fontSize: 12.0),),
                  ),
                  Icon(Icons.arrow_forward_ios_rounded, color: Colors.grey, size: 10.0,),
                ],
              ),
              Row(
                spacing: 5.0,
                children: [
                  Icon(Icons.favorite_outline, size: 16.0,),
                Expanded(
                  child: Text('坏了包赔 · 极速退款 · 不支持7天无理由', style: TextStyle(fontSize: 12.0),),
                ),
                    Icon(Icons.arrow_forward_ios_rounded, color: Colors.grey, size: 10.0,),
                  ],
                ),
                Row(
                  spacing: 5.0,
                  children: [
                    Icon(Icons.directions_bus, size: 16.0,),
                    Expanded(
                      child: Text('预计24小时内发货，1月21日送达', style: TextStyle(fontSize: 12.0),),
                    ),
                    Icon(Icons.arrow_forward_ios_rounded, color: Colors.grey, size: 10.0,),
                  ],
                ),
                    ],
                  ),
                ),
                // 详情
                Container(
                margin: EdgeInsets.only(top: 10.0),
                padding: EdgeInsets.all(10.0),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10.0),
                ),
                child: Column(
                  spacing: 10.0,
                  children: [
                    Text('热辣焦香的锅气小炒，配上冰爽甜蜜的冷饮甜品，冰火碰撞，快乐翻倍！道道好吃不踩雷，人均几十吃到撑。性价比超高的宝藏小馆，等你来开怀畅吃。'),
                    Image.network('https://qcloud.dpfile.com/pc/axq-vtc5adxDGDP9Ol9zr3S3tN0LjF2_gd76ih9NAXosmqt_iFFDpyVDwTmNHIV2Y0q73sB2DyQcgmKUxZFQtw.jpg', fit: BoxFit.contain,),
                    Image.network('https://qcloud.dpfile.com/pc/bPtiRX0q9JgU1nEzQCdo1YTkckPFWjHP0R9JSmB0C7Msmqt_iFFDpyVDwTmNHIV2Y0q73sB2DyQcgmKUxZFQtw.jpg', fit: BoxFit.contain,),
                    Image.network('https://qcloud.dpfile.com/pc/YJ4OOVWA5sj34gPWC8Nkwpc8wuTQF9y4IfNQ2cimzKkuclZKFe3DWF0_YvlhKe8mY0q73sB2DyQcgmKUxZFQtw.jpg', fit: BoxFit.contain,),
                    Image.network('https://qcloud.dpfile.com/pc/miOQqbKoYWdIqbPwxS72LdqqQlFzBz8WjmTperw6AAF93TS4Nnp4B8i73Y5Dh7OPkkCBOWO5rApRy3gE6VS0Vg.jpg', fit: BoxFit.contain,),
                  ],
                ),
                  ),
                  ],
                ),
                ),
              ],
            ),
            ),
          ),
        ],
      ),
      // 商品导航栏
      bottomNavigationBar: Container(
        height: 50.0,
        color: Colors.white,
        padding: EdgeInsets.symmetric(horizontal: 10.0, vertical: 5.0),
      child: Row(
        children: [
        Expanded(
          child: Row(
          spacing: 15.0,
          children: [
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.storefront, color: Color(0xFFFF2C55), size: 18.0,),
            Text('进店', style: TextStyle(fontSize: 12.0),)
          ],
        ),
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.chat_outlined, size: 18.0,),
            Text('客服', style: TextStyle(fontSize: 12.0),)
          ],
        ),
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Badge.count(
              backgroundColor: Colors.redAccent,
              offset: Offset(10.0, -4.0),
              count: 3,
              child: Icon(Icons.shopping_cart_outlined, size: 18.0,),
            ),
              Text('购物车', style: TextStyle(fontSize: 12.0),)
            ],
          ),
          ],
          ),
        ),
        Container(
          alignment: Alignment.center,
        height: 36.0,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: Color(0xFFFFEBEB),
          borderRadius: BorderRadius.circular(30.0),
      ),
      child: Row(
        children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 10.0),
          child: Text('加入购物车', style: TextStyle(color: Color(0xFFFF2C55), fontSize: 14.0),),
        ),
        GestureDetector(
          child: Container(
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            color: Color(0xFFFF2C55),
            child: Text('领券购买', style: TextStyle(color: Colors.white, fontSize: 14.0),),
          ),
          onTap: () {
            Get.toNamed('/order/ordersure');
            },
          ),
        ],
        ),
      ),
      ],
    ),
  ),
  // 返回顶部
  floatingActionButton: Backtop(controller: scrollController, offset: scrollOffset),
  );
}
}
