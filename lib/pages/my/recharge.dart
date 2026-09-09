/// 充值模板
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class Recharge extends StatefulWidget {
  const Recharge({super.key});

@override
State<Recharge> createState() => _RechargeState();
}

class _RechargeState extends State<Recharge> {
String? payWay = 'alipay';

@override
Widget build(BuildContext context) {
  return Scaffold(
    backgroundColor: const Color(0xFFEEEEEE),
    appBar: AppBar(
      backgroundColor: const Color(0xFFEEEEEE),
      foregroundColor: Colors.black,
      title: Text('充值', style: TextStyle(fontSize: 18.0),),
      leading: IconButton(icon: Icon(Icons.arrow_back), onPressed: () {Navigator.pop(context);}),
      centerTitle: true,
    ),
    body: ListView(
      children: [
        Column(
          children: <Widget>[
            Container(
            padding: const EdgeInsets.fromLTRB(20.0, 20.0, 20.0, 10.0),
            decoration: const BoxDecoration(
              color: Color(0xFFFAFAFA),
            ),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
              Text('充值金额', style: TextStyle(fontSize: 16.0)),
              TextField(
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                ],
                autofocus: true,
                decoration: InputDecoration(
                  icon: Icon(Icons.attach_money),
                  border: InputBorder.none,
                ),
                style: TextStyle(fontSize: 28.0),
              ),
            ],
            ),
          ),
          const SizedBox(height: 10.0,),
          // 支付方式
          Container(
            color: Colors.grey[50],
            child: Column(
            children: <Widget>[
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
                    value: 'alipay',
                    title: Text('支付宝支付'),
                    subtitle: const Text('推荐', style: TextStyle(color: Colors.red, fontSize: 12.0)),
                    secondary: Image.asset('assets/images/alipay.png', height: 16.0, fit: BoxFit.contain),
                    activeColor: Color(0xFF027DFD),
                  ),
                  RadioListTile(
                    value: 'wxpay',
                    title: Text('微信支付'),
                    secondary: Image.asset('assets/images/wxpay.png', height: 16.0, fit: BoxFit.contain),
                    activeColor: Color(0xFF027DFD),
                  ),
                  ],
                )
                ),
              ],
            ),
          ),
          const SizedBox(height: 20.0,),
          FilledButton(
            style: ButtonStyle(
              backgroundColor: WidgetStateProperty.all(const Color(0xFF07C160)),
              padding: WidgetStateProperty.all(EdgeInsets.zero),
              minimumSize: WidgetStateProperty.all(const Size(200.0, 50.0)),
            ),
            onPressed: () {},
            child: const Text('充值', style: TextStyle(fontSize: 18.0),),
          ),
        ],
      ),
      ],
    ),
  );
  }
}
