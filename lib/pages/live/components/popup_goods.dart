/// 底部商品框
library;

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../behavior/custom_scroll_behavior.dart';

class PopupGoods extends StatefulWidget {
  const PopupGoods({
    super.key,
    this.goodsList
  });

  // 带货商品列表
  final List? goodsList;

  @override
  State<PopupGoods> createState() => _PopupGoodsState();
}

class _PopupGoodsState extends State<PopupGoods> with SingleTickerProviderStateMixin {
// 商品分类标签
List goodsTag = ['全部', '书籍杂志', '学习用品', '零食特产', '生鲜', '粮油调味', '生活电器', '内衣裤袜', '3C数码配件'];

late TabController tabController = TabController(initialIndex: 0, length: goodsTag.length, vsync: this);

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
    body: SafeArea(
    child: ScrollConfiguration(
      behavior: CustomScrollBehavior().copyWith(scrollbars: false),
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
          SizedBox(
            height: MediaQuery.of(context).size.height * 3 / 4, // 自定义高度
            child: Material(
              color: Colors.grey[50],
              borderRadius: const BorderRadius.vertical(top: Radius.circular(10.0)),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.only(left: 10.0, top: 10.0, bottom: 5.0, right: 15.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                      Expanded(
                          child: Row(
                          spacing: 5.0,
                          children: [
                          ClipOval(
                            child: Image.asset('assets/images/avatar/img11.jpg', height: 35.0, width: 35.0, fit: BoxFit.cover),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text('平安喜乐的橱窗', style: TextStyle(fontSize: 15.0, fontWeight: FontWeight.w600),),
                                  Icon(Icons.arrow_forward_ios, size: 10.0,),
                                ],
                              ),
                              Row(
                                children: [
                                  Text('带货达人', style: TextStyle(color: Colors.red, fontSize: 12.0,)),
                                  SizedBox(width: 7.0,),
                                  Text('5.0 高', style: TextStyle(color: Colors.blue, fontSize: 12.0,)),
                                  ],
                                ),
                                ],
                              ),
                              ],
                              ),
                            ),
                            Wrap(
                              spacing: 15.0,
                              children: [
                              Column(
                                children: [
                                  Icon(Icons.shopping_cart_rounded, color: Colors.black54, size: 16.0,),
                                Text('购物车', style: TextStyle(color: Colors.black54, fontSize: 12.0,),),
                              ],
                            ),
                            Column(
                              children: [
                                Icon(Icons.my_library_books_rounded, color: Colors.black54, size: 16.0,),
                                Text('订单', style: TextStyle(color: Colors.black54, fontSize: 12.0,),),
                              ],
                            ),
                              ]
                            ),
                          ],
                      ),
                      Container(
                        height: 35.0,
                        width: double.infinity,
                        margin: const EdgeInsets.only(top: 5.0),
                      child: TabBar(
                        controller: tabController,
                        tabs: goodsTag.map((v) => Tab(text: v)).toList(),
                        isScrollable: true,
                        tabAlignment: TabAlignment.start,
                        overlayColor: WidgetStateProperty.all(Colors.transparent),
                        unselectedLabelColor: Colors.black38,
                        labelColor: Colors.black,
                        indicatorColor: Colors.black,
                        indicatorSize: TabBarIndicatorSize.tab,
                        unselectedLabelStyle: TextStyle(fontSize: 14.0, fontFamily: 'Microsoft YaHei'),
                        labelStyle: TextStyle(fontSize: 16.0, fontFamily: 'Microsoft YaHei', fontWeight: FontWeight.w700),
                        dividerHeight: 0,
                        labelPadding: EdgeInsets.symmetric(horizontal: 7.5),
                        indicatorPadding: EdgeInsets.symmetric(horizontal: 15.0, vertical: 2.0),
                        ),
                      ),
                    ],
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      shrinkWrap: true,
                      padding: EdgeInsets.all(8.0),
                      itemCount: widget.goodsList!.length,
                      itemBuilder: (context, index) {
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8.0),
                    padding: const EdgeInsets.all(8.0),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10.0),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: 10.0,
                    children: [
                      Stack(
                        children: [
                      ClipRRect(
                          borderRadius: BorderRadius.circular(10.0),
                          child: Image.network('${widget.goodsList![index]['image']}', height: 100.0, width: 100.0, fit: BoxFit.cover,),
                        ),
                        Positioned(
                          left: 0.0,
                          top: 0.0,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 1.0),
                            decoration: const BoxDecoration(
                              color: Colors.black38,
                              borderRadius: BorderRadius.only(topLeft: Radius.circular(10.0), bottomRight: Radius.circular(6.0),),
                            ),
                            child: Text('${index+1}', style: const TextStyle(color: Colors.white, fontSize: 12.0, fontWeight: FontWeight.w900),),
                          ),
                        ),
                        Visibility(
                          visible: index == 0,
                          child: Positioned(
                            left: 0.0,
                            right: 0.0,
                          bottom: 0.0,
                            child: Container(
                              padding: const EdgeInsets.all(3.0),
                              decoration: BoxDecoration(
                                color: Color(0xFFFF2C55).withAlpha(220),
                                borderRadius: BorderRadius.vertical(bottom: Radius.circular(10.0)),
                              ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Image.asset('assets/images/wave.png', height: 18.0,),
                              Text('讲解中', style: TextStyle(color: Colors.white, fontSize: 12.0),),
                            ],
                              ),
                            ),
                            ),
                          ),
                          ],
                        ),
                        Expanded(
                          child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${widget.goodsList![index]['title']}', maxLines: 1, style: const TextStyle(fontSize: 15.0,), overflow: TextOverflow.ellipsis,),
                            // 副标题(tips): 服务端未下发时不留空行(空文本照样占一行高度, 视觉上就是标题下方一大块空白)
                            if ('${widget.goodsList![index]['tips']}'.trim().isNotEmpty)
                            Text('${widget.goodsList![index]['tips']}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.red, fontSize: 12.0,),),
                            const SizedBox(height: 4.0,),
                            Wrap(
                              spacing: 5.0,
                              children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5.0),
                              decoration: BoxDecoration(
                                border: Border.all(color: const Color(0xFFFD7970), width: .5),
                                borderRadius: BorderRadius.circular(3.0),
                              ),
                              child: const Text('立减3元', style: TextStyle(color: Colors.red, fontSize: 10.0,),),
                              ),
                              Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5.0),
                              decoration: BoxDecoration(
                                border: Border.all(color: const Color(0xFFFDBA54), width: .5),
                                borderRadius: BorderRadius.circular(3.0),
                              ),
                              child: const Text('新人立减10元', style: TextStyle(color: Colors.orange, fontSize: 10.0,),),
                            ),
                            ],
                          ),
                          const SizedBox(height: 6.0,),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                            // 价格行: 独占一行, 不再与购买按钮挤在一行
                            Row(
                              children: [
                                const Text('¥', style: TextStyle(color: Colors.red, fontSize: 12.0),),
                                Flexible(
                                  child: Text('${widget.goodsList![index]['price']}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.red, fontSize: 16.0),),
                                ),
                                const SizedBox(width: 5.0,),
                                const Text(' 券后价 ', style: TextStyle(color: Colors.grey, fontSize: 10.0),),
                                Flexible(
                                  child: Text('¥${widget.goodsList![index]['mprice']}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.grey, fontSize: 10.0, decoration: TextDecoration.lineThrough),),
                                ),
                              ],
                            ),
                          const SizedBox(height: 8.0,),
                          // 购买行: 领券购买按钮独占下一行, 靠右对齐
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Container(
                                alignment: Alignment.center,
                                height: 30.0,
                                clipBehavior: Clip.antiAlias,
                                decoration: BoxDecoration(
                                  color: Color(0xFFF5F5F5),
                                    borderRadius: BorderRadius.circular(15.0),
                                  ),
                                  child: Row(
                                    children: [
                                      const Padding(
                                        padding: EdgeInsets.symmetric(horizontal: 7.0),
                                        child: Icon(Icons.add_shopping_cart, color: Colors.grey, size: 16.0,),
                                      ),
                                      Container(
                                        alignment: Alignment.center,
                                        height: 30.0,
                                        padding: const EdgeInsets.symmetric(horizontal: 10.0),
                                        color: Color(0xFFFF2C55),
                                        child: const Text('领券购买', style: TextStyle(color: Colors.white, fontSize: 12.0),),
                                      ),
                                      ],
                                      ),
                                    ),
                                    ],
                                  ),
                          ],
                          ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                        },
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
