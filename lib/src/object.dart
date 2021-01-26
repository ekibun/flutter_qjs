/*
 * @Description: wrap object
 * @Author: ekibun
 * @Date: 2020-10-02 13:49:03
 * @LastEditors: ekibun
 * @LastEditTime: 2020-10-03 22:21:31
 */
part of '../flutter_qjs.dart';

/// js invokable
abstract class JSInvokable extends JSReleasable {
  dynamic invoke(List args, [dynamic thisVal]);

  static dynamic _wrap(dynamic func) {
    return func is JSInvokable
        ? func
        : func is Function
            ? _DartFunction(func)
            : func;
  }

  @override
  noSuchMethod(Invocation invocation) {
    return invoke(
      invocation.positionalArguments,
      invocation.namedArguments[#thisVal],
    );
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
    return Function.apply(_func, args, passThis ? {#thisVal: thisVal} : null);
  }

  @override
  String toString() {
    return _func.toString();
  }

  @override
  release() {}
}

/// implement this to capture js object release.
abstract class JSReleasable {
  void release();
}

class _DartObject extends JSRef {
  @override
  bool leakable = true;

  Object _obj;
  Pointer _ctx;
  _DartObject(this._ctx, this._obj) {
    runtimeOpaques[jsGetRuntime(_ctx)]?.addRef(this);
  }

  static _DartObject fromAddress(Pointer rt, int val) {
    return runtimeOpaques[rt]?.getRef((e) => identityHashCode(e) == val);
  }

  @override
  String toString() {
    if (_ctx == null) return "DartObject(<released>)";
    return _obj.toString();
  }

  @override
  void release() {
    if (_ctx == null) return;
    runtimeOpaques[jsGetRuntime(_ctx)]?.removeRef(this);
    _ctx = null;
    if (_obj is JSReleasable) {
      (_obj as JSReleasable).release();
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

  static JSError _decode(Map obj, SendPort port) {
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

  static _JSObject fromAddress(Pointer ctx, Pointer val) {
    Pointer rt = jsGetRuntime(ctx);
    return runtimeOpaques[rt]?.getRef((e) =>
        e is _JSObject &&
        e._val.address == val.address &&
        e._ctx.address == ctx.address);
  }

  @override
  void release() {
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

  static _JSFunction fromAddress(Pointer ctx, Pointer val) {
    return _JSObject.fromAddress(ctx, val);
  }

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

  static _JSFunction _decode(Map obj, SendPort port) {
    if (obj.containsKey(#jsFunction) && port == null)
      return _JSFunction.fromAddress(
        Pointer.fromAddress(obj[#jsFunctionCtx]),
        Pointer.fromAddress(obj[#jsFunction]),
      );
    return null;
  }

  @override
  Map _encode() {
    return {
      #jsFunction: _val.address,
      #jsFunctionCtx: _ctx.address,
    };
  }

  @override
  noSuchMethod(Invocation invocation) {
    return invoke(
      invocation.positionalArguments,
      invocation.namedArguments[#thisVal],
    );
  }
}

/// JS function wrapper for isolate
class _IsolateJSFunction extends JSInvokable implements _IsolateEncodable {
  int _val;
  int _ctx;
  SendPort _port;
  _IsolateJSFunction(this._ctx, this._val, this._port);

  @override
  Future invoke(List arguments, [thisVal]) async {
    if (0 == _val ?? 0) return;
    final evaluatePort = ReceivePort();
    _port.send({
      #type: #call,
      #ctx: _ctx,
      #val: _val,
      #args: _encodeData(arguments),
      #thisVal: _encodeData(thisVal),
      #port: evaluatePort.sendPort,
    });
    final result = await evaluatePort.first;
    evaluatePort.close();
    if (result is Map && result.containsKey(#error))
      throw _decodeData(result[#error], _port);
    return _decodeData(result, _port);
  }

  static _IsolateJSFunction _decode(Map obj, SendPort port) {
    if (obj.containsKey(#jsFunction) && port != null)
      return _IsolateJSFunction(obj[#jsFunctionCtx], obj[#jsFunction], port);
    return null;
  }

  @override
  Map _encode() {
    return {
      #jsFunction: _val,
      #jsFunctionCtx: _ctx,
    };
  }

  @override
  void release() {
    if (_port == null) return;
    _port.send({
      #type: #closeFunction,
      #ctx: _ctx,
      #val: _val,
    });
    _port = null;
    _val = null;
    _ctx = null;
  }
}

/// Dart function wrapper for isolate
class _IsolateFunction extends JSInvokable
    implements JSReleasable, _IsolateEncodable {
  SendPort _port;
  SendPort _func;
  _IsolateFunction(this._func, this._port);

  static _IsolateFunction _bind(Function func, SendPort port) {
    final JSInvokable invokable = JSInvokable._wrap(func);
    final funcPort = ReceivePort();
    funcPort.listen((msg) async {
      if (msg == #close) return funcPort.close();
      SendPort msgPort = msg[#port];
      try {
        List args = _decodeData(msg[#args], port);
        Map thisVal = _decodeData(msg[#thisVal], port);
        final data = await invokable.invoke(args, thisVal);
        if (msgPort != null) msgPort.send(_encodeData(data));
      } catch (e) {
        if (msgPort != null)
          msgPort.send({
            #error: _encodeData(e),
          });
      }
    });
    return _IsolateFunction(funcPort.sendPort, port);
  }

  @override
  Future invoke(List positionalArguments, [thisVal]) async {
    if (_func == null) return;
    final evaluatePort = ReceivePort();
    _func.send({
      #args: _encodeData(positionalArguments),
      #thisVal: _encodeData(thisVal),
      #port: evaluatePort.sendPort,
    });
    final result = await evaluatePort.first;
    evaluatePort.close();
    if (result is Map && result.containsKey(#error))
      throw _decodeData(result[#error], _port);
    return _decodeData(result, _port);
  }

  static _IsolateFunction _decode(Map obj, SendPort port) {
    if (obj.containsKey(#jsFunctionPort))
      return _IsolateFunction(obj[#jsFunctionPort], port);
    return null;
  }

  @override
  Map _encode() {
    return {
      #jsFunctionPort: _func,
    };
  }

  @override
  void release() {
    if (_func == null) return;
    _func.send(#close);
    _func = null;
  }
}
