/*
 * @Description: quickjs engine
 * @Author: ekibun
 * @Date: 2020-08-08 08:29:09
 * @LastEditors: ekibun
 * @LastEditTime: 2020-09-06 13:03:56
 */
import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';

/// Handle function to manage js call with `dart(method, ...args)` function.
typedef JsMethodHandler = Future<dynamic> Function(String method, List args);

/// Handle function to manage js module.
typedef JsModuleHandler = Future<String> Function(String name);

/// return this in [JsMethodHandler] to mark method not implemented.
class JsMethodHandlerNotImplement {}

/// FlutterJs instance.
/// Each [FlutterQjs] object creates a new thread that runs a simple js loop.
/// Make sure call `destroy` to terminate thread and release memory when you don't need it.
class FlutterQjs {
  dynamic _engine;
  dynamic get pointer => _engine;

  _ensureEngine() async {
    if (_engine == null) {
      _engine = await _FlutterJs.instance._channel.invokeMethod("createEngine");
    }
  }

  /// Set a handler to manage js call with `dart(method, ...args)` function.
  setMethodHandler(JsMethodHandler handler) async {
    if (handler == null)
      return _FlutterJs.instance._methodHandlers.remove(_engine);
    await _ensureEngine();
    _FlutterJs.instance._methodHandlers[_engine] = handler;
  }

  /// Set a handler to manage js module.
  setModuleHandler(JsModuleHandler handler) async {
    if (handler == null)
      return _FlutterJs.instance._moduleHandlers.remove(_engine);
    await _ensureEngine();
    _FlutterJs.instance._moduleHandlers[_engine] = handler;
  }

  /// Terminate thread and release memory.
  destroy() async {
    if (_engine != null) {
      await setMethodHandler(null);
      await setModuleHandler(null);
      var engine = _engine;
      _engine = null;
      await _FlutterJs.instance._channel.invokeMethod("close", engine);
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
  Map<dynamic, JsMethodHandler> _methodHandlers =
      Map<dynamic, JsMethodHandler>();
  Map<dynamic, JsModuleHandler> _moduleHandlers =
      Map<dynamic, JsModuleHandler>();
  _FlutterJs._internal() {
    _channel.setMethodCallHandler((call) async {
      var engine = call.arguments["engine"];
      var args = call.arguments["args"];
      if (args is List) {
        if (_methodHandlers[engine] == null) return call.noSuchMethod(null);
        var ret = await _methodHandlers[engine](
            call.method, _wrapFunctionArguments(args, engine));
        if (ret is JsMethodHandlerNotImplement) return call.noSuchMethod(null);
        return ret;
      } else {
        if (_moduleHandlers[engine] == null) return call.noSuchMethod(null);
        var ret = await _moduleHandlers[engine](args);
        if (ret is JsMethodHandlerNotImplement) return call.noSuchMethod(null);
        return ret;
      }
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
            "arguments": args,
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
