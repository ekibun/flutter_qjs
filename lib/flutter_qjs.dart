/*
 * @Description: 
 * @Author: ekibun
 * @Date: 2020-08-08 08:29:09
 * @LastEditors: ekibun
 * @LastEditTime: 2020-08-08 17:40:35
 */
import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';

class FlutterJs {
  static const MethodChannel _channel = const MethodChannel('soko.ekibun.flutter_qjs');

  static Future<dynamic> Function(String method, List args) methodHandler;

  static Future<int> initEngine() async {
    final int engineId = await _channel.invokeMethod("initEngine");
    _channel.setMethodCallHandler((call) async {
      if (methodHandler == null) return call.noSuchMethod(null);
      List args = jsonDecode(call.arguments);
      return jsonEncode(await methodHandler(call.method, args));
    });
    return engineId;
  }

  static Future<String> evaluate(String command, String name) async {
    var arguments = {"script": command, "name": command};
    final String jsResult = await _channel.invokeMethod("evaluate", arguments);
    return jsResult ?? "null";
  }

  static Future<void> close() async {
    return await _channel.invokeMethod("close");
  }
}
