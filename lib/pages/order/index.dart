/// 订单列表模板
library;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import '../../behavior/custom_scroll_behavior.dart';
import '../../components/popup_pay.dart';
class Order extends StatefulWidget {
  const Order({super.key});

  @override
  State<Order> createState() => _OrderState();
}

class _OrderState extends State<Order> with SingleTickerProviderStateMixin {
  GlobalKey<ScaffoldState> scaffoldKey = GlobalKey();
List tabList = [
 {'name': "全部"},
  {'name': "待付款", 'badge': 1},
 {'name': "待发货"},
  {'name': "待收货"},
 {'name': "已完成"},
{'name': "取消"}
];

late ScrollController scrollController = ScrollController();
late TabController tabController = TabController(initialIndex: 0, length: tabList.length, vsync: this);

Widget emptyTip() {
  return Column(
  mainAxisAlignment: MainAxisAlignment.center,
  spacing: 5.0,
  children: [
    SvgPicture.asset('assets/images/svg/empty.svg', colorFilter: ColorFilter.mode(Colors.black38, BlendMode.srcIn), width: 40.0,),
    Text('还没有相关订单~', style: TextStyle(color: Colors.grey, fontSize: 12.0),)
  ],
);
}

@override
void initState() {
  super.initState();
}

@override
void dispose() {
  scrollController.dispose();
  tabController.dispose();
  super.dispose();
}

// 支付弹窗
 void submitPayDialog() {
  showModalBottomSheet(
  backgroundColor: Colors.grey[50],
  shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(15.0))),
  showDragHandle: true,
  clipBehavior: Clip.antiAlias,
  context: context,
  builder: (context) {
    return PopupPay(
      onChanged: (value) {
        debugPrint('支付信息::: $value');
      },
    );
    },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: scaffoldKey,
    backgroundColor: Colors.white,
    appBar: AppBar(
      forceMaterialTransparency: true,
      titleSpacing: 1.0,
      title: Container(
        height: 36.0,
        margin: EdgeInsets.only(right: 5.0),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(30.0),
      ),
      child: TextField(
        decoration: InputDecoration(
          isDense: true,
        hintText: "搜索订单",
        hintStyle: TextStyle(color: Colors.black38, fontSize: 14.0),
        prefixIcon: Icon(Icons.search, color: Colors.black38, size: 21.0,),
        contentPadding: EdgeInsets.symmetric(vertical: 0, horizontal: 10.0),
        border: OutlineInputBorder(borderSide: BorderSide.none, borderRadius: BorderRadius.circular(30.0))
      ),
      cursorColor: Colors.black,
      onChanged: (val) {
        debugPrint(val);
      },
      ),
    ),
    actions: [
      IconButton(
        icon: Icon(Icons.filter_alt_outlined, size: 18.0),
        onPressed: () {
          // 自定义打开右侧drawer
          scaffoldKey.currentState?.openEndDrawer();
          },
        ),
      ],
      bottom: PreferredSize(
        preferredSize: Size.fromHeight(45.0),
        child: Row(
        children: [
          Expanded(
            child: TabBar(
            controller: tabController,
          tabs: tabList.map((item) => Container(
          alignment: Alignment.center,
          height: 45.0,
          child: Badge.count(
            backgroundColor: Colors.red,
            count: item['badge'] ?? 0,
            isLabelVisible: item['badge'] != null ? true : false,
            child: Text(item['name'])
          ),
        )).toList(),
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        overlayColor: WidgetStateProperty.all(Colors.transparent),
        unselectedLabelColor: Colors.black87,
        labelColor: Color(0xFFFF2C55),
        indicator: UnderlineTabIndicator(
          borderRadius: BorderRadius.circular(10.0),
          borderSide: BorderSide(color: Color(0xFFFF2C55), width: 2.0),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        unselectedLabelStyle: TextStyle(fontSize: 16.0, fontFamily: 'Microsoft YaHei'),
        labelStyle: TextStyle(fontSize: 18.0, fontFamily: 'Microsoft YaHei', fontWeight: FontWeight.w700),
        dividerHeight: 0,
        padding: EdgeInsets.symmetric(horizontal: 10.0),
          labelPadding: EdgeInsets.symmetric(horizontal: 10.0),
          indicatorPadding: EdgeInsets.symmetric(horizontal: 15.0, vertical: 5.0),
        ),
          ),
          ]
        ),
        ),
      ),
      body: ScrollConfiguration(
        behavior: CustomScrollBehavior().copyWith(scrollbars: false),
        child: Container(
        color: Colors.grey[50],
      child: TabBarView(
      controller: tabController,
      children: [
        ListView(
          controller: scrollController,
          physics: BouncingScrollPhysics(),
          padding: EdgeInsets.all(10.0),
        children: [
          GestureDetector(
          child: Container(
            margin: EdgeInsets.only(bottom: 10.0),
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
            child: Column(
              spacing: 10.0,
              children: [
              Row(
                children: [
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 5.0,
                children: [
                  ClipOval(
                    child: Image.asset('assets/images/avatar/img11.jpg', width: 25.0,),
                ),
                  Text('老白干自营旗舰店'),
                    Icon(Icons.arrow_forward_ios_rounded, color: Colors.grey, size: 12.0,),
                  ],
                ),
                Spacer(),
                Text('待付款', style: TextStyle(color: Colors.red),)
              ],
              ),
              Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 10.0,
                children: [
                  Image.network('https://img14.360buyimg.com/mobilecms/s360x360_jfs/t1/259359/11/175/106869/676390c0Fc19afe45/0d87faffa5e788e6.jpg', width: 80.0,),
                Expanded(
                  child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 5.0,
                children: [
                  Text('贺兰红西鸽N18赤霞珠干红葡萄酒750ml*6整箱装 宁夏贺兰山国产红酒宴请', maxLines: 2, overflow: TextOverflow.ellipsis,),
                  Row(
                    children: [
                      Text('¥199', style: TextStyle(color: Colors.red),),
                      Spacer(),
                      Text('x10', style: TextStyle(color: Colors.grey),),
                      ],
                    ),
                      ],
                    ),
                  )
                  ],
                ),
                // 提示信息
                Container(
                  padding: EdgeInsets.all(5.0),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(5.0),
                  ),
                  child: Row(
                    children: [
                    Icon(Icons.person_pin),
                    Text('已拼团8人，还差2人'),
                    Spacer(),
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(text: '实付款: '),
                          TextSpan(text: '¥1990', style: TextStyle(color: Colors.red),),
                        ]
                      ),
                      ),
                    ],
                    ),
                  ),
                  // 按钮组
                  Row(
                    spacing: 10.0,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    ElevatedButton(onPressed: (){}, style: ButtonStyle(backgroundColor: WidgetStateProperty.all(Colors.white)), child: Text('取消订单'),),
                    ElevatedButton(onPressed: (){submitPayDialog();}, style: ButtonStyle(backgroundColor: WidgetStateProperty.all(Color(0xff07c160)), foregroundColor: WidgetStateProperty.all(Colors.white)), child: Text('去支付'),),
                  ],
                ),
                Row(
                    spacing: 10.0,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      ElevatedButton(onPressed: (){}, style: ButtonStyle(backgroundColor: WidgetStateProperty.all(Colors.white)), child: Text('查看发票'),),
                      ElevatedButton(onPressed: (){}, style: ButtonStyle(backgroundColor: WidgetStateProperty.all(Color(0xFF10B9FC)), foregroundColor: WidgetStateProperty.all(Colors.white)), child: Text('评价'),),
                    ],
                  ),
                  Row(
                  spacing: 10.0,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    ElevatedButton(onPressed: (){}, style: ButtonStyle(backgroundColor: WidgetStateProperty.all(Colors.white)), child: Text('申请退款'),),
                    ElevatedButton(onPressed: (){}, style: ButtonStyle(backgroundColor: WidgetStateProperty.all(Color(0xFFFFCC00)), foregroundColor: WidgetStateProperty.all(Colors.white)), child: Text('联系客服'),),
                  ],
                ),
                  Row(
                    spacing: 10.0,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      ElevatedButton(onPressed: (){}, style: ButtonStyle(backgroundColor: WidgetStateProperty.all(Colors.white)), child: Text('退款/售后'),),
                    ],
                  ),
                  Row(
                    spacing: 10.0,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      ElevatedButton(onPressed: (){}, style: ButtonStyle(backgroundColor: WidgetStateProperty.all(Colors.white)), child: Text('删除'),),
                      ElevatedButton(onPressed: (){}, style: ButtonStyle(backgroundColor: WidgetStateProperty.all(Color(0xFFFF2C55)), foregroundColor: WidgetStateProperty.all(Colors.white)), child: Text('再次预订'),),
                    ],
                    ),
                  ],
                  ),
                ),
                onTap: () {
                  Get.toNamed('/order/detail');
                },
              ),
              SizedBox(
                height: 180.0,
                child: emptyTip(),
                )
              ],
            ),
            emptyTip(),
            emptyTip(),
            emptyTip(),
            emptyTip(),
            emptyTip(),
          ]
        ),
        ),
      ),
      endDrawer: Drawer(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.horizontal(left: Radius.circular(15.0))),
      width: 300,
      clipBehavior: Clip.antiAlias,
      child: Container(
        color: Colors.white,
      child: Column(
        children: [
          SizedBox(
            height: 200.0,
            child: emptyTip(),
          )
        ],
      ),
      ),
    ),
    );
  }
}
