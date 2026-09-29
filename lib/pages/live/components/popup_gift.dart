import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../behavior/custom_scroll_behavior.dart';

import '../mock/gift_json.dart';

class PopupGift extends StatefulWidget {
const PopupGift({
  super.key,
  this.onChanged,
});

// 输入框值改变
final ValueChanged? onChanged;

@override
State<PopupGift> createState() => _PopupGiftState();
}

class _PopupGiftState extends State<PopupGift> with SingleTickerProviderStateMixin {
int tabIndex = 0;
List<String> tabList = ['礼物', '互动', '粉丝团', '等级'];
late final TabController tabController = TabController(initialIndex: tabIndex, length: tabList.length, vsync: this);
int giftIndex = 0;

@override
void initState() {
  super.initState();
}

@override
void dispose() {
  tabController.dispose();
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
        Material(
          color: Color(0xFF161823),
          borderRadius: BorderRadius.vertical(top: Radius.circular(10.0)),
          child: Column(
            children: [
              Container(
                padding: EdgeInsets.symmetric(horizontal: 15.0, vertical: 10.0,),
                child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                  children: [
                    Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                      SliderTheme(
                          data: SliderThemeData(
                            trackHeight: 3.0,
                            thumbShape: RoundSliderThumbShape(enabledThumbRadius: 0.0), // 调整滑块的大小
                            // trackShape: RectangularSliderTrackShape(), // 使用矩形轨道形状
                            overlayShape: RoundSliderOverlayShape(overlayRadius: 0), // 去掉Slider默认上下边距间隙
                            inactiveTrackColor: Colors.white24, // 设置非活动进度条的颜色
                            activeTrackColor: Color(0xFFFF2C55), // 设置活动进度条的颜色
                            thumbColor: Color(0xFFFF2C55), // 设置滑块的颜色
                            overlayColor: Colors.transparent, // 设置滑块覆盖层的颜色
                          ),
                          child: Slider(
                            value: .8,
                            onChanged: (value) {},
                          ),
                          ),
                          SizedBox(height: 3.0,),
                          Text('距离8级还差100钻', style: TextStyle(color: Color(0xFFFFE81D), fontSize: 10.0,)),
                        ],
                        ),
                      ),
                      Container(
                        margin: EdgeInsets.only(left: 20.0,),
                      padding: EdgeInsets.symmetric(horizontal: 10.0, vertical: 5.0),
                        decoration: BoxDecoration(
                        color: Color(0xFF25283A),
                            borderRadius: BorderRadius.circular(15.0),
                          ),
                          child: Row(
                            spacing: 3.0,
                            children: [
                              Text('充值', style: TextStyle(color: Color(0xFFFFE81D), fontSize: 12.0),),
                              Icon(Icons.arrow_forward_ios, color: Colors.white54, size: 10.0,)
                            ],
                          ),
                        ),
                        Container(
                          margin: EdgeInsets.only(left: 10.0,),
                          padding: EdgeInsets.symmetric(horizontal: 10.0, vertical: 5.0),
                          decoration: BoxDecoration(
                            color: Color(0xFF25283A),
                            borderRadius: BorderRadius.circular(15.0),
                          ),
                          child: Text('个人中心', style: TextStyle(color: Colors.white54, fontSize: 12.0),),
                          ),
                        ],
                      ),
                        Container(
                          height: 25.0,
                        margin: EdgeInsets.only(top: 10.0,),
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
                        ],
                      ),
                    ),
                    SizedBox(
                      height: 275.0,
                      child: TabBarView(
                      controller: tabController,
                      children: [
                        GridView.builder(
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
                          itemCount: giftJson.length,
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
                                Image.asset('${giftJson[index]['pic']}', height: 40.0, width: 40.0, fit: BoxFit.cover),
                                SizedBox(height: 5.0),
                                Visibility(
                                    visible: giftIndex != index,
                                    child: Text('${giftJson[index]['title']}', style: TextStyle(color: Colors.white70, fontSize: 12.0),),
                                  ),
                                  SizedBox(height: 3.0),
                                  Text('${giftJson[index]['coins']}钻', style: TextStyle(color: giftIndex == index ? Colors.white : Colors.white38, fontSize: 10.0),),
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
                                widget.onChanged!(giftJson[index]['coins']);
                              },
                              ),
                              ),
                            )
                          ],
                          ),
                          );
                        },
                      ),
                      Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Image.asset('assets/images/common-empty.png', width: 120.0),
                          SizedBox(height: 20.0,),
                          Text('暂无数据', style: TextStyle(color: Colors.white54,),),
                        ],
                      ),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Image.asset('assets/images/common-empty.png', width: 120.0),
                          SizedBox(height: 20.0,),
                          Text('暂无数据', style: TextStyle(color: Colors.white54,),),
                        ],
                      ),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Image.asset('assets/images/common-empty.png', width: 120.0),
                          SizedBox(height: 20.0,),
                          Text('暂无数据', style: TextStyle(color: Colors.white54,),),
                        ],
                      ),
                    ],
                  ),
                  ),
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
