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

  void _freeRecursive(dynamic obj, [Set cache]) {
    if (obj == null) return;
    if (cache == null) cache = Set();
    if (cache.contains(obj)) return;
    if (obj is List) {
      cache.add(obj);
      obj.forEach((e) => _freeRecursive(e, cache));
    }
    if (obj is Map) {
      cache.add(obj);
      obj.values.forEach((e) => _freeRecursive(e, cache));
    }
    if (obj is JSRef) {
      obj.free();
    }
  }

  @override
  invoke(List args, [thisVal]) {
    /// wrap this into function
    final passThis =
        RegExp('{.*thisVal.*}').hasMatch(_func.runtimeType.toString());
    final ret =
        Function.apply(_func, args, passThis ? {#thisVal: thisVal} : null);
    _freeRecursive(args);
    _freeRecursive(thisVal);
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
    if (_val == null) return null;
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
    final func = IsolateFunction._new(this);
    final ret = func._encode();
    return ret;
  }
}

abstract class _IsolatePortHandler {
  int _isolateId;
  dynamic _handle(dynamic);
}

class _IsolatePort {
  static ReceivePort _invokeHandler;
  static Set<_IsolatePortHandler> _handlers = Set();

  static get _port {
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

  static _send(SendPort isolate, _IsolatePortHandler handler, msg) async {
    if (isolate == null) return handler._handle(msg);
    final evaluatePort = ReceivePort();
    isolate.send({
      #handler: handler._isolateId,
      #msg: msg,
      #port: evaluatePort.sendPort,
    });
    final result = await evaluatePort.first;
    if (result is Map && result.containsKey(#error))
      throw _decodeData(result[#error]);
    return _decodeData(result);
  }

  static _add(_IsolatePortHandler sendport) => _handlers.add(sendport);
  static _remove(_IsolatePortHandler sendport) => _handlers.remove(sendport);
}

/// Dart function wrapper for isolate
class IsolateFunction extends JSInvokable
    implements _IsolateEncodable, _IsolatePortHandler {
  @override
  int _isolateId;
  SendPort _port;
  JSInvokable _invokable;
  IsolateFunction._fromId(this._isolateId, this._port);

  IsolateFunction._new(this._invokable) {
    _IsolatePort._add(this);
  }

  static IsolateFunction func(Function func) {
    return IsolateFunction._new(_DartFunction(func));
  }

  _destroy() {
    _IsolatePort._remove(this);
    _invokable?.free();
  }

  @override
  _handle(msg) async {
    switch (msg) {
      case #dup:
        _refCount++;
        return null;
      case #free:
        _refCount--;
        print("${identityHashCode(this)} ref $_refCount");
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
    return _IsolatePort._send(_port, this, {
      #type: #invokeIsolate,
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
      #jsFunctionPort: _port ?? _IsolatePort._port,
    };
  }

  int _refCount = 0;

  @override
  dup() {
    _IsolatePort._send(_port, this, #dup);
  }

  @override
  free() {
    _IsolatePort._send(_port, this, #free);
  }

  @override
  void destroy() {
    _IsolatePort._send(_port, this, #destroy);
  }
}
