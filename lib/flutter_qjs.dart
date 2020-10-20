/*
 * @Description: 
 * @Author: ekibun
 * @Date: 2020-10-14 19:35:56
 * @LastEditors: ekibun
 * @LastEditTime: 2020-10-20 23:57:46
 */
import 'dart:async';
import 'dart:isolate';

import 'wasm.dart' if(dart.library.ffi) 'ffi.dart';
import 'define.dart';
import 'wrapper.dart';

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
      try {
        if (method.address != 0) {
          if (methodHandler == null) throw Exception("No MethodHandler");
          var argvs = jsToDart(ctx, argv);
          return dartToJs(
              ctx,
              methodHandler(
                pointerToString(method),
                argvs,
              ));
        }
        if (moduleHandler == null) throw Exception("No ModuleHandler");
        var ret = stringToPointer(moduleHandler(pointerToString(argv)));
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

  /// Set a handler to manage js call with `channel(method, args)` function.
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
  Future<dynamic> evaluate(String command, {String name, int evalFlags}) async {
    _ensureEngine();
    var jsval =
        jsEval(_ctx, command, name ?? "<eval>", evalFlags ?? JSEvalType.GLOBAL);
    if (jsIsException(jsval) != 0) {
      jsFreeValue(_ctx, jsval);
      throw Exception(parseJSException(_ctx));
    }
    var ret = runtimeOpaques[_rt]?.promsieToFuture(jsval);
    jsFreeValue(_ctx, jsval);
    return ret;
  }
}
