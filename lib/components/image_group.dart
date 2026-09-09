/// 九宫格预览图片组
library;

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../router/hero_route.dart';
import './image_viewer.dart';

import '../utils/index.dart';

class ImageGroup extends StatelessWidget {
  const ImageGroup({
  super.key,
  this.images,
  this.width = 200.0,
  this.album = false,
  this.limit = 9,
  this.onChoose,
});

final List<String>? images; // 图片组
final double width; // 图片宽度
final bool album; // 是否相册/专辑(最后面显示+可选择图片)
final int limit; // 限制多少张
final Function? onChoose; // 选择图片回调
int? get count => images?.length;
List<String>? get imgList => count! >= limit ? images?.sublist(0, limit) : images;

// 创建可点击预览图片
GestureDetector createImage(BuildContext context, String img, int key) {
  return GestureDetector(
    child: Hero(
      tag: img, // 放大缩小动画效果标识
    child: img == '+' ? 
    Container(color: Colors.transparent, child: const Icon(Icons.add, size: 30.0, color: Colors.black45),)
    :
      Utils.isUrl(img) ?
      Image.network(
        img,
        width: width,
        fit: BoxFit.contain,
      )
      :
      Image.asset(
        img,
        width: width,
        fit: BoxFit.contain,
      ),
    ),
    onTap: () {
      // 选择图片
      if(img == '+') {
        onChoose!();
      }else {
        navigator?.push(HeroRoute(route: ImageViewer(
          images: album ? imgList!.sublist(0, imgList!.length - 1) : imgList,
          index: key,
        )));
      }
      },
    );
  }

  @override
Widget build(BuildContext context){
  // 一张图片
  if(count == 1 && !album) {
  return SizedBox(
    width: width,
    child: createImage(context, imgList![0], 0),
  );
}

if(album && count! < limit) {
  imgList?.add('+');
}

// 多张图片
return GridView(
  shrinkWrap: true,
  physics: const NeverScrollableScrollPhysics(),
  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
    // 横轴元素个数
    crossAxisCount: 3,
    // 纵轴间距
    mainAxisSpacing: 5.0,
    // 横轴间距
    crossAxisSpacing: 5.0,
    // 子组件宽高比例
    childAspectRatio: 1,
  ),
  children: imgList!.asMap().entries.map((item) {
    return Container(
      color: Colors.grey[100],
      child: createImage(context, item.value, item.key),
    );
    }).toList(),
  );
}
}
