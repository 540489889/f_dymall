/// 直播举报弹窗(对应 H5 livepull.nvue 的 reportPop)
/// * 举报原因单选(H5 reportList) → 选填描述 → 提交调用 /live/api/shop/complaint
/// * 未选原因点提交提示"请选择举报类型", 提交后 toast 服务端文案并关闭弹窗
library;

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../api/live.dart';

/// 举报原因(与 H5 reportList 保持一致)
const List<String> reportReasons = <String>[
  '违法犯罪',
  '色情低俗',
  '诈骗',
  '危险行为',
  '未成年人不良内容',
  '录播',
  '错误价值观',
  '恶俗惩罚/游戏',
  '言语侮辱',
  '剧本演绎/炒作',
  '其他',
];

class PopupReport extends StatefulWidget {
  const PopupReport({super.key, required this.roomId});

  /// 房间号 sn(举报接口 no 参数)
  final String roomId;

  @override
  State<PopupReport> createState() => _PopupReportState();
}

class _PopupReportState extends State<PopupReport> {
  String reason = '';
  final TextEditingController contentCtrl = TextEditingController();
  bool submitting = false;

  @override
  void dispose() {
    contentCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Scaffold 默认 resizeToAvoidBottomInset=true: 键盘弹出时 body 被压缩,
    // 底部弹窗会自动贴着键盘上方。这里给内容区一个最大高度约束,
    // 让内部 SingleChildScrollView 真正可滚动, 避免 BOTTOM OVERFLOWED。
    final double maxSheetH =
        MediaQuery.of(context).size.height - MediaQuery.of(context).viewInsets.bottom - 16.0;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        children: <Widget>[
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => Navigator.of(context).pop(),
              child: const SizedBox.expand(),
            ),
          ),
          Material(
            color: Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(10.0)),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: maxSheetH),
              child: Padding(
                padding: const EdgeInsets.only(left: 16.0, right: 16.0, top: 10.0, bottom: 16.0),
                child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const SizedBox(
                      height: 40.0,
                      child: Center(
                        child: Text(
                          '举报本场直播',
                          style: TextStyle(fontSize: 17.0, fontWeight: FontWeight.bold, color: Color(0xFF161823)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6.0),
                    const Text('举报原因', style: TextStyle(fontSize: 14.0, color: Color(0xFF999999))),
                    const SizedBox(height: 10.0),
                    // 原因标签: 单行放不下自动换行(H5 report-list 是三列)
                    Wrap(
                      spacing: 10.0,
                      runSpacing: 10.0,
                      children: reportReasons.map((String text) => _reasonChip(text)).toList(),
                    ),
                    const SizedBox(height: 16.0),
                    const Text('举报描述 （选填）', style: TextStyle(fontSize: 14.0, color: Color(0xFF999999))),
                    const SizedBox(height: 10.0),
                    TextField(
                      controller: contentCtrl,
                      maxLines: 4,
                      maxLength: 200,
                      style: const TextStyle(fontSize: 14.0, color: Color(0xFF161823)),
                      decoration: InputDecoration(
                        counterText: '',
                        filled: true,
                        fillColor: const Color(0xFFF3F3F4),
                        hintText: '请指出存在宣扬拜金主义、刻意审丑、恶心猎奇等错误价值观的相关内容，便于平台判断违规情况',
                        hintStyle: const TextStyle(fontSize: 13.0, color: Color(0xFF999999)),
                        contentPadding: const EdgeInsets.all(12.0),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10.0),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16.0),
                    SizedBox(
                      width: double.infinity,
                      height: 44.0,
                      child: TextButton(
                        style: TextButton.styleFrom(
                          backgroundColor: const Color(0xFFFE6000),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0)),
                        ),
                        onPressed: submitting ? null : _submit,
                        child: Text(
                          submitting ? '提交中...' : '提交',
                          style: const TextStyle(fontSize: 16.0, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        ],
      ),
    );
  }

  /// 单个原因标签: 选中态用主色描边 + 浅色底
  Widget _reasonChip(String text) {
    final bool selected = reason == text;
    return GestureDetector(
      onTap: () => setState(() => reason = text),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFFFF1E8) : const Color(0xFFF7F7F8),
          borderRadius: BorderRadius.circular(18.0),
          border: Border.all(
            color: selected ? const Color(0xFFFE6000) : const Color(0xFFE5E5E5),
          ),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 13.0,
            color: selected ? const Color(0xFFFE6000) : const Color(0xFF333333),
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (reason.isEmpty) {
      _toast('请选择举报类型');
      return;
    }
    if (widget.roomId.isEmpty) {
      _toast('房间信息还在加载');
      return;
    }
    setState(() => submitting = true);
    final Map<String, dynamic> res = await LiveApi.complaint(
      no: widget.roomId,
      type: reason,
      content: contentCtrl.text.trim(),
    );
    if (!mounted) return;
    final bool ok = res['ok'] == true;
    // 直接提示接口返回的文案(优先 data, 回落 message)
    _toast('${res['message'] ?? ''}'.trim().isEmpty ? '举报已提交' : '${res['message']}');
    if (ok) {
      // 提交成功才关闭弹窗(与 H5 行为一致)
      // 注意: 弹窗是 Navigator.push 打开的, 必须用 Navigator.pop 才能关掉,
      // Get.back() 只关 GetX 自己的路由栈, 关不掉这里的页面
      Navigator.of(context).pop();
    } else {
      // 失败: 保留弹窗让用户看到原因并可重试, 恢复按钮可再次点击
      setState(() => submitting = false);
    }
  }

  void _toast(String message) {
    Get.snackbar('提示', message, snackPosition: SnackPosition.BOTTOM);
  }
}
