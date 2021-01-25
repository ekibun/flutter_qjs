/*
 * @Description: 
 * @Author: ekibun
 * @Date: 2020-09-19 22:07:47
 * @LastEditors: ekibun
 * @LastEditTime: 2020-12-02 11:14:03
 */
import 'dart:async';
import 'dart:ffi';
import 'dart:isolate';
import 'dart:typed_data';
import 'package:ffi/ffi.dart';
import 'ffi.dart';

abstract class JSInvokable {
  dynamic invoke(List args, [dynamic thisVal]);

  static dynamic wrap(dynamic func) {
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

class NativeJSInvokable extends JSInvokable {
  dynamic Function(Pointer ctx, Pointer thisVal, List<Pointer> args) _func;
  NativeJSInvokable(this._func);

  @override
  dynamic invoke(List args, [dynamic thisVal]) {
    throw UnimplementedError('use invokeNative instead.');
  }

  invokeNative(Pointer ctx, Pointer thisVal, List<Pointer> args) {
    _func(ctx, thisVal, args);
  }
}

class _DartFunction extends JSInvokable {
  Function _func;
  _DartFunction(this._func);

  @override
  invoke(List args, [thisVal]) {
    /// wrap this into function
    final passThis =
        RegExp('{.*thisVal.*}').hasMatch(_func.runtimeType.toString());
    return Function.apply(_func, args, passThis ? {#thisVal: thisVal} : null);
  }
}

abstract class DartReleasable {
  void release();
}

class DartObject implements JSRef {
  Object _obj;
  Pointer _ctx;
  DartObject(this._ctx, this._obj) {
    runtimeOpaques[jsGetRuntime(_ctx)]?.ref?.add(this);
  }

  static DartObject fromAddress(Pointer rt, int val) {
    return runtimeOpaques[rt]?.ref?.firstWhere(
          (e) => identityHashCode(e) == val,
          orElse: () => null,
        );
  }

  @override
  void release() {
    if (_obj is DartReleasable) {
      (_obj as DartReleasable).release();
    }
    _obj = null;
    _ctx = null;
  }
}

class JSObject implements JSRef {
  Pointer _val;
  Pointer _ctx;

  /// Create
  JSObject(this._ctx, Pointer _val) {
    Pointer rt = jsGetRuntime(_ctx);
    this._val = jsDupValue(_ctx, _val);
    runtimeOpaques[rt]?.ref?.add(this);
  }

  JSObject.fromAddress(Pointer ctx, Pointer val) {
    this._ctx = ctx;
    this._val = val;
  }

  @override
  void release() {
    if (_val != null) {
      jsFreeValue(_ctx, _val);
    }
    _val = null;
    _ctx = null;
  }
}

class JSFunction extends JSObject implements JSInvokable {
  JSFunction(Pointer ctx, Pointer val) : super(ctx, val);

  JSFunction.fromAddress(Pointer ctx, Pointer val)
      : super.fromAddress(ctx, val);

  @override
  invoke(List<dynamic> arguments, [dynamic thisVal]) {
    Pointer jsRet = _invoke(arguments, thisVal);
    if (jsRet == null) return;
    bool isException = jsIsException(jsRet) != 0;
    if (isException) {
      jsFreeValue(_ctx, jsRet);
      throw parseJSException(_ctx);
    }
    var ret = jsToDart(_ctx, jsRet);
    jsFreeValue(_ctx, jsRet);
    return ret;
  }

  Pointer _invoke(List<dynamic> arguments, [dynamic thisVal]) {
    if (_val == null) return null;
    List<Pointer> args = arguments
        .map(
          (e) => dartToJs(_ctx, e),
        )
        .toList();
    Pointer jsThis = dartToJs(_ctx, thisVal);
    Pointer jsRet = jsCall(_ctx, _val, jsThis, args);
    jsFreeValue(_ctx, jsThis);
    for (Pointer jsArg in args) {
      jsFreeValue(_ctx, jsArg);
    }
    return jsRet;
  }

  @override
  noSuchMethod(Invocation invocation) {
    return invoke(
      invocation.positionalArguments,
      invocation.namedArguments[#thisVal],
    );
  }
}

class IsolateJSFunction extends JSInvokable {
  int _val;
  int _ctx;
  SendPort port;
  IsolateJSFunction(this._ctx, this._val, this.port);

  @override
  Future invoke(List arguments, [thisVal]) async {
    if (0 == _val ?? 0) return;
    var evaluatePort = ReceivePort();
    port.send({
      'type': 'call',
      'ctx': _ctx,
      'val': _val,
      'args': encodeData(arguments),
      'this': encodeData(thisVal),
      'port': evaluatePort.sendPort,
    });
    Map result = await evaluatePort.first;
    evaluatePort.close();
    if (result.containsKey('data'))
      return decodeData(result['data'], port);
    else
      throw result['error'];
  }
}

class IsolateFunction extends JSInvokable implements DartReleasable {
  SendPort _port;
  SendPort func;
  IsolateFunction(this.func, this._port);

  static IsolateFunction bind(Function func, SendPort port) {
    final JSInvokable invokable = JSInvokable.wrap(func);
    final funcPort = ReceivePort();
    funcPort.listen((msg) async {
      if (msg == 'close') return funcPort.close();
      var data;
      SendPort msgPort = msg['port'];
      try {
        List args = decodeData(msg['args'], port);
        Map thisVal = decodeData(msg['this'], port);
        data = await invokable.invoke(args, thisVal);
        if (msgPort != null)
          msgPort.send({
            'data': encodeData(data),
          });
      } catch (e, stack) {
        if (msgPort != null)
          msgPort.send({
            'error': e.toString() + '\n' + stack.toString(),
          });
      }
    });
    return IsolateFunction(funcPort.sendPort, port);
  }

  @override
  Future invoke(List positionalArguments, [thisVal]) async {
    if (func == null) return;
    var evaluatePort = ReceivePort();
    func.send({
      'args': encodeData(positionalArguments),
      'this': encodeData(thisVal),
      'port': evaluatePort.sendPort,
    });
    Map result = await evaluatePort.first;
    evaluatePort.close();
    if (result.containsKey('data'))
      return decodeData(result['data'], _port);
    else
      throw result['error'];
  }

  @override
  void release() {
    if (func == null) return;
    func.send('close');
    func = null;
  }
}

dynamic encodeData(dynamic data, {Map<dynamic, dynamic> cache}) {
  if (cache == null) cache = Map();
  if (cache.containsKey(data)) return cache[data];
  if (data is List) {
    var ret = [];
    cache[data] = ret;
    for (int i = 0; i < data.length; ++i) {
      ret.add(encodeData(data[i], cache: cache));
    }
    return ret;
  }
  if (data is Map) {
    var ret = {};
    cache[data] = ret;
    for (var entry in data.entries) {
      ret[encodeData(entry.key, cache: cache)] =
          encodeData(entry.value, cache: cache);
    }
    return ret;
  }
  if (data is JSObject) {
    return {
      '__js_function': data is JSFunction,
      '__js_obj_ctx': data._ctx.address,
      '__js_obj_val': data._val.address,
    };
  }
  if (data is IsolateJSFunction) {
    return {
      '__js_obj_ctx': data._ctx,
      '__js_obj_val': data._val,
    };
  }
  if (data is IsolateFunction) {
    return {
      '__js_function_port': data.func,
    };
  }
  if (data is Future) {
    var futurePort = ReceivePort();
    data.then((value) {
      futurePort.first.then((port) {
        futurePort.close();
        (port as SendPort).send({'data': encodeData(value)});
      });
    }, onError: (e, stack) {
      futurePort.first.then((port) {
        futurePort.close();
        (port as SendPort)
            .send({'error': e.toString() + '\n' + stack.toString()});
      });
    });
    return {
      '__js_future_port': futurePort.sendPort,
    };
  }
  return data;
}

dynamic decodeData(dynamic data, SendPort port, {Map<dynamic, dynamic> cache}) {
  if (cache == null) cache = Map();
  if (cache.containsKey(data)) return cache[data];
  if (data is List) {
    var ret = [];
    cache[data] = ret;
    for (int i = 0; i < data.length; ++i) {
      ret.add(decodeData(data[i], port, cache: cache));
    }
    return ret;
  }
  if (data is Map) {
    if (data.containsKey('__js_obj_val')) {
      int ctx = data['__js_obj_ctx'];
      int val = data['__js_obj_val'];
      if (data['__js_function'] == false) {
        return JSObject.fromAddress(
          Pointer.fromAddress(ctx),
          Pointer.fromAddress(val),
        );
      } else if (port != null) {
        return IsolateJSFunction(ctx, val, port);
      } else {
        return JSFunction.fromAddress(
          Pointer.fromAddress(ctx),
          Pointer.fromAddress(val),
        );
      }
    }
    if (data.containsKey('__js_function_port')) {
      return IsolateFunction(data['__js_function_port'], port);
    }
    if (data.containsKey('__js_future_port')) {
      SendPort port = data['__js_future_port'];
      var futurePort = ReceivePort();
      port.send(futurePort.sendPort);
      var futureCompleter = Completer();
      futureCompleter.future.catchError((e) {});
      futurePort.first.then((value) {
        futurePort.close();
        if (value['error'] != null) {
          futureCompleter.completeError(value['error']);
        } else {
          futureCompleter.complete(value['data']);
        }
      });
      return futureCompleter.future;
    }
    var ret = {};
    cache[data] = ret;
    for (var entry in data.entries) {
      ret[decodeData(entry.key, port, cache: cache)] =
          decodeData(entry.value, port, cache: cache);
    }
    return ret;
  }
  return data;
}

String parseJSException(Pointer ctx, [Pointer perr]) {
  final e = perr ?? jsGetException(ctx);

  var err = jsToCString(ctx, e);
  if (jsValueGetTag(e) == JSTag.OBJECT) {
    Pointer stack = jsGetPropertyValue(ctx, e, 'stack');
    if (jsToBool(ctx, stack) != 0) {
      err += '\n' + jsToCString(ctx, stack);
    }
    jsFreeValue(ctx, stack);
  }
  if (perr == null) jsFreeValue(ctx, e);
  return err;
}

void definePropertyValue(
  Pointer ctx,
  Pointer obj,
  dynamic key,
  dynamic val, {
  Map<dynamic, dynamic> cache,
}) {
  var jsAtomVal = dartToJs(ctx, key, cache: cache);
  var jsAtom = jsValueToAtom(ctx, jsAtomVal);
  jsDefinePropertyValue(
    ctx,
    obj,
    jsAtom,
    dartToJs(ctx, val, cache: cache),
    JSProp.C_W_E,
  );
  jsFreeAtom(ctx, jsAtom);
  jsFreeValue(ctx, jsAtomVal);
}

Pointer jsGetPropertyValue(
  Pointer ctx,
  Pointer obj,
  dynamic key, {
  Map<dynamic, dynamic> cache,
}) {
  var jsAtomVal = dartToJs(ctx, key, cache: cache);
  var jsAtom = jsValueToAtom(ctx, jsAtomVal);
  var jsProp = jsGetProperty(ctx, obj, jsAtom);
  jsFreeAtom(ctx, jsAtom);
  jsFreeValue(ctx, jsAtomVal);
  return jsProp;
}

Pointer dartToJs(Pointer ctx, dynamic val, {Map<dynamic, dynamic> cache}) {
  if (val == null) return jsUNDEFINED();
  if (val is JSObject) return jsDupValue(ctx, val._val);
  if (val is Future) {
    var resolvingFunc = allocate<Uint8>(count: sizeOfJSValue * 2);
    var resolvingFunc2 =
        Pointer.fromAddress(resolvingFunc.address + sizeOfJSValue);
    var ret = jsNewPromiseCapability(ctx, resolvingFunc);
    var res = jsToDart(ctx, resolvingFunc);
    var rej = jsToDart(ctx, resolvingFunc2);
    jsFreeValue(ctx, resolvingFunc, free: false);
    jsFreeValue(ctx, resolvingFunc2, free: false);
    free(resolvingFunc);
    val.then((value) {
      res(value);
    }, onError: (e, stack) {
      rej(e.toString() + '\n' + stack.toString());
    });
    return ret;
  }
  if (cache == null) cache = Map();
  if (val is bool) return jsNewBool(ctx, val ? 1 : 0);
  if (val is int) return jsNewInt64(ctx, val);
  if (val is double) return jsNewFloat64(ctx, val);
  if (val is String) return jsNewString(ctx, val);
  if (val is Uint8List) {
    var ptr = allocate<Uint8>(count: val.length);
    var byteList = ptr.asTypedList(val.length);
    byteList.setAll(0, val);
    var ret = jsNewArrayBufferCopy(ctx, ptr, val.length);
    free(ptr);
    return ret;
  }
  if (cache.containsKey(val)) {
    return jsDupValue(ctx, cache[val]);
  }
  if (val is List) {
    Pointer ret = jsNewArray(ctx);
    cache[val] = ret;
    for (int i = 0; i < val.length; ++i) {
      definePropertyValue(ctx, ret, i, val[i], cache: cache);
    }
    return ret;
  }
  if (val is Map) {
    Pointer ret = jsNewObject(ctx);
    cache[val] = ret;
    for (MapEntry<dynamic, dynamic> entry in val.entries) {
      definePropertyValue(ctx, ret, entry.key, entry.value, cache: cache);
    }
    return ret;
  }
  // wrap Function to JSInvokable
  final valWrap = JSInvokable.wrap(val);
  int dartObjectClassId =
      runtimeOpaques[jsGetRuntime(ctx)]?.dartObjectClassId ?? 0;
  if (dartObjectClassId == 0) return jsUNDEFINED();
  var dartObject = jsNewObjectClass(
    ctx,
    dartObjectClassId,
    identityHashCode(DartObject(ctx, valWrap)),
  );
  if (valWrap is JSInvokable) {
    final ret = jsNewCFunction(ctx, dartObject);
    jsFreeValue(ctx, dartObject);
    return ret;
  }
  return dartObject;
}

dynamic jsToDart(Pointer ctx, Pointer val, {Map<int, dynamic> cache}) {
  if (cache == null) cache = Map();
  int tag = jsValueGetTag(val);
  if (jsTagIsFloat64(tag) != 0) {
    return jsToFloat64(ctx, val);
  }
  switch (tag) {
    case JSTag.BOOL:
      return jsToBool(ctx, val) != 0;
    case JSTag.INT:
      return jsToInt64(ctx, val);
    case JSTag.STRING:
      return jsToCString(ctx, val);
    case JSTag.OBJECT:
      final rt = jsGetRuntime(ctx);
      final dartObjectClassId = runtimeOpaques[rt].dartObjectClassId;
      if (dartObjectClassId != 0) {
        final dartObject = DartObject.fromAddress(
            rt, jsGetObjectOpaque(val, dartObjectClassId));
        if (dartObject != null) return dartObject._obj;
      }
      Pointer<IntPtr> psize = allocate<IntPtr>();
      Pointer<Uint8> buf = jsGetArrayBuffer(ctx, psize, val);
      int size = psize.value;
      free(psize);
      if (buf.address != 0) {
        return Uint8List.fromList(buf.asTypedList(size));
      }
      int valptr = jsValueGetPtr(val).address;
      if (cache.containsKey(valptr)) {
        return cache[valptr];
      }
      if (jsIsFunction(ctx, val) != 0) {
        return JSFunction(ctx, val);
      } else if (jsIsPromise(ctx, val) != 0) {
        Pointer jsPromiseThen = jsGetPropertyValue(ctx, val, 'then');
        JSFunction promiseThen = jsToDart(ctx, jsPromiseThen, cache: cache);
        jsFreeValue(ctx, jsPromiseThen);
        var completer = Completer();
        completer.future.catchError((e) {});
        final jsRet = promiseThen._invoke([
          (v) {
            if (!completer.isCompleted) completer.complete(v);
          },
          NativeJSInvokable((ctx, thisVal, args) {
            if (!completer.isCompleted)
              completer
                  .completeError(parseJSException(ctx, args[0]));
          }),
        ], JSObject.fromAddress(ctx, val));
        bool isException = jsIsException(jsRet) != 0;
        jsFreeValue(ctx, jsRet);
        if (isException) throw parseJSException(ctx);
        return completer.future;
      } else if (jsIsArray(ctx, val) != 0) {
        Pointer jslength = jsGetPropertyValue(ctx, val, 'length');
        int length = jsToInt64(ctx, jslength);
        List<dynamic> ret = [];
        cache[valptr] = ret;
        for (int i = 0; i < length; ++i) {
          var jsProp = jsGetPropertyValue(ctx, val, i);
          ret.add(jsToDart(ctx, jsProp, cache: cache));
          jsFreeValue(ctx, jsProp);
        }
        return ret;
      } else {
        Pointer<Pointer> ptab = allocate<Pointer>();
        Pointer<Uint32> plen = allocate<Uint32>();
        if (jsGetOwnPropertyNames(ctx, ptab, plen, val, -1) != 0) return null;
        int len = plen.value;
        free(plen);
        Map<dynamic, dynamic> ret = Map();
        cache[valptr] = ret;
        for (int i = 0; i < len; ++i) {
          var jsAtom = jsPropertyEnumGetAtom(ptab.value, i);
          var jsAtomValue = jsAtomToValue(ctx, jsAtom);
          var jsProp = jsGetProperty(ctx, val, jsAtom);
          ret[jsToDart(ctx, jsAtomValue, cache: cache)] =
              jsToDart(ctx, jsProp, cache: cache);
          jsFreeValue(ctx, jsAtomValue);
          jsFreeValue(ctx, jsProp);
          jsFreeAtom(ctx, jsAtom);
        }
        jsFree(ctx, ptab.value);
        free(ptab);
        return ret;
      }
      break;
    default:
  }
  return null;
}
