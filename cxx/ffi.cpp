/*
 * @Description: 
 * @Author: ekibun
 * @Date: 2020-09-06 18:32:45
 * @LastEditors: ekibun
 * @LastEditTime: 2020-12-02 11:11:42
 */
#include "ffi.h"
#include <functional>
#include <future>
#include <string.h>

extern "C"
{

  DLLEXPORT JSValue *jsThrow(JSContext *ctx, JSValue *obj)
  {
    return new JSValue(JS_Throw(ctx, JS_DupValue(ctx, *obj)));
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
    const char *str = (char *)channel(ctx, JSChannelType_MODULE, (void *)module_name);
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

  JSValue js_channel(JSContext *ctx, JSValueConst this_val, int argc, JSValueConst *argv, int magic, JSValue *func_data)
  {
    JSRuntime *rt = JS_GetRuntime(ctx);
    JSChannel *channel = (JSChannel *)JS_GetRuntimeOpaque(rt);
    void *data[4];
    data[0] = &this_val;
    data[1] = &argc;
    data[2] = argv;
    data[3] = func_data;
    return *(JSValue *)channel(ctx, JSChannelType_METHON, data);
  }

  void js_promise_rejection_tracker(JSContext *ctx, JSValueConst promise,
                                    JSValueConst reason,
                                    JS_BOOL is_handled, void *opaque)
  {
    if (is_handled)
      return;
    JSRuntime *rt = JS_GetRuntime(ctx);
    JSChannel *channel = (JSChannel *)JS_GetRuntimeOpaque(rt);
    channel(ctx, JSChannelType_PROMISE_TRACK, &reason);
  }

  DLLEXPORT JSRuntime *jsNewRuntime(JSChannel channel)
  {
    JSRuntime *rt = JS_NewRuntime();
    JS_SetRuntimeOpaque(rt, (void *)channel);
    JS_SetHostPromiseRejectionTracker(rt, js_promise_rejection_tracker, nullptr);
    JS_SetModuleLoaderFunc(rt, nullptr, js_module_loader, nullptr);
    return rt;
  }

  DLLEXPORT uint32_t jsNewClass(JSContext *ctx, const char *name)
  {
    JSClassID QJSClassId = 0;
    JS_NewClassID(&QJSClassId);
    JSRuntime *rt = JS_GetRuntime(ctx);
    if (!JS_IsRegisteredClass(rt, QJSClassId))
    {
      JSClassDef def{
          name,
          // destructor
          [](JSRuntime *rt, JSValue obj) noexcept {
            JSClassID classid = JS_GetClassID(obj);
            void *opaque = JS_GetOpaque(obj, classid);
            JSChannel *channel = (JSChannel *)JS_GetRuntimeOpaque(rt);
            if (channel == nullptr)
              return;
            channel((JSContext *)rt, JSChannelType_FREE_OBJECT, opaque);
          }};
      int e = JS_NewClass(rt, QJSClassId, &def);
      if (e < 0)
      {
        JS_ThrowInternalError(ctx, "Cant register class %s", name);
        return 0;
      }
    }
    return QJSClassId;
  }

  DLLEXPORT void *jsGetObjectOpaque(JSValue *obj, uint32_t classid)
  {
    return JS_GetOpaque(*obj, classid);
  }

  DLLEXPORT JSValue *jsNewObjectClass(JSContext *ctx, uint32_t QJSClassId, void *opaque)
  {
    auto jsobj = new JSValue(JS_NewObjectClass(ctx, QJSClassId));
    if (JS_IsException(*jsobj))
      return jsobj;
    JS_SetOpaque(*jsobj, opaque);
    return jsobj;
  }

  DLLEXPORT void jsSetMaxStackSize(JSRuntime *rt, size_t stack_size)
  {
    JS_SetMaxStackSize(rt, stack_size);
  }

  DLLEXPORT void jsFreeRuntime(JSRuntime *rt)
  {
    JS_SetRuntimeOpaque(rt, nullptr);
    JS_FreeRuntime(rt);
  }

  DLLEXPORT JSValue *jsNewCFunction(JSContext *ctx, JSValue *funcData)
  {
    return new JSValue(JS_NewCFunctionData(ctx, js_channel, 0, 0, 1, funcData));
  }

  DLLEXPORT JSContext *jsNewContext(JSRuntime *rt)
  {
    JSContext *ctx = JS_NewContext(rt);
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

  DLLEXPORT JSValue *jsEval(JSContext *ctx, const char *input, size_t input_len, const char *filename, int32_t eval_flags)
  {
    JSRuntime *rt = JS_GetRuntime(ctx);
    JS_UpdateStackTop(rt);
    JSValue *ret = new JSValue(JS_Eval(ctx, input, input_len, filename, eval_flags));
    return ret;
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

  DLLEXPORT JSValue *jsNewBool(JSContext *ctx, int32_t val)
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

  DLLEXPORT void jsFreeValue(JSContext *ctx, JSValue *v, int32_t free)
  {
    JS_FreeValue(ctx, *v);
    if (free)
      delete v;
  }

  DLLEXPORT void jsFreeValueRT(JSRuntime *rt, JSValue *v, int32_t free)
  {
    JS_FreeValueRT(rt, *v);
    if (free)
      delete v;
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
    JSRuntime *rt = JS_GetRuntime(ctx);
    JS_UpdateStackTop(rt);
    const char *ret = JS_ToCString(ctx, *val);
    return ret;
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

  DLLEXPORT int32_t jsIsPromise(JSContext *ctx, JSValueConst *val)
  {
    return JS_IsPromise(ctx, *val);
  }

  DLLEXPORT int32_t jsIsArray(JSContext *ctx, JSValueConst *val)
  {
    return JS_IsArray(ctx, *val);
  }

  DLLEXPORT int32_t jsIsError(JSContext *ctx, JSValueConst *val)
  {
    return JS_IsError(ctx, *val);
  }

  DLLEXPORT JSValue *jsNewError(JSContext *ctx)
  {
    return new JSValue(JS_NewError(ctx));
  }

  DLLEXPORT JSValue *jsGetProperty(JSContext *ctx, JSValueConst *this_obj,
                                   JSAtom prop)
  {
    return new JSValue(JS_GetProperty(ctx, *this_obj, prop));
  }

  DLLEXPORT int32_t jsDefinePropertyValue(JSContext *ctx, JSValueConst *this_obj,
                                          JSAtom prop, JSValue *val, int32_t flags)
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

  DLLEXPORT int32_t jsGetOwnPropertyNames(JSContext *ctx, JSPropertyEnum **ptab,
                                          uint32_t *plen, JSValueConst *obj, int32_t flags)
  {
    return JS_GetOwnPropertyNames(ctx, ptab, plen, *obj, flags);
  }

  DLLEXPORT JSAtom jsPropertyEnumGetAtom(JSPropertyEnum *ptab, int32_t i)
  {
    return ptab[i].atom;
  }

  DLLEXPORT uint32_t sizeOfJSValue()
  {
    return sizeof(JSValue);
  }

  DLLEXPORT void setJSValueList(JSValue *list, uint32_t i, JSValue *val)
  {
    list[i] = *val;
  }

  DLLEXPORT JSValue *jsCall(JSContext *ctx, JSValueConst *func_obj, JSValueConst *this_obj,
                            int32_t argc, JSValueConst *argv)
  {
    JSRuntime *rt = JS_GetRuntime(ctx);
    JS_UpdateStackTop(rt);
    JSValue *ret = new JSValue(JS_Call(ctx, *func_obj, *this_obj, argc, argv));
    return ret;
  }

  DLLEXPORT int32_t jsIsException(JSValueConst *val)
  {
    return JS_IsException(*val);
  }

  DLLEXPORT JSValue *jsGetException(JSContext *ctx)
  {
    return new JSValue(JS_GetException(ctx));
  }

  DLLEXPORT int32_t jsExecutePendingJob(JSRuntime *rt)
  {
    JS_UpdateStackTop(rt);
    JSContext *ctx;
    int ret = JS_ExecutePendingJob(rt, &ctx);
    return ret;
  }

  DLLEXPORT JSValue *jsNewPromiseCapability(JSContext *ctx, JSValue *resolving_funcs)
  {
    return new JSValue(JS_NewPromiseCapability(ctx, resolving_funcs));
  }

  DLLEXPORT void jsFree(JSContext *ctx, void *ptab)
  {
    js_free(ctx, ptab);
  }
}