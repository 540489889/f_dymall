/// 确认订单
library;

import 'package:flutter/material.dart';
import 'package:card_swiper/card_swiper.dart';
import 'package:get/get.dart';
import 'package:shirne_dialog/shirne_dialog.dart';
import '../../behavior/custom_scroll_behavior.dart';
import '../../components/popup_pay.dart';

class OrderSure extends StatefulWidget {
  const OrderSure({ super.key });
  @override
  State<OrderSure> createState() => _OrderSureState();
}

class _OrderSureState extends State<OrderSure> {
  // 房间数
  int roomNum = 1;
  @override
  void initState() {
  super.initState();
}

@override
void dispose() {
  super.dispose();
  }
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
        MyDialog.toast('$value');
      },
      );
    },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
    backgroundColor: Colors.grey[50],
    appBar: AppBar(
      forceMaterialTransparency: true,
      titleSpacing: 1.0,
      leading: IconButton(
        icon: Icon(Icons.arrow_back_ios_rounded, size: 20.0,),
        onPressed: () {
          Get.back();
        },
      ),
      title: Text('确认订单', style: TextStyle(fontSize: 18.0),),
    ),
    body: ScrollConfiguration(
      behavior: CustomScrollBehavior().copyWith(scrollbars: false),
      child: ListView(
        padding: EdgeInsets.zero,
      children: [
        Container(
          margin: EdgeInsets.fromLTRB(10.0, 5.0, 10.0, 0),
          padding: EdgeInsets.all(10.0),
        width: double.infinity,
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
            spacing: 5.0,
            children: [
            Icon(Icons.location_on_outlined),
            Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text.rich(
                  TextSpan(
                    children: [
                      WidgetSpan(child: Text('Andy', style: TextStyle(fontSize: 16.0),)),
                      WidgetSpan(child: SizedBox(width: 5.0,)),
                      WidgetSpan(child: Text('134****2030', style: TextStyle(color: Colors.grey, fontSize: 12.0),)),
                    ]
                    )
                  ),
                  Text('广东省 深圳市 龙岗区 保利国际大厦2栋10单元', maxLines: 1, overflow: TextOverflow.ellipsis,)
                ],
              ),
            ),
              Icon(Icons.arrow_forward_ios_rounded, size: 12.0)
              ],
              ),
            ),

          Container(
            margin: EdgeInsets.fromLTRB(10.0, 10.0, 10.0, 0),
          padding: EdgeInsets.all(10.0),
          width: double.infinity,
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
            Container(
              constraints: BoxConstraints(minWidth: 80.0),
              child: Text('收货人'),
            ),
            Expanded(
              child: TextField(
              style: const TextStyle(fontSize: 14.0,),
              decoration: const InputDecoration(
                  hintText: '请输入收货人姓名',
                  hintStyle: TextStyle(color: Colors.grey),
                  isDense: true,
                  hoverColor: Colors.transparent,
                  contentPadding: EdgeInsets.all(0.0),
                  border: OutlineInputBorder(borderSide: BorderSide.none),
                ),
              ),
              ),
              Icon(Icons.person_add_alt, color: Color(0xFF006ff6),  size: 18.0),
            ],
          ),
          Divider(color: Color(0xfff7f7f7), thickness: 1.0, height: 1.0,),
          Row(
          children: [
            Container(
              constraints: BoxConstraints(minWidth: 80.0),
              child: Text('手机号码'),
            ),
            Expanded(
              child: TextField(
              style: const TextStyle(fontSize: 14.0,),
              decoration: const InputDecoration(
                hintText: '请输入手机号',
              hintStyle: TextStyle(color: Colors.grey),
              isDense: true,
              hoverColor: Colors.transparent,
              contentPadding: EdgeInsets.all(0.0),
              border: OutlineInputBorder(borderSide: BorderSide.none),
            ),
              ),
            ),
            Icon(Icons.phone_android_outlined, color: Color(0xFF006ff6), size: 18.0),
              ],
            ),
              Divider(color: Color(0xfff7f7f7), thickness: 1.0, height: 1.0,),
              Row(
                children: [
                Container(
                  constraints: BoxConstraints(minWidth: 80.0),
                  child: Text('所在区域'),
                ),
                Expanded(
                  child: TextField(
                    readOnly: true,
                  style: const TextStyle(fontSize: 14.0,),
                  decoration: const InputDecoration(
                    hintText: '请选择区域',
                    hintStyle: TextStyle(color: Colors.grey),
                    isDense: true,
                    hoverColor: Colors.transparent,
                    contentPadding: EdgeInsets.all(0.0),
                    border: OutlineInputBorder(borderSide: BorderSide.none),
                  ),
                  onTap: () {
                    MyDialog.toast('该功能自行实现~');
                  },
                  ),
                ),
                Icon(Icons.arrow_forward_ios_rounded, color: Colors.grey, size: 12.0,),
                ],
              ),
              Divider(color: Color(0xfff7f7f7), thickness: 1.0, height: 1.0,),
              Row(
              children: [
                Container(
                  constraints: BoxConstraints(minWidth: 80.0),
                child: Text('详细地址'),
              ),
              Expanded(
                child: TextField(
                    style: const TextStyle(fontSize: 14.0,),
                    decoration: const InputDecoration(
                      hintText: '请输入详细收获地址',
                      hintStyle: TextStyle(color: Colors.grey),
                      isDense: true,
                      hoverColor: Colors.transparent,
                      contentPadding: EdgeInsets.all(0.0),
                      border: OutlineInputBorder(borderSide: BorderSide.none),
                    ),
                  ),
                ),
              ],
              ),
            ],
            )
          ),

          // 商品信息
          Container(
            margin: EdgeInsets.fromLTRB(10.0, 10.0, 10.0, 0),
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
            ],
            ),
          ),
        // 优惠券
        Container(
          margin: EdgeInsets.fromLTRB(10.0, 10.0, 10.0, 0),
        padding: EdgeInsets.all(10.0),
        width: double.infinity,
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
        child: InkWell(
          child: Row(
          children: [
            Text('优惠券', style: TextStyle(fontSize: 16.0, fontWeight: FontWeight.w700),),
            Spacer(),
            Text('2张优惠券',  style: TextStyle(fontSize: 12.0),),
            Icon(Icons.arrow_forward_ios_rounded, color: Colors.grey, size: 12.0,),
          ],
          ),
          onTap: () {
            MyDialog.toast('该功能自行实现~');
          },
          )
        ),
        // 积分
        Container(
          margin: EdgeInsets.fromLTRB(10.0, 10.0, 10.0, 0),
        padding: EdgeInsets.all(10.0),
        width: double.infinity,
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
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 5.0,
          children: [
            Text('本单可享', style: TextStyle(fontSize: 16.0, fontWeight: FontWeight.w700),),
          Row(
            children: [
              Text('下单赚10倍积分'),
              Spacer(),
              Text('168积分',  style: TextStyle(fontSize: 12.0),),
              Icon(Icons.arrow_forward_ios_rounded, color: Colors.grey, size: 12.0,),
            ],
            ),
          ],
          ),
        ),
        // 广告图
        Container(
          margin: EdgeInsets.all(10.0),
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
          Image.network('https://m.360buyimg.com/babel/jfs/t20281125/360602/38/9142/115578/6926c520F7bf02d70/63baca236f5ea2c2.jpg', fit: BoxFit.fill,),
          Image.network('https://m.360buyimg.com/babel/jfs/t20281123/356425/36/15448/83034/6923ff4cF809328db/752d88efa7ccc2da.jpg', fit: BoxFit.fill,),
        ],
      ),
      ),
      // 条款
      Container(
        padding: EdgeInsets.fromLTRB(10.0, 0, 10.0, 20.0),
        child: Text.rich(
        TextSpan(
          style: TextStyle(color: Colors.grey, fontSize: 12.0),
          children: [
            TextSpan(text: '请您在提交订单前仔细阅读'),
            TextSpan(text: '趣玩商城预订条款', style: TextStyle(color: Colors.red,)),
            TextSpan(text: '和'),
            TextSpan(text: '个人信息授权声明', style: TextStyle(color: Colors.red,)),
            TextSpan(text: '。下单预订服务由趣玩商城有限公司及其分公司提供，涉及其它套餐的预订服务由第三方提供。'),
          ]
          ),
        ),
        )
        ],
        ),
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
      children: [
        Text('在线付 ', style: TextStyle(fontSize: 12.0),),
        Text('¥168', style: TextStyle(color: Color(0xFFFF2C55), fontSize: 16.0, fontFamily: 'Arial'),),
        Spacer(),
        Text('费用明细', style: TextStyle(color: Color(0xFFFF2C55), fontSize: 12.0),),
        Icon(Icons.arrow_drop_up, color: Color(0xFFFF2C55), size: 18.0,),
      ],
      ),
    ),
    SizedBox(width: 10.0,),
    GestureDetector(
      child: Container(
        alignment: Alignment.center,
        height: 36.0,
        width: 120.0,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: Color(0xFFFF2C55),
          borderRadius: BorderRadius.circular(30.0),
        ),
        child: Text('立即支付', style: TextStyle(color: Colors.white, fontSize: 14.0),),
        ),
        onTap: () {
          submitPayDialog();
        },
        ),
      ],
      ),
      ),
    );
  }
}
