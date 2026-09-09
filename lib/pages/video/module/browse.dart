/// 逛逛模块
library;

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:card_swiper/card_swiper.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../components/loading.dart';
import '../../../components/backtop.dart';

class BrowseModule extends StatefulWidget {
  const BrowseModule({ super.key });
  @override
  State<BrowseModule> createState() => _BrowseModuleState();
}

class _BrowseModuleState extends State<BrowseModule> {
  List<String> tabList = ['新品', '手机', '家电', '电脑数码', '汽车', '美食', '生鲜', '酒水饮料', '美妆', '家居'];
  // 瀑布流列表
  List waterfallData = [
    {
    'price': 239.90,
    'title': '品尝刺身、鲍鱼等新鲜出品，真材实料,样样新鲜。',
    'image': 'https://qcloud.dpfile.com/pc/miOQqbKoYWdIqbPwxS72LdqqQlFzBz8WjmTperw6AAF93TS4Nnp4B8i73Y5Dh7OPkkCBOWO5rApRy3gE6VS0Vg.jpg',
    'saleNum': '1.6万',
    'commnetNum': '6298',
    'tag': '上新'
  },
  {
    'price': 299.90,
    'title': '罗蒙（ROMON）羽绒服男外套爸爸装长款工作服装过膝加厚',
    'image': 'https://img14.360buyimg.com/mobilecms/s360x360_jfs/t1/172036/27/38888/54333/64ddd0f3Fa45b1afd/16bab41480f69947.jpg',
    'saleNum': '9.9万',
    'commnetNum': '4万+',
    'discount': '官方直降12%'
  },
  {
    'price': 19.00,
    'title': '奥利奥（Oreo）夹心饼干 草莓味349g 休闲零食 分享装 早餐下午茶（包装随机发）',
  'image': 'https://img14.360buyimg.com/mobilecms/s360x360_jfs/t1/238478/40/16230/137133/66ab636bFb9d5298b/ae2d46de5d1b898c.jpg',
  'saleNum': '7654',
  'commnetNum': '1208'
  },
  {
    'price': 6999.90,
    'title': '华为mate70 新品旗舰手机上市【现货当天发】 华为鸿蒙智能手机 曜石黑 12G+1TB 官方标配',
    'image': 'https://img11.360buyimg.com/n1/s450x450_jfs/t1/257273/7/12722/29856/6788a71aF72ffe327/4d247d1b354a8007.jpg',
    'saleNum': '1254',
    'commnetNum': '10万+',
    'tag': '年货节',
    'discount': '官方直降8%'
  },
  {
    'price': 43.90,
    'title': '维达（Vinda）抽纸 超韧3层150抽*24包S码 湿水不易破 卫生纸 纸巾 餐巾纸 整箱',
    'image': 'https://img14.360buyimg.com/mobilecms/s360x360_jfs/t1/258961/4/5484/170228/677266b8F0aa84789/d8f2446824f6bf9d.jpg',
    'saleNum': '1639',
    'commnetNum': '1万+'
  },
  {
    'price': 520.00,
    'title': '路易拉菲（LOUIS LAFON）法国原瓶进口红酒干红葡萄酒750ml果香浓郁聚会节日礼盒礼物送礼 传奇14度整箱装750ml*6瓶',
    'image': 'https://img14.360buyimg.com/mobilecms/s360x360_jfs/t1/176904/40/46082/129271/6642f885F0e20fb4b/1f81bcd1973f707a.jpg',
    'saleNum': '8764',
    'commnetNum': '10万+',
      'tag': '爆品'
    },
    {
    'price': 87.00,
    'title': '鲜京采 厄瓜多尔白虾 净重3斤/盒 特大号20-30规格   30-45只/盒',
    'image': 'https://img14.360buyimg.com/mobilecms/s360x360_jfs/t1/262779/20/6748/152056/6775e67dFe6af2c55/14d367d3f34d1296.jpg',
    'saleNum': '5106',
    'commnetNum': '16'
  },
  {
    'price': 8088.90,
    'title': '佳能（Canon） EOS 200D二代 200d2单反相机 入门级Vlog数码照相机200DII代 EF-S 18-55 STM 套机 白色 官方标配（抢64G卡 年货大礼包 ）',
    'image': 'https://img14.360buyimg.com/mobilecms/s360x360_jfs/t1/262166/32/8770/173845/677b92a9F99d806a6/9df47b8307d0e45a.jpg',
    'saleNum': '3.2万',
    'commnetNum': '3万+',
    'tag': '热门'
    },
  ];
  // 列表
  List dataList = [];
  bool isLoading = false;
  late ScrollController scrollController = ScrollController();
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
    debugPrint('[browse]滚动到底部');
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
      alignment: Alignment.center,
      margin: EdgeInsets.only(bottom: 5.0),
      height: 40.0,
      decoration: BoxDecoration(
        color: Colors.white,
      border: Border.all(color: Color(0xFFFF2C55), width: 1.5),
      borderRadius: BorderRadius.circular(10.0),
    ),
    child: TextField(
      decoration: InputDecoration(
        isDense: true,
        hintText: "请输入关键词",
        prefixIcon: Icon(Icons.search, color: Colors.black38, size: 20.0,),
        suffixIcon: Container(
        padding: EdgeInsets.only(right: 15.0),
        child: Row(
          mainAxisSize: MainAxisSize.min,
        spacing: 10.0,
        children: [
          Icon(Icons.keyboard_voice, color: Colors.black45, size: 20.0,),
          Icon(Icons.camera_alt_outlined, color: Colors.black45, size: 20.0,),
        ],
      ),
    ),
      contentPadding: EdgeInsets.symmetric(vertical: 0, horizontal: 10.0),
      border: OutlineInputBorder(borderSide: BorderSide.none,)
      ),
      style: TextStyle(fontSize: 14.0),
      cursorColor: Colors.black,
      onChanged: (val) {
        debugPrint(val);
          },
        ),
      ),
      bottom: PreferredSize(
        preferredSize: Size.fromHeight(40.0),
        child: SizedBox(
      height: 40.0,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
      padding: EdgeInsets.fromLTRB(10.0, 0, 10.0, 10.0),
      child: Row(
        spacing: 5.0,
        children: tabList.map((item) {
          return FilledButton(
            style: ButtonStyle(
            elevation: WidgetStateProperty.all(0.0),
            backgroundColor: WidgetStateProperty.all(Colors.white),
            foregroundColor: WidgetStateProperty.all(Colors.black),
            side: WidgetStateProperty.all(BorderSide(color: Colors.black12)),
            padding: WidgetStateProperty.all(EdgeInsets.symmetric(horizontal: 15.0)),
            shape: WidgetStatePropertyAll(
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0))
            )
          ),
          onPressed: () {},
          child: Text(item, style: TextStyle(fontSize: 13.0),),
        );
        }).toList(),
          ),
          ),
        )
      ),
      flexibleSpace: Container(
      decoration: BoxDecoration(
      image: DecorationImage(
        image: AssetImage('assets/images/hdbg1.png'),
        fit: BoxFit.fill,
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
        Color(0xFFFFFFFF), Color(0xFFF5F5F5)
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
          // 广告图
          Container(
            margin: EdgeInsets.fromLTRB(10.0, 10.0, 10.0, 0),
            height: 100.0,
          clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10.0),
            ),
            child: Swiper.children(
              autoplay: true,
              children: [
                CachedNetworkImage(imageUrl: 'https://m.360buyimg.com/babel/jfs/t20281123/362139/37/8600/111182/6923b524Fb48ae3d4/e86507485d34caf1.png', fit: BoxFit.fill,),
                CachedNetworkImage(imageUrl: 'https://m.360buyimg.com/babel/jfs/t20281104/350194/40/21791/112469/690b2c69F06798ce3/347ee0ab58bdadbc.jpg', fit: BoxFit.fill,),
                CachedNetworkImage(imageUrl: 'https://m.360buyimg.com/babel/jfs/t20281123/369519/16/5262/75892/692403aeF4b5d52fd/77fc1d7cfa0c553b.jpg', fit: BoxFit.fill,),
              ],
            ),
          ),
          Container(
            padding: EdgeInsets.all(10.0),
          child: Column(
            spacing: 10.0,
            children: [
          dataList.isEmpty ? 
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
    if (item['discount'] != null)
      Text('${item['discount']}', style: TextStyle(color: Color(0xff1dbe18), fontSize: 12.0),),
      Row(
      spacing: 5.0,
      children: [
      if (item['tag'] != null)
        Container(
          color: Colors.pinkAccent,
          padding: EdgeInsets.symmetric(horizontal: 2.0),
          child: Text('${item['tag']}', style: TextStyle(color: Colors.white, fontSize: 11.0),),
        ),
      Text('${item['commnetNum']}条评论', style: TextStyle(color: Colors.grey, fontSize: 11.0),),
        ],
      )
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
