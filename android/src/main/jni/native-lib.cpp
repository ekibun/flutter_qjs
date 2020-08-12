/*
 * @Description: 
 * @Author: ekibun
 * @Date: 2020-08-09 18:16:11
 * @LastEditors: ekibun
 * @LastEditTime: 2020-08-12 23:11:35
 */
#include <jni.h>
#include <string>
#include "js_engine.hpp"

qjs::Engine *engine = nullptr;

// static jobject gClassLoader;
// static jmethodID gFindClassMethod;

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

// JNIEXPORT jint JNICALL JNI_OnLoad(JavaVM *pjvm, void *reserved)
// {
//   JNIEnv *env = getEnv(pjvm);
//   auto randomClass = env->FindClass("soko/ekibun/flutter_qjs/ResultWrapper");
//   jclass classClass = env->GetObjectClass(randomClass);
//   auto classLoaderClass = env->FindClass("java/lang/ClassLoader");
//   auto getClassLoaderMethod = env->GetMethodID(classClass, "getClassLoader",
//                                                "()Ljava/lang/ClassLoader;");
//   gClassLoader = env->NewGlobalRef(env->CallObjectMethod(randomClass, getClassLoaderMethod));
//   gFindClassMethod = env->GetMethodID(classLoaderClass, "findClass",
//                                       "(Ljava/lang/String;)Ljava/lang/Class;");

//   return JNI_VERSION_1_6;
// }

// jclass findClass(JNIEnv *env, const char *name)
// {
//   return static_cast<jclass>(env->CallObjectMethod(gClassLoader, gFindClassMethod, env->NewStringUTF(name)));
// }

void jniResultResolve(JavaVM *jvm, jobject result, std::string data)
{
  JNIEnv *env = getEnv(jvm);
  jclass jclazz = env->GetObjectClass(result);
  jmethodID jmethod = env->GetMethodID(jclazz, "success", "(Ljava/lang/String;)V");
  jstring jdata = env->NewStringUTF(data.c_str());
  env->CallVoidMethod(result, jmethod, jdata);
  env->DeleteLocalRef(jdata);
  env->DeleteGlobalRef(result);
  jvm->DetachCurrentThread();
}

void jniResultReject(JavaVM *jvm, jobject result, std::string reason)
{
  JNIEnv *env = getEnv(jvm);
  jclass jclazz = env->GetObjectClass(result);
  jmethodID jmethod = env->GetMethodID(jclazz, "error", "(Ljava/lang/String;)V");
  jstring jreason = env->NewStringUTF(reason.c_str());
  env->CallVoidMethod(result, jmethod, jreason);
  env->DeleteLocalRef(jreason);
  env->DeleteGlobalRef(result);
  jvm->DetachCurrentThread();
}

void jniChannelInvoke(JavaVM *jvm, jobject channel, std::promise<qjs::JSFutureReturn> *promise, std::string method, std::string argv)
{
  JNIEnv *env = nullptr;
  jvm->GetEnv((void **)&env, JNI_VERSION_1_2);
  jvm->AttachCurrentThread(&env, NULL);
  jclass jclazz = env->GetObjectClass(channel);
  jmethodID jmethod = env->GetMethodID(jclazz, "invokeMethod", "(Ljava/lang/String;Ljava/lang/String;J)V");
  jstring jstrmethod = env->NewStringUTF(method.c_str());
  jstring jstrargv = env->NewStringUTF(argv.c_str());
  
  env->CallVoidMethod(channel, jmethod, jstrmethod, jstrargv, (jlong)promise);
  env->DeleteLocalRef(jstrmethod);
  env->DeleteLocalRef(jstrargv);
  jvm->DetachCurrentThread();
}

extern "C" JNIEXPORT jint JNICALL
Java_soko_ekibun_flutter_1qjs_JniBridge_initEngine(
    JNIEnv *env,
    jobject thiz,
    jobject channel)
{
  JavaVM *jvm = nullptr;
  env->GetJavaVM(&jvm);
  jobject gchannel = env->NewGlobalRef(channel);
  engine = new qjs::Engine([jvm, gchannel](std::string name, std::string args) {
    auto promise = new std::promise<qjs::JSFutureReturn>();
    jniChannelInvoke(jvm, gchannel, promise, name, args);
    return promise->get_future();
  });
  return (jlong)engine;
}

extern "C" JNIEXPORT void JNICALL
Java_soko_ekibun_flutter_1qjs_JniBridge_evaluate(
    JNIEnv *env,
    jobject thiz,
    jstring script,
    jstring name,
    jobject result)
{
  JavaVM *jvm = nullptr;
  env->GetJavaVM(&jvm);
  jobject gresult = env->NewGlobalRef(result);
  engine->commit(qjs::EngineTask{
      env->GetStringUTFChars(script, 0),
      env->GetStringUTFChars(name, 0),
      [jvm, gresult](std::string resolve) {
        jniResultResolve(jvm, gresult, resolve);
        // flutter::EncodableValue response(resolve);
        // presult->Success(&response);
      },
      [jvm, gresult](std::string reject) {
        jniResultReject(jvm, gresult, reject);
        // presult->Error("FlutterJSException", reject);
      }});
}

extern "C" JNIEXPORT void JNICALL
Java_soko_ekibun_flutter_1qjs_JniBridge_close(
    JNIEnv *env,
    jobject /* this */)
{
  delete engine;
}

extern "C" JNIEXPORT void JNICALL
Java_soko_ekibun_flutter_1qjs_JniBridge_resolve(
    JNIEnv *env,
    jobject clazz,
    jlong promise, jstring data)
{
  ((std::promise<qjs::JSFutureReturn> *)promise)->set_value((qjs::JSFutureReturn)[data = std::string(env->GetStringUTFChars(data, 0))](qjs::JSContext * ctx) {
    qjs::JSValue *ret = new qjs::JSValue{JS_NewString(ctx, data.c_str())};
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