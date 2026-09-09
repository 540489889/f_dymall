/// 视频模块controller
library;

import 'package:get/get.dart';

class VideoStore extends GetxController {
static VideoStore get to => Get.find();
// 底部导航栏索引
RxInt bottomNavigationIndex = 0.obs;
// 视频页面顶部Tab索引
RxInt videoTabIndex = 7.obs;
// 当前播放视频索引
RxInt videoPlayIndex = 0.obs;
void updateBottomNavigationIndex(int index) {
  bottomNavigationIndex.value = index;
  update();
}
void updateVideoTabIndex(int index) {
  videoTabIndex.value = index;
  update();
}
void updateVideoPlayIndex(int index) {
  videoPlayIndex.value = index;
  update();
  }
}
