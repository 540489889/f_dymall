/// 钱包模板
library;

import 'package:flutter/material.dart';
import 'package:get/get.dart';

class Wallet extends StatefulWidget {
  const Wallet({super.key});
  @override
  State<Wallet> createState() => _WalletState();
}

class _WalletState extends State<Wallet> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
    backgroundColor: Colors.white,
    appBar: AppBar(
      backgroundColor: Colors.transparent,
    foregroundColor: Colors.white,
    title: Text('钱包', style: TextStyle(fontSize: 18.0),),
    leading: IconButton(icon: Icon(Icons.arrow_back_ios_rounded), onPressed: () {Navigator.pop(context);}),
    flexibleSpace: Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFFF3F0F), Color(0xFFFF9A15)
          ],
        )
      ),
    ),
    actions: [
      IconButton(icon: const Icon(Icons.more_horiz, color: Colors.white,), onPressed: () {},),
      ],
      ),
      body: ListView(
        children: [
      Column(
      children: <Widget>[
        const SizedBox(height: 50.0),
        Icon(Icons.wallet, color: const Color(0xFFFF970F), size: 50.0),
      const Text('我的零钱', style: TextStyle(fontSize: 16.0, color: Colors.black87)),
      const Text('￥1314', style: TextStyle(fontSize: 36.0, fontFamily: 'arial')),
      const SizedBox(height: 100.0),
      FilledButton(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.all(const Color(0xFF07C160)),
          padding: WidgetStateProperty.all(EdgeInsets.zero),
          minimumSize: WidgetStateProperty.all(const Size(155.0, 45.0)),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0))
          )
        ),
        onPressed: () {Get.toNamed('/my/recharge');},
        child: const Text('充值', style: TextStyle(fontSize: 15.0),),
      ),
      const SizedBox(height: 10.0),
      FilledButton(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.all(const Color(0xFFDDDDDD)),
          padding: WidgetStateProperty.all(EdgeInsets.zero),
          minimumSize: WidgetStateProperty.all(const Size(155.0, 45.0)),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0))
          )
        ),
        onPressed: () {},
          child: const Text('提现', style: TextStyle(color: Colors.black, fontSize: 15.0),),
          ),
        ],
        ),
      ],
    ),
    );
  }
}
