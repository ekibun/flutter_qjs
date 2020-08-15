/*
 * @Description: 
 * @Author: ekibun
 * @Date: 2020-08-08 08:29:09
 * @LastEditors: ekibun
 * @LastEditTime: 2020-08-15 13:58:11
 */
import 'dart:async';

import 'package:flutter/services.dart';

class FlutterJs {
  static const MethodChannel _channel = const MethodChannel('soko.ekibun.flutter_qjs');

  static Future<dynamic> Function(String method, List args) methodHandler;

  static Future<int> initEngine() async {
    final int engineId = await _channel.invokeMethod("initEngine");
    _channel.setMethodCallHandler((call) async {
      if (methodHandler == null) return call.noSuchMethod(null);
      return await methodHandler(call.method, _wrapFunctionArguments(call.arguments));
    });
    return engineId;
  }

  static dynamic _wrapFunctionArguments(dynamic val) {
    if (val is List) {
      for (var i = 0; i < val.length; ++i) {
        val[i] = _wrapFunctionArguments(val[i]);
      }
    } else if (val is Map) {
      if (val["__js_function__"] != 0) {
        var functionId = val["__js_function__"];
        return (List<dynamic> args) async {
          var arguments = {"function": functionId, "arguments": args};
          return await _channel.invokeMethod("call", arguments);
        };
      }else for(var key in val.keys) {
        val[key] = _wrapFunctionArguments(val[key]);
      }
    }
    return val;
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
