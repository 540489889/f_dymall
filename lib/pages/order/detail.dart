/// 订单详情模板
library;

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:shirne_dialog/shirne_dialog.dart';
import '../../behavior/custom_scroll_behavior.dart';
import '../../components/popup_pay.dart';
class OrderDetail extends StatefulWidget {
  const OrderDetail({super.key});
  @override
  State<OrderDetail> createState() => _OrderDetailState();
}

class _OrderDetailState extends State<OrderDetail> with SingleTickerProviderStateMixin {
 int remainingSeconds = 30 * 60;
  late Timer timer;
  @override
  void initState() {
    super.initState();
    startTimer();
  }

  @override
  void dispose() {
    timer.cancel();
    super.dispose();
  }

  void startTimer() {
    timer = Timer.periodic(const Duration(seconds: 1), (timer) {
    setState(() {
      if (remainingSeconds > 0) {
        remainingSeconds--;
      } else {
        timer.cancel();
      }
    });
    });
  }

  String formatTime(int seconds) {
    int hours = seconds ~/ 3600;
  int minutes = (seconds % 3600) ~/ 60;
  int secs = seconds % 60;
  return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
}

Widget emptyTip() {
  return Column(
    mainAxisAlignment: MainAxisAlignment.center,
    spacing: 5.0,
    children: [
      SvgPicture.asset('assets/images/svg/empty.svg', colorFilter: ColorFilter.mode(Colors.black38, BlendMode.srcIn), width: 40.0,),
      Text('还没有订单信息~', style: TextStyle(color: Colors.grey, fontSize: 12.0),)
    ],
  );
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
      backgroundColor: Color(0xFFFF2C55),
      foregroundColor: Colors.white,
      title: Text('订单详情', style: TextStyle(fontSize: 18.0),),
      titleSpacing: 1.0,
      actions: [
        IconButton(icon: Icon(Icons.help_outline, size: 20.0), onPressed: () {},),
      ],
    ),
    body: ScrollConfiguration(
      behavior: CustomScrollBehavior().copyWith(scrollbars: false),
      child: ListView(
      physics: BouncingScrollPhysics(),
    padding: EdgeInsets.all(10.0),
    children: [
      Column(
      spacing: 5.0,
      children: [
      Text.rich(
        TextSpan(
          children: [
          WidgetSpan(child: Icon(Icons.info_outline, size: 16.0,)),
          TextSpan(text: ' 待支付, '),
          TextSpan(text: ' 剩余 '),
          TextSpan(text: formatTime(remainingSeconds), style: TextStyle(color: Colors.red,),),
        ]
      ),
      ),
      Text('超过30分钟未支付，订单将自动取消', style: TextStyle(color: Colors.grey, fontSize: 12.0),),
      SizedBox(height: 10.0,),
      ],
    ),
    // 商品信息
    Container(
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
          ],
        ),
        ),
        // 订单信息
        Container(
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
            Text('订单信息', style: TextStyle(fontSize: 15.0, fontWeight: FontWeight.bold),),
          Spacer(),
          InkWell(
            child: Icon(Icons.copy, color: Colors.grey, size: 14.0,),
            onTap: () {
              MyDialog.toast('复制订单信息', icon: Icon(Icons.check_circle));
            },
          )
        ],
        ),
        Column(
        spacing: 5.0,
        children: [
        Row(
        children: [
          Text('订单号', style: TextStyle(color: Colors.grey),),
          Spacer(),
          Text('20251124u712r09431a62', style: TextStyle(fontSize: 12.0)),
          ],
        ),
        Row(
          children: [
            Text('下单时间', style: TextStyle(color: Colors.grey),),
            Spacer(),
            Text('2025-11-25 23:18:36', style: TextStyle(fontSize: 12.0)),
            ],
          ),
          Row(
            children: [
              Text('购买数量', style: TextStyle(color: Colors.grey),),
                Spacer(),
                Text('10', style: TextStyle(fontSize: 12.0)),
              ],
            ),
            Row(
              children: [
                Text('订单金额', style: TextStyle(color: Colors.grey),),
                Spacer(),
                Text('¥1990', style: TextStyle(fontSize: 12.0)),
              ],
            ),
              Row(
                children: [
                  Text('实付金额', style: TextStyle(color: Colors.grey),),
                  Spacer(),
                  Text('¥1990', style: TextStyle(fontSize: 12.0)),
                ],
              ),
              ],
            )
              ],
            ),
          ),
          SizedBox(
            height: 200.0,
            child: emptyTip(),
          )
          ],
        ),
      ),
      // 底部固定按钮
      // 商品导航栏
      bottomNavigationBar: Container(
        height: 50.0,
      color: Colors.white,
      padding: EdgeInsets.symmetric(horizontal: 10.0, vertical: 5.0),
      child: Row(
        spacing: 10.0,
        mainAxisAlignment: MainAxisAlignment.end,
      children: [
        SizedBox(
        height: 36.0,
        child: ElevatedButton(onPressed: (){}, style: ButtonStyle(backgroundColor: WidgetStateProperty.all(Colors.white)), child: Text('取消订单'),),
      ),
      SizedBox(
        height: 36.0,
        child: ElevatedButton(
          onPressed: (){
            submitPayDialog();
          },
          style: ButtonStyle(backgroundColor: WidgetStateProperty.all(Color(0xff07c160)), foregroundColor: WidgetStateProperty.all(Colors.white)), child: Text('去支付'),
        ),
        ),
      ],
      ),
    ),
  );
  }
}
