/*
 * @Description: 
 * @Author: ekibun
 * @Date: 2020-09-19 22:07:47
 * @LastEditors: ekibun
 * @LastEditTime: 2020-09-20 15:41:16
 */
import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

import 'ffi.dart';

class JSFunction extends JSRef {
  Pointer val;
  Pointer ctx;
  JSFunction(this.ctx, Pointer val) {
    Pointer rt = jsGetRuntime(ctx);
    this.val = jsDupValue(ctx, val);
    runtimeOpaques[rt]?.ref?.add(this);
  }

  @override
  void release() {
    if (val != null) {
      jsFreeValue(ctx, val);
      deleteJSValue(val);
      val = null;
    }
  }

  @override
  noSuchMethod(Invocation invocation) {
    return super.noSuchMethod(invocation);
  }
}

Pointer dartToJs(Pointer ctx, dynamic val, {Map<dynamic, dynamic> cache}) {
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
    return cache[val];
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
      deleteJSValue(jsAtomVal);
    }
    return ret;
  }
  if (val is Map) {
    Pointer ret = jsNewObject(ctx);
    cache[val] = ret;
    for (MapEntry<dynamic, dynamic> entry in val.entries){
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
      deleteJSValue(jsAtomVal);
    }
    return ret;
  }
  return jsUNDEFINED();
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
      Pointer<Int64> psize = allocate<Int64>();
      Pointer<Uint8> buf = jsGetArrayBuffer(ctx, psize, val);
      int size = psize.value;
      free(psize);
      if (buf.address != 0) {
        return buf.asTypedList(size);
      }
      int valptr = jsValueGetPtr(val).address;
      if (cache.containsKey(valptr)) {
        return cache[valptr];
      }
      if (jsIsFunction(ctx, val) != 0) {
        return JSFunction(ctx, val);
      } else if (jsIsArray(ctx, val) != 0) {
        var jsAtomVal = jsNewString(ctx, "length");
        var jsAtom = jsValueToAtom(ctx, jsAtomVal);
        var jslength = jsGetProperty(ctx, val, jsAtom);
        jsFreeAtom(ctx, jsAtom);
        jsFreeValue(ctx, jsAtomVal);
        deleteJSValue(jsAtomVal);

        int length = jsToInt64(ctx, jslength);
        deleteJSValue(jslength);
        List<dynamic> ret = List();
        cache[valptr] = ret;
        for (int i = 0; i < length; ++i) {
          var jsAtomVal = jsNewInt64(ctx, i);
          var jsAtom = jsValueToAtom(ctx, jsAtomVal);
          var jsProp = jsGetProperty(ctx, val, jsAtom);
          jsFreeAtom(ctx, jsAtom);
          jsFreeValue(ctx, jsAtomVal);
          deleteJSValue(jsAtomVal);
          ret.add(jsToDart(ctx, jsProp, cache: cache));
          jsFreeValue(ctx, jsProp);
          deleteJSValue(jsProp);
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
          ret[jsToDart(ctx, jsAtomValue, cache: cache)] = jsToDart(ctx, jsProp, cache: cache);
          jsFreeValue(ctx, jsAtomValue);
          deleteJSValue(jsAtomValue);
          jsFreeValue(ctx, jsProp);
          deleteJSValue(jsProp);
          jsFreeAtom(ctx, jsAtom);
        }
        free(ptab);
        return ret;
      }
      break;
    default:
  }
  return null;
}
