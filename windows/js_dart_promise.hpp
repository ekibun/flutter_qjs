/*
 * @Description: 
 * @Author: ekibun
 * @Date: 2020-08-07 13:55:52
 * @LastEditors: ekibun
 * @LastEditTime: 2020-08-08 16:54:23
 */
#pragma once
#include "quickjs/quickjspp.hpp"
#include "quickjs/quickjs/list.h"
#include <flutter/method_result_functions.h>
#include <future>

namespace qjs
{
  static JSClassID js_dart_promise_class_id;

  typedef struct
  {
    int count;
    JSValue *argv;
  } JSOSFutureArgv;

  using JSFutureReturn = std::function<JSOSFutureArgv(JSContext *)>;

  typedef struct
  {
    struct list_head link;
    std::shared_future<JSFutureReturn> future;
    JSValue resolve;
    JSValue reject;
  } JSOSFuture;

  typedef struct JSThreadState
  {
    struct list_head os_future; /* list of JSOSFuture.link */
    std::shared_ptr<flutter::MethodChannel<flutter::EncodableValue>> channel;
  } JSThreadState;

  static JSValue js_add_future(Value resolve, Value reject, std::shared_future<JSFutureReturn> future)
  {
    JSRuntime *rt = JS_GetRuntime(resolve.ctx);
    JSThreadState *ts = (JSThreadState *)JS_GetRuntimeOpaque(rt);
    JSValueConst jsResolve, jsReject;
    JSOSFuture *th;
    JSValue obj;

    jsResolve = resolve.v;
    if (!JS_IsFunction(resolve.ctx, jsResolve))
      return JS_ThrowTypeError(resolve.ctx, "resolve not a function");
    jsReject = reject.v;
    if (!JS_IsFunction(reject.ctx, jsReject))
      return JS_ThrowTypeError(reject.ctx, "reject not a function");
    obj = JS_NewObjectClass(resolve.ctx, js_dart_promise_class_id);
    if (JS_IsException(obj))
      return obj;
    th = (JSOSFuture *)js_mallocz(resolve.ctx, sizeof(*th));
    if (!th)
    {
      JS_FreeValue(resolve.ctx, obj);
      return JS_EXCEPTION;
    }
    th->future = future;
    th->resolve = JS_DupValue(resolve.ctx, jsResolve);
    th->reject = JS_DupValue(reject.ctx, jsReject);
    list_add_tail(&th->link, &ts->os_future);
    JS_SetOpaque(obj, th);
    return obj;
  }

  JSValue js_dart_future(Value resolve, Value reject, std::string name, std::string args)
  {
    auto promise = new std::promise<JSFutureReturn>();
    JSRuntime *rt = JS_GetRuntime(resolve.ctx);
    JSThreadState *ts = (JSThreadState *)JS_GetRuntimeOpaque(rt);
    ts->channel->InvokeMethod(
        name,
        std::make_unique<flutter::EncodableValue>(args),
        std::make_unique<flutter::MethodResultFunctions<flutter::EncodableValue>>(
            (flutter::ResultHandlerSuccess<flutter::EncodableValue>)[promise](
                const flutter::EncodableValue *result) {
              promise->set_value((JSFutureReturn)[rep = std::get<std::string>(*result)](JSContext * ctx) {
                JSValue *ret = new JSValue{JS_NewString(ctx, rep.c_str())};
                return JSOSFutureArgv{1, ret};
              });
            },
            (flutter::ResultHandlerError<flutter::EncodableValue>)[promise](
                const std::string &error_code,
                const std::string &error_message,
                const flutter::EncodableValue *error_details) {
              promise->set_value((JSFutureReturn)[error_message](JSContext * ctx) {
                JSValue *ret = new JSValue{JS_NewString(ctx, error_message.c_str())};
                return JSOSFutureArgv{-1, ret};
              });
            },
            (flutter::ResultHandlerNotImplemented<flutter::EncodableValue>)[promise]() {
              promise->set_value((JSFutureReturn)[](JSContext * ctx) {
                JSValue *ret = new JSValue{JS_NewString(ctx, "NotImplemented")};
                return JSOSFutureArgv{-1, ret};
              });
            }));
    return js_add_future(resolve, reject, promise->get_future());
  }

  static void unlink_future(JSRuntime *rt, JSOSFuture *th)
  {
    if (th->link.prev)
    {
      list_del(&th->link);
      th->link.prev = th->link.next = NULL;
    }
  }

  static void free_future(JSRuntime *rt, JSOSFuture *th)
  {
    JS_FreeValueRT(rt, th->resolve);
    JS_FreeValueRT(rt, th->reject);
    js_free_rt(rt, th);
  }

  void js_init_handlers(JSRuntime *rt, std::shared_ptr<flutter::MethodChannel<flutter::EncodableValue>> channel)
  {
    JSThreadState *ts = (JSThreadState *)malloc(sizeof(*ts));
    if (!ts)
    {
      fprintf(stderr, "Could not allocate memory for the worker");
      exit(1);
    }
    memset(ts, 0, sizeof(*ts));
    init_list_head(&ts->os_future);
    ts->channel = channel;

    JS_SetRuntimeOpaque(rt, ts);
  }

  void js_free_handlers(JSRuntime *rt)
  {
    JSThreadState *ts = (JSThreadState *)JS_GetRuntimeOpaque(rt);
    struct list_head *el, *el1;

    list_for_each_safe(el, el1, &ts->os_future)
    {
      JSOSFuture *th = list_entry(el, JSOSFuture, link);
      th->future.get();
      unlink_future(rt, th);
      free_future(rt, th);
    }
    ts->channel = nullptr;
    free(ts);
    JS_SetRuntimeOpaque(rt, NULL); /* fail safe */
  }

  static void call_handler(JSContext *ctx, JSValueConst func, int count, JSValue *argv)
  {
    JSValue ret, func1;
    /* 'func' might be destroyed when calling itself (if it frees the
        handler), so must take extra care */
    func1 = JS_DupValue(ctx, func);
    ret = JS_Call(ctx, func1, JS_UNDEFINED, count, argv);
    JS_FreeValue(ctx, func1);
    if (JS_IsException(ret))
      throw exception{};
    JS_FreeValue(ctx, ret);
  }

  static int js_dart_poll(JSContext *ctx)
  {
    JSRuntime *rt = JS_GetRuntime(ctx);
    JSThreadState *ts = (JSThreadState *)JS_GetRuntimeOpaque(rt);
    struct list_head *el;

    /* XXX: handle signals if useful */

    if (list_empty(&ts->os_future))
      return -1; /* no more events */

    /* XXX: only timers and basic console input are supported */
    if (!list_empty(&ts->os_future))
    {
      list_for_each(el, &ts->os_future)
      {
        JSOSFuture *th = list_entry(el, JSOSFuture, link);
        if (th->future._Is_ready())
        {
          JSOSFutureArgv argv = th->future.get()(ctx);
          JSValue resolve, reject;
          int64_t delay;
          /* the timer expired */
          resolve = th->resolve;
          th->resolve = JS_UNDEFINED;
          reject = th->reject;
          th->reject = JS_UNDEFINED;
          unlink_future(rt, th);
          free_future(rt, th);
          call_handler(ctx, argv.count < 0 ? reject : resolve, abs(argv.count), argv.argv);
          for (int i = 0; i < abs(argv.count); ++i)
            JS_FreeValue(ctx, argv.argv[i]);
          JS_FreeValue(ctx, resolve);
          JS_FreeValue(ctx, reject);
          delete argv.argv;
          return 0;
        }
      }
    }
    return 0;
  }
} // namespace qjs