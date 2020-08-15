/*
 * @Description: 
 * @Author: ekibun
 * @Date: 2020-08-08 10:30:59
 * @LastEditors: ekibun
 * @LastEditTime: 2020-08-15 16:31:14
 */
#pragma once

#include <vector>
#include <queue>
#include <thread>
#include <atomic>
#include <future>
#include <iostream>

#include "js_dart_promise.hpp"
#include "quickjspp/quickjspp.hpp"

namespace qjs
{
  struct EngineTask
  {
    std::function<Value(Context&)> invoke;
    std::function<void(Value)> resolve;
    std::function<void(Value)> reject;
  };

  struct EngineTaskResolver
  {
    Value result;
    std::function<void(Value)> resolve;
    std::function<void(Value)> reject;
  };

  std::string getStackTrack(Value exc)
  {
    std::string err = (std::string)exc;
    if ((bool)exc["stack"])
      err += "\n" + (std::string)exc["stack"];
    return err;
  }

  class Engine
  {
    // 引擎线程
    std::thread thread;
    // 任务队列
    std::queue<EngineTask> tasks;
    // 同步
    std::mutex m_lock;
    // 是否关闭提交
    std::atomic<bool> stoped;

    void handleException(qjs::Value exc)
    {
      std::cout << getStackTrack(exc) << std::endl;
    }

  public:
    inline Engine(std::function<std::promise<JSFutureReturn> *(std::string, Value, Engine *)> channel) : stoped{false}
    {
      thread = std::thread([this, channel = [this, channel](std::string method, Value args){
        return channel(method, args, this);
      }] {
        // 创建运行环境
        Runtime rt;
        js_init_handlers(rt.rt, channel);
        Context ctx(rt);
        auto &module = ctx.addModule("__DartImpl");
        module.function<&js_dart_future>("__invoke");
        ctx.eval(
            R"xxx(
              import * as __DartImpl from "__DartImpl";
              globalThis.dart = (method, ...args) => new Promise((res, rej) => 
                __DartImpl.__invoke(res, rej, method, args));
            )xxx",
            "<dart>", JS_EVAL_TYPE_MODULE);
        std::vector<EngineTaskResolver> unresolvedTask;
        Value promiseWrapper = ctx.eval(
            R"xxx(
              (value) => {
                const __ret = Promise.resolve(value)
                  .then(v => {
                    __ret.__value = v;
                    __ret.__resolved = true;
                  }).catch(e => {
                    __ret.__error = e;
                    __ret.__rejected = true;
                  });
                return __ret;
              }
            )xxx",
            "<PromiseWrapper>", JS_EVAL_TYPE_GLOBAL);

        // 循环
        while (!this->stoped)
        {
          // 获取待执行的task
          EngineTask task;
          {                                                  // 获取一个待执行的 task
            std::unique_lock<std::mutex> lock{this->m_lock}; // unique_lock 相比 lock_guard 的好处是：可以随时 unlock() 和 lock()
            if (!this->tasks.empty())
            {
              task = this->tasks.front(); // 取一个 task
              this->tasks.pop();
            }
          }
          // 执行task
          if (task.resolve)
            try
            {
              Value val = task.invoke(ctx);
              Value ret = Value{ctx.ctx, JS_Call(ctx.ctx, promiseWrapper.v, ctx.global().v, 1, &(val.v))};
              unresolvedTask.emplace_back(EngineTaskResolver{ret, std::move(task.resolve), std::move(task.reject)});
            }
            catch (exception)
            {
              task.reject(ctx.getException());
            }
          // 执行microtask
          JSContext *pctx;
          for (;;)
          {
            int err = JS_ExecutePendingJob(rt.rt, &pctx);
            if (err <= 0)
            {
              if (err < 0)
                std::cout << getStackTrack(ctx.getException()) << std::endl;
              break;
            }
          }
          // TODO 检查promise状态
          for (auto it = unresolvedTask.begin(); it != unresolvedTask.end();)
          {
            bool finished = false;
            if (it->result["__resolved"])
            {
              it->resolve(it->result["__value"]);
              finished = true;
            };
            if (it->result["__rejected"])
            {
              it->reject(it->result["__error"]);
              finished = true;
            };
            if (finished)
              it = unresolvedTask.erase(it);
            else
              ++it;
          }
          // 检查dart交互
          bool idle = true;
          try
          {
            idle = js_dart_poll(ctx.ctx);
          }
          catch (exception)
          {
            handleException(ctx.getException());
          }
          // 空闲时reject所有task
          if (idle && !JS_IsJobPending(rt.rt) && !unresolvedTask.empty())
          {
            for (EngineTaskResolver &_task : unresolvedTask)
            {
              _task.reject(ctx.newValue("Promise cannot resolve"));
            }
            unresolvedTask.clear();
          }
        }
        js_free_handlers(rt.rt);
      });
    }
    inline ~Engine()
    {
      stoped.store(true);
      if (thread.joinable())
        thread.join(); // 等待任务结束， 前提：线程一定会执行完
    }

  public:
    // 提交一个任务
    void commit(EngineTask task)
    {
      if (stoped.load()) // stop == true ??
        throw std::runtime_error("commit on stopped engine.");
      {                                           // 添加任务到队列
        std::lock_guard<std::mutex> lock{m_lock}; //对当前块的语句加锁  lock_guard 是 mutex 的 stack 封装类，构造的时候 lock()，析构的时候 unlock()
        tasks.emplace(task);
      }
    }
  };

} // namespace qjs
