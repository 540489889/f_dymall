import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../behavior/custom_scroll_behavior.dart';

import '../../../api/live.dart';
import '../../../api/member_point.dart';
import '../../../controller/app_config.dart';

// 虚拟币价格式化: 接口下发的是 amount("1.00"/"666.00" 这类字符串)
// * 整数值去掉小数尾巴, 显示「1金币」而不是「1.0金币」; 真有小数时保留
// * 单位名统一走 AppConfig.to.pointName()(/api/config/init 的 point_config.name),
//   不再写死「钻」——后台改名后全站同步
String _coinText(dynamic coins) {
  final num v = coins is num ? coins : (num.tryParse('${coins ?? ''}') ?? 0);
  return v == v.roundToDouble() ? '${v.toInt()}' : '$v';
}

class PopupGift extends StatefulWidget {
const PopupGift({
  super.key,
  this.onChanged,
});

// 赠送: 回调整条礼物数据({id, name, image, coins}), 由直播间调 /live/api/gift/give
final ValueChanged<Map<String, dynamic>>? onChanged;

/// 金币余额刷新信号(值本身无意义, 变化即代表需要重新拉取)
/// * 场景: 充值弹窗付款成功后, 礼物弹窗还压在下面, 靠它通知刷新余额
static final ValueNotifier<int> balanceTick = ValueNotifier<int>(0);

/// 触发余额刷新(充值成功回调里调用)
static void notifyBalanceChanged() => balanceTick.value++;

@override
State<PopupGift> createState() => _PopupGiftState();
}

class _PopupGiftState extends State<PopupGift> with SingleTickerProviderStateMixin {
int tabIndex = 0;
// 只保留「礼物」tab: 互动/粉丝团/等级无对应功能, 已去掉
List<String> tabList = ['礼物'];
late final TabController tabController = TabController(initialIndex: tabIndex, length: tabList.length, vsync: this);
int giftIndex = 0;
// 礼物列表: 打开弹窗时调 /live/api/gift/lists, 拿到结果前先转圈
final List<Map<String, dynamic>> gifts = <Map<String, dynamic>>[];
bool giftLoading = true;
// 当前金币余额: /api/memberaccount/point 的 point, 单位跟随 point_config.name
// * 未登录/请求失败时保留 '--' 占位, 不误导用户
String pointText = '--';

@override
void initState() {
  super.initState();
  _loadGifts();
  _loadPoint();
  // 充值成功后重新拉取余额
  PopupGift.balanceTick.addListener(_loadPoint);
}

// 金币余额(/api/memberaccount/point 的 point)
// * 失败时静默处理: 保留 '--', 不弹 toast 打断挑礼物
Future<void> _loadPoint() async {
  try {
    final Map<String, dynamic> res = await MemberPointApi.point();
    if (!mounted) return;
    setState(() => pointText = _coinText(res['point']));
  } catch (_) {
    if (!mounted) return;
    setState(() => pointText = '--');
  }
}

// 礼物列表: 由接口下发, 失败/无数据就留空并展示空态
// * 不再回落本地演示数据(mock/gift_json.dart): 演示礼物的价格是编的, 展示出来会误导
Future<void> _loadGifts() async {
  final List<Map<String, dynamic>>? list = await LiveApi.giftLists();
  if (!mounted) return;
  setState(() {
    gifts.clear();
    if (list != null) gifts.addAll(list);
    giftLoading = false;
  });
}

@override
void dispose() {
  tabController.dispose();
  PopupGift.balanceTick.removeListener(_loadPoint);
  super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: ScrollConfiguration(
    behavior: CustomScrollBehavior().copyWith(scrollbars: false),
    child: SafeArea(
      top: true,
      bottom: false,
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
          color: Color(0xFF161823),
          borderRadius: BorderRadius.vertical(top: Radius.circular(10.0)),
          child: Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom),
            child: Column(
            children: [
              Container(
                padding: EdgeInsets.symmetric(horizontal: 15.0, vertical: 10.0,),
                child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 「礼物」标题 + 当前金币余额 同一行(充值/个人中心/等级进度条已去掉)
                  // * 余额取 /api/memberaccount/point 的 point, 单位跟随 point_config.name
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: 25.0,
                          child: TabBar(
                            controller: tabController,
                            tabs: tabList.map((v) => Tab(text: v)).toList(),
                            isScrollable: true,
                            tabAlignment: TabAlignment.start,
                            overlayColor: WidgetStateProperty.all(Colors.transparent),
                            unselectedLabelColor: Colors.white54,
                            labelColor: Color(0xFFFFE81D),
                            indicatorColor: Colors.transparent,
                            indicatorSize: TabBarIndicatorSize.label,
                            unselectedLabelStyle: TextStyle(fontSize: 14.0, fontFamily: 'Microsoft YaHei'),
                            labelStyle: TextStyle(fontSize: 14.0, fontFamily: 'Microsoft YaHei', fontWeight: FontWeight.w600),
                            dividerHeight: 0,
                            labelPadding: EdgeInsets.only(right: 20.0),
                            indicatorPadding: EdgeInsets.symmetric(horizontal: 5.0,),
                            onTap: (index) {
                              setState(() {
                                tabIndex = index;
                              });
                            },
                          ),
                        ),
                      ),
                      SizedBox(width: 10.0,),
                      // 金币余额: 硬币图标 + 数值 + 单位
                      Row(
                        spacing: 4.0,
                        children: [
                          Icon(Icons.monetization_on_outlined, color: Color(0xFFFFE81D), size: 16.0,),
                          Text('余额', style: TextStyle(color: Colors.white54, fontSize: 12.0),),
                          Text('$pointText${AppConfig.to.pointName()}', style: TextStyle(color: Color(0xFFFFE81D), fontSize: 13.0, fontWeight: FontWeight.w600), maxLines: 1),
                        ],
                      ),
                    ],
                  ),
                        ],
                      ),
                    ),
                    SizedBox(
                      height: 275.0,
                      child: TabBarView(
                      controller: tabController,
                      children: [
                        // 礼物tab: 加载中转圈 / 无数据空态 / 有数据走网格
                        giftLoading
                        ? const Center(
                            child: SizedBox(
                              width: 22.0,
                              height: 22.0,
                              child: CircularProgressIndicator(strokeWidth: 2.0, color: Color(0xFFFFE81D)),
                            ),
                          )
                        : gifts.isEmpty
                        ? Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Image.asset('assets/images/common-empty.png', width: 120.0),
                              const SizedBox(height: 20.0),
                              const Text('暂无礼物', style: TextStyle(color: Colors.white54)),
                            ],
                          )
                        : GridView.builder(
                          shrinkWrap: true,
                          padding: EdgeInsets.symmetric(horizontal: 15.0, vertical: 7.0),
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            // 横轴元素个数
                            crossAxisCount: 4,
                            // 纵轴间距
                            mainAxisSpacing: 5.0,
                            // 横轴间距
                            crossAxisSpacing: 10.0,
                            mainAxisExtent: 100.0,
                          ),
                          itemCount: gifts.length,
                          itemBuilder: (context, index) {
                            return Container(
                            decoration: BoxDecoration(
                              color: giftIndex == index ? Color(0xFF25283A) : Colors.transparent,
                              border: Border.all(color: giftIndex == index ? Colors.white12 : Colors.transparent, width: .5),
                              borderRadius: BorderRadius.circular(10.0),
                            ),
                            child: Stack(
                              children: [
                            InkWell(
                            splashColor: Colors.transparent,
                            overlayColor: WidgetStateProperty.all(Colors.transparent),
                            child: Container(
                            alignment: Alignment.center,
                            child: Column(
                              children: [
                                SizedBox(height: 5.0),
                                // 礼物图标由接口下发(网络图), 取不到时占位, 不阻塞渲染
                                '${gifts[index]['image']}'.isEmpty
                                    ? const Icon(Icons.card_giftcard, color: Colors.white54, size: 40.0)
                                    : Image.network('${gifts[index]['image']}', height: 40.0, width: 40.0, fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) => const Icon(Icons.card_giftcard, color: Colors.white54, size: 40.0)),
                                SizedBox(height: 5.0),
                                Visibility(
                                    visible: giftIndex != index,
                                    child: Text('${gifts[index]['name']}', style: TextStyle(color: Colors.white70, fontSize: 12.0),),
                                  ),
                                  SizedBox(height: 3.0),
                                  Text('${_coinText(gifts[index]['coins'])}${AppConfig.to.pointName()}', style: TextStyle(color: giftIndex == index ? Colors.white : Colors.white38, fontSize: 10.0),),
                                ],
                              ),
                            ),
                            onTap: () {
                              setState(() {
                                giftIndex = index;
                              });
                              },
                            ),
                            Visibility(
                              visible: giftIndex == index,
                          child: Positioned(
                            left: 0,
                            right: 0,
                            bottom: 0,
                            child: GestureDetector(
                              child: Container(
                                alignment: Alignment.center,
                                padding: EdgeInsets.symmetric(vertical: 4.0,),
                                decoration: BoxDecoration(
                                  color: Color(0xFFFF2C55),
                                  borderRadius: BorderRadius.vertical(bottom: Radius.circular(10.0)),
                                ),
                                child: Text('赠送', style: TextStyle(color: Colors.white, fontSize: 13.0),),
                              ),
                              onTap: () {
                                // 传整条: 直播间要 id 调 give, 也要 name 拼赠送成功提示
                                widget.onChanged!(gifts[index]);
                              },
                              ),
                              ),
                            )
                          ],
                          ),
                          );
                        },
                      ),
                      ],
                  ),
                  ),
                ],
              ),
              ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
