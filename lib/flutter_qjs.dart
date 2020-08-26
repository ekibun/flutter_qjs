/*
 * @Description: quickjs engine
 * @Author: ekibun
 * @Date: 2020-08-08 08:29:09
 * @LastEditors: ekibun
 * @LastEditTime: 2020-08-26 23:11:10
 */
import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';

/// Handle function to manage js call with `dart(method, ...args)` function.
typedef JsMethodHandler = Future<dynamic> Function(String method, List args);

/// return this in [JsMethodHandler] to mark method not implemented.
class JsMethodHandlerNotImplement {}

/// FlutterJs instance.
/// Each [FlutterJs] object creates a new thread that runs a simple js loop.
/// Make sure call `destroy` to terminate thread and release memory when you don't need it.
class FlutterJs {
  dynamic _engine;

  _ensureEngine() async {
    if (_engine == null) {
      _engine = await _FlutterJs.instance._channel.invokeMethod("createEngine");
    }
  }

  /// Set a handler to manage js call with `dart(method, ...args)` function.
  setMethodHandler(JsMethodHandler handler) async {
    await _ensureEngine();
    _FlutterJs.instance.methodHandlers[_engine] = handler;
  }

  /// Terminate thread and release memory.
  destroy() async {
    if (_engine != null) {
      await _FlutterJs.instance._channel
          .invokeMethod("close", _engine);
      _engine = null;
    }
  }

  /// Evaluate js script.
  Future<dynamic> evaluate(String command, String name) async {
    await _ensureEngine();
    var arguments = {"engine": _engine, "script": command, "name": name};
    return _FlutterJs.instance._wrapFunctionArguments(
        await _FlutterJs.instance._channel.invokeMethod("evaluate", arguments),
        _engine);
  }
}

class _FlutterJs {
  factory _FlutterJs() => _getInstance();
  static _FlutterJs get instance => _getInstance();
  static _FlutterJs _instance;
  MethodChannel _channel = const MethodChannel('soko.ekibun.flutter_qjs');
  Map<dynamic, JsMethodHandler> methodHandlers =
      Map<dynamic, JsMethodHandler>();
  _FlutterJs._internal() {
    _channel.setMethodCallHandler((call) async {
      var engine = call.arguments["engine"];
      var args = call.arguments["args"];
      if (methodHandlers[engine] == null) return call.noSuchMethod(null);
      var ret = await methodHandlers[engine](
          call.method, _wrapFunctionArguments(args, engine));
      if (ret is JsMethodHandlerNotImplement) return call.noSuchMethod(null);
      return ret;
    });
  }
  dynamic _wrapFunctionArguments(dynamic val, dynamic engine) {
    if (val is List && !(val is List<int>)) {
      for (var i = 0; i < val.length; ++i) {
        val[i] = _wrapFunctionArguments(val[i], engine);
      }
    } else if (val is Map) {
      // wrap boolean in Android see https://github.com/flutter/flutter/issues/45066
      if (Platform.isAndroid && val["__js_boolean__"] != null) {
        return val["__js_boolean__"] != 0;
      }
      if (val["__js_function__"] != null) {
        var functionId = val["__js_function__"];
        return (List<dynamic> args) async {
          var arguments = {
            "engine": engine,
            "function": functionId,
            "arguments": args
          };
          return _wrapFunctionArguments(
              await _channel.invokeMethod("call", arguments), engine);
        };
      } else
        for (var key in val.keys) {
          val[key] = _wrapFunctionArguments(val[key], engine);
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
