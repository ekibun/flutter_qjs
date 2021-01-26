/*
 * @Description: quickjs engine
 * @Author: ekibun
 * @Date: 2020-08-08 08:29:09
 * @LastEditors: ekibun
 * @LastEditTime: 2020-10-06 23:47:13
 */
part of '../flutter_qjs.dart';

/// Handler function to manage js module.
typedef _JsModuleHandler = String Function(String name);

/// Handler to manage unhandled promise rejection.
typedef _JsHostPromiseRejectionHandler = void Function(dynamic reason);

/// Quickjs engine for flutter.
class FlutterQjs {
  Pointer _rt;
  Pointer _ctx;

  /// Max stack size for quickjs.
  final int stackSize;

  /// Message Port for event loop. Close it to stop dispatching event loop.
  ReceivePort port = ReceivePort();

  /// Handler function to manage js module.
  _JsModuleHandler moduleHandler;

  /// Handler function to manage js module.
  _JsHostPromiseRejectionHandler hostPromiseRejectionHandler;

  FlutterQjs({
    this.moduleHandler,
    this.stackSize,
    this.hostPromiseRejectionHandler,
  });

  _ensureEngine() {
    if (_rt != null) return;
    _rt = jsNewRuntime((ctx, type, ptr) {
      try {
        switch (type) {
          case JSChannelType.METHON:
            final pdata = ptr.cast<Pointer>();
            final argc = pdata.elementAt(1).value.cast<Int32>().value;
            List pargs = [];
            for (int i = 0; i < argc; ++i) {
              pargs.add(_jsToDart(
                ctx,
                Pointer.fromAddress(
                  pdata.elementAt(2).value.address + sizeOfJSValue * i,
                ),
              ));
            }
            JSInvokable func = _jsToDart(ctx, pdata.elementAt(3).value);
            return _dartToJs(
                ctx,
                func.invoke(
                  pargs,
                  _jsToDart(ctx, pdata.elementAt(0).value),
                ));
          case JSChannelType.MODULE:
            if (moduleHandler == null) throw JSError('No ModuleHandler');
            final ret = Utf8.toUtf8(moduleHandler(
              Utf8.fromUtf8(ptr.cast<Utf8>()),
            ));
            Future.microtask(() {
              free(ret);
            });
            return ret;
          case JSChannelType.PROMISE_TRACK:
            final err = _parseJSException(ctx, ptr);
            if (hostPromiseRejectionHandler != null) {
              hostPromiseRejectionHandler(err);
            } else {
              print('unhandled promise rejection: $err');
            }
            return Pointer.fromAddress(0);
          case JSChannelType.FREE_OBJECT:
            Pointer rt = ctx;
            _DartObject obj = _DartObject.fromAddress(rt, ptr.address);
            obj?.release();
            return Pointer.fromAddress(0);
        }
        throw JSError('call channel with wrong type');
      } catch (e) {
        if (type == JSChannelType.FREE_OBJECT) {
          print('DartObject release error: $e');
          return Pointer.fromAddress(0);
        }
        if (type == JSChannelType.MODULE) {
          print('host Promise Rejection Handler error: $e');
          return Pointer.fromAddress(0);
        }
        final throwObj = _dartToJs(ctx, e);
        final err = jsThrow(ctx, throwObj);
        jsFreeValue(ctx, throwObj);
        if (type == JSChannelType.MODULE) {
          jsFreeValue(ctx, err);
          return Pointer.fromAddress(0);
        }
        return err;
      }
    }, port);
    if (this.stackSize != null && this.stackSize > 0)
      jsSetMaxStackSize(_rt, this.stackSize);
    _ctx = jsNewContext(_rt);
  }

  /// Free Runtime and Context which can be recreate when evaluate again.
  close() {
    if (_rt == null) return;
    final rt = _rt;
    final ctx = _ctx;
    _executePendingJob();
    _rt = null;
    _ctx = null;
    jsFreeContext(ctx);
    try {
      jsFreeRuntime(rt);
    } on String catch (e) {
      throw JSError(e);
    }
  }

  void _executePendingJob() {
    if (_rt == null) return;
    while (true) {
      int err = jsExecutePendingJob(_rt);
      if (err <= 0) {
        if (err < 0) print(_parseJSException(_ctx));
        break;
      }
    }
  }

  /// Dispatch JavaScript Event loop.
  Future<void> dispatch() async {
    await for (final _ in port) {
      _executePendingJob();
    }
  }

  /// Evaluate js script.
  dynamic evaluate(String command, {String name, int evalFlags}) {
    _ensureEngine();
    final jsval = jsEval(
      _ctx,
      command,
      name ?? '<eval>',
      evalFlags ?? JSEvalFlag.GLOBAL,
    );
    if (jsIsException(jsval) != 0) {
      jsFreeValue(_ctx, jsval);
      throw _parseJSException(_ctx);
    }
    final result = _jsToDart(_ctx, jsval);
    jsFreeValue(_ctx, jsval);
    return result;
  }
}
