/*
 * @Description: 
 * @Author: ekibun
 * @Date: 2020-09-19 22:07:47
 * @LastEditors: ekibun
 * @LastEditTime: 2020-12-02 11:14:03
 */
import 'dart:async';
import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

import 'ffi.dart';

class JSRefValue implements JSRef {
  Pointer val;
  Pointer ctx;
  JSRefValue(this.ctx, Pointer val) {
    Pointer rt = jsGetRuntime(ctx);
    this.val = jsDupValue(ctx, val);
    runtimeOpaques[rt]?.ref?.add(this);
  }

  JSRefValue.fromAddress(int ctx, int val) {
    this.ctx = Pointer.fromAddress(ctx);
    this.val = Pointer.fromAddress(val);
  }

  @override
  void release() {
    if (val != null) {
      jsFreeValue(ctx, val);
    }
    val = null;
    ctx = null;
  }
}

class DartObject implements JSRef {
  Object obj;
  Pointer ctx;
  DartObject(this.ctx, this.obj) {
    runtimeOpaques[jsGetRuntime(ctx)]?.ref?.add(this);
  }

  static DartObject fromAddress(Pointer ctx, int val) {
    return runtimeOpaques[jsGetRuntime(ctx)]?.ref?.firstWhere(
          (e) => identityHashCode(e) == val,
          orElse: null,
        );
  }

  @override
  void release() {
    ctx = null;
  }
}

class JSPromise extends JSRefValue {
  Completer completer;
  JSPromise(Pointer ctx, Pointer val, this.completer) : super(ctx, val);

  @override
  void release() {
    super.release();
    if (!completer.isCompleted) {
      completer.completeError("Promise cannot resolve");
    }
  }

  bool checkResolveReject() {
    if (val == null || completer.isCompleted) return true;
    var status = jsToDart(ctx, val);
    if (status["__resolved"] == true) {
      completer.complete(status["__value"]);
      return true;
    }
    if (status["__rejected"] == true) {
      completer.completeError(parseJSException(
        ctx,
        e: jsGetPropertyStr(ctx, val, "__error"),
      ));
      return true;
    }
    return false;
  }
}

class JSFunction extends JSRefValue {
  JSFunction(Pointer ctx, Pointer val) : super(ctx, val);

  JSFunction.fromAddress(int ctx, int val) : super.fromAddress(ctx, val);

  invoke(List<dynamic> arguments) {
    if (val == null) return;
    List<Pointer> args = arguments
        .map(
          (e) => dartToJs(ctx, e),
        )
        .toList();
    Pointer jsRet = jsCall(ctx, val, null, args);
    for (Pointer jsArg in args) {
      jsFreeValue(ctx, jsArg);
    }
    bool isException = jsIsException(jsRet) != 0;
    if (isException) {
      jsFreeValue(ctx, jsRet);
      throw Exception(parseJSException(ctx));
    }
    var ret = jsToDart(ctx, jsRet);
    jsFreeValue(ctx, jsRet);
    return ret;
  }

  @override
  noSuchMethod(Invocation invocation) {
    return invoke(invocation.positionalArguments);
  }
}

Pointer jsGetPropertyStr(Pointer ctx, Pointer val, String prop) {
  var jsAtomVal = jsNewString(ctx, prop);
  var jsAtom = jsValueToAtom(ctx, jsAtomVal);
  Pointer jsProp = jsGetProperty(ctx, val, jsAtom);
  jsFreeAtom(ctx, jsAtom);
  jsFreeValue(ctx, jsAtomVal);
  return jsProp;
}

String parseJSException(Pointer ctx, {Pointer e}) {
  e = e ?? jsGetException(ctx);
  var err = jsToCString(ctx, e);
  if (jsValueGetTag(e) == JSTag.OBJECT) {
    Pointer stack = jsGetPropertyStr(ctx, e, "stack");
    if (jsToBool(ctx, stack) != 0) {
      err += '\n' + jsToCString(ctx, stack);
    }
    jsFreeValue(ctx, stack);
  }
  jsFreeValue(ctx, e);
  return err;
}

Pointer dartToJs(Pointer ctx, dynamic val, {Map<dynamic, dynamic> cache}) {
  if (val == null) return jsUNDEFINED();
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
      rej(e.toString() + "\n" + stack.toString());
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
  if (val is JSFunction) {
    return jsDupValue(ctx, val.val);
  }
  if (val is List) {
    Pointer ret = jsNewArray(ctx);
    cache[val] = ret;
    for (int i = 0; i < val.length; ++i) {
      var jsAtomVal = jsNewInt64(ctx, i);
      var jsAtom = jsValueToAtom(ctx, jsAtomVal);
      jsDefinePropertyValue(
        ctx,
        ret,
        jsAtom,
        dartToJs(ctx, val[i], cache: cache),
        JSProp.C_W_E,
      );
      jsFreeAtom(ctx, jsAtom);
      jsFreeValue(ctx, jsAtomVal);
    }
    return ret;
  }
  if (val is Map) {
    Pointer ret = jsNewObject(ctx);
    cache[val] = ret;
    for (MapEntry<dynamic, dynamic> entry in val.entries) {
      var jsAtomVal = dartToJs(ctx, entry.key, cache: cache);
      var jsAtom = jsValueToAtom(ctx, jsAtomVal);
      jsDefinePropertyValue(
        ctx,
        ret,
        jsAtom,
        dartToJs(ctx, entry.value, cache: cache),
        JSProp.C_W_E,
      );
      jsFreeAtom(ctx, jsAtom);
      jsFreeValue(ctx, jsAtomVal);
    }
    return ret;
  }
  return runtimeOpaques[jsGetRuntime(ctx)]?.objectWrapper(val) ?? jsUNDEFINED();
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
        return runtimeOpaques[jsGetRuntime(ctx)]?.promiseToFuture(val);
      } else if (jsIsArray(ctx, val) != 0) {
        Pointer jslength = jsGetPropertyStr(ctx, val, "length");
        int length = jsToInt64(ctx, jslength);
        List<dynamic> ret = [];
        cache[valptr] = ret;
        for (int i = 0; i < length; ++i) {
          var jsAtomVal = jsNewInt64(ctx, i);
          var jsAtom = jsValueToAtom(ctx, jsAtomVal);
          var jsProp = jsGetProperty(ctx, val, jsAtom);
          jsFreeAtom(ctx, jsAtom);
          jsFreeValue(ctx, jsAtomVal);
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
        final objHash = ret["__dart_obj_hash__"];
        if (objHash is int) {
          return DartObject.fromAddress(ctx, objHash)?.obj ?? ret;
        }
        return ret;
      }
      break;
    default:
  }
  return null;
}

Pointer jsNewContextWithPromsieWrapper(Pointer rt) {
  var ctx = jsNewContext(rt);
  final runtimeOpaque = runtimeOpaques[rt];
  if (runtimeOpaque == null) throw Exception("Runtime has been released!");

  var jsPromiseWrapper = jsEval(
      ctx,
      """
        (value) => {
          const __ret = {};
          Promise.resolve(value)
            .then(v => {
              __ret.__value = v;
              __ret.__resolved = true;
            }).catch(e => {
              __ret.__error = e;
              __ret.__rejected = true;
            });
          return __ret;
        }
        """,
      "<future>",
      JSEvalFlag.GLOBAL);
  var jsObjectWrapper = jsEval(
      ctx,
      """
        (objHash, type) => {
            const ret = {
              "__dart_obj_hash__": objHash,
            };
            ret.__proto__.toString = ()=>  "" + type;
            return ret;
        };
        """,
      "<future>",
      JSEvalFlag.GLOBAL);
  final promiseWrapper = JSRefValue(ctx, jsPromiseWrapper);
  jsFreeValue(ctx, jsPromiseWrapper);
  final objectWrapper = JSRefValue(ctx, jsObjectWrapper);
  jsFreeValue(ctx, jsObjectWrapper);
  runtimeOpaque.promiseToFuture = (promise) {
    var completer = Completer();
    var wrapper = promiseWrapper.val;
    if (wrapper == null)
      completer.completeError(Exception("Runtime has been released!"));
    var jsPromise = jsCall(ctx, wrapper, null, [promise]);
    var wrapPromise = JSPromise(ctx, jsPromise, completer);
    jsFreeValue(ctx, jsPromise);
    return wrapPromise.completer.future;
  };
  runtimeOpaque.objectWrapper = (obj) {
    var jsObjHash = jsNewInt64(ctx, identityHashCode(DartObject(ctx, obj)));
    var jsTypeString = jsNewString(ctx, obj.toString());
    var wrapper = objectWrapper.val;
    if (wrapper == null) throw Exception("Runtime has been released!");
    var ret = jsCall(ctx, wrapper, null, [jsObjHash, jsTypeString]);
    jsFreeValue(ctx, jsObjHash);
    jsFreeValue(ctx, jsTypeString);
    return ret;
  };

  return ctx;
}
