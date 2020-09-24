#include "quickjs/quickjs.h"

#ifdef _MSC_VER
#define DLLEXPORT __declspec(dllexport)
#else
#define DLLEXPORT __attribute__((visibility("default"))) __attribute__((used))
#endif

extern "C"
{

typedef void *JSChannel(JSContext *ctx, const char *method, void *argv);

JSValue *jsThrowInternalError(JSContext *ctx, char *message);

JSValue *jsEXCEPTION();

JSValue *jsUNDEFINED();

JSValue *jsNULL();

JSRuntime *jsNewRuntime(JSChannel channel);

void jsFreeRuntime(JSRuntime *rt);

JSContext *jsNewContext(JSRuntime *rt);

void jsFreeContext(JSContext *ctx);

JSRuntime *jsGetRuntime(JSContext *ctx);

JSValue *jsEval(JSContext *ctx, const char *input, size_t input_len, const char *filename, int32_t eval_flags);

int32_t jsValueGetTag(JSValue *val);

void *jsValueGetPtr(JSValue *val);

int32_t jsTagIsFloat64(int32_t tag);

JSValue *jsNewBool(JSContext *ctx, int32_t val);

JSValue *jsNewInt64(JSContext *ctx, int64_t val);

JSValue *jsNewFloat64(JSContext *ctx, double val);

JSValue *jsNewString(JSContext *ctx, const char *str);

JSValue *jsNewArrayBufferCopy(JSContext *ctx, const uint8_t *buf, size_t len);

JSValue *jsNewArray(JSContext *ctx);

JSValue *jsNewObject(JSContext *ctx);

void jsFreeValue(JSContext *ctx, JSValue *v);

void jsFreeValueRT(JSRuntime *rt, JSValue *v);

JSValue *jsDupValue(JSContext *ctx, JSValueConst *v);

JSValue *jsDupValueRT(JSRuntime *rt, JSValue *v);

int32_t jsToBool(JSContext *ctx, JSValueConst *val);

int64_t jsToInt64(JSContext *ctx, JSValueConst *val);

double jsToFloat64(JSContext *ctx, JSValueConst *val);

const char *jsToCString(JSContext *ctx, JSValueConst *val);

void jsFreeCString(JSContext *ctx, const char *ptr);

uint8_t *jsGetArrayBuffer(JSContext *ctx, size_t *psize, JSValueConst *obj);

int32_t jsIsFunction(JSContext *ctx, JSValueConst *val);

int32_t jsIsArray(JSContext *ctx, JSValueConst *val);

void deleteJSValue(JSValueConst *val);

JSValue *jsGetProperty(JSContext *ctx, JSValueConst *this_obj,
                                   JSAtom prop);

int32_t jsDefinePropertyValue(JSContext *ctx, JSValueConst *this_obj,
                                      JSAtom prop, JSValue *val, int32_t flags);

void jsFreeAtom(JSContext *ctx, JSAtom v);

JSAtom jsValueToAtom(JSContext *ctx, JSValueConst *val);

JSValue *jsAtomToValue(JSContext *ctx, JSAtom val);

int32_t jsGetOwnPropertyNames(JSContext *ctx, JSPropertyEnum **ptab,
                                      uint32_t *plen, JSValueConst *obj, int32_t flags);

JSAtom jsPropertyEnumGetAtom(JSPropertyEnum *ptab, int32_t i);

uint32_t sizeOfJSValue();

void setJSValueList(JSValue *list, uint32_t i, JSValue *val);

JSValue *jsCall(JSContext *ctx, JSValueConst *func_obj, JSValueConst *this_obj,
                            int32_t argc, JSValueConst *argv);

int32_t jsIsException(JSValueConst *val);

JSValue *jsGetException(JSContext *ctx);

int32_t jsExecutePendingJob(JSRuntime *rt);

JSValue *jsNewPromiseCapability(JSContext *ctx, JSValue *resolving_funcs);

}