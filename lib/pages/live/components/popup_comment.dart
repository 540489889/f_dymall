import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../behavior/custom_scroll_behavior.dart';

class PopupComment extends StatefulWidget {
  const PopupComment({
    super.key,
    this.onChanged
  });

  // 输入框值改变
  final ValueChanged? onChanged;

  @override
  State<PopupComment> createState() => _PopupCommentState();
}

class _PopupCommentState extends State<PopupComment> {
  List commentTags = ['这个好棒啊🔥', '根本抢不到', '这个多少钱', '怎么买最便宜', '太划算了👍', '好想要~', '已下单回购', '期待值拉满😎'];
  final TextEditingController textEditingController = TextEditingController();
  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    textEditingController.dispose();
    super.dispose();
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
      Container(
        decoration: BoxDecoration(
        color: Colors.white,
      ),
      child: Column(
      children: [
      Container(
        height: 45.0,
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 10.0),
      child: Row(
      children: [
        Expanded(
        child: ListView.builder(
          shrinkWrap: true,
            scrollDirection: Axis.horizontal,
          itemCount: commentTags.length,
          itemBuilder: (context, index) {
        return UnconstrainedBox(
          child: Container(
            alignment: Alignment.center,
            height: 30.0,
          margin: const EdgeInsets.only(right: 10.0,),
          padding: const EdgeInsets.symmetric(horizontal: 10.0,),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(20.0),
          ),
          child: Text('${commentTags[index]}', style: const TextStyle(fontSize: 12.0),),
          ),
        );
          },
        ),
          ),
          ],
          ),
        ),
        Container(
          color: Colors.grey[100],
            padding: EdgeInsets.all(10.0),
            child: Row(
            spacing: 10.0,
            children: [
            Expanded(
                child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20.0),
              ),
              child: TextField(
                decoration: const InputDecoration(
                  hintText: '说点什么...',
                  isDense: true,
                  hoverColor: Colors.transparent,
                contentPadding: EdgeInsets.all(10.0),
                border: OutlineInputBorder(borderSide: BorderSide.none),
                ),
                style: const TextStyle(fontSize: 14.0,),
                textInputAction: TextInputAction.send,
                autofocus: true,
                maxLines: null,
                controller: textEditingController,
                cursorColor: const Color(0xFFFF2C55),
                onEditingComplete: () {
                  widget.onChanged!(textEditingController.text);
                  Get.back();
                },
                  onChanged: (value) {},
                ),
                  ),
                ),
                FilledButton(
                  style: ButtonStyle(
                    backgroundColor: WidgetStateProperty.all(const Color(0xFFFF2C55)),
                    padding: WidgetStateProperty.all(EdgeInsets.zero),
                    minimumSize: WidgetStateProperty.all(const Size(60.0, 40.0)),
                    shape: WidgetStatePropertyAll(
                      RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.0))
                    )
                  ),
                  onPressed: () {
                    widget.onChanged!(textEditingController.text);
                    Get.back();
                  },
                  child: const Text('发送',),
                ),
                ],
              ),
            )
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
