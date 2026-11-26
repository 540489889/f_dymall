import 'package:flutter_test/flutter_test.dart';
import 'package:pangrowth_content/pangrowth_content.dart';

void main() {
  group('PangrowthContent', () {
    test('can import package', () {
      expect(PangrowthContent, isNotNull);
    });

    test('has basic API methods', () {
      // 测试API方法是否存在
      expect(PangrowthContent.initialize, isA<Function>());
      expect(PangrowthContent.start, isA<Function>());
      expect(PangrowthContent.getDramaList, isA<Function>());
      expect(PangrowthContent.createDramaHome, isA<Function>());
      expect(PangrowthContent.showDramaHome, isA<Function>());
      // removeEventListener已被移除,改用专用Listener
    });
  });
}
