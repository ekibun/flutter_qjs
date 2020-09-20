/*
 * @Description: 
 * @Author: ekibun
 * @Date: 2020-09-19 10:29:04
 * @LastEditors: ekibun
 * @LastEditTime: 2020-09-21 01:30:41
 */
import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';

import 'package:ffi/ffi.dart';

abstract class JSRef {
  void release();
}

/// JS_Eval() flags
class JSEvalType {
  static const GLOBAL = 0 << 0;
  static const MODULE = 1 << 0;
}

class JSProp {
  static const CONFIGURABLE = (1 << 0);
  static const WRITABLE = (1 << 1);
  static const ENUMERABLE = (1 << 2);
  static const C_W_E = (CONFIGURABLE | WRITABLE | ENUMERABLE);
}

class JSTag {
  static const FIRST = -11; /* first negative tag */
  static const BIG_DECIMAL = -11;
  static const BIG_INT = -10;
  static const BIG_FLOAT = -9;
  static const SYMBOL = -8;
  static const STRING = -7;
  static const MODULE = -3; /* used internally */
  static const FUNCTION_BYTECODE = -2; /* used internally */
  static const OBJECT = -1;

  static const INT = 0;
  static const BOOL = 1;
  static const NULL = 2;
  static const UNDEFINED = 3;
  static const UNINITIALIZED = 4;
  static const CATCH_OFFSET = 5;
  static const EXCEPTION = 6;
  static const FLOAT64 = 7;
}

final DynamicLibrary qjsLib = Platform.environment['FLUTTER_TEST'] == 'true'
    ? (Platform.isWindows
        ? DynamicLibrary.open("test/build/Debug/flutter_qjs.dll")
        : DynamicLibrary.process())
    : (Platform.isWindows ? DynamicLibrary.open("flutter_qjs_plugin.dll") : DynamicLibrary.process());

/// JSValue *jsEXCEPTION()
final Pointer Function() jsEXCEPTION =
    qjsLib.lookup<NativeFunction<Pointer Function()>>("jsEXCEPTION").asFunction();

/// JSValue *jsUNDEFINED()
final Pointer Function() jsUNDEFINED =
    qjsLib.lookup<NativeFunction<Pointer Function()>>("jsUNDEFINED").asFunction();

/// JSRuntime *jsNewRuntime(JSChannel channel)
final Pointer Function(
  Pointer<NativeFunction<Pointer Function(Pointer ctx, Pointer method, Pointer argv)>>,
) _jsNewRuntime = qjsLib
    .lookup<
        NativeFunction<
            Pointer Function(
      Pointer,
    )>>("jsNewRuntime")
    .asFunction();

typedef JSChannel = Pointer Function(Pointer ctx, Pointer method, Pointer argv);

class RuntimeOpaque {
  JSChannel channel;
  List<JSRef> ref = List();
  ReceivePort port;
  Pointer Function(Future) futureToPromise;
  Future Function(Pointer) promsieToFuture;
}

final Map<Pointer, RuntimeOpaque> runtimeOpaques = Map();

Pointer channelDispacher(Pointer ctx, Pointer method, Pointer argv) {
  return runtimeOpaques[jsGetRuntime(ctx)].channel(ctx, method, argv);
}

Pointer jsNewRuntime(
  JSChannel callback,
  ReceivePort port,
) {
  var rt = _jsNewRuntime(Pointer.fromFunction(channelDispacher));
  runtimeOpaques[rt] = RuntimeOpaque()..channel = callback..port = port;
  return rt;
}

/// void jsFreeRuntime(JSRuntime *rt)
final void Function(
  Pointer,
) _jsFreeRuntime = qjsLib
    .lookup<
        NativeFunction<
            Void Function(
      Pointer,
    )>>("jsFreeRuntime")
    .asFunction();

void jsFreeRuntime(
  Pointer rt,
) {
  runtimeOpaques[rt]?.ref?.forEach((val) {
    val.release();
  });
  runtimeOpaques.remove(rt);
  _jsFreeRuntime(rt);
}

/// JSContext *jsNewContext(JSRuntime *rt)
final Pointer Function(
  Pointer rt,
) jsNewContext = qjsLib
    .lookup<
        NativeFunction<
            Pointer Function(
      Pointer,
    )>>("jsNewContext")
    .asFunction();

/// void jsFreeContext(JSContext *ctx)
final void Function(
  Pointer,
) jsFreeContext = qjsLib
    .lookup<
        NativeFunction<
            Void Function(
      Pointer,
    )>>("jsFreeContext")
    .asFunction();

/// JSRuntime *jsGetRuntime(JSContext *ctx)
final Pointer Function(
  Pointer,
) jsGetRuntime = qjsLib
    .lookup<
        NativeFunction<
            Pointer Function(
      Pointer,
    )>>("jsGetRuntime")
    .asFunction();

/// JSValue *jsEval(JSContext *ctx, const char *input, size_t input_len, const char *filename, int eval_flags)
final Pointer Function(
  Pointer ctx,
  Pointer<Utf8> input,
  int inputLen,
  Pointer<Utf8> filename,
  int evalFlags,
) _jsEval = qjsLib
    .lookup<
        NativeFunction<
            Pointer Function(
      Pointer,
      Pointer<Utf8>,
      Int64,
      Pointer<Utf8>,
      Int32,
    )>>("jsEval")
    .asFunction();

Pointer jsEval(
  Pointer ctx,
  String input,
  String filename,
  int evalFlags,
) {
  var utf8input = Utf8.toUtf8(input);
  var utf8filename = Utf8.toUtf8(filename);
  var val = _jsEval(ctx, utf8input, Utf8.strlen(utf8input), utf8filename, evalFlags);
  free(utf8input);
  free(utf8filename);
  runtimeOpaques[jsGetRuntime(ctx)].port.sendPort.send('eval');
  return val;
}

/// DLLEXPORT int32_t jsValueGetTag(JSValue *val)
final int Function(
  Pointer val,
) jsValueGetTag = qjsLib
    .lookup<
        NativeFunction<
            Int32 Function(
      Pointer,
    )>>("jsValueGetTag")
    .asFunction();

/// void *jsValueGetPtr(JSValue *val)
final Pointer Function(
  Pointer val,
) jsValueGetPtr = qjsLib
    .lookup<
        NativeFunction<
            Pointer Function(
      Pointer,
    )>>("jsValueGetPtr")
    .asFunction();

/// DLLEXPORT bool jsTagIsFloat64(int32_t tag)
final int Function(
  int val,
) jsTagIsFloat64 = qjsLib
    .lookup<
        NativeFunction<
            Int32 Function(
      Int32,
    )>>("jsTagIsFloat64")
    .asFunction();

/// JSValue *jsNewBool(JSContext *ctx, int val)
final Pointer Function(
  Pointer ctx,
  int val,
) jsNewBool = qjsLib
    .lookup<
        NativeFunction<
            Pointer Function(
      Pointer,
      Int32,
    )>>("jsNewBool")
    .asFunction();

/// JSValue *jsNewInt64(JSContext *ctx, int64_t val)
final Pointer Function(
  Pointer ctx,
  int val,
) jsNewInt64 = qjsLib
    .lookup<
        NativeFunction<
            Pointer Function(
      Pointer,
      Int64,
    )>>("jsNewInt64")
    .asFunction();

/// JSValue *jsNewFloat64(JSContext *ctx, double val)
final Pointer Function(
  Pointer ctx,
  double val,
) jsNewFloat64 = qjsLib
    .lookup<
        NativeFunction<
            Pointer Function(
      Pointer,
      Double,
    )>>("jsNewFloat64")
    .asFunction();

/// JSValue *jsNewString(JSContext *ctx, const char *str)
final Pointer Function(
  Pointer ctx,
  Pointer<Utf8> str,
) _jsNewString = qjsLib
    .lookup<
        NativeFunction<
            Pointer Function(
      Pointer,
      Pointer<Utf8>,
    )>>("jsNewString")
    .asFunction();

Pointer jsNewString(
  Pointer ctx,
  String str,
) {
  var utf8str = Utf8.toUtf8(str);
  return _jsNewString(ctx, utf8str);
}

/// JSValue *jsNewArrayBufferCopy(JSContext *ctx, const uint8_t *buf, size_t len)
final Pointer Function(
  Pointer ctx,
  Pointer<Uint8> buf,
  int len,
) jsNewArrayBufferCopy = qjsLib
    .lookup<
        NativeFunction<
            Pointer Function(
      Pointer,
      Pointer<Uint8>,
      Uint64,
    )>>("jsNewArrayBufferCopy")
    .asFunction();

/// JSValue *jsNewArray(JSContext *ctx)
final Pointer Function(
  Pointer ctx,
) jsNewArray = qjsLib
    .lookup<
        NativeFunction<
            Pointer Function(
      Pointer,
    )>>("jsNewArray")
    .asFunction();

/// JSValue *jsNewObject(JSContext *ctx)
final Pointer Function(
  Pointer ctx,
) jsNewObject = qjsLib
    .lookup<
        NativeFunction<
            Pointer Function(
      Pointer,
    )>>("jsNewObject")
    .asFunction();

/// void jsFreeValue(JSContext *ctx, JSValue *val)
final void Function(
  Pointer ctx,
  Pointer val,
) jsFreeValue = qjsLib
    .lookup<
        NativeFunction<
            Void Function(
      Pointer,
      Pointer,
    )>>("jsFreeValue")
    .asFunction();

/// void jsFreeValueRT(JSRuntime *rt, JSValue *v)
final void Function(
  Pointer rt,
  Pointer val,
) jsFreeValueRT = qjsLib
    .lookup<
        NativeFunction<
            Void Function(
      Pointer,
      Pointer,
    )>>("jsFreeValueRT")
    .asFunction();

/// JSValue *jsDupValue(JSContext *ctx, JSValueConst *v)
final Pointer Function(
  Pointer ctx,
  Pointer val,
) jsDupValue = qjsLib
    .lookup<
        NativeFunction<
            Pointer Function(
      Pointer,
      Pointer,
    )>>("jsDupValue")
    .asFunction();

/// JSValue *jsDupValueRT(JSRuntime *rt, JSValue *v)
final Pointer Function(
  Pointer rt,
  Pointer val,
) jsDupValueRT = qjsLib
    .lookup<
        NativeFunction<
            Pointer Function(
      Pointer,
      Pointer,
    )>>("jsDupValueRT")
    .asFunction();

/// int32_t jsToBool(JSContext *ctx, JSValueConst *val)
final int Function(
  Pointer ctx,
  Pointer val,
) jsToBool = qjsLib
    .lookup<
        NativeFunction<
            Int32 Function(
      Pointer,
      Pointer,
    )>>("jsToBool")
    .asFunction();

/// int64_t jsToFloat64(JSContext *ctx, JSValueConst *val)
final int Function(
  Pointer ctx,
  Pointer val,
) jsToInt64 = qjsLib
    .lookup<
        NativeFunction<
            Int64 Function(
      Pointer,
      Pointer,
    )>>("jsToInt64")
    .asFunction();

/// double jsToFloat64(JSContext *ctx, JSValueConst *val)
final double Function(
  Pointer ctx,
  Pointer val,
) jsToFloat64 = qjsLib
    .lookup<
        NativeFunction<
            Double Function(
      Pointer,
      Pointer,
    )>>("jsToFloat64")
    .asFunction();

/// const char *jsToCString(JSContext *ctx, JSValue *val)
final Pointer<Utf8> Function(
  Pointer ctx,
  Pointer val,
) _jsToCString = qjsLib
    .lookup<
        NativeFunction<
            Pointer<Utf8> Function(
      Pointer,
      Pointer,
    )>>("jsToCString")
    .asFunction();

/// void jsFreeCString(JSContext *ctx, const char *ptr)
final void Function(
  Pointer ctx,
  Pointer<Utf8> val,
) jsFreeCString = qjsLib
    .lookup<
        NativeFunction<
            Void Function(
      Pointer,
      Pointer<Utf8>,
    )>>("jsFreeCString")
    .asFunction();

String jsToCString(
  Pointer ctx,
  Pointer val,
) {
  var ptr = _jsToCString(ctx, val);
  var str = Utf8.fromUtf8(ptr);
  jsFreeCString(ctx, ptr);
  return str;
}

/// uint8_t *jsGetArrayBuffer(JSContext *ctx, size_t *psize, JSValueConst *obj)
final Pointer<Uint8> Function(
  Pointer ctx,
  Pointer<Int64> psize,
  Pointer val,
) jsGetArrayBuffer = qjsLib
    .lookup<
        NativeFunction<
            Pointer<Uint8> Function(
      Pointer,
      Pointer<Int64>,
      Pointer,
    )>>("jsGetArrayBuffer")
    .asFunction();

/// int32_t jsIsFunction(JSContext *ctx, JSValueConst *val)
final int Function(
  Pointer ctx,
  Pointer val,
) jsIsFunction = qjsLib
    .lookup<
        NativeFunction<
            Int32 Function(
      Pointer,
      Pointer,
    )>>("jsIsFunction")
    .asFunction();

/// int32_t jsIsArray(JSContext *ctx, JSValueConst *val)
final int Function(
  Pointer ctx,
  Pointer val,
) jsIsArray = qjsLib
    .lookup<
        NativeFunction<
            Int32 Function(
      Pointer,
      Pointer,
    )>>("jsIsArray")
    .asFunction();

/// void deleteJSValue(JSValueConst *val)
final void Function(
  Pointer val,
) deleteJSValue = qjsLib
    .lookup<
        NativeFunction<
            Void Function(
      Pointer,
    )>>("deleteJSValue")
    .asFunction();

/// JSValue *jsGetProperty(JSContext *ctx, JSValueConst *this_obj,
///                           JSAtom prop)
final Pointer Function(
  Pointer ctx,
  Pointer thisObj,
  int prop,
) jsGetProperty = qjsLib
    .lookup<
        NativeFunction<
            Pointer Function(
      Pointer,
      Pointer,
      Uint32,
    )>>("jsGetProperty")
    .asFunction();

/// int jsDefinePropertyValue(JSContext *ctx, JSValueConst *this_obj,
///                           JSAtom prop, JSValue *val, int flags)
final int Function(Pointer ctx, Pointer thisObj, int prop, Pointer val, int flag)
    jsDefinePropertyValue = qjsLib
        .lookup<
            NativeFunction<
                Int32 Function(
          Pointer,
          Pointer,
          Uint32,
          Pointer,
          Int32,
        )>>("jsDefinePropertyValue")
        .asFunction();

/// void jsFreeAtom(JSContext *ctx, JSAtom v)
final Pointer Function(
  Pointer ctx,
  int v,
) jsFreeAtom = qjsLib
    .lookup<
        NativeFunction<
            Pointer Function(
      Pointer,
      Uint32,
    )>>("jsFreeAtom")
    .asFunction();

/// JSAtom jsValueToAtom(JSContext *ctx, JSValueConst *val)
final int Function(
  Pointer ctx,
  Pointer val,
) jsValueToAtom = qjsLib
    .lookup<
        NativeFunction<
            Uint32 Function(
      Pointer,
      Pointer,
    )>>("jsValueToAtom")
    .asFunction();

/// JSValue *jsAtomToValue(JSContext *ctx, JSAtom val)
final Pointer Function(
  Pointer ctx,
  int val,
) jsAtomToValue = qjsLib
    .lookup<
        NativeFunction<
            Pointer Function(
      Pointer,
      Uint32,
    )>>("jsAtomToValue")
    .asFunction();

/// int jsGetOwnPropertyNames(JSContext *ctx, JSPropertyEnum **ptab,
///                           uint32_t *plen, JSValueConst *obj, int flags)
final int Function(
  Pointer ctx,
  Pointer<Pointer> ptab,
  Pointer<Uint32> plen,
  Pointer obj,
  int flags,
) jsGetOwnPropertyNames = qjsLib
    .lookup<
        NativeFunction<
            Int32 Function(
      Pointer,
      Pointer<Pointer>,
      Pointer<Uint32>,
      Pointer,
      Int32,
    )>>("jsGetOwnPropertyNames")
    .asFunction();

/// JSAtom jsPropertyEnumGetAtom(JSPropertyEnum *ptab, int i)
final int Function(
  Pointer ptab,
  int i,
) jsPropertyEnumGetAtom = qjsLib
    .lookup<
        NativeFunction<
            Uint32 Function(
      Pointer,
      Int32,
    )>>("jsPropertyEnumGetAtom")
    .asFunction();

/// uint32_t sizeOfJSValue()
final int Function() _sizeOfJSValue =
    qjsLib.lookup<NativeFunction<Uint32 Function()>>("sizeOfJSValue").asFunction();

final sizeOfJSValue = _sizeOfJSValue();

/// void setJSValueList(JSValue *list, int i, JSValue *val)
final void Function(
  Pointer list,
  int i,
  Pointer val,
) setJSValueList = qjsLib
    .lookup<
        NativeFunction<
            Void Function(
      Pointer,
      Uint32,
      Pointer,
    )>>("setJSValueList")
    .asFunction();

/// JSValue *jsCall(JSContext *ctx, JSValueConst *func_obj, JSValueConst *this_obj,
///                 int argc, JSValueConst *argv)
final Pointer Function(
  Pointer ctx,
  Pointer funcObj,
  Pointer thisObj,
  int argc,
  Pointer argv,
) _jsCall = qjsLib
    .lookup<
        NativeFunction<
            Pointer Function(
      Pointer,
      Pointer,
      Pointer,
      Int32,
      Pointer,
    )>>("jsCall")
    .asFunction();

Pointer jsCall(
  Pointer ctx,
  Pointer funcObj,
  Pointer thisObj,
  List<Pointer> argv,
) {
  Pointer jsArgs = allocate<Uint8>(count: argv.length > 0 ? sizeOfJSValue * argv.length : 1);
  for (int i = 0; i < argv.length; ++i) {
    Pointer jsArg = argv[i];
    setJSValueList(jsArgs, i, jsArg);
  }
  Pointer func1 = jsDupValue(ctx, funcObj);
  Pointer _thisObj = thisObj ?? jsUNDEFINED();
  Pointer jsRet = _jsCall(ctx, funcObj, _thisObj, argv.length, jsArgs);
  if (thisObj == null) {
    jsFreeValue(ctx, _thisObj);
    deleteJSValue(_thisObj);
  }
  jsFreeValue(ctx, func1);
  deleteJSValue(func1);
  free(jsArgs);
  runtimeOpaques[jsGetRuntime(ctx)].port.sendPort.send('call');
  return jsRet;
}

/// int jsIsException(JSValueConst *val)
final int Function(
  Pointer val,
) jsIsException = qjsLib
    .lookup<
        NativeFunction<
            Int32 Function(
      Pointer,
    )>>("jsIsException")
    .asFunction();

/// JSValue *jsGetException(JSContext *ctx)
final Pointer Function(
  Pointer ctx,
) jsGetException = qjsLib
    .lookup<
        NativeFunction<
            Pointer Function(
      Pointer,
    )>>("jsGetException")
    .asFunction();

/// int jsExecutePendingJob(JSRuntime *rt)
final int Function(
  Pointer ctx,
) jsExecutePendingJob = qjsLib
    .lookup<
        NativeFunction<
            Int32 Function(
      Pointer,
    )>>("jsExecutePendingJob")
    .asFunction();