/// 积分兑换结果
/// 对齐 H5: pages_promotion/point/result.vue(纯积分兑换或支付完成后落地页)
library;

import 'package:flutter/material.dart';
import 'package:get/get.dart';

class PointResultPage extends StatelessWidget {
  const PointResultPage({super.key});

  static const Color primary = Color(0xFFF16914);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        foregroundColor: Colors.black87,
        title: const Text('兑换结果', style: TextStyle(fontSize: 17.0)),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, size: 18.0),
          onPressed: () => Get.offNamed('/point/order_list'),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(30.0, 60.0, 30.0, 30.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            Container(
              width: 76.0,
              height: 76.0,
              decoration: const BoxDecoration(color: primary, shape: BoxShape.circle),
              alignment: Alignment.center,
              child: const Icon(Icons.check, color: Colors.white, size: 42.0),
            ),
            const SizedBox(height: 22.0),
            const Text('兑换成功', style: TextStyle(fontSize: 19.0, fontWeight: FontWeight.w600)),
            const SizedBox(height: 10.0),
            const Text(
              '积分已扣除,可在兑换订单中查看进度',
              style: TextStyle(fontSize: 13.0, color: Color(0xFF999999)),
            ),
            const SizedBox(height: 40.0),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: ButtonStyle(
                  backgroundColor: WidgetStateProperty.all(primary),
                  shape: WidgetStateProperty.all(RoundedRectangleBorder(borderRadius: BorderRadius.circular(22.0))),
                ),
                onPressed: () => Get.offNamed('/point/order_list'),
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12.0),
                  child: Text('查看兑换订单', style: TextStyle(fontSize: 15.0)),
                ),
              ),
            ),
            const SizedBox(height: 12.0),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                style: ButtonStyle(
                  foregroundColor: WidgetStateProperty.all(primary),
                  side: WidgetStateProperty.all(const BorderSide(color: primary)),
                  shape: WidgetStateProperty.all(RoundedRectangleBorder(borderRadius: BorderRadius.circular(22.0))),
                ),
                onPressed: () => Get.offNamed('/point/shop'),
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12.0),
                  child: Text('继续逛逛', style: TextStyle(fontSize: 15.0)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
