import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pangrowth_content/pangrowth_content_method_channel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  MethodChannelPangrowthContent platform = MethodChannelPangrowthContent();
  const MethodChannel channel = MethodChannel('pangrowth_content');

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
          return '42';
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('getPlatformVersion', () async {
    expect(await platform.getPlatformVersion(), '42');
  });
}
