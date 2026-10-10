import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../behavior/custom_scroll_behavior.dart';

class PopupComment extends StatefulWidget {
  const PopupComment({
    super.key,
    this.onChanged,
    this.prefill
  });

  // 输入框值改变
  final ValueChanged? onChanged;

  // 输入框初始内容(福袋参与口令等需要预填并直接发送的场景)
  final String? prefill;

  @override
  State<PopupComment> createState() => _PopupCommentState();
}

class _PopupCommentState extends State<PopupComment> {
  List commentTags = ['这个好棒啊🔥', '根本抢不到', '这个多少钱', '怎么买最便宜', '太划算了👍', '好想要~', '已下单回购', '期待值拉满😎'];
  final TextEditingController textEditingController = TextEditingController();
  // 输入框焦点: 点击快捷短语后保持输入框聚焦
  final FocusNode commentFocusNode = FocusNode();
  @override
  void initState() {
    super.initState();
    // 预填内容(如福袋参与口令): 直接填入输入框, 光标移到末尾(autofocus 已聚焦)
    final String prefill = '${widget.prefill ?? ''}'.trim();
    if (prefill.isNotEmpty) {
      textEditingController.value = TextEditingValue(
        text: prefill,
        selection: TextSelection.collapsed(offset: prefill.length),
      );
    }
  }

  @override
  void dispose() {
    textEditingController.dispose();
    commentFocusNode.dispose();
    super.dispose();
  }

  // 关闭弹窗: 先释放输入框焦点再返回
  // * iOS 上没有返回键, 直接 pop 时 TextField 仍持有焦点, 键盘会挂在引擎上不收(页面关了键盘还在)
  void _close() {
    FocusManager.instance.primaryFocus?.unfocus();
    Get.back<void>();
  }

  // 快捷短语: 点击后填入输入框(覆盖当前内容), 光标移到末尾并保持聚焦
  void _fillComment(String text) {
    textEditingController.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
    commentFocusNode.requestFocus();
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
      onTap: _close,
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
          child: GestureDetector(
          // 点击快捷短语: 填入输入框(样式保持不变)
          onTap: () {
            _fillComment('${commentTags[index]}');
          },
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
                focusNode: commentFocusNode,
                cursorColor: const Color(0xFFFF2C55),
                onEditingComplete: () {
                  widget.onChanged?.call(textEditingController.text);
                  _close();
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
                    widget.onChanged?.call(textEditingController.text);
                    _close();
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
