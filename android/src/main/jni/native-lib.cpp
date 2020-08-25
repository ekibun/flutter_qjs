/*
 * @Description: 
 * @Author: ekibun
 * @Date: 2020-08-09 18:16:11
 * @LastEditors: ekibun
 * @LastEditTime: 2020-08-25 16:00:46
 */
#include "java_js_wrapper.hpp"
#include "android/log.h"

JNIEnv *getEnv(JavaVM *gJvm)
{
  JNIEnv *env;
  int status = gJvm->GetEnv((void **)&env, JNI_VERSION_1_6);
  if (status < 0)
  {
    status = gJvm->AttachCurrentThread(&env, NULL);
    if (status < 0)
    {
      return nullptr;
    }
  }
  return env;
}

void jniResultResolve(JNIEnv *env, jobject result, jobject data)
{
  jclass jclazz = env->GetObjectClass(result);
  jmethodID jmethod = env->GetMethodID(jclazz, "success", "(Ljava/lang/Object;)V");
  env->CallVoidMethod(result, jmethod, data);
  env->DeleteLocalRef(data);
  env->DeleteGlobalRef(result);
}

void jniResultReject(JNIEnv *env, jobject result, std::string reason)
{
  jclass jclazz = env->GetObjectClass(result);
  jmethodID jmethod = env->GetMethodID(jclazz, "error", "(Ljava/lang/String;)V");
  jstring jreason = env->NewStringUTF(reason.c_str());
  env->CallVoidMethod(result, jmethod, jreason);
  env->DeleteLocalRef(jreason);
  env->DeleteGlobalRef(result);
}

void jniChannelInvoke(JNIEnv *env, jobject channel, std::promise<qjs::JSFutureReturn> *promise, std::string method, qjs::Value args, qjs::Engine *engine)
{
  jclass jclazz = env->GetObjectClass(channel);
  jmethodID jmethod = env->GetMethodID(jclazz, "invokeMethod", "(Ljava/lang/String;Ljava/lang/Object;J)V");
  jstring jstrmethod = env->NewStringUTF(method.c_str());
  std::map<jobject, jobject> retMap;
  retMap[env->NewStringUTF("engine")] = jniWrapPrimity<jlong>(env, (int64_t) engine);
  retMap[env->NewStringUTF("args")] = qjs::jsToJava(env, args);
  jobject jsargs = jniWrapMap(env, retMap);
  env->CallVoidMethod(channel, jmethod, jstrmethod, jsargs, (jlong)promise);
  env->DeleteLocalRef(jstrmethod);
  env->DeleteLocalRef(jsargs);
}

extern "C" JNIEXPORT jlong JNICALL
Java_soko_ekibun_flutter_1qjs_JniBridge_createEngine(
    JNIEnv *env,
    jobject thiz,
    jobject channel)
{
  JavaVM *jvm = nullptr;
  env->GetJavaVM(&jvm);
  jobject gchannel = env->NewGlobalRef(channel);
  qjs::Engine *engine = new qjs::Engine([jvm, gchannel](std::string name, qjs::Value args, qjs::Engine *engine) {
    auto promise = new std::promise<qjs::JSFutureReturn>();
    JNIEnv *env = getEnv(jvm);
    jniChannelInvoke(env, gchannel, promise, name, args, engine);
    jvm->DetachCurrentThread();
    return promise;
  });
  return (jlong)engine;
}

extern "C" JNIEXPORT void JNICALL
Java_soko_ekibun_flutter_1qjs_JniBridge_evaluate(
    JNIEnv *env,
    jobject thiz,
    jlong engine,
    jstring script,
    jstring name,
    jobject result)
{
  JavaVM *jvm = nullptr;
  env->GetJavaVM(&jvm);
  jobject gresult = env->NewGlobalRef(result);
  ((qjs::Engine *)engine)->commit(qjs::EngineTask{
      [script = std::string(env->GetStringUTFChars(script, 0)),
       name = std::string(env->GetStringUTFChars(name, 0))](qjs::Context &ctx) {
        return ctx.eval(script, name.c_str(), JS_EVAL_TYPE_GLOBAL);
      },
      [jvm, gresult](qjs::Value resolve) {
        JNIEnv *env = getEnv(jvm);
        jniResultResolve(env, gresult, qjs::jsToJava(env, resolve));
        jvm->DetachCurrentThread();
      },
      [jvm, gresult](qjs::Value reject) {
        JNIEnv *env = getEnv(jvm);
        jniResultReject(env, gresult, qjs::getStackTrack(reject));
        jvm->DetachCurrentThread();
      }});
}

extern "C" JNIEXPORT void JNICALL
Java_soko_ekibun_flutter_1qjs_JniBridge_close(
    JNIEnv *env,
    jobject thiz,
    jlong engine)
{
  delete ((qjs::Engine *)engine);
}

extern "C" JNIEXPORT void JNICALL
Java_soko_ekibun_flutter_1qjs_JniBridge_call(
    JNIEnv *env,
    jobject thiz,
    jlong engine,
    jlong function,
    jobject args,
    jobject result)
{
  JavaVM *jvm = nullptr;
  env->GetJavaVM(&jvm);
  jobject gresult = env->NewGlobalRef(result);
  jobject gargs = env->NewGlobalRef(args);
  ((qjs::Engine *)engine)->commit(qjs::EngineTask{
      [jvm, function = (qjs::JSValue *)function, gargs](qjs::Context &ctx) {
        JNIEnv *env = getEnv(jvm);
        jobjectArray array = jniToArray(env, gargs);
        jsize argscount = env->GetArrayLength(array);
        qjs::JSValue *callargs = new qjs::JSValue[argscount];
        for (jsize i = 0; i < argscount; i++)
        {
          callargs[i] = qjs::javaToJs(ctx.ctx, env, env->GetObjectArrayElement(array, i));
        }
        jvm->DetachCurrentThread();
        qjs::JSValue ret = qjs::call_handler(ctx.ctx, *function, (int)argscount, callargs);
        delete[] callargs;
        if (qjs::JS_IsException(ret))
          throw qjs::exception{};
        return qjs::Value{ctx.ctx, ret};
      },
      [jvm, gresult](qjs::Value resolve) {
        JNIEnv *env = getEnv(jvm);
        jniResultResolve(env, gresult, qjs::jsToJava(env, resolve));
        jvm->DetachCurrentThread();
      },
      [jvm, gresult](qjs::Value reject) {
        JNIEnv *env = getEnv(jvm);
        jniResultReject(env, gresult, qjs::getStackTrack(reject));
        jvm->DetachCurrentThread();
      }});
}

extern "C" JNIEXPORT void JNICALL
Java_soko_ekibun_flutter_1qjs_JniBridge_resolve(
    JNIEnv *env,
    jobject clazz,
    jlong promise, jobject data)
{
  JavaVM *jvm = nullptr;
  env->GetJavaVM(&jvm);
  jobject gdata = env->NewGlobalRef(data);
  ((std::promise<qjs::JSFutureReturn> *)promise)->set_value((qjs::JSFutureReturn)[jvm, gdata](qjs::JSContext * ctx) {
    JNIEnv *env = getEnv(jvm);
    qjs::JSValue *ret = new qjs::JSValue{qjs::javaToJs(ctx, env, gdata)};
    return qjs::JSOSFutureArgv{1, ret};
  });
}

extern "C" JNIEXPORT void JNICALL
Java_soko_ekibun_flutter_1qjs_JniBridge_reject(
    JNIEnv *env,
    jobject clazz,
    jlong promise, jstring data)
{
  ((std::promise<qjs::JSFutureReturn> *)promise)->set_value((qjs::JSFutureReturn)[data = std::string(env->GetStringUTFChars(data, 0))](qjs::JSContext * ctx) {
    qjs::JSValue *ret = new qjs::JSValue{JS_NewString(ctx, data.c_str())};
    return qjs::JSOSFutureArgv{-1, ret};
  });
}