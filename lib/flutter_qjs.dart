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

import 'isolate.dart';

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

  /// Handler function to manage js module.
  JsModuleHandler moduleHandler;

  /// Handler function to manage js module.
  JsHostPromiseRejectionHandler hostPromiseRejectionHandler;

  /// Quickjs engine for flutter.
  ///
  /// Pass handlers to implement js-dart interaction and resolving modules.
  FlutterQjs({
    this.moduleHandler,
    this.stackSize,
    this.hostPromiseRejectionHandler,
  });

  static applyFunction(Function func, List args, dynamic thisVal) {
    final passThis =
        RegExp("{.*thisVal.*}").hasMatch(func.runtimeType.toString());
    return Function.apply(func, args, passThis ? {#thisVal: thisVal} : null);
  }

  _ensureEngine() {
    if (_rt != null) return;
    _rt = jsNewRuntime((ctx, type, ptr) {
      try {
        switch (type) {
          case JSChannelType.METHON:
            final pdata = ptr.cast<Pointer>();
            final argc = pdata.elementAt(1).value.cast<Int32>().value;
            List args = [];
            for (var i = 0; i < argc; i++) {
              args.add(jsToDart(
                  ctx,
                  Pointer.fromAddress(
                    pdata.elementAt(2).value.address + sizeOfJSValue * i,
                  )));
            }
            final thisVal = jsToDart(ctx, pdata.elementAt(0).value);
            final func = jsToDart(ctx, pdata.elementAt(3).value);
            final ret = func is QjsInvokable
                ? func.invoke(args, thisVal)
                : applyFunction(func, args, thisVal);
            return dartToJs(ctx, ret);
          case JSChannelType.MODULE:
            if (moduleHandler == null) throw Exception("No ModuleHandler");
            var ret = Utf8.toUtf8(moduleHandler(
              Utf8.fromUtf8(ptr.cast<Utf8>()),
            ));
            Future.microtask(() {
              free(ret);
            });
            return ret;
          case JSChannelType.PROMISE_TRACK:
            final errStr = parseJSException(ctx, perr: ptr);
            if (hostPromiseRejectionHandler != null) {
              hostPromiseRejectionHandler(errStr);
            } else {
              print("unhandled promise rejection: $errStr");
            }
            return Pointer.fromAddress(0);
          case JSChannelType.FREE_OBJECT:
            Pointer rt = ctx;
            DartObject obj = DartObject.fromAddress(rt, ptr.address);
            obj?.release();
            runtimeOpaques[rt]?.ref?.remove(obj);
            return Pointer.fromAddress(0);
        }
        throw Exception("call channel with wrong type");
      } catch (e, stack) {
        final errStr = e.toString() + "\n" + stack.toString();
        if (type == JSChannelType.FREE_OBJECT) {
          print("DartObject release error: " + errStr);
          return Pointer.fromAddress(0);
        }
        if (type == JSChannelType.MODULE) {
          print("host Promise Rejection Handler error: " + errStr);
          return Pointer.fromAddress(0);
        }
        var err = jsThrowInternalError(
          ctx,
          errStr,
        );
        if (type == JSChannelType.MODULE) {
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
