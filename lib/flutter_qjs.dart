/*
 * @Description: quickjs engine
 * @Author: ekibun
 * @Date: 2020-08-08 08:29:09
 * @LastEditors: ekibun
 * @LastEditTime: 2020-09-21 01:36:30
 */
import 'dart:async';
import 'dart:ffi';
import 'dart:isolate';

import 'package:ffi/ffi.dart';
import 'package:flutter_qjs/ffi.dart';
import 'package:flutter_qjs/wrapper.dart';

/// Handle function to manage js call with `dart(method, ...args)` function.
typedef JsMethodHandler = dynamic Function(String method, List args);

/// Handle function to manage js module.
typedef JsModuleHandler = String Function(String name);

class FlutterQjs {
  Pointer _rt;
  Pointer _ctx;
  ReceivePort port = ReceivePort();
  JsMethodHandler methodHandler;
  JsModuleHandler moduleHandler;

  _ensureEngine() {
    if (_rt != null) return;
    _rt = jsNewRuntime((ctx, method, argv) {
      if (method.address != 0) {
        var argvs = jsToDart(ctx, argv);
        if (methodHandler == null) throw Exception("No MethodHandler");
        return dartToJs(ctx, methodHandler(Utf8.fromUtf8(method.cast<Utf8>()), argvs));
      }
      if (moduleHandler == null) throw Exception("No ModuleHandler");
      var ret = Utf8.toUtf8(moduleHandler(Utf8.fromUtf8(argv.cast<Utf8>())));
      Future.microtask(() {
        free(ret);
      });
      return ret;
    }, port);
    _ctx = jsNewContextWithPromsieWrapper(_rt);
  }

  /// Set a handler to manage js call with `dart(method, ...args)` function.
  setMethodHandler(JsMethodHandler handler) {
    methodHandler = handler;
  }

  /// Set a handler to manage js module.
  setModuleHandler(JsModuleHandler handler) {
    moduleHandler = handler;
  }

  /// Free Runtime and Context which can be recreate when evaluate again.
  recreate() {
    if (_rt != null) {
      jsFreeContext(_ctx);
      jsFreeRuntime(_rt);
    }
    _rt = null;
    _ctx = null;
  }

  /// Close ReceivePort.
  close() {
    if (port != null) {
      port.close();
      recreate();
    }
    port = null;
  }

  /// DispatchMessage
  Future<void> dispatch() async {
    await for (var _ in port) {
      while (true) {
        int err = jsExecutePendingJob(_rt);
        if (err <= 0) {
          if (err < 0) print(parseJSException(_ctx));
          break;
        }
      }
      List jsPromises = runtimeOpaques[_rt].ref.where((v) => v is JSPromise).toList();
      for (JSPromise jsPromise in jsPromises) {
        if (jsPromise.checkResolveReject()) {
          jsPromise.release();
          runtimeOpaques[_rt].ref.remove(jsPromise);
        }
      }
    }
  }

  /// Evaluate js script.
  Future<dynamic> evaluate(String command, String name) async {
    _ensureEngine();
    var jsval = jsEval(_ctx, command, name, JSEvalType.GLOBAL);
    if (jsIsException(jsval) != 0) {
      throw Exception(parseJSException(_ctx));
    }
    var ret = runtimeOpaques[_rt]?.promsieToFuture(jsval);
    jsFreeValue(_ctx, jsval);
    deleteJSValue(jsval);
    return ret;
  }
}
