/// 发红包模板
library;

import 'package:flutter/material.dart';

class RedPacket extends StatefulWidget {
  const RedPacket({
  super.key,
  this.onChanged
});

// 回调函数
final ValueChanged? onChanged;

@override
State<RedPacket> createState() => _RedPacketState();
}

class _RedPacketState extends State<RedPacket> {
final Map redpacketForm = {
  'num': '',
  'amount': '0.00',
  'msg': '恭喜发财，大吉大利'
};

@override
Widget build(BuildContext context) {
  return Material(
    type: MaterialType.transparency,
    child: Column(
      children: [
        ListView(
          shrinkWrap: true,
        padding: const EdgeInsets.only(bottom: 50.0),
        children: [
          const SizedBox(height: 10.0),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 15.0),
          padding: const EdgeInsets.symmetric(horizontal: 10.0),
          decoration: BoxDecoration(
            color: Colors.white, borderRadius: BorderRadius.circular(10.0),
          ),
          child: Row(
          children: <Widget>[
            const Text('红包个数'),
            Expanded(
              child: TextField(
                keyboardType: TextInputType.number,
              textAlign: TextAlign.right,
              decoration: const InputDecoration(
                hintText: "填写个数",
                border: OutlineInputBorder(borderSide: BorderSide.none)
              ),
              style: TextStyle(fontSize: 14.0),
              onChanged: (value) {
                setState(() {
                  redpacketForm['num'] = value;
                });
              },
            ),
            ),
            const Text('个'),
              ],
            ),
            ),
            const SizedBox(height: 10.0),
            Container(
            margin: const EdgeInsets.symmetric(horizontal: 15.0),
            padding: const EdgeInsets.symmetric(horizontal: 10.0),
            decoration: BoxDecoration(
              color: Colors.white, borderRadius: BorderRadius.circular(10.0),
            ),
            child: Row(
            children: <Widget>[
              const Text('总金额'),
              Expanded(
                child: TextField(
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                textAlign: TextAlign.right,
                decoration: const InputDecoration(
                  hintText: "￥0.00",
                  border: OutlineInputBorder(borderSide: BorderSide.none)
                ),
                style: TextStyle(fontSize: 14.0),
                onChanged: (value) {
                  setState(() {
                    redpacketForm['amount'] = value.isNotEmpty ? value : '0.00';
                  });
                },
                ),
              ),
              const Text('元'),
            ],
            ),
          ),
          const SizedBox(height: 10.0),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 15.0),
          padding: const EdgeInsets.symmetric(horizontal: 10.0),
        decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(10.0),
            ),
        child: Row(
          children: <Widget>[
          const Text('留言'),
          Expanded(
            child: TextField(
              maxLines: null,
            keyboardType: TextInputType.multiline,
            textAlign: TextAlign.right,
            decoration: const InputDecoration(
              hintText: "恭喜发财，大吉大利",
              border: OutlineInputBorder(borderSide: BorderSide.none)
            ),
            style: TextStyle(fontSize: 14.0),
            onChanged: (value) {
              setState(() {
                redpacketForm['msg'] = value;
              });
            },
          ),
        ),
          ],
        ),
      ),
    const SizedBox(height: 30.0),
    Row(
      mainAxisAlignment: MainAxisAlignment.center,
    children: <Widget>[
      const Text('￥', style: TextStyle(fontSize: 24.0)), Text(redpacketForm['amount'], style: const TextStyle(fontSize: 36.0))
    ]
    ),
    const SizedBox(height: 20.0,),
    UnconstrainedBox(
      constrainedAxis: Axis.vertical,
    child: FilledButton(
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.all(Colors.red),
        padding: WidgetStateProperty.all(EdgeInsets.zero),
        minimumSize: WidgetStateProperty.all(const Size(165.0, 45.0)),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0))
          ),
        ),
        onPressed: () {
          widget.onChanged!(redpacketForm);
          Navigator.of(context).pop();
        },
        child: const Text('塞钱进红包', style: TextStyle(fontSize: 16.0),),
      ),
    ),
    const SizedBox(height: 10.0,),
      const Align(
        alignment: Alignment.center,
        child: Text('未领取的红包，将于24小时后发起退款', style: TextStyle(color: Colors.grey, fontSize: 12.0),),
      ),
      ],
    ),
    ],
  ),
);
  }
}
