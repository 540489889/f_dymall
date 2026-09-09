/// 底部支付弹框
library;

import 'package:flutter/material.dart';
import 'package:get/get.dart';

class PopupPay extends StatefulWidget {
  const PopupPay({
  super.key,
  this.onChanged,
});

final ValueChanged? onChanged;

@override
State<PopupPay> createState() => _PopupPayState();
}

class _PopupPayState extends State<PopupPay> with SingleTickerProviderStateMixin {
int payMoney = 520;
String? payWay = 'wxpay';

@override
void initState() {
  super.initState();
}

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
        width: double.infinity,
        alignment: Alignment.center,
        child: Text.rich(
          TextSpan(
            children: [
              TextSpan(text: '支付 '),
              TextSpan(text: '¥$payMoney', style: TextStyle(color: Color(0xFFFF2C55), fontSize: 24.0, fontFamily: 'Arial', fontWeight: FontWeight.w700),),
            ]
          ),
          ),
        ),
        Container(
          margin: EdgeInsets.fromLTRB(20.0, 20.0, 20.0, 10.0),
          child: Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10.0),
            clipBehavior: Clip.antiAlias,
            elevation: 2.0,
              shadowColor: Colors.black26,
            child: Column(
              children: [
              RadioGroup(
                onChanged: (value) {
                setState(() {
                  payWay = value;
                });
              },
              groupValue: payWay,
              child: Column(
              children: [
                RadioListTile(
                  title: Text('微信支付', style: TextStyle(fontSize: 14.0),),
                  secondary: Image.asset('assets/images/wxpay.png', height: 20.0,),
                  activeColor: Color(0xFFFF2C55),
                  value: 'wxpay',
                ),
                RadioListTile(
                  title: Text('支付宝支付', style: TextStyle(fontSize: 14.0),),
                  secondary: Image.asset('assets/images/alipay.png', height: 20.0,),
                  activeColor: Color(0xFFFF2C55),
                  value: 'alipay',
                  ),
                ],
                )
              ),
              ],
            ),
            ),
          ),
          Container(
            margin: EdgeInsets.all(20.0),
            child: FilledButton(
            style: ButtonStyle(
              backgroundColor: WidgetStateProperty.all(Color(0xFFFF2C55)),
              padding: WidgetStateProperty.all(EdgeInsets.zero),
              minimumSize: WidgetStateProperty.all(Size(double.infinity, 45.0)),
              shape: WidgetStatePropertyAll(
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(30.0))
              )
            ),
            onPressed: () {
              widget.onChanged!('$payWay —— $payMoney');
              Get.back();
            },
            child: Text('确认支付', style: TextStyle(fontSize: 15.0),),
          ),
        ),
      ],
      ),
    );
  }
}
