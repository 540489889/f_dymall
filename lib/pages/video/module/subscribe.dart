/// 订阅模块
library;

import 'package:flutter/material.dart';
import 'package:card_swiper/card_swiper.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../components/loading.dart';
import '../../../components/backtop.dart';

class SubscribeModule extends StatefulWidget {
const SubscribeModule({ super.key });

@override
State<SubscribeModule> createState() => _SubscribeModuleState();
}

class _SubscribeModuleState extends State<SubscribeModule> {
// 模拟器请求数据
List fetchData = [
  {
    'logo': 'https://m.360buyimg.com/babel/jfs/t20281118/368484/24/2615/54720/691d8c73F2064e4c1/35ede2e5c43ecf4d.jpg',
  'name': '文娱商城专卖店',
  'subname': '天猫旗舰店',
  'time': '2分钟前',
  'images': [
    'https://m.360buyimg.com/babel/jfs/t20281118/368484/24/2615/54720/691d8c73F2064e4c1/35ede2e5c43ecf4d.jpg',
    'https://m.360buyimg.com/babel/jfs/t20281120/358726/23/13220/166260/692001f1F289212a0/38d2676e424c688a.png',
    'https://m.360buyimg.com/babel/jfs/t1/359464/9/9094/145185/691682c9F15da3722/1897f0c78f62d21c.png',
    'https://m.360buyimg.com/babel/jfs/t1/348850/23/25735/107527/6916929dF9ef45e77/6e40c0736435e35a.png',
  ],
  'desc': '跨店好书，图解百科，立减10%起'
},
{
  'logo': 'https://img10.360buyimg.com/n1/s450x450_jfs/t1/180445/36/49960/141577/67203b9aFcc5462d7/baecf198635367d9.jpg',
  'name': '小米京东自营旗舰店',
  'subname': '京东自营店',
  'time': '10分钟前',
  'images': [
    'https://img.alicdn.com/imgextra/i4/1714128138/O1CN01kQdpTK29zGHhH3bcb_!!1714128138.png',
    'https://img.alicdn.com/imgextra/i4/2218608788268/O1CN01P0KoIp2AwnlSqZ6JZ_!!2218608788268.png'
  ],
    'desc': '小米17Pro Max 手机新品新款上市小米徕卡联合研发小米手机官网同款'
  },
  {
    'logo': 'https://img14.360buyimg.com/mobilecms/s360x360_jfs/t1/39114/14/20805/86340/638b4940E942d72fb/348e214e2d5c22f1.jpg',
    'name': '时尚男装',
    'subname': '时尚男装京东专卖店',
    'time': '6小时前',
    'desc': '男装羽绒服男女同款冬季新款长款过膝加长加厚情侣款外套 黑色（可拆卸帽） 2XL'
  },
  {
    'logo': 'https://m.360buyimg.com/babel/jfs/t1/234937/40/29822/63318/6757aa98F1b059678/e482cf2ae399447b.jpg',
    'name': '京蟹世家',
    'subname': '京蟹世家旗舰店',
    'time': '昨天',
      'images': [
      'https://m.360buyimg.com/babel/jfs/t20281119/360051/39/7244/61672/691eef46F2e64a4f7/3e0324d8869c8f3a.jpg',
      'https://m.360buyimg.com/babel/jfs/t20281116/367502/27/1329/169465/691b0ef6F464a7bd9/8253b1d0a8c0b6d0.jpg',
      'https://m.360buyimg.com/babel/jfs/t20281119/353960/29/14705/182638/691ee1f5Fbc331c3e/52d677aa9641f7fb.png',
    ],
    'desc': '【活蟹】阳澄逍遥大闸蟹鲜活螃蟹全母2.7-3.0两8只现货生鲜礼盒海鲜湖河蟹次日达'
  },
];
// 列表
List dataList = [];
// 是否加载中
bool isLoading = false;
late ScrollController scrollController = ScrollController();
// 记录滚动位置
final ValueNotifier<double> scrollOffset = ValueNotifier(0);

// 加载更多
Future<void> loadMoreData() async {
    if(isLoading) return;
  setState(() {
    isLoading = true;
  });
  // 模拟网络请求或数据获取延迟
  await Future.delayed(Duration(seconds: 1));
  setState(() {
    dataList.addAll(fetchData);
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
    debugPrint('[subscribe]滚动到底部');
    if(!isLoading) {
      loadMoreData();
    }
  }
});

  handleRefresh();
}

@override
void dispose() {
  scrollController.dispose();
  super.dispose();
}

@override
Widget build(BuildContext context) {
  return Scaffold(
    backgroundColor: Colors.white,
      appBar: AppBar(
      toolbarHeight: 0,
      forceMaterialTransparency: true,
    ),
    body: Container(
      color: Colors.grey[50],
      child: dataList.isEmpty ? 
      // 初始loading提示
      Center(
        child: RefreshProgressIndicator(
          backgroundColor: Colors.white,
          color: Color(0xFFFF2C55),
          indicatorMargin: EdgeInsets.only(top: 10.0),
        ),
      )
      :
      RefreshIndicator(
        backgroundColor: Colors.white,
        color: Color(0xFFFF2C55),
      displacement: 10.0,
      onRefresh: handleRefresh,
      child: ListView.builder(
        controller: scrollController,
        physics: BouncingScrollPhysics(),
      padding: EdgeInsets.all(10.0),
      itemCount: dataList.length + 1,
      itemBuilder: (BuildContext context, int index) {
        // 底部loading提示
        if(index == dataList.length) {
          return Loading();
        }
        return CardItem(item: dataList[index]);
        },
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
  return Container(
    margin: EdgeInsets.only(bottom: 10.0),
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
child: ListTile(
    contentPadding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 5.0),
    title: Row(
      spacing: 5.0,
    children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(100.0),
        child: Image.network('${item['logo']}', height: 35.0, width: 35.0, isAntiAlias: true, fit: BoxFit.cover,),
      ),
      Expanded(
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(item['name'], style: TextStyle(fontSize: 15.0, fontWeight: FontWeight.w700),),
          Text(item['subname'], style: TextStyle(fontSize: 12.0, color: Colors.grey[400]),),
        ],
      ),
    ),
    Text(item['time'], style: TextStyle(fontSize: 11.0, color: Colors.grey[400]),),
    ],
  ),
  subtitle: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    spacing: 5.0,
  children: [
    SizedBox(height: 5.0,),
      // 图片区域
      if (item['images'] != null)
      Container(
        height: 180.0,
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(
      color: Colors.grey[50],
      borderRadius: BorderRadius.circular(10.0),
    ),
    child: Swiper(
      itemBuilder: (context, index) {
        return CachedNetworkImage(imageUrl: '${item['images'][index]}', fit: BoxFit.fill,);
      },
      itemCount: item['images'].length,
      pagination: SwiperPagination(
        alignment: Alignment.bottomRight,
      builder: DotSwiperPaginationBuilder(
        color: Colors.white,
        activeColor: Color(0xFFFF2C55),
        size: 5.0,
        activeSize: 5.0
        ),
        ),
      ),
    ),
  Text(item['desc'], style: const TextStyle(fontSize: 14.0,),),
    SizedBox(height: 5.0,),
    Row(
    children: [
      const Expanded(
        child: Row(
          spacing: 10.0,
        children: [
        Row(
          children: [
            Icon(Icons.share, color: Colors.black54, size: 16.0,),
          ],
        ),
        ]
        ),
        ),
      Row(
        spacing: 15.0,
        children: [
          const Row(
            spacing: 2.0,
            children: [
              Icon(Icons.favorite_border, color: Colors.black54, size: 16.0,), Text('点赞', style: TextStyle(color: Colors.black54, fontSize: 12.0),),
            ],
          ),
          const Row(
            spacing: 2.0,
            children: [
              Icon(Icons.star_border, color: Colors.black54, size: 16.0,), Text('收藏', style: TextStyle(color: Colors.black54, fontSize: 12.0),),
            ],
          ),
          const Row(
            spacing: 2.0,
            children: [
              Icon(Icons.messenger_outline, color: Colors.black54, size: 16.0,), Text('评论', style: TextStyle(color: Colors.black54, fontSize: 12.0),),
            ],
            ),
            ]
          ),
          ],
        ),
      ],
      ),
    ),
  );
}
}
