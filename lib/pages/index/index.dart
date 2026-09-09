/// 首页模板
library;

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:card_swiper/card_swiper.dart';
import 'package:get/get.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../behavior/custom_scroll_behavior.dart';
import '../../components/custom_sticky_header.dart';
import '../../components/loading.dart';
import '../../components/backtop.dart';
import '../../components/custom_pageview_indicator.dart';
class IndexPage extends StatefulWidget {
  const IndexPage({super.key});
  @override
  State<IndexPage> createState() => _IndexPageState();
}

class _IndexPageState extends State<IndexPage> with SingleTickerProviderStateMixin {
  // 分类列表
  List cateList = [
    {
    'id': 1,
  'list': [
    { 'icon': 'assets/images/svg/huiyuan.svg', 'label': '每日签到' },
    { 'icon': 'assets/images/svg/dianpu.svg', 'label': '刷短剧' },
    { 'icon': 'assets/images/svg/shoucang.svg', 'label': '看小说' },
    { 'icon': 'assets/images/svg/shiyong.svg', 'label': '看直播' }

  ]
},
{
  'id': 2,
  'list': [
    { 'icon': 'assets/images/svg/order.svg', 'label': '我的订单', 'count': '待发货2' },
    { 'icon': 'assets/images/svg/chongzhi.svg', 'label': '充值中心', 'count': '减10元' },
    { 'icon': 'assets/images/svg/coupon.svg', 'label': '券红包' },
    { 'icon': 'assets/images/svg/cart.svg', 'label': '购物车' }
  ]
},
{
  'id': 3,
  'list': [
    { 'icon': 'assets/images/svg/kefu.svg', 'label': '客服消息' },
    { 'icon': 'assets/images/svg/tuikuan.svg', 'label': '退款/售后' },
    { 'icon': 'assets/images/svg/comment.svg', 'label': '评价中心' }
    ]
    }
  ];

  List<String> tabList = ['推荐', '新品', '手机', '酒水饮料', '男装', '女装', '爱车', '食品', '生鲜', '家电', '生活旅行'];

  // 瀑布流列表
  List waterfallData = [
    {
    'price': 69.00,
    'title': '一家超级美貌的面包甜品店🎅🏻🎄。',
    'shop': '甜品治愈店',
    'image': 'https://qcloud.dpfile.com/pc/v1bIsYHx3Y87jclud6DDqfNBYql3vxbAqq-znhZU9TH6C11FNL1SypW4dSClWkDpY0q73sB2DyQcgmKUxZFQtw.jpg',
    'saleNum': '8764'
  },
  {
    'price': 139.00,
    'title': '尝了第一口，立马决定加单了，真正的咸甜永动机啊🍬 ',
    'shop': '薄荷牛舌卷旗舰店',
    'image': 'https://qcloud.dpfile.com/pc/bPtiRX0q9JgU1nEzQCdo1YTkckPFWjHP0R9JSmB0C7Msmqt_iFFDpyVDwTmNHIV2Y0q73sB2DyQcgmKUxZFQtw.jpg',
    'saleNum': '1639'
  },
  {
    'price': 468.00,
    'title': '皮尔卡丹男装羽绒服男女同款冬季新款长款过膝加长加厚情侣款外套 黑色（可拆卸帽） 2XL',
    'shop': '皮尔卡丹专卖店',
    'image': 'https://img14.360buyimg.com/mobilecms/s360x360_jfs/t1/39114/14/20805/86340/638b4940E942d72fb/348e214e2d5c22f1.jpg',
    'saleNum': '1200'
  },
  {
    'price': 19.00,
    'title': '半价圣诞蛋糕🎄',
    'shop': '萨莉亚专卖店',
    'image': 'https://qcloud.dpfile.com/pc/YJ4OOVWA5sj34gPWC8Nkwpc8wuTQF9y4IfNQ2cimzKkuclZKFe3DWF0_YvlhKe8mY0q73sB2DyQcgmKUxZFQtw.jpg',
    'saleNum': '2.1万'
  },
  {
    'price': 2099.00,
    'title': '小米 REDMI K80 国家补贴 第三代骁龙 8 6550mAh大电池 澎湃OS 玄夜黑 12GB+256GB 红米5G至尊手机',
    'shop': '小米京东自营旗舰店',
    'image': 'https://img10.360buyimg.com/n1/s450x450_jfs/t1/264409/38/13856/102861/678dcfdaFb723c58f/5b97cf154bbba96c.jpg',
    'saleNum': '9726'
  },
  {
    'price': 1.00,
    'title': '圣菲尔伯爵法国红酒Saintfilcount干红葡萄酒珍藏13.5度单瓶送礼红酒 一元试饮',
    'shop': '小森葡萄酒专营店',
    'image': 'https://img10.360buyimg.com/n7/jfs/t1/226168/23/3411/118733/65537e5fF2db2d109/7d1d11a8013d6e8f.jpg',
    'saleNum': '9.9万'
  },
  {
    'price': 1499.90,
    'title': '茅台（MOUTAI）飞天 53%vol 500ml 贵州茅台酒（带杯）',
    'shop': '茅台京东自营旗舰店',
    'image': 'https://img13.360buyimg.com/n1/jfs/t1/97097/12/15694/245806/5e7373e6Ec4d1b0ac/9d8c13728cc2544d.jpg',
    'saleNum': '1254'
  },
  {
    'price': 42.00,
    'title': '美的（Midea）LED便携充电小台灯书桌学习阅读灯学生宿舍卧室床头灯学习台灯',
    'shop': '美的（Midea）旗舰店',
    'image': 'https://img14.360buyimg.com/mobilecms/s360x360_jfs/t1/226233/4/10194/156936/658e8f88Fcfc9cb40/cea4a48783f11a7a.jpg',
    'saleNum': '5106'
  },
  {
    'price': 19.90,
    'title': '『 江西炒米粉 』本次最佳😋香就一个字话。锅气的香🔥干辣椒的焦香🌶️油的润香🐷蔬菜混合的清香🥬',
    'shop': '去月球野餐嗎',
    'image': 'https://qcloud.dpfile.com/pc/pOAOL-DQRBWfkVZIWYVoy0mMQf6_UutNlOpEpGkT_nz3b1n7ZbpikPgtXMhMsjXNY0q73sB2DyQcgmKUxZFQtw.jpg',
    'saleNum': '3.2万'
  },
  {
    'price': 22.90,
    'title': '蒙都 羊杂500g 加热即食 京东超市肉干肉脯及礼包11.11真便宜',
    'shop': '蒙都旗舰店',
    'image': 'https://img10.360buyimg.com/n7/jfs/t1/155306/32/25324/231912/62d22fb8E4ffab855/c6001ee702fb240a.jpg',
    'saleNum': '1.6万'
    },
  ];
  // 列表
  List dataList = [];
  // 是否加载中
  bool isLoading = false;

late ScrollController scrollController = ScrollController();
late TabController tabController = TabController(initialIndex: 0, length: tabList.length, vsync: this);
final PageController pageController = PageController();
// 记录滚动位置
final ValueNotifier<double> scrollOffset = ValueNotifier(0);
Future<void> loadMoreData() async {
  if(isLoading) return;
  setState(() {
    isLoading = true;
  });
  // 模拟网络请求或数据获取延迟
  await Future.delayed(Duration(seconds: 1));
  setState(() {
    dataList.addAll(waterfallData);
  isLoading = false;
  });
}

// 下拉刷新
Future<void> handleRefresh() async {
  setState(() {
    dataList.clear();
  });
  loadMoreData();
}

@override
void initState() {
  super.initState();
  scrollController.addListener(() {
    scrollOffset.value = scrollController.offset;

    if(scrollController.position.pixels == scrollController.position.maxScrollExtent) {
      debugPrint('[index]滚动到底部');
      if(!isLoading) {
        loadMoreData();
      }
    }
  });

  // 初始化加载
  handleRefresh();
  }

  @override
  void dispose() {
    scrollController.dispose();
    tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
    backgroundColor: Colors.grey[50],
    body: ScrollConfiguration(
      behavior: CustomScrollBehavior().copyWith(scrollbars: false),
      child: RefreshIndicator(
        backgroundColor: Colors.white,
        color: Color(0xFFFF2C55),
        displacement: 10.0,
        onRefresh: handleRefresh,
        child: CustomScrollView(
          controller: scrollController,
          slivers: [
            SliverAppBar(
              backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          pinned: true,
          expandedHeight: 220.0,
          toolbarHeight: 94.0,
          titleSpacing: 0.0,
          title: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 第一行: logo + 品牌名  |  去绑定门店 + 购物车
              Padding(
                padding: EdgeInsets.only(left: 12.0, right: 6.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Image.asset('assets/images/logo.png', width: 26.0, height: 26.0, fit: BoxFit.contain, isAntiAlias: true),
                    SizedBox(width: 6.0),
                    Text('乐惠生活', style: TextStyle(color: Colors.white, fontSize: 20.0, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                    Spacer(),
                    // 去绑定门店入口
                    Material(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(15.0),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(15.0),
                        onTap: () {
                          debugPrint('去绑定门店');
                        },
                        child: Container(
                          padding: EdgeInsets.symmetric(horizontal: 10.0, vertical: 5.0),
                          child: Text('去绑定门店', style: TextStyle(color: Colors.white, fontSize: 13.0)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 6.0),
              // 搜索框(高斯模糊背景) + 右侧购物车
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 10.0),
                child: Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
            borderRadius: BorderRadius.circular(30.0),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
              child: Container(
                height: 42.0,
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(200),
            ),
            child: TextField(
                decoration: InputDecoration(
                  isDense: true,
              hintText: "2026国补",
              prefixIcon: Icon(Icons.search, color: Colors.black54, size: 20.0,),
              suffixIcon: Container(
                padding: EdgeInsets.only(right: 15.0),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  spacing: 10.0,
                  children: [
                    Icon(Icons.keyboard_voice, color: Colors.black54, size: 20.0,),
                    Icon(Icons.camera_alt_outlined, color: Colors.black54, size: 20.0,),
                  ],
                ),
                  ),
                  contentPadding: EdgeInsets.symmetric(vertical: 0, horizontal: 10.0),
                  border: OutlineInputBorder(borderSide: BorderSide.none, borderRadius: BorderRadius.circular(30.0))
                ),
                style: TextStyle(fontSize: 15.0),
                cursorColor: Colors.black,
                onChanged: (val) {
                  debugPrint(val);
                },
                  ),
                ),
              ),
                    ),
                  ),
                  SizedBox(width: 4.0),
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: BoxConstraints(minWidth: 30.0, minHeight: 30.0),
                    icon: Icon(Icons.shopping_cart_outlined, color: Colors.white, size: 22.0),
                    onPressed: () { debugPrint('购物车'); },
                  ),
                ],
              ),
              ),
            ],
          ),
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
                background: Swiper.children(
                pagination: SwiperPagination(
                      builder: DotSwiperPaginationBuilder(
                  color: Colors.white70,
                  activeColor: Colors.white,
                )
              ),
              indicatorLayout: PageIndicatorLayout.SCALE,
              children: [
                CachedNetworkImage(
                  imageUrl: 'https://m.360buyimg.com/babel/jfs/t20281118/356751/9/12253/82448/691d63f8Fc9511ae6/3d5a48eb2f613cd0.jpg',
                  placeholder: (context, url) => Container(color: Colors.grey[50]),
                  fit: BoxFit.fill,
                ),
                CachedNetworkImage(
                  imageUrl: 'https://m.360buyimg.com/babel/jfs/t20281126/363429/14/6762/278758/69283a1dFa354dd17/01953f5ca31b08fc.png',
                  placeholder: (context, url) => Container(color: Colors.grey[50]),
                  fit: BoxFit.fill,
                ),
                CachedNetworkImage(
                  imageUrl: 'https://m.360buyimg.com/babel/jfs/t20281125/363656/36/6056/154345/69267511F6c7bb231/ba21f9349fa661a6.jpg',
                  placeholder: (context, url) => Container(color: Colors.grey[50]),
                  fit: BoxFit.fill,
                ),
                CachedNetworkImage(
                  imageUrl: 'https://m.360buyimg.com/babel/jfs/t20281127/356616/26/17402/95517/69292231F262ad573/59e415cfbc72bfcb.jpg',
                  placeholder: (context, url) => Container(color: Colors.grey[50]),
                  fit: BoxFit.fill,
                ),
              ],
            ),
              ),
            ),
          ),

          // 分类
          SliverToBoxAdapter(
          child: Container(
            margin: EdgeInsets.all(10.0),
            padding: EdgeInsets.only(bottom: 6.0),
            height: 90.0,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10.0),
            ),
            child: Column(
              children: [
                Expanded(
                  child: PageView.builder(
                    controller: pageController,
                    itemCount: cateList.length,
                    itemBuilder: (context, index) {
                      final item = cateList[index];
                      return GridView.builder(
                        shrinkWrap: true,
                        padding: EdgeInsets.zero,
                        physics: NeverScrollableScrollPhysics(),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 4,
                        ),
                        itemCount: item['list'].length,
                        itemBuilder: (BuildContext context, int index) {
                          final citem = item['list'][index];
                          return Container(
                          padding: EdgeInsets.only(top: 12.0),
                            child: Column(
                              spacing: 3.0,
                              children: [
                                if (citem['icon'] != null)
                                  Badge(
                                    isLabelVisible: citem['count'] != null,
                                    backgroundColor: Colors.redAccent,
                                    label: Text('${citem['count']}'),
                                    child: SvgPicture.asset('${citem['icon']}', height: 30.0, width: 30.0,),
                                  ),
                                Text(citem['label']),
                              ],
                              ),
                              );
                            },
                          );
                          },
                        ),
                      ),
                      CustomPageViewIndicator(
                      controller: pageController,
                      count: cateList.length,
                      color: Color(0xFFCECECE),
                      activeColor: Color(0xFFFF2C55),
                    ),
                  ],
                )
              ),
            ),

            // tabbar列表
            SliverPersistentHeader(
              pinned: true,
              delegate: CustomStickyHeader(
                child: PreferredSize(
                preferredSize: Size.fromHeight(45.0),
                child: Container(
                  color: Colors.white,
                height: 45.0,
                child: TabBar(
                  controller: tabController,
                  tabs: tabList.map((v) => Tab(text: v)).toList(),
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                overlayColor: WidgetStateProperty.all(Colors.transparent),
                unselectedLabelColor: Colors.black87,
                labelColor: Color(0xFFFF2C55),
                indicatorColor: Color(0xFFFF2C55),
                indicatorSize: TabBarIndicatorSize.tab,
                unselectedLabelStyle: TextStyle(fontSize: 15.0, fontFamily: 'Microsoft YaHei'),
                labelStyle: TextStyle(fontSize: 15.0, fontFamily: 'Microsoft YaHei', fontWeight: FontWeight.w700),
                dividerHeight: 0,
                padding: EdgeInsets.symmetric(horizontal: 10.0),
                labelPadding: EdgeInsets.symmetric(horizontal: 10.0),
                indicatorPadding: EdgeInsets.symmetric(horizontal: 15.0, vertical: 5.0),
                ),
                ),
              ),
              ),
            ),

            // 瀑布流列表
            SliverPadding(
            padding: const EdgeInsets.all(10),
              sliver: SliverMasonryGrid.count(
                crossAxisCount: 2,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
              childCount: dataList.length,
              itemBuilder: (BuildContext context, int index) => CardItem(item: dataList[index]),
            ),
          ),
          SliverToBoxAdapter(
            child: Opacity(
              opacity: isLoading ? 1 : 0,
              child: const Padding(
                padding: EdgeInsets.only(bottom: 20),
                child: Loading(title: '加载中...'),
              ),
            ),
            ),
          ],
        ),
      ),
    ),
    // 返回顶部
    floatingActionButton: Backtop(controller: scrollController, offset: scrollOffset),
  );
}
}

// 卡片组件
class CardItem extends StatelessWidget {
final dynamic item;
const CardItem({super.key, required this.item});

@override
Widget build(BuildContext context) {
  return GestureDetector(
    child: Container(
      clipBehavior: Clip.antiAlias,
      padding: EdgeInsets.all(5.0),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(10.0),
    ),
    child: Column(
      children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(10.0),
      child: CachedNetworkImage(
        imageUrl: '${item['image']}',
        placeholder: (context, url) => Container(
          height: 150.0,
        ),
      ),
    ),
    Container(
      padding: EdgeInsets.all(5.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 5.0,
      children: [
        Text('${item['title']}', style: TextStyle(fontSize: 15.0, height: 1.2), maxLines: 2, overflow: TextOverflow.ellipsis,),
      Row(
        spacing: 5.0,
        children: [
          Text.rich(
            TextSpan(
              style: TextStyle(color: Colors.red, fontSize: 12.0, fontWeight: FontWeight.w700, fontFamily: 'Arial'),
              children: [
                TextSpan(text: '¥'),
                TextSpan(text: '${item['price']}', style: TextStyle(fontSize: 16.0,)),
              ]
            ),
          ),
            Text('已售${item['saleNum']}件', style: TextStyle(color: Colors.grey, fontSize: 10.0),),
          ],
        ),
          Text('${item['shop']}', style: TextStyle(color: Colors.grey, fontSize: 12.0),),
        ],
        ),
        )
        ],
      ),
    ),
    onTap: () {
      Get.toNamed('/goods');
    },
  );
  }
}
