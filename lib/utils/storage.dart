/// 封装get_storage缓存类
library;

import 'package:get_storage/get_storage.dart';

class Storage {
  /// 读取缓存
 static dynamic read(String key) {
   return GetStorage().read(key);
  }
  /// 写入缓存
 static void write(String key, value) {
  GetStorage().write(key, value);
  }
  /// 是否有缓存数据
  static bool hasData(String key) {
   return GetStorage().hasData(key);
  }
  /// 删除缓存
 static void remove(String key) {
  GetStorage().remove(key);
  }
  /// 清空缓存
 static void clear() {
  GetStorage().erase();
  }
}
