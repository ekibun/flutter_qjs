/*
 * @Description: wrap object
 * @Author: ekibun
 * @Date: 2020-10-02 13:49:03
 * @LastEditors: ekibun
 * @LastEditTime: 2020-10-03 22:21:31
 */
part of '../flutter_qjs.dart';

/// js invokable
abstract class JSInvokable extends JSRef {
  dynamic invoke(List args, [dynamic thisVal]);

  static dynamic _wrap(dynamic func) {
    return func is JSInvokable
        ? func
        : func is Function
            ? _DartFunction(func)
            : func;
  }
}

class _DartFunction extends JSInvokable {
  final Function _func;
  _DartFunction(this._func);

  @override
  invoke(List args, [thisVal]) {
    /// wrap this into function
    final passThis =
        RegExp('{.*thisVal.*}').hasMatch(_func.runtimeType.toString());
    final ret =
        Function.apply(_func, args, passThis ? {#thisVal: thisVal} : null);
    JSRef.freeRecursive(args);
    JSRef.freeRecursive(thisVal);
    return ret;
  }

  @override
  String toString() {
    return _func.toString();
  }

  @override
  destroy() {}
}

/// implement this to capture js object release.

class _DartObject extends JSRef implements JSRefLeakable {
  Object _obj;
  Pointer _ctx;
  _DartObject(this._ctx, this._obj) {
    if (_obj is JSRef) {
      (_obj as JSRef).dup();
    }
    runtimeOpaques[jsGetRuntime(_ctx)]?.addRef(this);
  }

  static _DartObject fromAddress(Pointer rt, int val) {
    return runtimeOpaques[rt]?.getRef((e) => identityHashCode(e) == val);
  }

  @override
  String toString() {
    if (_ctx == null) return "DartObject(released)";
    return _obj.toString();
  }

  @override
  void destroy() {
    if (_ctx == null) return;
    runtimeOpaques[jsGetRuntime(_ctx)]?.removeRef(this);
    _ctx = null;
    if (_obj is JSRef) {
      (_obj as JSRef).free();
    }
    _obj = null;
  }
}

/// JS Error wrapper
class JSError extends _IsolateEncodable {
  String message;
  String stack;
  JSError(message, [stack]) {
    if (message is JSError) {
      this.message = message.message;
      this.stack = message.stack;
    } else {
      this.message = message.toString();
      this.stack = (stack ?? StackTrace.current).toString();
    }
  }

  @override
  String toString() {
    return stack == null ? message.toString() : "$message\n$stack";
  }

  static JSError _decode(Map obj) {
    if (obj.containsKey(#jsError))
      return JSError(obj[#jsError], obj[#jsErrorStack]);
    return null;
  }

  @override
  Map _encode() {
    return {
      #jsError: message,
      #jsErrorStack: stack,
    };
  }
}

/// JS Object reference
/// call [release] to release js object.
class _JSObject extends JSRef {
  Pointer _val;
  Pointer _ctx;

  /// Create
  _JSObject(this._ctx, Pointer _val) {
    Pointer rt = jsGetRuntime(_ctx);
    this._val = jsDupValue(_ctx, _val);
    runtimeOpaques[rt]?.addRef(this);
  }

  @override
  void destroy() {
    if (_val == null) return;
    Pointer rt = jsGetRuntime(_ctx);
    runtimeOpaques[rt]?.removeRef(this);
    jsFreeValue(_ctx, _val);
    _val = null;
    _ctx = null;
  }

  @override
  String toString() {
    if (_val == null) return "JSObject(released)";
    return jsToCString(_ctx, _val);
  }
}

/// JS function wrapper
class _JSFunction extends _JSObject implements JSInvokable, _IsolateEncodable {
  _JSFunction(Pointer ctx, Pointer val) : super(ctx, val);

  @override
  invoke(List<dynamic> arguments, [dynamic thisVal]) {
    Pointer jsRet = _invoke(arguments, thisVal);
    if (jsRet == null) return;
    bool isException = jsIsException(jsRet) != 0;
    if (isException) {
      jsFreeValue(_ctx, jsRet);
      throw _parseJSException(_ctx);
    }
    final ret = _jsToDart(_ctx, jsRet);
    jsFreeValue(_ctx, jsRet);
    return ret;
  }

  Pointer _invoke(List<dynamic> arguments, [dynamic thisVal]) {
    if (_val == null) throw JSError("InternalError: JSValue released");
    List<Pointer> args = arguments
        .map(
          (e) => _dartToJs(_ctx, e),
        )
        .toList();
    Pointer jsThis = _dartToJs(_ctx, thisVal);
    Pointer jsRet = jsCall(_ctx, _val, jsThis, args);
    jsFreeValue(_ctx, jsThis);
    for (Pointer jsArg in args) {
      jsFreeValue(_ctx, jsArg);
    }
    return jsRet;
  }

  @override
  Map _encode() {
    return IsolateFunction._new(this)._encode();
  }
}

/// Dart function wrapper for isolate
class IsolateFunction extends JSInvokable implements _IsolateEncodable {
  int _isolateId;
  SendPort _port;
  JSInvokable _invokable;
  IsolateFunction._fromId(this._isolateId, this._port);

  IsolateFunction._new(this._invokable) {
    _handlers.add(this);
  }
  IsolateFunction(Function func) : this._new(_DartFunction(func));

  static ReceivePort _invokeHandler;
  static Set<IsolateFunction> _handlers = Set();

  static get _handlePort {
    if (_invokeHandler == null) {
      _invokeHandler = ReceivePort();
      _invokeHandler.listen((msg) async {
        final msgPort = msg[#port];
        try {
          final handler = _handlers.firstWhere(
            (v) => identityHashCode(v) == msg[#handler],
            orElse: () => null,
          );
          if (handler == null) throw JSError('handler released');
          final ret = _encodeData(await handler._handle(msg[#msg]));
          if (msgPort != null) msgPort.send(ret);
        } catch (e) {
          final err = _encodeData(e);
          if (msgPort != null)
            msgPort.send({
              #error: err,
            });
        }
      });
    }
    return _invokeHandler.sendPort;
  }

  _send(msg) async {
    if (_port == null) return _handle(msg);
    final evaluatePort = ReceivePort();
    _port.send({
      #handler: _isolateId,
      #msg: msg,
      #port: evaluatePort.sendPort,
    });
    final result = await evaluatePort.first;
    if (result is Map && result.containsKey(#error))
      throw _decodeData(result[#error]);
    return _decodeData(result);
  }

  _destroy() {
    _handlers.remove(this);
    _invokable?.free();
  }

  _handle(msg) async {
    switch (msg) {
      case #dup:
        _refCount++;
        return null;
      case #free:
        _refCount--;
        if (_refCount < 0) _destroy();
        return null;
      case #destroy:
        _destroy();
        return null;
    }
    List args = _decodeData(msg[#args]);
    Map thisVal = _decodeData(msg[#thisVal]);
    return _invokable.invoke(args, thisVal);
  }

  @override
  Future invoke(List positionalArguments, [thisVal]) async {
    List dArgs = _encodeData(positionalArguments);
    Map dThisVal = _encodeData(thisVal);
    return _send({
      #args: dArgs,
      #thisVal: dThisVal,
    });
  }

  static IsolateFunction _decode(Map obj) {
    if (obj.containsKey(#jsFunctionPort))
      return IsolateFunction._fromId(
        obj[#jsFunctionId],
        obj[#jsFunctionPort],
      );
    return null;
  }

  @override
  Map _encode() {
    return {
      #jsFunctionId: _isolateId ?? identityHashCode(this),
      #jsFunctionPort: _port ?? IsolateFunction._handlePort,
    };
  }

  int _refCount = 0;

  @override
  dup() {
    _send(#dup);
  }

  @override
  free() {
    _send(#free);
  }

  @override
  void destroy() {
    _send(#destroy);
  }
}
