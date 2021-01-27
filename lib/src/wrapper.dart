/*
 * @Description: wrapper
 * @Author: ekibun
 * @Date: 2020-09-19 22:07:47
 * @LastEditors: ekibun
 * @LastEditTime: 2020-12-02 11:14:03
 */
part of '../flutter_qjs.dart';

dynamic _parseJSException(Pointer ctx, [Pointer perr]) {
  final e = perr ?? jsGetException(ctx);
  var err;
  try {
    err = _jsToDart(ctx, e);
  } catch (exception) {
    err = exception;
  }
  if (perr == null) jsFreeValue(ctx, e);
  return err;
}

void _definePropertyValue(
  Pointer ctx,
  Pointer obj,
  dynamic key,
  dynamic val, {
  Map<dynamic, dynamic> cache,
}) {
  final jsAtomVal = _dartToJs(ctx, key, cache: cache);
  final jsAtom = jsValueToAtom(ctx, jsAtomVal);
  jsDefinePropertyValue(
    ctx,
    obj,
    jsAtom,
    _dartToJs(ctx, val, cache: cache),
    JSProp.C_W_E,
  );
  jsFreeAtom(ctx, jsAtom);
  jsFreeValue(ctx, jsAtomVal);
}

Pointer _jsGetPropertyValue(
  Pointer ctx,
  Pointer obj,
  dynamic key, {
  Map<dynamic, dynamic> cache,
}) {
  final jsAtomVal = _dartToJs(ctx, key, cache: cache);
  final jsAtom = jsValueToAtom(ctx, jsAtomVal);
  final jsProp = jsGetProperty(ctx, obj, jsAtom);
  jsFreeAtom(ctx, jsAtom);
  jsFreeValue(ctx, jsAtomVal);
  return jsProp;
}

Pointer _dartToJs(Pointer ctx, dynamic val, {Map<dynamic, dynamic> cache}) {
  if (val == null) return jsUNDEFINED();
  if (val is JSError) {
    final ret = jsNewError(ctx);
    _definePropertyValue(ctx, ret, "name", "");
    _definePropertyValue(ctx, ret, "message", val.message);
    _definePropertyValue(ctx, ret, "stack", val.stack);
    return ret;
  }
  if (val is _JSObject) return jsDupValue(ctx, val._val);
  if (val is Future) {
    final resolvingFunc = allocate<Uint8>(count: sizeOfJSValue * 2);
    final resolvingFunc2 =
        Pointer.fromAddress(resolvingFunc.address + sizeOfJSValue);
    final ret = jsNewPromiseCapability(ctx, resolvingFunc);
    _JSFunction res = _jsToDart(ctx, resolvingFunc);
    _JSFunction rej = _jsToDart(ctx, resolvingFunc2);
    jsFreeValue(ctx, resolvingFunc, free: false);
    jsFreeValue(ctx, resolvingFunc2, free: false);
    free(resolvingFunc);
    _DartObject refRes = _DartObject(ctx, res);
    _DartObject refRej = _DartObject(ctx, rej);
    res.free();
    rej.free();
    val.then((value) {
      res.invoke([value]);
    }, onError: (e) {
      rej.invoke([e]);
    }).whenComplete(() {
      refRes.free();
      refRej.free();
    });
    return ret;
  }
  if (cache == null) cache = Map();
  if (val is bool) return jsNewBool(ctx, val ? 1 : 0);
  if (val is int) return jsNewInt64(ctx, val);
  if (val is double) return jsNewFloat64(ctx, val);
  if (val is String) return jsNewString(ctx, val);
  if (val is Uint8List) {
    final ptr = allocate<Uint8>(count: val.length);
    final byteList = ptr.asTypedList(val.length);
    byteList.setAll(0, val);
    final ret = jsNewArrayBufferCopy(ctx, ptr, val.length);
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
      _definePropertyValue(ctx, ret, i, val[i], cache: cache);
    }
    return ret;
  }
  if (val is Map) {
    Pointer ret = jsNewObject(ctx);
    cache[val] = ret;
    for (MapEntry<dynamic, dynamic> entry in val.entries) {
      _definePropertyValue(ctx, ret, entry.key, entry.value, cache: cache);
    }
    return ret;
  }
  // wrap Function to JSInvokable
  final valWrap = JSInvokable._wrap(val);
  int dartObjectClassId =
      runtimeOpaques[jsGetRuntime(ctx)]?.dartObjectClassId ?? 0;
  if (dartObjectClassId == 0) return jsUNDEFINED();
  final dartObject = jsNewObjectClass(
    ctx,
    dartObjectClassId,
    identityHashCode(_DartObject(ctx, valWrap)),
  );
  if (valWrap is JSInvokable) {
    final ret = jsNewCFunction(ctx, dartObject);
    jsFreeValue(ctx, dartObject);
    return ret;
  }
  return dartObject;
}

dynamic _jsToDart(Pointer ctx, Pointer val, {Map<int, dynamic> cache}) {
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
        final dartObject = _DartObject.fromAddress(
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
        return _JSFunction(ctx, val);
      } else if (jsIsError(ctx, val) != 0) {
        final err = jsToCString(ctx, val);
        final pstack = _jsGetPropertyValue(ctx, val, 'stack');
        final stack =
            jsToBool(ctx, pstack) != 0 ? jsToCString(ctx, pstack) : null;
        jsFreeValue(ctx, pstack);
        return JSError(err, stack);
      } else if (jsIsPromise(ctx, val) != 0) {
        Pointer jsPromiseThen = _jsGetPropertyValue(ctx, val, 'then');
        _JSFunction promiseThen = _jsToDart(ctx, jsPromiseThen, cache: cache);
        jsFreeValue(ctx, jsPromiseThen);
        final completer = Completer();
        completer.future.catchError((e) {});
        final jsPromise = _JSObject(ctx, val);
        final jsRet = promiseThen._invoke([
          (v) {
            if (!completer.isCompleted) completer.complete(v);
          },
          (e) {
            if (!completer.isCompleted) completer.completeError(e);
          },
        ], jsPromise);
        jsPromise.free();
        promiseThen.free();
        bool isException = jsIsException(jsRet) != 0;
        jsFreeValue(ctx, jsRet);
        if (isException) throw _parseJSException(ctx);
        return completer.future;
      } else if (jsIsArray(ctx, val) != 0) {
        Pointer jslength = _jsGetPropertyValue(ctx, val, 'length');
        int length = jsToInt64(ctx, jslength);
        List<dynamic> ret = [];
        cache[valptr] = ret;
        for (int i = 0; i < length; ++i) {
          final jsProp = _jsGetPropertyValue(ctx, val, i);
          ret.add(_jsToDart(ctx, jsProp, cache: cache));
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
          final jsAtom = jsPropertyEnumGetAtom(ptab.value, i);
          final jsAtomValue = jsAtomToValue(ctx, jsAtom);
          final jsProp = jsGetProperty(ctx, val, jsAtom);
          ret[_jsToDart(ctx, jsAtomValue, cache: cache)] =
              _jsToDart(ctx, jsProp, cache: cache);
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
