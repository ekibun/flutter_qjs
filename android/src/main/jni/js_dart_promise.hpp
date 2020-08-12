/*
 * @Description: 
 * @Author: ekibun
 * @Date: 2020-08-07 13:55:52
 * @LastEditors: ekibun
 * @LastEditTime: 2020-08-12 14:24:42
 */
#pragma once
#include "quickjs/quickjspp.hpp"
#include "quickjs/list.h"
#include <future>
#include <string.h>

namespace qjs
{
  static JSClassID js_dart_promise_class_id;

  typedef struct
  {
    int count;
    JSValue *argv;
  } JSOSFutureArgv;

  using JSFutureReturn = std::function<JSOSFutureArgv(JSContext *)>;
  using DartChannel = std::function<std::future<JSFutureReturn>(std::string, std::string)>;

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
    std::function<std::future<JSFutureReturn>(std::string, std::string)> channel;
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
    JSRuntime *rt = JS_GetRuntime(resolve.ctx);
    JSThreadState *ts = (JSThreadState *)JS_GetRuntimeOpaque(rt);
    return js_add_future(resolve, reject, ts->channel(name, args));
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

  void js_init_handlers(JSRuntime *rt, DartChannel channel)
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
        auto status = th->future.wait_for(std::chrono::seconds(0));
        if (status == std::future_status::ready)
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