/*
 * @Description: 
 * @Author: ekibun
 * @Date: 2020-09-06 18:32:45
 * @LastEditors: ekibun
 * @LastEditTime: 2020-09-13 17:26:29
 */
#include "../../cxx/quickjs/quickjs.h"
#include <cstring>

#ifdef _MSC_VER
#define DLLEXPORT __declspec(dllexport)
#else
#define DLLEXPORT __attribute__((visibility("default")))
#endif

extern "C"
{

  DLLEXPORT JSRuntime *jsNewRuntime()
  {
    return JS_NewRuntime();
  }

  DLLEXPORT JSContext *jsNewContext(JSRuntime *rt)
  {
    return JS_NewContext(rt);
  }

  DLLEXPORT JSValue *jsEval(JSContext *ctx, const char *input, const char *filename, int eval_flags)
  {
    return new JSValue{JS_Eval(ctx, input, strlen(input), filename, eval_flags)};
  }

  DLLEXPORT const char *jsToCString(JSContext *ctx, JSValue *val)
  {
    return JS_ToCString(ctx, *val);
  }
}