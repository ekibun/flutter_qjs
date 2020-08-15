/*
 * @Description: 
 * @Author: ekibun
 * @Date: 2020-08-08 08:29:09
 * @LastEditors: ekibun
 * @LastEditTime: 2020-08-15 16:21:56
 */
import 'dart:async';
import 'package:flutter/services.dart';

typedef JsMethodHandler = Future<dynamic> Function(String method, List args);

class _FlutterJs {
  factory _FlutterJs() => _getInstance();
  static _FlutterJs get instance => _getInstance();
  static _FlutterJs _instance;
  MethodChannel _channel = const MethodChannel('soko.ekibun.flutter_qjs');
  Map<dynamic, JsMethodHandler> methodHandlers = Map<dynamic, JsMethodHandler>();
  _FlutterJs._internal() {
    _channel.setMethodCallHandler((call) async {
      print(call.arguments);
      var engine = call.arguments["engine"];
      var args = call.arguments["args"];
      print(methodHandlers.entries);
      print(methodHandlers[engine]);
      if (methodHandlers[engine] == null) return call.noSuchMethod(null);
      return await methodHandlers[engine](call.method, _wrapFunctionArguments(args));
    });
  }
  dynamic _wrapFunctionArguments(dynamic val) {
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
      } else
        for (var key in val.keys) {
          val[key] = _wrapFunctionArguments(val[key]);
        }
    }
    return val;
  }

  static _FlutterJs _getInstance() {
    if (_instance == null) {
      _instance = new _FlutterJs._internal();
    }
    return _instance;
  }
}

class FlutterJs {
  dynamic _engine;

  ensureEngine() async {
    if(_engine == null){
      _engine = await _FlutterJs.instance._channel.invokeMethod("createEngine");
    }
  }

  setMethodHandler(JsMethodHandler handler) async {
    await ensureEngine();
    _FlutterJs.instance.methodHandlers[_engine] = handler;
  }

  destroy() async {
    if (_engine != null){
      await _FlutterJs.instance._channel.invokeMethod("close", {"engine": _engine});
      _engine = null;
    }
  }

  Future<dynamic> evaluate(String command, String name) async {
    ensureEngine();
    var arguments = {"engine": _engine, "script": command, "name": command};
    return _FlutterJs.instance._wrapFunctionArguments(
        await _FlutterJs.instance._channel.invokeMethod("evaluate", arguments));
  }
}
