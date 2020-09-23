/*
 * @Description: 
 * @Author: ekibun
 * @Date: 2020-09-06 18:32:45
 * @LastEditors: ekibun
 * @LastEditTime: 2020-09-24 00:28:11
 */
#include "quickjs/quickjs.h"
#include <functional>
#include <future>
#include <string.h>

#ifdef _MSC_VER
#define DLLEXPORT __declspec(dllexport)
#else
#define DLLEXPORT __attribute__((visibility("default"))) __attribute__((used))
#endif

extern "C"
{
  typedef void *JSChannel(JSContext *ctx, const char *method, void *argv);

  DLLEXPORT JSValue *jsThrowInternalError(JSContext *ctx, char *message)
  {
    return new JSValue(JS_ThrowInternalError(ctx, "%s", message));
  }

  DLLEXPORT JSValue *jsEXCEPTION()
  {
    return new JSValue(JS_EXCEPTION);
  }

  DLLEXPORT JSValue *jsUNDEFINED()
  {
    return new JSValue(JS_UNDEFINED);
  }

  DLLEXPORT JSValue *jsNULL()
  {
    return new JSValue(JS_NULL);
  }

  JSModuleDef *js_module_loader(
      JSContext *ctx,
      const char *module_name, void *opaque)
  {
    JSRuntime *rt = JS_GetRuntime(ctx);
    JSChannel *channel = (JSChannel *)JS_GetRuntimeOpaque(rt);
    const char *str = (char *)channel(ctx, (char *)0, (void *)module_name);
    if (str == 0)
      return NULL;
    JSValue func_val = JS_Eval(ctx, str, strlen(str), module_name, JS_EVAL_TYPE_MODULE | JS_EVAL_FLAG_COMPILE_ONLY);
    if (JS_IsException(func_val))
      return NULL;
    /* the module is already referenced, so we must free it */
    JSModuleDef *m = (JSModuleDef *)JS_VALUE_GET_PTR(func_val);
    JS_FreeValue(ctx, func_val);
    return m;
  }

  JSValue js_channel(JSContext *ctx, JSValueConst this_val, int argc, JSValueConst *argv)
  {
    JSRuntime *rt = JS_GetRuntime(ctx);
    JSChannel *channel = (JSChannel *)JS_GetRuntimeOpaque(rt);
    const char *str = JS_ToCString(ctx, argv[0]);
    JS_DupValue(ctx, *(argv + 1));
    JSValue ret = *(JSValue *)channel(ctx, str, argv + 1);
    JS_FreeValue(ctx, *(argv + 1));
    JS_FreeCString(ctx, str);
    return ret;
  }

  DLLEXPORT JSRuntime *jsNewRuntime(JSChannel channel)
  {
    JSRuntime *rt = JS_NewRuntime();
    JS_SetRuntimeOpaque(rt, (void *)channel);
    JS_SetModuleLoaderFunc(rt, nullptr, js_module_loader, nullptr);
    return rt;
  }

  DLLEXPORT void jsFreeRuntime(JSRuntime *rt)
  {
    JS_SetRuntimeOpaque(rt, nullptr);
    JS_FreeRuntime(rt);
  }

  DLLEXPORT JSContext *jsNewContext(JSRuntime *rt)
  {
    JSContext *ctx = JS_NewContext(rt);
    JSAtom atom = JS_NewAtom(ctx, "channel");
    JSValue globalObject = JS_GetGlobalObject(ctx);
    JS_SetProperty(ctx, globalObject, atom, JS_NewCFunction(ctx, js_channel, "channel", 2));
    JS_FreeValue(ctx, globalObject);
    JS_FreeAtom(ctx, atom);
    return ctx;
  }

  DLLEXPORT void jsFreeContext(JSContext *ctx)
  {
    JS_FreeContext(ctx);
  }

  DLLEXPORT JSRuntime *jsGetRuntime(JSContext *ctx)
  {
    return JS_GetRuntime(ctx);
  }

  DLLEXPORT JSValue *jsEval(JSContext *ctx, const char *input, size_t input_len, const char *filename, int eval_flags)
  {
    return new JSValue(JS_Eval(ctx, input, input_len, filename, eval_flags));
  }

  DLLEXPORT int32_t jsValueGetTag(JSValue *val)
  {
    return JS_VALUE_GET_TAG(*val);
  }

  DLLEXPORT void *jsValueGetPtr(JSValue *val)
  {
    return JS_VALUE_GET_PTR(*val);
  }

  DLLEXPORT int32_t jsTagIsFloat64(int32_t tag)
  {
    return JS_TAG_IS_FLOAT64(tag);
  }

  DLLEXPORT JSValue *jsNewBool(JSContext *ctx, int val)
  {
    return new JSValue(JS_NewBool(ctx, val));
  }

  DLLEXPORT JSValue *jsNewInt64(JSContext *ctx, int64_t val)
  {
    return new JSValue(JS_NewInt64(ctx, val));
  }

  DLLEXPORT JSValue *jsNewFloat64(JSContext *ctx, double val)
  {
    return new JSValue(JS_NewFloat64(ctx, val));
  }

  DLLEXPORT JSValue *jsNewString(JSContext *ctx, const char *str)
  {
    return new JSValue(JS_NewString(ctx, str));
  }

  DLLEXPORT JSValue *jsNewArrayBufferCopy(JSContext *ctx, const uint8_t *buf, size_t len)
  {
    return new JSValue(JS_NewArrayBufferCopy(ctx, buf, len));
  }

  DLLEXPORT JSValue *jsNewArray(JSContext *ctx)
  {
    return new JSValue(JS_NewArray(ctx));
  }

  DLLEXPORT JSValue *jsNewObject(JSContext *ctx)
  {
    return new JSValue(JS_NewObject(ctx));
  }

  DLLEXPORT void jsFreeValue(JSContext *ctx, JSValue *v)
  {
    JS_FreeValue(ctx, *v);
  }

  DLLEXPORT void jsFreeValueRT(JSRuntime *rt, JSValue *v)
  {
    JS_FreeValueRT(rt, *v);
  }

  DLLEXPORT JSValue *jsDupValue(JSContext *ctx, JSValueConst *v)
  {
    return new JSValue(JS_DupValue(ctx, *v));
  }

  DLLEXPORT JSValue *jsDupValueRT(JSRuntime *rt, JSValue *v)
  {
    return new JSValue(JS_DupValueRT(rt, *v));
  }

  DLLEXPORT int32_t jsToBool(JSContext *ctx, JSValueConst *val)
  {
    return JS_ToBool(ctx, *val);
  }

  DLLEXPORT int64_t jsToInt64(JSContext *ctx, JSValueConst *val)
  {
    int64_t p;
    JS_ToInt64(ctx, &p, *val);
    return p;
  }

  DLLEXPORT double jsToFloat64(JSContext *ctx, JSValueConst *val)
  {
    double p;
    JS_ToFloat64(ctx, &p, *val);
    return p;
  }

  DLLEXPORT const char *jsToCString(JSContext *ctx, JSValueConst *val)
  {
    return JS_ToCString(ctx, *val);
  }

  DLLEXPORT void jsFreeCString(JSContext *ctx, const char *ptr)
  {
    return JS_FreeCString(ctx, ptr);
  }

  DLLEXPORT uint8_t *jsGetArrayBuffer(JSContext *ctx, size_t *psize, JSValueConst *obj)
  {
    return JS_GetArrayBuffer(ctx, psize, *obj);
  }

  DLLEXPORT int32_t jsIsFunction(JSContext *ctx, JSValueConst *val)
  {
    return JS_IsFunction(ctx, *val);
  }

  DLLEXPORT int32_t jsIsArray(JSContext *ctx, JSValueConst *val)
  {
    return JS_IsArray(ctx, *val);
  }

  DLLEXPORT void deleteJSValue(JSValueConst *val)
  {
    delete val;
  }

  DLLEXPORT JSValue *jsGetProperty(JSContext *ctx, JSValueConst *this_obj,
                                   JSAtom prop)
  {
    return new JSValue(JS_GetProperty(ctx, *this_obj, prop));
  }

  DLLEXPORT int jsDefinePropertyValue(JSContext *ctx, JSValueConst *this_obj,
                                      JSAtom prop, JSValue *val, int flags)
  {
    return JS_DefinePropertyValue(ctx, *this_obj, prop, *val, flags);
  }

  DLLEXPORT void jsFreeAtom(JSContext *ctx, JSAtom v)
  {
    JS_FreeAtom(ctx, v);
  }

  DLLEXPORT JSAtom jsValueToAtom(JSContext *ctx, JSValueConst *val)
  {
    return JS_ValueToAtom(ctx, *val);
  }

  DLLEXPORT JSValue *jsAtomToValue(JSContext *ctx, JSAtom val)
  {
    return new JSValue(JS_AtomToValue(ctx, val));
  }

  DLLEXPORT int jsGetOwnPropertyNames(JSContext *ctx, JSPropertyEnum **ptab,
                                      uint32_t *plen, JSValueConst *obj, int flags)
  {
    return JS_GetOwnPropertyNames(ctx, ptab, plen, *obj, flags);
  }

  DLLEXPORT JSAtom jsPropertyEnumGetAtom(JSPropertyEnum *ptab, int i)
  {
    return ptab[i].atom;
  }

  DLLEXPORT uint32_t sizeOfJSValue()
  {
    return sizeof (JSValue);
  }

  DLLEXPORT void setJSValueList(JSValue *list, uint32_t i, JSValue *val)
  {
    list[i] = *val;
  }

  DLLEXPORT JSValue *jsCall(JSContext *ctx, JSValueConst *func_obj, JSValueConst *this_obj,
                            int argc, JSValueConst *argv)
  {
    return new JSValue(JS_Call(ctx, *func_obj, *this_obj, argc, argv));
  }

  DLLEXPORT int jsIsException(JSValueConst *val)
  {
    return JS_IsException(*val);
  }

  DLLEXPORT JSValue *jsGetException(JSContext *ctx)
  {
    return new JSValue(JS_GetException(ctx));
  }

  DLLEXPORT int jsExecutePendingJob(JSRuntime *rt)
  {
    JSContext *ctx;
    return JS_ExecutePendingJob(rt, &ctx);
  }

  DLLEXPORT JSValue *jsNewPromiseCapability(JSContext *ctx, JSValue *resolving_funcs)
  {
    return new JSValue(JS_NewPromiseCapability(ctx, resolving_funcs));
  }
}