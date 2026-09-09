import 'package:flutter/material.dart';
import 'package:card_swiper/card_swiper.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../components/loading.dart';
import '../../../components/backtop.dart';
class DramaModule extends StatefulWidget {
  const DramaModule({ super.key });
  @override
  State<DramaModule> createState() => _DramaModuleState();
}

class _DramaModuleState extends State<DramaModule> {
  // 模拟器请求数据
  List fetchData = [
  {'image': 'https://i0.hdslb.com/bfs/bangumi/image/5c1622f50bf3845432a5b321f7a7d3d098e057dd.png', 'name': '香格里拉', 'desc': '香格里拉边境全新上新《第二季》。', 'like': '1208'},
  {'image': 'https://i0.hdslb.com/bfs/archive/855e52477cdb85fcaacbcfb9d37aa6957b777b0c.png', 'name': '小猪佩奇', 'desc': '《小猪佩奇》是一部针对学龄前儿童的动画片，讲述的是一只名叫佩奇的可爱小猪的故事。', 'like': '3129'},
  {'image': 'https://s2-10623.kwimgs.com/kimg/bs2/zt-image-host/ChgwOGQyZmFlMGNjMDIxMGFkZTI5YWYwMDYQ3svXLw.jpg', 'name': '新福音战士', 'desc': '第二次冲击爆发。在南极大陆上发生的这起大灾难，造成地轴偏斜、海平面上升。', 'like': '168'},
  {'image': 'https://i0.hdslb.com/bfs/archive/4657b6a60a0eae61f0d1f57da2af4a7b00b99104.png', 'name': '蓝色禁区', 'desc': '赌上一切去挑战。上吧，才能的原石们啊！改变时代的，是我们Blue Lock（蓝色监狱）。', 'like': '8256'},
  {'image': 'https://i0.hdslb.com/bfs/bangumi/image/6c1ca4159442a6de3577bbee5e583be72b00499f.jpg', 'name': '隐瞒之事', 'desc': '我们仍未知道那天所看见的花的名字。', 'like': '1805'},
  {'image': 'https://i0.hdslb.com/bfs/bangumi/image/cde0f6de97c5beac7358d3a89a68aa9b37b4c059.png', 'name': '魔力新世界', 'desc': '小马宝莉之魔力新世界 第二季。', 'like': '512'},
  {'image': 'https://i0.hdslb.com/bfs/archive/1ceb3aee0f352291a838c470b352d05ccd202fd4.png', 'name': '假面骑士', 'desc': '"在人类世界里暗中行动的智慧生物——砂糖人。 他们为了获取“黑暗零食”持续掳掠人类。 接连不断有人类遭到砂糖人袭击', 'like': '756'},
  {'image': 'https://s1-10623.kwimgs.com/kimg/bs2/zt-image-host/ChQwODg2YmVmYzI5MTBjY2JlZjEyYRDfy9cv.jpg', 'name': '汪喵喵', 'desc': '与汪汪喵喵同居的日子。', 'like': '95'},
  
];
// 列表
List dataList = [];
// 是否加载中
bool isLoading = false;

late ScrollController scrollController = ScrollController();
// 记录滚动位置
final ValueNotifier<double> scrollOffset = ValueNotifier(0);

// 加载更多
Future<void> loadMoreData() async {
  if(isLoading) return;
  setState(() {
  isLoading = true;
});
// 模拟网络请求或数据获取延迟
  await Future.delayed(Duration(seconds: 1));
  setState(() {
    dataList.addAll(fetchData);
    isLoading = false;
  });
}

// 下拉刷新
Future<void> handleRefresh() async {
  setState(() {
    dataList.clear();
  });
  loadMoreData();
}

@override
  void initState() {
  super.initState();
scrollController.addListener(() {
  scrollOffset.value = scrollController.offset;

  if(scrollController.position.pixels == scrollController.position.maxScrollExtent) {
    debugPrint('[drama]滚动到底部');
    if(!isLoading) {
      loadMoreData();
    }
    }
  });

  handleRefresh();
}

@override
void dispose() {
  scrollController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
    appBar: AppBar(
      toolbarHeight: 0,
      forceMaterialTransparency: true,
    ),
    body: Container(
      color: Colors.grey[50],
      child: RefreshIndicator(
        backgroundColor: Colors.white,
        color: Color(0xFFFF2C55),
        displacement: 10.0,
        onRefresh: handleRefresh,
      child: ListView(
        controller: scrollController,
        physics: BouncingScrollPhysics(),
        children: [
          // 广告图
          SizedBox(
            height: 150.0,
          child: Swiper.children(
            autoplay: true,
            pagination: SwiperPagination(
              alignment: Alignment.bottomRight,
            builder: DotSwiperPaginationBuilder(
              color: Colors.white70,
              activeColor: Colors.white,
              size: 5.0,
              activeSize: 8.0
              )
            ),
            children: [
              CachedNetworkImage(imageUrl: 'https://i0.hdslb.com/bfs/bangumi/image/8b1883de98ffad7dfa8fc716ae72610adbf56ea2.png', fit: BoxFit.fill),
              CachedNetworkImage(imageUrl: 'https://i0.hdslb.com/bfs/bangumi/image/2a59bdfd0c73e236d17a0dcba8eae539a0ab63bf.png', fit: BoxFit.fill),
              CachedNetworkImage(imageUrl: 'https://i0.hdslb.com/bfs/bangumi/image/7c50b2efec9f009a7b69ab148dac895927214709.png', fit: BoxFit.fill),
            ],
            ),
          ),
          Container(
            padding: EdgeInsets.all(10.0),
          child: Column(
            spacing: 10.0,
            children: [
            dataList.isEmpty ? 
              // 初始loading提示
              Column(
              children: [
                RefreshProgressIndicator(
                  backgroundColor: Colors.white,
                  color: Color(0xFFFF2C55),
                ),
              ],
            )
            :
            MasonryGridView.count(
              shrinkWrap: true,
            padding: EdgeInsets.zero,
            physics: NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            mainAxisSpacing: 10.0,
            crossAxisSpacing: 10.0,
            itemCount: dataList.length,
            itemBuilder: (BuildContext context, int index) => CardItem(item: dataList[index]),
          ),
          Opacity(
            opacity: dataList.isNotEmpty && isLoading ? 1 : 0,
            child: Loading(title: 'loading...')
            ),
            ],
          ),
        ),
      ],
      ),
    ),
  ),
  // 返回顶部
  floatingActionButton: Backtop(controller: scrollController, offset: scrollOffset),
  );
}
}

// 卡片组件
class CardItem extends StatelessWidget {
final dynamic item;
const CardItem({super.key, required this.item});

@override
Widget build(BuildContext context) {
  return Container(
    padding: EdgeInsets.all(5.0),
    decoration: BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(5.0),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withAlpha(10),
        offset: Offset(0.0, 1.0),
        blurRadius: 1.0,
        spreadRadius: 0.0,
      ),
    ]
  ),
  child: Column(
    children: [
      CachedNetworkImage(
        imageUrl: '${item['image']}',
      placeholder: (context, url) => Container(
        height: 100.0,
      ),
      height: 100.0,
      width: double.infinity,
      fit: BoxFit.cover,
    ),
    Container(
      padding: const EdgeInsets.all(5.0),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
      SizedBox(
      height: 40.0,
      child: Text('${item['desc']}', style: TextStyle(fontSize: 14.0, height: 1.2), maxLines: 2, overflow: TextOverflow.ellipsis,),
    ),
    const SizedBox(height: 5.0,),
    Row(
      children: [
      Expanded(
    child: Row(
      children: [
          ClipOval(
          child: CachedNetworkImage(imageUrl: '${item['image']}', height: 20.0, width: 20.0, fit: BoxFit.cover,),
        ),
        const SizedBox(width: 5.0,),
        Container(
          constraints: const BoxConstraints(
              maxWidth: 90.0,
            ),
            child: Text('${item['name']}', style: const TextStyle(color: Colors.grey, fontSize: 12.0), maxLines: 1, overflow: TextOverflow.ellipsis,),
          )
        ],
      ),
      ),
      const Icon(Icons.thumb_up_off_alt, color: Colors.black54, size: 14.0,),
      Text('${item['like']}', style: const TextStyle(color: Colors.grey, fontSize: 12.0),)
        ],
      ),
        ],
      ),
    ),
    ],
  ),
  );
  }
}
