/// 底部礼物充值框
library;

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../behavior/custom_scroll_behavior.dart';

class PopupRecharge extends StatefulWidget {
  const PopupRecharge({
    super.key,
    this.onChanged,
  });
  final ValueChanged? onChanged;
  @override
  State<PopupRecharge> createState() => _PopupRechargeState();
}

class _PopupRechargeState extends State<PopupRecharge> with SingleTickerProviderStateMixin {
  int activeIndex = 0;
  List rechargeList = [
   {'label': 10, 'money': 1},
    {'label': 60, 'money': 6},
   {'label': 100, 'money': 10},
    {'label': 200, 'money': 20},
   {'label': 300, 'money': 30},
  {'label': 1000, 'money': 100},
  ];

  @override
void initState() {
  super.initState();
}

@override
Widget build(BuildContext context) {
  return Scaffold(
    backgroundColor: Colors.transparent,
    body: ScrollConfiguration(
      behavior: CustomScrollBehavior().copyWith(scrollbars: false),
      child: SafeArea(
      child: Column(
        children: [
        Expanded(
        child: GestureDetector(
          child: Container(
            color: Colors.transparent,
          ),
          onTap: () {
            Get.back();
          },
        ),
        ),
      Material(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(10.0)),
        child: Column(
          children: [
            Container(
            padding: EdgeInsets.all(10.0),
          child: Text('充值', style: TextStyle(fontSize: 16.0),),
        ),
        Container(
          alignment: Alignment.centerLeft,
          padding: EdgeInsets.only(left: 15.0),
          child: Text('余额: 0钻 (还差1钻)', style: TextStyle(color: Colors.grey, fontSize: 14.0),),
        ),
        Container(
          height: 150.0,
        padding: EdgeInsets.symmetric(horizontal: 15.0, vertical: 8.0),
        child: GridView.builder(
          shrinkWrap: true,
            padding: EdgeInsets.zero,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              // 横轴元素个数
              crossAxisCount: 3,
              // 纵轴间距
            mainAxisSpacing: 5.0,
            // 横轴间距
            crossAxisSpacing: 5.0,
            mainAxisExtent: 60.0,
          ),
          itemCount: rechargeList.length,
        itemBuilder: (context, index) {
          final item = rechargeList[index];
          return GestureDetector(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey[50],
                border: Border.all(color: activeIndex == index ? Color(0xFFFAE310) : Colors.transparent, width: 2.0),
              borderRadius: BorderRadius.circular(10.0),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              spacing: 3.0,
              children: [
                Text('${item['label']}钻', style: TextStyle(color: Colors.black, fontSize: 16.0),),
                Text('${item['money']}元', style: TextStyle(color: Colors.grey, fontSize: 12.0),),
              ],
            ),
            ),
            onTap: () {
              setState(() {
                activeIndex = index;
                });
              },
                  );
                },
                ),
              ),
              Container(
                margin: EdgeInsets.fromLTRB(15.0, 0, 15.0, 20.0),
                child: FilledButton(
                  style: ButtonStyle(
                    backgroundColor: WidgetStateProperty.all(Color(0xFFFF2C55)),
                    padding: WidgetStateProperty.all(EdgeInsets.zero),
                    minimumSize: WidgetStateProperty.all(Size(double.infinity, 45.0)),
                    shape: WidgetStatePropertyAll(
                      RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0))
                    )
                  ),
                  onPressed: () {
                    widget.onChanged!(rechargeList[activeIndex]['money']);
                    Get.back();
                  },
                  child: Text('确认付款 ${rechargeList[activeIndex]['money']} 元', style: TextStyle(fontSize: 15.0),),
                ),
              ),
              ],
              ),
            ),
          ],
          ),
        ),
      ),
    );
  }
}
