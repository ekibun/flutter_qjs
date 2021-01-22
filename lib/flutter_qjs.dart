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

/// Handler function to manage js call.
typedef JsMethodHandler = dynamic Function(String method, List args);

/// Handler function to manage js module.
typedef JsModuleHandler = String Function(String name);

/// Handler to manage unhandled promise rejection.
typedef JsHostPromiseRejectionHandler = void Function(String reason);

class FlutterQjs {
  Pointer _rt;
  Pointer _ctx;

  /// Max stack size for quickjs.
  final int stackSize;

  /// Message Port for event loop. Close it to stop dispatching event loop.
  ReceivePort port = ReceivePort();

  /// Handler function to manage js call with `channel(method, [...args])` function.
  JsMethodHandler methodHandler;

  /// Handler function to manage js module.
  JsModuleHandler moduleHandler;

  /// Handler function to manage js module.
  JsHostPromiseRejectionHandler hostPromiseRejectionHandler;

  /// Quickjs engine for flutter.
  ///
  /// Pass handlers to implement js-dart interaction and resolving modules.
  FlutterQjs(
      {this.methodHandler,
      this.moduleHandler,
      this.stackSize,
      this.hostPromiseRejectionHandler});

  _ensureEngine() {
    if (_rt != null) return;
    _rt = jsNewRuntime((ctx, method, argv) {
      try {
        if (method.address == 0) {
          Pointer rt = ctx;
          DartObject obj = DartObject.fromAddress(rt, argv.address);
          obj?.release();
          runtimeOpaques[rt]?.ref?.remove(obj);
          return Pointer.fromAddress(0);
        }
        if (argv.address != 0) {
          if (method.address == ctx.address) {
            final errStr = parseJSException(ctx, perr: argv);
            if (hostPromiseRejectionHandler != null) {
              hostPromiseRejectionHandler(errStr);
            } else {
              print("unhandled promise rejection: $errStr");
            }
            return Pointer.fromAddress(0);
          }
          if (methodHandler == null) throw Exception("No MethodHandler");
          return dartToJs(
              ctx,
              methodHandler(
                Utf8.fromUtf8(method.cast<Utf8>()),
                jsToDart(ctx, argv),
              ));
        }
        if (moduleHandler == null) throw Exception("No ModuleHandler");
        var ret =
            Utf8.toUtf8(moduleHandler(Utf8.fromUtf8(method.cast<Utf8>())));
        Future.microtask(() {
          free(ret);
        });
        return ret;
      } catch (e, stack) {
        final errStr = e.toString() + "\n" + stack.toString();
        if (method.address == 0) {
          print("DartObject release error: " + errStr);
          return Pointer.fromAddress(0);
        }
        if (method.address == ctx.address) {
          print("host Promise Rejection Handler error: " + errStr);
          return Pointer.fromAddress(0);
        }
        var err = jsThrowInternalError(
          ctx,
          errStr,
        );
        if (argv.address == 0) {
          jsFreeValue(ctx, err);
          return Pointer.fromAddress(0);
        }
        return err;
      }
    }, port);
    if (this.stackSize != null && this.stackSize > 0)
      jsSetMaxStackSize(_rt, this.stackSize);
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

  /// Dispatch JavaScript Event loop.
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
