import 'dart:async';

import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'pangrowth_content_method_channel.dart';

/// Base contract for communicating with the underlying PanGrowth content implementations.
abstract class PangrowthContentPlatform extends PlatformInterface {
  PangrowthContentPlatform() : super(token: _token);

  static final Object _token = Object();

  static PangrowthContentPlatform _instance = MethodChannelPangrowthContent();

  /// The active platform implementation.
  static PangrowthContentPlatform get instance => _instance;

  static set instance(PangrowthContentPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  /// Broadcast stream with raw events emitted from the native layer.
  Stream<Map<String, dynamic>> get contentEventStream {
    throw UnimplementedError('contentEventStream has not been implemented.');
  }

  /// Invoke a platform method and return a typed result.
  Future<T?> invokeMethod<T>(String method, [Map<String, dynamic>? arguments]) {
    throw UnimplementedError('invokeMethod() has not been implemented.');
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('getPlatformVersion() has not been implemented.');
  }
}
