/*
 * @Description: 
 * @Author: ekibun
 * @Date: 2020-10-20 23:54:27
 * @LastEditors: ekibun
 * @LastEditTime: 2020-10-21 00:42:31
 */
import 'dart:isolate';
import 'dart:wasm';

import 'package:flutter/services.dart';

import 'define.dart';

class Uint8 {}

class Uint32 {}

class Int64 {}

class Pointer<T> {
  int address;
  Pointer.fromAddress(int ptr) {
    address = ptr;
  }

  dynamic value;
  asTypedList(int count) {
    throw "No Implemented";
  }
}

typedef JSChannel = Pointer Function(Pointer ctx, Pointer method, Pointer argv);

class RuntimeOpaque {
  JSChannel channel;
  List<JSRef> ref = List();
  ReceivePort port;
  Future Function(Pointer) promsieToFuture;
}

final Map<Pointer, RuntimeOpaque> runtimeOpaques = Map();

String pointerToString(Pointer ptr) {
  throw "No Implemented";
}

Pointer stringToPointer(String str) {
  throw "No Implemented";
}

void free(Pointer ptr){
  throw "No Implemented";
}

Pointer allocate<T>({int count}){
  throw "No Implemented";
}

WasmInstance _inst;

void wasmInit() async {
  var bundle = await rootBundle.load("packages/flutter_qjs/web/build/ffiquickjs.wasm");
  _inst = WasmModule(bundle.buffer.asUint8List()).instantiate(WasmImports());
}

/// JSValue *jsThrowInternalError(JSContext *ctx, char *message)
// final Pointer Function(
//   Pointer ctx,
//   Pointer<Utf8> message,
// ) _jsThrowInternalError = qjsLib
//     .lookup<
//         NativeFunction<
//             Pointer Function(
//       Pointer,
//       Pointer<Utf8>,
//     )>>("jsThrowInternalError")
//     .asFunction();

Pointer jsThrowInternalError(Pointer ctx, String message) {
  // var utf8message = Utf8.toUtf8(message);
  // var val = _jsThrowInternalError(ctx, utf8message);
  // free(utf8message);
  // return val;
  throw "No Implemented";
}

/// JSValue *jsEXCEPTION()
// final Pointer Function() jsEXCEPTION = qjsLib
//     .lookup<NativeFunction<Pointer Function()>>("jsEXCEPTION")
//     .asFunction();

Pointer jsEXCEPTION() {
  throw "No Implemented";
}

/// JSValue *jsUNDEFINED()
// final Pointer Function() jsUNDEFINED = qjsLib
//     .lookup<NativeFunction<Pointer Function()>>("jsUNDEFINED")
//     .asFunction();

Pointer jsUNDEFINED() {
  throw "No Implemented";
}

/// JSRuntime *jsNewRuntime(JSChannel channel)
// final Pointer Function(
//   Pointer<NativeFunction<Pointer Function(Pointer ctx, Pointer method, Pointer argv)>>,
// ) _jsNewRuntime = qjsLib
//     .lookup<
//         NativeFunction<
//             Pointer Function(
//       Pointer,
//     )>>("jsNewRuntime")
//     .asFunction();

Pointer channelDispacher(Pointer ctx, Pointer method, Pointer argv) {
  return runtimeOpaques[jsGetRuntime(ctx)].channel(ctx, method, argv);
}

Pointer jsNewRuntime(
  JSChannel callback,
  ReceivePort port,
) {
  // var rt = _jsNewRuntime(Pointer.fromFunction(channelDispacher));
  // runtimeOpaques[rt] = RuntimeOpaque()
  //   ..channel = callback
  //   ..port = port;
  // return rt;
  throw "No Implemented";
}

/// void jsFreeRuntime(JSRuntime *rt)
// final void Function(
//   Pointer,
// ) _jsFreeRuntime = qjsLib
//     .lookup<
//         NativeFunction<
//             Void Function(
//       Pointer,
//     )>>("jsFreeRuntime")
//     .asFunction();

void jsFreeRuntime(
  Pointer rt,
) {
  // runtimeOpaques[rt]?.ref?.forEach((val) {
  //   val.release();
  // });
  // runtimeOpaques.remove(rt);
  // _jsFreeRuntime(rt);
  throw "No Implemented";
}

/// JSContext *jsNewContext(JSRuntime *rt)
// final Pointer Function(
//   Pointer rt,
// ) jsNewContext = qjsLib
//     .lookup<
//         NativeFunction<
//             Pointer Function(
//       Pointer,
//     )>>("jsNewContext")
//     .asFunction();

Pointer jsNewContext(
  Pointer rt,
) {
  throw "No Implemented";
}

/// void jsFreeContext(JSContext *ctx)
// final void Function(
//   Pointer ctx,
// ) jsFreeContext = qjsLib
//     .lookup<
//         NativeFunction<
//             Void Function(
//       Pointer,
//     )>>("jsFreeContext")
//     .asFunction();
void jsFreeContext(
  Pointer ctx,
) {
  throw "No Implemented";
}

/// JSRuntime *jsGetRuntime(JSContext *ctx)
// final Pointer Function(
//   Pointer,
// ) jsGetRuntime = qjsLib
//     .lookup<
//         NativeFunction<
//             Pointer Function(
//       Pointer,
//     )>>("jsGetRuntime")
//     .asFunction();
Pointer jsGetRuntime(
  Pointer ctx,
) {
  throw "No Implemented";
}

/// JSValue *jsEval(JSContext *ctx, const char *input, size_t input_len, const char *filename, int eval_flags)
// final Pointer Function(
//   Pointer ctx,
//   Pointer<Utf8> input,
//   int inputLen,
//   Pointer<Utf8> filename,
//   int evalFlags,
// ) _jsEval = qjsLib
//     .lookup<
//         NativeFunction<
//             Pointer Function(
//       Pointer,
//       Pointer<Utf8>,
//       Int64,
//       Pointer<Utf8>,
//       Int32,
//     )>>("jsEval")
//     .asFunction();

Pointer jsEval(
  Pointer ctx,
  String input,
  String filename,
  int evalFlags,
) {
  // var utf8input = Utf8.toUtf8(input);
  // var utf8filename = Utf8.toUtf8(filename);
  // var val = _jsEval(
  //   ctx,
  //   utf8input,
  //   Utf8.strlen(utf8input),
  //   utf8filename,
  //   evalFlags,
  // );
  // free(utf8input);
  // free(utf8filename);
  // runtimeOpaques[jsGetRuntime(ctx)].port.sendPort.send('eval');
  // return val;
  throw "No Implemented";
}

/// DLLEXPORT int32_t jsValueGetTag(JSValue *val)
// final int Function(
//   Pointer val,
// ) jsValueGetTag = qjsLib
//     .lookup<
//         NativeFunction<
//             Int32 Function(
//       Pointer,
//     )>>("jsValueGetTag")
//     .asFunction();
int jsValueGetTag(
  Pointer val,
) {
  throw "No Implemented";
}

/// void *jsValueGetPtr(JSValue *val)
// final Pointer Function(
//   Pointer val,
// ) jsValueGetPtr = qjsLib
//     .lookup<
//         NativeFunction<
//             Pointer Function(
//       Pointer,
//     )>>("jsValueGetPtr")
//     .asFunction();
Pointer jsValueGetPtr(
  Pointer val,
) {
  throw "No Implemented";
}

/// DLLEXPORT bool jsTagIsFloat64(int32_t tag)
// final int Function(
//   int val,
// ) jsTagIsFloat64 = qjsLib
//     .lookup<
//         NativeFunction<
//             Int32 Function(
//       Int32,
//     )>>("jsTagIsFloat64")
//     .asFunction();
int jsTagIsFloat64(
  int val,
) {
  throw "No Implemented";
}

/// JSValue *jsNewBool(JSContext *ctx, int val)
// final Pointer Function(
//   Pointer ctx,
//   int val,
// ) jsNewBool = qjsLib
//     .lookup<
//         NativeFunction<
//             Pointer Function(
//       Pointer,
//       Int32,
//     )>>("jsNewBool")
//     .asFunction();
Pointer jsNewBool(
  Pointer ctx,
  int val,
) {
  throw "No Implemented";
}

/// JSValue *jsNewInt64(JSContext *ctx, int64_t val)
// final Pointer Function(
//   Pointer ctx,
//   int val,
// ) jsNewInt64 = qjsLib
//     .lookup<
//         NativeFunction<
//             Pointer Function(
//       Pointer,
//       Int64,
//     )>>("jsNewInt64")
//     .asFunction();
Pointer jsNewInt64(
  Pointer ctx,
  int val,
) {
  throw "No Implemented";
}

/// JSValue *jsNewFloat64(JSContext *ctx, double val)
// final Pointer Function(
//   Pointer ctx,
//   double val,
// ) jsNewFloat64 = qjsLib
//     .lookup<
//         NativeFunction<
//             Pointer Function(
//       Pointer,
//       Double,
//     )>>("jsNewFloat64")
//     .asFunction();
Pointer jsNewFloat64(
  Pointer ctx,
  double val,
) {
  throw "No Implemented";
}

/// JSValue *jsNewString(JSContext *ctx, const char *str)
// final Pointer Function(
//   Pointer ctx,
//   Pointer<Utf8> str,
// ) _jsNewString = qjsLib
//     .lookup<
//         NativeFunction<
//             Pointer Function(
//       Pointer,
//       Pointer<Utf8>,
//     )>>("jsNewString")
//     .asFunction();

Pointer jsNewString(
  Pointer ctx,
  String str,
) {
  // var utf8str = Utf8.toUtf8(str);
  // return _jsNewString(ctx, utf8str);
  throw "No Implemented";
}

/// JSValue *jsNewArrayBufferCopy(JSContext *ctx, const uint8_t *buf, size_t len)
// final Pointer Function(
//   Pointer ctx,
//   Pointer<Uint8> buf,
//   int len,
// ) jsNewArrayBufferCopy = qjsLib
//     .lookup<
//         NativeFunction<
//             Pointer Function(
//       Pointer,
//       Pointer<Uint8>,
//       Uint64,
//     )>>("jsNewArrayBufferCopy")
//     .asFunction();
Pointer jsNewArrayBufferCopy(
  Pointer ctx,
  Pointer buf,
  int len,
) {
  throw "No Implemented";
}

/// JSValue *jsNewArray(JSContext *ctx)
// final Pointer Function(
//   Pointer ctx,
// ) jsNewArray = qjsLib
//     .lookup<
//         NativeFunction<
//             Pointer Function(
//       Pointer,
//     )>>("jsNewArray")
//     .asFunction();
Pointer jsNewArray(
  Pointer ctx,
) {
  throw "No Implemented";
}

/// JSValue *jsNewObject(JSContext *ctx)
// final Pointer Function(
//   Pointer ctx,
// ) jsNewObject = qjsLib
//     .lookup<
//         NativeFunction<
//             Pointer Function(
//       Pointer,
//     )>>("jsNewObject")
//     .asFunction();
Pointer jsNewObject(
  Pointer ctx,
) {
  throw "No Implemented";
}

/// void jsFreeValue(JSContext *ctx, JSValue *val)
// final void Function(
//   Pointer ctx,
//   Pointer val,
// ) jsFreeValue = qjsLib
//     .lookup<
//         NativeFunction<
//             Void Function(
//       Pointer,
//       Pointer,
//     )>>("jsFreeValue")
//     .asFunction();
void jsFreeValue(
  Pointer ctx,
  Pointer val,
) {
  throw "No Implemented";
}

/// void jsFreeValueRT(JSRuntime *rt, JSValue *v)
// final void Function(
//   Pointer rt,
//   Pointer val,
// ) jsFreeValueRT = qjsLib
//     .lookup<
//         NativeFunction<
//             Void Function(
//       Pointer,
//       Pointer,
//     )>>("jsFreeValueRT")
//     .asFunction();
void jsFreeValueRT(
  Pointer rt,
  Pointer val,
) {
  throw "No Implemented";
}

/// JSValue *jsDupValue(JSContext *ctx, JSValueConst *v)
// final Pointer Function(
//   Pointer ctx,
//   Pointer val,
// ) jsDupValue = qjsLib
//     .lookup<
//         NativeFunction<
//             Pointer Function(
//       Pointer,
//       Pointer,
//     )>>("jsDupValue")
//     .asFunction();
Pointer jsDupValue(
  Pointer ctx,
  Pointer val,
) {
  throw "No Implemented";
}

/// JSValue *jsDupValueRT(JSRuntime *rt, JSValue *v)
// final Pointer Function(
//   Pointer rt,
//   Pointer val,
// ) jsDupValueRT = qjsLib
//     .lookup<
//         NativeFunction<
//             Pointer Function(
//       Pointer,
//       Pointer,
//     )>>("jsDupValueRT")
//     .asFunction();
Pointer jsDupValueRT(
  Pointer rt,
  Pointer val,
) {
  throw "No Implemented";
}

/// int32_t jsToBool(JSContext *ctx, JSValueConst *val)
// final int Function(
//   Pointer ctx,
//   Pointer val,
// ) jsToBool = qjsLib
//     .lookup<
//         NativeFunction<
//             Int32 Function(
//       Pointer,
//       Pointer,
//     )>>("jsToBool")
//     .asFunction();
int jsToBool(
  Pointer ctx,
  Pointer val,
) {
  throw "No Implemented";
}

/// int64_t jsToFloat64(JSContext *ctx, JSValueConst *val)
// final int Function(
//   Pointer ctx,
//   Pointer val,
// ) jsToInt64 = qjsLib
//     .lookup<
//         NativeFunction<
//             Int64 Function(
//       Pointer,
//       Pointer,
//     )>>("jsToInt64")
//     .asFunction();
int jsToInt64(
  Pointer ctx,
  Pointer val,
) {
  throw "No Implemented";
}

/// double jsToFloat64(JSContext *ctx, JSValueConst *val)
// final double Function(
//   Pointer ctx,
//   Pointer val,
// ) jsToFloat64 = qjsLib
//     .lookup<
//         NativeFunction<
//             Double Function(
//       Pointer,
//       Pointer,
//     )>>("jsToFloat64")
//     .asFunction();
double jsToFloat64(
  Pointer ctx,
  Pointer val,
) {
  throw "No Implemented";
}


/// const char *jsToCString(JSContext *ctx, JSValue *val)
// final Pointer<Utf8> Function(
//   Pointer ctx,
//   Pointer val,
// ) _jsToCString = qjsLib
//     .lookup<
//         NativeFunction<
//             Pointer<Utf8> Function(
//       Pointer,
//       Pointer,
//     )>>("jsToCString")
//     .asFunction();

/// void jsFreeCString(JSContext *ctx, const char *ptr)
// final void Function(
//   Pointer ctx,
//   Pointer<Utf8> val,
// ) jsFreeCString = qjsLib
//     .lookup<
//         NativeFunction<
//             Void Function(
//       Pointer,
//       Pointer<Utf8>,
//     )>>("jsFreeCString")
//     .asFunction();
void jsFreeCString(
  Pointer ctx,
  Pointer val,
) {
  throw "No Implemented";
}

String jsToCString(
  Pointer ctx,
  Pointer val,
) {
  // var ptr = _jsToCString(ctx, val);
  // if (ptr.address == 0) throw Exception("JSValue cannot convert to string");
  // var str = Utf8.fromUtf8(ptr);
  // jsFreeCString(ctx, ptr);
  // return str;
  throw "No Implemented";
}

/// uint8_t *jsGetArrayBuffer(JSContext *ctx, size_t *psize, JSValueConst *obj)
// final Pointer<Uint8> Function(
//   Pointer ctx,
//   Pointer<Int64> psize,
//   Pointer val,
// ) jsGetArrayBuffer = qjsLib
//     .lookup<
//         NativeFunction<
//             Pointer<Uint8> Function(
//       Pointer,
//       Pointer<Int64>,
//       Pointer,
//     )>>("jsGetArrayBuffer")
//     .asFunction();
Pointer jsGetArrayBuffer(
  Pointer ctx,
  Pointer psize,
  Pointer val,
) {
  throw "No Implemented";
}

/// int32_t jsIsFunction(JSContext *ctx, JSValueConst *val)
// final int Function(
//   Pointer ctx,
//   Pointer val,
// ) jsIsFunction = qjsLib
//     .lookup<
//         NativeFunction<
//             Int32 Function(
//       Pointer,
//       Pointer,
//     )>>("jsIsFunction")
//     .asFunction();
int jsIsFunction(
  Pointer ctx,
  Pointer val,
) {
  throw "No Implemented";
}

/// int32_t jsIsArray(JSContext *ctx, JSValueConst *val)
// final int Function(
//   Pointer ctx,
//   Pointer val,
// ) jsIsArray = qjsLib
//     .lookup<
//         NativeFunction<
//             Int32 Function(
//       Pointer,
//       Pointer,
//     )>>("jsIsArray")
//     .asFunction();
int jsIsArray(
  Pointer ctx,
  Pointer val,
) {
  throw "No Implemented";
}

/// JSValue *jsGetProperty(JSContext *ctx, JSValueConst *this_obj,
///                           JSAtom prop)
// final Pointer Function(
//   Pointer ctx,
//   Pointer thisObj,
//   int prop,
// ) jsGetProperty = qjsLib
//     .lookup<
//         NativeFunction<
//             Pointer Function(
//       Pointer,
//       Pointer,
//       Uint32,
//     )>>("jsGetProperty")
//     .asFunction();
Pointer jsGetProperty(
  Pointer ctx,
  Pointer thisObj,
  int prop,
) {
  throw "No Implemented";
}

/// int jsDefinePropertyValue(JSContext *ctx, JSValueConst *this_obj,
///                           JSAtom prop, JSValue *val, int flags)
// final int Function(
//   Pointer ctx,
//   Pointer thisObj,
//   int prop,
//   Pointer val,
//   int flag,
// ) jsDefinePropertyValue = qjsLib
//     .lookup<
//         NativeFunction<
//             Int32 Function(
//       Pointer,
//       Pointer,
//       Uint32,
//       Pointer,
//       Int32,
//     )>>("jsDefinePropertyValue")
//     .asFunction();
int jsDefinePropertyValue(
  Pointer ctx,
  Pointer thisObj,
  int prop,
  Pointer val,
  int flag,
) {
  throw "No Implemented";
}

/// void jsFreeAtom(JSContext *ctx, JSAtom v)
// final Pointer Function(
//   Pointer ctx,
//   int v,
// ) jsFreeAtom = qjsLib
//     .lookup<
//         NativeFunction<
//             Pointer Function(
//       Pointer,
//       Uint32,
//     )>>("jsFreeAtom")
//     .asFunction();
Pointer jsFreeAtom(
  Pointer ctx,
  int v,
) {
  throw "No Implemented";
}

/// JSAtom jsValueToAtom(JSContext *ctx, JSValueConst *val)
// final int Function(
//   Pointer ctx,
//   Pointer val,
// ) jsValueToAtom = qjsLib
//     .lookup<
//         NativeFunction<
//             Uint32 Function(
//       Pointer,
//       Pointer,
//     )>>("jsValueToAtom")
//     .asFunction();
int jsValueToAtom(
  Pointer ctx,
  Pointer val,
) {
  throw "No Implemented";
}

/// JSValue *jsAtomToValue(JSContext *ctx, JSAtom val)
// final Pointer Function(
//   Pointer ctx,
//   int val,
// ) jsAtomToValue = qjsLib
//     .lookup<
//         NativeFunction<
//             Pointer Function(
//       Pointer,
//       Uint32,
//     )>>("jsAtomToValue")
//     .asFunction();
Pointer jsAtomToValue(
  Pointer ctx,
  int val,
) {
  throw "No Implemented";
}

/// int jsGetOwnPropertyNames(JSContext *ctx, JSPropertyEnum **ptab,
///                           uint32_t *plen, JSValueConst *obj, int flags)
// final int Function(
//   Pointer ctx,
//   Pointer<Pointer> ptab,
//   Pointer<Uint32> plen,
//   Pointer obj,
//   int flags,
// ) jsGetOwnPropertyNames = qjsLib
//     .lookup<
//         NativeFunction<
//             Int32 Function(
//       Pointer,
//       Pointer<Pointer>,
//       Pointer<Uint32>,
//       Pointer,
//       Int32,
//     )>>("jsGetOwnPropertyNames")
//     .asFunction();
int jsGetOwnPropertyNames(
  Pointer ctx,
  Pointer ptab,
  Pointer plen,
  Pointer obj,
  int flags,
) {
  throw "No Implemented";
}

/// JSAtom jsPropertyEnumGetAtom(JSPropertyEnum *ptab, int i)
// final int Function(
//   Pointer ptab,
//   int i,
// ) jsPropertyEnumGetAtom = qjsLib
//     .lookup<
//         NativeFunction<
//             Uint32 Function(
//       Pointer,
//       Int32,
//     )>>("jsPropertyEnumGetAtom")
//     .asFunction();
int jsPropertyEnumGetAtom(
  Pointer ptab,
  int i,
) {
  throw "No Implemented";
}

/// uint32_t sizeOfJSValue()
// final int Function() _sizeOfJSValue =
//     qjsLib.lookup<NativeFunction<Uint32 Function()>>("sizeOfJSValue").asFunction();

final sizeOfJSValue = -1; //_sizeOfJSValue();

/// void setJSValueList(JSValue *list, int i, JSValue *val)
// final void Function(
//   Pointer list,
//   int i,
//   Pointer val,
// ) setJSValueList = qjsLib
//     .lookup<
//         NativeFunction<
//             Void Function(
//       Pointer,
//       Uint32,
//       Pointer,
//     )>>("setJSValueList")
//     .asFunction();
void setJSValueList(
  Pointer list,
  int i,
  Pointer val,
) {
  throw "No Implemented";
}

/// JSValue *jsCall(JSContext *ctx, JSValueConst *func_obj, JSValueConst *this_obj,
///                 int argc, JSValueConst *argv)
// final Pointer Function(
//   Pointer ctx,
//   Pointer funcObj,
//   Pointer thisObj,
//   int argc,
//   Pointer argv,
// ) _jsCall = qjsLib
//     .lookup<
//         NativeFunction<
//             Pointer Function(
//       Pointer,
//       Pointer,
//       Pointer,
//       Int32,
//       Pointer,
//     )>>("jsCall")
//     .asFunction();

Pointer jsCall(
  Pointer ctx,
  Pointer funcObj,
  Pointer thisObj,
  List<Pointer> argv,
) {
  // Pointer jsArgs = allocate<Uint8>(
  //   count: argv.length > 0 ? sizeOfJSValue * argv.length : 1,
  // );
  // for (int i = 0; i < argv.length; ++i) {
  //   Pointer jsArg = argv[i];
  //   setJSValueList(jsArgs, i, jsArg);
  // }
  // Pointer func1 = jsDupValue(ctx, funcObj);
  // Pointer _thisObj = thisObj ?? jsUNDEFINED();
  // Pointer jsRet = _jsCall(ctx, funcObj, _thisObj, argv.length, jsArgs);
  // if (thisObj == null) {
  //   jsFreeValue(ctx, _thisObj);
  // }
  // jsFreeValue(ctx, func1);
  // free(jsArgs);
  // runtimeOpaques[jsGetRuntime(ctx)].port.sendPort.send('call');
  // return jsRet;
  throw "No Implemented";
}

/// int jsIsException(JSValueConst *val)
// final int Function(
//   Pointer val,
// ) jsIsException = qjsLib
//     .lookup<
//         NativeFunction<
//             Int32 Function(
//       Pointer,
//     )>>("jsIsException")
//     .asFunction();
int jsIsException(
  Pointer val,
) {
  throw "No Implemented";
}

/// JSValue *jsGetException(JSContext *ctx)
// final Pointer Function(
//   Pointer ctx,
// ) jsGetException = qjsLib
//     .lookup<
//         NativeFunction<
//             Pointer Function(
//       Pointer,
//     )>>("jsGetException")
//     .asFunction();
Pointer jsGetException(
  Pointer ctx,
) {
  throw "No Implemented";
}

/// int jsExecutePendingJob(JSRuntime *rt)
// final int Function(
//   Pointer ctx,
// ) jsExecutePendingJob = qjsLib
//     .lookup<
//         NativeFunction<
//             Int32 Function(
//       Pointer,
//     )>>("jsExecutePendingJob")
//     .asFunction();
int jsExecutePendingJob(
  Pointer ctx,
) {
  throw "No Implemented";
}

/// JSValue *jsNewPromiseCapability(JSContext *ctx, JSValue *resolving_funcs)
// final Pointer Function(
//   Pointer ctx,
//   Pointer resolvingFuncs,
// ) jsNewPromiseCapability = qjsLib
//     .lookup<
//         NativeFunction<
//             Pointer Function(
//       Pointer,
//       Pointer,
//     )>>("jsNewPromiseCapability")
//     .asFunction();
Pointer jsNewPromiseCapability(
  Pointer ctx,
  Pointer resolvingFuncs,
) {
  throw "No Implemented";
}

/// void jsFree(JSContext *ctx, void *ptab)
// final void Function(
//   Pointer ctx,
//   Pointer ptab,
// ) jsFree = qjsLib
//     .lookup<
//         NativeFunction<
//             Void Function(
//       Pointer,
//       Pointer,
//     )>>("jsFree")
//     .asFunction();
void jsFree(
  Pointer ctx,
  Pointer ptab,
) {
  throw "No Implemented";
}
