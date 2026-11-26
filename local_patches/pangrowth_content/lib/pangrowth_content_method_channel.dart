import 'dart:async';

import 'package:flutter/services.dart';

import 'pangrowth_content_platform_interface.dart';

/// Default MethodChannel implementation used by Flutter.
class MethodChannelPangrowthContent extends PangrowthContentPlatform {
  MethodChannelPangrowthContent()
    : _methodChannel = const MethodChannel(_methodChannelName),
      _eventChannel = const EventChannel(_eventChannelName);

  static const String _methodChannelName = 'pangrowth_content';
  static const String _eventChannelName = 'pangrowth_content_event';

  final MethodChannel _methodChannel;
  final EventChannel _eventChannel;

  Stream<Map<String, dynamic>>? _eventStream;

  @override
  Stream<Map<String, dynamic>> get contentEventStream {
    return _eventStream ??= _eventChannel
        .receiveBroadcastStream()
        .map<Map<String, dynamic>>(_coerceEventPayload)
        .asBroadcastStream();
  }

  @override
  Future<T?> invokeMethod<T>(String method, [Map<String, dynamic>? arguments]) {
    return _methodChannel.invokeMethod<T>(method, arguments);
  }

  @override
  Future<String?> getPlatformVersion() {
    return _methodChannel.invokeMethod<String>('getPlatformVersion');
  }

  Map<String, dynamic> _coerceEventPayload(dynamic raw) {
    if (raw is Map) {
      return raw.map<String, dynamic>(
        (dynamic key, dynamic value) => MapEntry(key.toString(), value),
      );
    }
    throw ArgumentError(
      'Expected event payload to be a Map but found ${raw.runtimeType}',
    );
  }
}
