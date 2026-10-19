part of '../flutter_qjs.dart';

final log = Logger('flutter_qjs');

/// Handler function to manage js module.
typedef JsModuleHandler = String Function(String name);

/// Handler to manage unhandled promise rejection.
typedef JsHostPromiseRejectionHandler = void Function(dynamic reason);

/// Quickjs engine for flutter.
class FlutterQjs {
  Pointer<JSRuntime>? _rt;
  Pointer<JSContext>? _ctx;

  /// Max stack size for quickjs.
  final int? stackSize;

  /// Max stack size for quickjs.
  final int? timeout;

  /// Max memory for quickjs.
  final int? memoryLimit;

  /// Message Port for event loop; null while the engine is closed.
  ReceivePort? _port;

  /// Handler function to manage js module.
  final JsModuleHandler? moduleHandler;

  /// Handler function to manage js module.
  final JsHostPromiseRejectionHandler? hostPromiseRejectionHandler;

  FlutterQjs({
    this.moduleHandler,
    this.stackSize,
    this.timeout,
    this.memoryLimit,
    this.hostPromiseRejectionHandler,
  });

  void _ensureEngine() async {
    if (_rt != null) return;
    final port = _port ??= ReceivePort();
    final rt = jsNewRuntime((ctx, type, ptr) {
      try {
        switch (type) {
          case JSChannelType.METHON:
            final pdata = ptr.cast<Pointer<JSValue>>();
            final argc = (pdata+1).value.cast<Int32>().value;
            final pargs = [];
            for (var i = 0; i < argc; ++i) {
              pargs.add(_jsToDart(
                ctx,
                Pointer.fromAddress(
                  (pdata+2).value.address + sizeOfJSValue * i,
                ),
              ));
            }
            final JSInvokable func = _jsToDart(
              ctx,
              (pdata+3).value,
            );
            return _dartToJs(
                ctx,
                func.invoke(
                  pargs,
                  _jsToDart(ctx, pdata.value),
                ));
          case JSChannelType.MODULE:
            if (moduleHandler == null) throw JSError('No ModuleHandler');
            final ret = moduleHandler!(
              ptr.cast<Utf8>().toDartString(),
            ).toNativeUtf8();
            Future.microtask(() {
              malloc.free(ret);
            });
            return ret.cast();
          case JSChannelType.PROMISE_TRACK:
            final err = _parseJSException(ctx, ptr);
            if (hostPromiseRejectionHandler != null) {
              hostPromiseRejectionHandler!(err);
            } else {
              log.warning('unhandled promise rejection: $err');
            }
            return nullptr;
          case JSChannelType.FREE_OBJECT:
            final rt = ctx.cast<JSRuntime>();
            _DartObject.fromAddress(rt, ptr.address)?.free();
            return nullptr;
        }
        throw JSError('call channel with wrong type');
      } catch (e) {
        if (type == JSChannelType.FREE_OBJECT) {
          log.warning('DartObject release error: $e');
          return nullptr;
        }
        // Throw onto ctx so JS sees the handler's original error (jsThrow takes the ref).
        final throwObj = _dartToJs(ctx, e);
        final err = jsThrow(ctx, throwObj);
        jsFreeValue(ctx, throwObj);
        if (type == JSChannelType.MODULE) {
          // The handle is one-shot; the pending exception stays on ctx.
          jsFreeValue(ctx, err);
          return nullptr;
        }
        return err;
      }
    }, timeout ?? 0, port);
    final stackSize = this.stackSize ?? 0;
    if (stackSize > 0) jsSetMaxStackSize(rt, stackSize);
    final memoryLimit = this.memoryLimit ?? 0;
    if (memoryLimit > 0) jsSetMemoryLimit(rt, memoryLimit);
    _rt = rt;
    _ctx = jsNewContext(rt);
    // Start the event loop with the engine; it ends when close() closes the port.
    unawaited(() async {
      await for (final _ in port) {
        _executePendingJob();
      }
    }());
  }

  /// Free Runtime and Context which can be recreate when evaluate again.
  dynamic close() {
    // Close the port so the event loop ends; null marks the engine as closed.
    _port?.close();
    _port = null;
    final rt = _rt;
    final ctx = _ctx;
    _rt = null;
    _ctx = null;
    if (ctx != null) jsFreeContext(ctx);
    if (rt == null) return;
    _executePendingJob();
    try {
      jsFreeRuntime(rt);
    } on String catch (e) {
      throw JSError(e);
    }
  }

  void _executePendingJob() {
    final rt = _rt;
    final ctx = _ctx;
    if (rt == null || ctx == null) return;
    while (true) {
      int err = jsExecutePendingJob(rt);
      if (err <= 0) {
        if (err < 0) log.warning(_parseJSException(ctx));
        break;
      }
    }
  }

  /// Evaluate js script.
  dynamic evaluate(
    String command, {
    String? name,
    int? evalFlags,
  }) {
    _ensureEngine();
    final ctx = _ctx!;
    final jsval = jsEval(
      ctx,
      command,
      name ?? '<eval>',
      evalFlags ?? JSEvalFlag.GLOBAL,
    );
    if (jsIsException(jsval) != 0) {
      jsFreeValue(ctx, jsval);
      throw _parseJSException(ctx);
    }
    final result = _jsToDart(ctx, jsval);
    jsFreeValue(ctx, jsval);
    return result;
  }
}
