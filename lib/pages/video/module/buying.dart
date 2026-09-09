/// 团购服务模块
library;

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:card_swiper/card_swiper.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../components/loading.dart';
import '../../../components/backtop.dart';
class BuyingModule extends StatefulWidget {
  const BuyingModule({ super.key });
  @override
  State<BuyingModule> createState() => _BuyingModuleState();
}

class _BuyingModuleState extends State<BuyingModule> {
  // 瀑布流列表
  List waterfallData = [
  {
    'price': 159.00,
    'title': '🍓草莓森林大杯',
    'image': 'https://qcloud.dpfile.com/pc/axq-vtc5adxDGDP9Ol9zr3S3tN0LjF2_gd76ih9NAXosmqt_iFFDpyVDwTmNHIV2Y0q73sB2DyQcgmKUxZFQtw.jpg',
    'saleNum': '7654',
    'commnetNum': '1208'
  },
  {
    'price': 65.90,
    'title': '干蒸排骨鲜嫩多汁， 猪杂粥味道很浓郁， 菜品很多个个都很好吃，性价比很高的一家店。',
    'image': 'https://qcloud.dpfile.com/pc/yEm2MxGwYZpPUWKgqYXPn0ZI3jqPBpPh8y25s4xRQzO0UZP48IL4YPQJmSCpTA-lY0q73sB2DyQcgmKUxZFQtw.jpg',
    'saleNum': '1.6万',
    'commnetNum': '6204'
  },
  {
    'price': 519.90,
    'title': '贺兰红西鸽N18赤霞珠干红葡萄酒750ml*6整箱装 宁夏贺兰山国产红酒宴请',
    'image': 'https://img14.360buyimg.com/mobilecms/s360x360_jfs/t1/259359/11/175/106869/676390c0Fc19afe45/0d87faffa5e788e6.jpg',
    'saleNum': '1.2万',
    'commnetNum': '8235',
    'tag': '上新'
  },
  {
    'price': 118.00,
      'title': '坠入Eatery·贵州创意菜(前滩店)，豆腐丸子超级好吃，一口惊艳。',
    'image': 'https://qcloud.dpfile.com/pc/vPi98wCha-04XdrONtpkU2fVNXBDzdlEgMUphUr4zuRmlW0dkLcW1DgXgRk7-KjjY0q73sB2DyQcgmKUxZFQtw.jpg',
    'saleNum': '5106',
    'commnetNum': '16'
  },
  {
    'price': 43.90,
    'title': '山姆店员：活爹们吃吧…吃吧…#山姆 #年末美食大作战',
    'image': 'https://p0.meituan.net/coverpic/2ab6bf4c6495bf3697f8b8e86eb7e3e7198978.jpg',
    'saleNum': '1639',
    'commnetNum': '1万+'
  },
  {
    'price': 520.00,
    'title': 'BAKE CHEESE TART(上海美罗城店)',
    'image': 'https://qcloud.dpfile.com/pc/PcgqFPbvXzt087psfK4cf_n_e_IZdyyujtnPoH-cCrsdTQUGwTBAhidAJAD-FdVSY0q73sB2DyQcgmKUxZFQtw.jpg',
  'saleNum': '8764',
  'commnetNum': '10万+',
    'tag': '爆品'
  },
  {
    'price': 599.90,
    'title': '自助餐就该这么吃！蚝英雄·鲜蚝自助(金虹桥店)',
    'image': 'https://p0.meituan.net/coverpic/6b55492ea0b5032ee0becf6b9a524329336170.jpg',
    'saleNum': '9.9万',
    'commnetNum': '4万+'
  },
  {
    'price': 299.90,
    'title': '韩料界的萨莉亚！',
    'image': 'https://qcloud.dpfile.com/pc/1c3egbzM_ICz90dhi6MAiTsazjxWYQcHCd-sbpD1Wqtph2eIJA04NCRvoGqL4_opG45IiB1YIyNuDTtqzVRwesm_qA1Pf8rFcayTY-n-rG8.jpg',
    'saleNum': '1254',
    'commnetNum': '10万+',
  },
  ];
  // 列表
  List dataList = [];
  bool isLoading = false;

  late ScrollController scrollController = ScrollController();
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
    debugPrint('[buying]滚动到底部');
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
    forceMaterialTransparency: true,
    title: Container(
      margin: EdgeInsets.only(bottom: 5.0),
      height: 40.0,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30.0),
      ),
      child: TextField(
        decoration: InputDecoration(
          isDense: true,
        hintText: "华为MateXT",
        prefixIcon: Icon(Icons.search, color: Colors.black38, size: 20.0,),
      suffixIcon: Container(
        margin: EdgeInsets.all(4.0),
        child: FilledButton(
          style: ButtonStyle(
            elevation: WidgetStateProperty.all(0.0),
          backgroundColor: WidgetStateProperty.all(Color(0xFFFF2C55)),
          padding: WidgetStateProperty.all(EdgeInsets.symmetric(horizontal: 15.0)),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(30.0))
          )
        ),
        onPressed: () {},
        child: Text('搜索', style: TextStyle(fontSize: 13.0),),
        ),
      ),
      contentPadding: EdgeInsets.symmetric(vertical: 0, horizontal: 10.0),
      border: OutlineInputBorder(borderSide: BorderSide.none, borderRadius: BorderRadius.circular(30.0))
    ),
    style: TextStyle(fontSize: 14.0),
    cursorColor: Colors.black,
        onChanged: (val) {
          debugPrint(val);
        },
      ),
    ),
    flexibleSpace: Container(
      decoration: BoxDecoration(
    image: DecorationImage(
        image: AssetImage('assets/images/hdbg2.png'),
        fit: BoxFit.cover,
      ),
    ),
    ),
  ),
  body: Container(
    decoration: BoxDecoration(
    gradient: LinearGradient(
        begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        Color(0xFFFFFFFF), Color(0xFFFEFEFE), Color(0xFFF5F5F5)
      ]
      )
    ),
    child: RefreshIndicator(
      backgroundColor: Colors.white,
      color: Color(0xFFFF2C55),
      displacement: 10.0,
      onRefresh: handleRefresh,
      child: ListView(
        controller: scrollController,
        children: [
        Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFFF2C55), Color(0xFFFFFFFF)
            ],
              stops: [0.1, 0.9],
            )
          ),
          child: Column(
            spacing: 10.0,
            children: [
              Container(
                margin: EdgeInsets.symmetric(horizontal: 10.0),
                padding: EdgeInsets.all(10.0),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10.0),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                  Column(
                  spacing: 3.0,
                children: [
                  SvgPicture.asset('assets/images/svg/order.svg', height: 30.0, width: 30.0,),
                  Text('我的订单')
                ],
                ),
                Column(
                  spacing: 3.0,
                  children: [
                    SvgPicture.asset('assets/images/svg/coupon.svg', height: 30.0, width: 30.0,),
                    Text('券红包')
                  ],
                ),
                Column(
                  spacing: 3.0,
                  children: [
                    SvgPicture.asset('assets/images/svg/huiyuan.svg', height: 30.0, width: 30.0,),
                    Text('品牌会员')
                  ],
                ),
                Column(
                  spacing: 3.0,
                  children: [
                  SvgPicture.asset('assets/images/svg/dianpu.svg', height: 30.0, width: 30.0,),
                    Text('店铺')
                    ],
                    )
                  ],
                ),
                ),
                // 广告图
                Container(
                  margin: EdgeInsets.symmetric(horizontal: 10.0),
                  height: 100.0,
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10.0),
                ),
                child: Swiper.children(
                  autoplay: true,
                  children: [
                  CachedNetworkImage(imageUrl: 'https://m.360buyimg.com/babel/jfs/t1/369715/17/2824/92983/691ef5ceFff402826/700143971b5b5fa9.jpg', fit: BoxFit.fill),
                  CachedNetworkImage(imageUrl: 'https://m.360buyimg.com/babel/jfs/t20281117/369895/25/1552/68519/691bd4a0F5cb22807/11e74517a610eaf8.jpg', fit: BoxFit.fill),
                  CachedNetworkImage(imageUrl: 'https://m.360buyimg.com/babel/jfs/t20281029/342471/24/17408/133576/69030210F21c75ee4/73ef726201caf33a.jpg', fit: BoxFit.fill),
                ],
                ),
              ),
              ],
            ),
          ),
          Container(
          padding: EdgeInsets.all(10.0),
          child: Column(
            spacing: 10.0,
          children: [
          dataList.isEmpty ? 
            // 初始loading提示
            Column(
              children: [
              RefreshProgressIndicator(
                backgroundColor: Colors.white,
                color: Color(0xFFFF2C55),
              ),
            ],
          )
          :
          MasonryGridView.count(
            shrinkWrap: true,
            padding: EdgeInsets.zero,
            physics: NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            mainAxisSpacing: 10.0,
            crossAxisSpacing: 10.0,
            itemCount: dataList.length,
            itemBuilder: (BuildContext context, int index) => CardItem(item: dataList[index]),
          ),
          Opacity(
            opacity: dataList.isNotEmpty && isLoading ? 1 : 0,
            child: Loading(title: '加载中...')
            ),
              ],
            ),
          ),
          ],
        ),
      ),
    ),
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
  child: Column(
    children: [
      CachedNetworkImage(
      imageUrl: '${item['image']}',
      placeholder: (context, url) => Container(
        height: 150.0,
      ),
      ),
      Container(
        padding: EdgeInsets.symmetric(horizontal: 10.0, vertical: 5.0),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 5.0,
        children: [
            Text.rich(
          TextSpan(
          children: [
            TextSpan(text: ' 团购 ', style: TextStyle(fontSize: 11.0, backgroundColor: Colors.orange, color: Colors.white)),
            TextSpan(text: ' ${item['title']}', style: TextStyle(fontSize: 14.0, height: 1.2),),
          ]
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        Row(
            spacing: 5.0,
            children: [
              Text('500m', style: TextStyle(color: Colors.grey, fontSize: 10.0),),
              Text('快餐', style: TextStyle(color: Colors.grey, fontSize: 10.0),),
              Text('已售${item['saleNum']}+', style: TextStyle(color: Colors.grey, fontSize: 10.0),),
            ],
          ),
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
              Text('3.5折', style: TextStyle(color: Colors.green, fontSize: 10.0),),
              ],
            ),
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
