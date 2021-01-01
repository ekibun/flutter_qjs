/*
 * @Description: quickjs engine
 * @Author: ekibun
 * @Date: 2020-08-08 08:29:09
 * @LastEditors: ekibun
 * @LastEditTime: 2020-10-06 23:47:13
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

  /// Set a handler to manage js call with `channel(method, args)` function.
  JsMethodHandler methodHandler;

  /// Set a handler to manage js module.
  JsModuleHandler moduleHandler;

  FlutterQjs({this.methodHandler, this.moduleHandler});

  _ensureEngine() {
    if (_rt != null) return;
    _rt = jsNewRuntime((ctx, method, argv) {
      try {
        if (method.address != 0) {
          if (methodHandler == null) throw Exception("No MethodHandler");
          var argvs = jsToDart(ctx, argv);
          return dartToJs(
              ctx,
              methodHandler(
                Utf8.fromUtf8(method.cast<Utf8>()),
                argvs,
              ));
        }
        if (moduleHandler == null) throw Exception("No ModuleHandler");
        var ret = Utf8.toUtf8(moduleHandler(Utf8.fromUtf8(argv.cast<Utf8>())));
        Future.microtask(() {
          free(ret);
        });
        return ret;
      } catch (e, stack) {
        var err = jsThrowInternalError(
          ctx,
          e.toString() + "\n" + stack.toString(),
        );
        if (method.address == 0) {
          jsFreeValue(ctx, err);
          return Pointer.fromAddress(0);
        }
        return err;
      }
    }, port);
    _ctx = jsNewContextWithPromsieWrapper(_rt);
  }

  /// Free Runtime and Context which can be recreate when evaluate again.
  close() {
    if (_rt != null) {
      jsFreeContext(_ctx);
      jsFreeRuntime(_rt);
    }
    _rt = null;
    _ctx = null;
  }

  /// DispatchMessage
  Future<void> dispatch() async {
    await for (var _ in port) {
      if (_rt == null) continue;
      while (true) {
        int err = jsExecutePendingJob(_rt);
        if (err <= 0) {
          if (err < 0) print(parseJSException(_ctx));
          break;
        }
      }
      List jsPromises = runtimeOpaques[_rt]
          .ref
          .where(
            (v) => v is JSPromise,
          )
          .toList();
      for (JSPromise jsPromise in jsPromises) {
        if (jsPromise.checkResolveReject()) {
          jsPromise.release();
          runtimeOpaques[_rt].ref.remove(jsPromise);
        }
      }
    }
  }

  /// Evaluate js script.
  dynamic evaluate(String command, {String name, int evalFlags}) {
    _ensureEngine();
    var jsval = jsEval(
      _ctx,
      command,
      name ?? "<eval>",
      evalFlags ?? JSEvalFlag.GLOBAL,
    );
    if (jsIsException(jsval) != 0) {
      jsFreeValue(_ctx, jsval);
      throw Exception(parseJSException(_ctx));
    }
    var result = jsToDart(_ctx, jsval);
    jsFreeValue(_ctx, jsval);
    return result;
  }
}
