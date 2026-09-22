/// 商品评价/追评
/// 对齐 H5: pages_tool/order/evaluate.vue + public/js/evaluate.js
/// * 入参 order_id(Get.arguments: { order_id: 1 })
/// * /api/order/evluateinfo      待评价商品(evaluate_status: 0评价/1追评)
/// * /api/goodsevaluate/add      提交评价
/// * /api/goodsevaluate/again    提交追评
library;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shirne_dialog/shirne_dialog.dart';

import '../../api/order.dart';
import '../../controller/auth_store.dart';

class OrderEvaluate extends StatefulWidget {
  const OrderEvaluate({super.key});

  @override
  State<OrderEvaluate> createState() => _OrderEvaluateState();
}

class _OrderEvaluateState extends State<OrderEvaluate> {
  static const Color primary = Color(0xFFFF2C55);

  int orderId = 0;
  String orderNo = '';
  bool loading = true;
  String errorMsg = '';
  bool submitting = false;

  /// 1 为追评(H5 isEvaluate)
  bool again = false;

  /// 待评价商品
  List<Map<String, dynamic>> goodsList = <Map<String, dynamic>>[];

  /// 每项评分(默认5)
  List<int> scores = <int>[];

  /// 每项输入框
  List<TextEditingController> controllers = <TextEditingController>[];

  /// 是否匿名
  bool isAnonymous = false;

  /// 评价配置(evaluate_status: 1 开启)
  Map<String, dynamic> evaluateConfig = <String, dynamic>{'evaluate_status': 1};

  @override
  void initState() {
    super.initState();
    final dynamic args = Get.arguments;
    if (args is Map) orderId = int.tryParse('${args['order_id'] ?? args['orderId'] ?? ''}') ?? 0;
    loadConfig();
    load();
  }

  @override
  void dispose() {
    for (final TextEditingController c in controllers) {
      c.dispose();
    }
    super.dispose();
  }

  /// 评价配置(/api/goodsevaluate/config)
  Future<void> loadConfig() async {
    try {
      final Map<String, dynamic> data = await OrderApi.evaluateConfig();
      if (!mounted || data.isEmpty) return;
      setState(() {
        evaluateConfig = data;
      });
    } catch (_) {
      // 失败按默认开启处理
    }
  }

  /// 待评价商品(/api/order/evluateinfo)
  Future<void> load() async {
    setState(() {
      loading = true;
      errorMsg = '';
    });
    try {
      final Map<String, dynamic> data = await OrderApi.evaluateInfo(orderId);
      if (!mounted) return;
      final List<Map<String, dynamic>> list = data['list'] is List
          ? (data['list'] as List).whereType<Map>().map((Map e) => e.cast<String, dynamic>()).toList()
          : <Map<String, dynamic>>[];
      again = int.tryParse('${data['evaluate_status'] ?? 0}') == 1;
      for (final TextEditingController c in controllers) {
        c.dispose();
      }
      controllers = List<TextEditingController>.generate(list.length, (_) => TextEditingController());
      scores = List<int>.filled(list.length, 5);
      setState(() {
        goodsList = list;
        orderNo = list.isEmpty ? '' : '${list.first['order_no'] ?? ''}';
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        errorMsg = OrderApi.errorMsg(e, '未获取到订单数据');
        loading = false;
      });
      MyDialog.toast('未获取到订单数据');
      Future<void>.delayed(const Duration(milliseconds: 1000), () {
        if (mounted) Get.back();
      });
    }
  }

  /// 评分 → 评价类型: >=4好评(1) 2~3中评(2) 1差评(3)
  int explainType(int score) {
    if (score >= 4) return 1;
    if (score > 1) return 2;
    return 3;
  }

  String explainName(int type) {
    switch (type) {
      case 1:
        return '好评';
      case 2:
        return '中评';
      default:
        return '差评';
    }
  }

  Future<void> submit() async {
    if ('${evaluateConfig['evaluate_status'] ?? 1}' != '1') {
      MyDialog.toast('商家未开启商品评价功能');
      return;
    }
    for (int i = 0; i < controllers.length; i++) {
      if (controllers[i].text.trim().isEmpty) {
        MyDialog.toast('商品的评价不能为空哦');
        return;
      }
    }
    if (submitting) return;
    setState(() {
      submitting = true;
    });
    final List<Map<String, dynamic>> payload = <Map<String, dynamic>>[];
    for (int i = 0; i < goodsList.length; i++) {
      final Map<String, dynamic> goods = goodsList[i];
      if (again) {
        payload.add(<String, dynamic>{
          'order_goods_id': goods['order_goods_id'],
          'goods_id': goods['goods_id'],
          'sku_id': goods['sku_id'],
          'again_content': controllers[i].text,
          'again_images': '',
        });
      } else {
        payload.add(<String, dynamic>{
          'content': controllers[i].text,
          'images': '',
          'scores': scores[i],
          'explain_type': explainType(scores[i]),
          'order_goods_id': goods['order_goods_id'],
          'goods_id': goods['goods_id'],
          'sku_id': goods['sku_id'],
          'sku_name': goods['sku_name'],
          'sku_price': goods['price'],
          'sku_image': goods['sku_image'],
        });
      }
    }
    try {
      if (again) {
        await OrderApi.againEvaluate(orderId: orderId, goodsEvaluate: payload);
      } else {
        await OrderApi.addEvaluate(
          orderId: orderId,
          goodsEvaluate: payload,
          orderNo: orderNo,
          memberName: AuthStore.to.nickname,
          memberHeadimg: AuthStore.to.headimg,
          isAnonymous: isAnonymous ? 1 : 0,
        );
      }
      MyDialog.toast('评价成功');
      await Future<void>.delayed(const Duration(milliseconds: 1000));
      // 与 H5 一致: 评价完成后回订单列表
      Get.offNamed('/order');
    } catch (e) {
      MyDialog.toast(OrderApi.errorMsg(e, '评价失败'));
      if (mounted) {
        setState(() {
          submitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        foregroundColor: Colors.black87,
        title: Text(again ? '追评' : '商品评价', style: const TextStyle(fontSize: 17.0)),
        centerTitle: true,
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2.0, valueColor: AlwaysStoppedAnimation<Color>(primary)))
          : _buildBody(),
      bottomNavigationBar: _buildBottom(),
    );
  }

  Widget _buildBody() {
    if (errorMsg.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(errorMsg, style: const TextStyle(fontSize: 14.0, color: Colors.grey)),
            TextButton(onPressed: load, child: const Text('重新加载')),
          ],
        ),
      );
    }
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(10.0),
      children: <Widget>[
        ...goodsList.asMap().entries.map((MapEntry<int, Map<String, dynamic>> entry) => _buildItem(entry.key, entry.value)),
        const SizedBox(height: 10.0),
      ],
    );
  }

  Widget _buildItem(int index, Map<String, dynamic> goods) {
    final String image = '${goods['sku_image'] ?? ''}';
    final int type = explainType(scores[index]);
    return Container(
      margin: const EdgeInsets.only(bottom: 10.0),
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10.0)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              ClipRRect(
                borderRadius: BorderRadius.circular(6.0),
                child: image.isEmpty
                    ? Container(width: 60.0, height: 60.0, color: const Color(0xFFF5F5F5))
                    : CachedNetworkImage(
                        imageUrl: image,
                        width: 60.0,
                        height: 60.0,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => Container(width: 60.0, height: 60.0, color: const Color(0xFFF5F5F5)),
                      ),
              ),
              const SizedBox(width: 10.0),
              Expanded(
                child: Text('${goods['sku_name'] ?? ''}', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13.0)),
              ),
            ],
          ),
          // 追评不显示评分(H5: v-if="!isEvaluate")
          if (!again) ...<Widget>[
            const SizedBox(height: 10.0),
            Row(
              children: <Widget>[
                const Text('描述相符', style: TextStyle(fontSize: 13.0, color: Color(0xFF888888))),
                const SizedBox(width: 8.0),
                ...List<Widget>.generate(5, (int i) => InkWell(
                      onTap: () => setState(() => scores[index] = i + 1),
                      child: Icon(
                        i < scores[index] ? Icons.star_rounded : Icons.star_border_rounded,
                        size: 20.0,
                        color: i < scores[index] ? const Color(0xFFFFB400) : const Color(0xFFDDDDDD),
                      ),
                    )),
                const SizedBox(width: 8.0),
                Text(explainName(type), style: const TextStyle(fontSize: 12.0, color: primary)),
              ],
            ),
          ],
          const SizedBox(height: 10.0),
          TextField(
            controller: controllers[index],
            maxLines: 4,
            maxLength: 200,
            style: const TextStyle(fontSize: 13.0),
            decoration: InputDecoration(
              hintText: again ? '请在此处输入您的追评' : '请在此处输入您的评价',
              hintStyle: const TextStyle(fontSize: 13.0, color: Color(0xFFBBBBBB)),
              filled: true,
              fillColor: const Color(0xFFF7F7F7),
              isCollapsed: true,
              contentPadding: const EdgeInsets.all(10.0),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(6.0), borderSide: BorderSide.none),
              counterStyle: const TextStyle(fontSize: 11.0, color: Colors.grey),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottom() {
    if (loading || errorMsg.isNotEmpty) return const SizedBox.shrink();
    return Container(
      padding: EdgeInsets.fromLTRB(12.0, 8.0, 12.0, 8.0 + MediaQuery.of(context).padding.bottom),
      decoration: const BoxDecoration(color: Colors.white),
      child: Row(
        children: <Widget>[
          // 追评不显示匿名(H5: v-if="!isEvaluate")
          if (!again)
            InkWell(
              onTap: () => setState(() => isAnonymous = !isAnonymous),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(
                    isAnonymous ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                    size: 18.0,
                    color: isAnonymous ? primary : const Color(0xFFBBBBBB),
                  ),
                  const SizedBox(width: 4.0),
                  const Text('匿名', style: TextStyle(fontSize: 13.0)),
                ],
              ),
            ),
          const Spacer(),
          SizedBox(
            width: 120.0,
            height: 36.0,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18.0)),
                padding: EdgeInsets.zero,
              ),
              onPressed: submitting ? null : submit,
              child: Text(submitting ? '提交中' : '提交', style: const TextStyle(fontSize: 14.0)),
            ),
          ),
        ],
      ),
    );
  }
}
