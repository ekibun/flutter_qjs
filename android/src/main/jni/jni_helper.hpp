/*
 * @Description: 
 * @Author: ekibun
 * @Date: 2020-08-16 13:20:03
 * @LastEditors: ekibun
 * @LastEditTime: 2020-08-16 17:56:52
 */
#include <jni.h>
#include <map>

jclass jniInstanceOf(JNIEnv *env, jobject obj, const char *className)
{
  jclass jclazz = env->FindClass(className);
  return env->IsInstanceOf(obj, jclazz) ? jclazz : nullptr;
}

jobjectArray jniToArray(JNIEnv *env, jobject obj)
{
  jmethodID mToArray = env->GetMethodID(env->GetObjectClass(obj), "toArray", "()[Ljava/lang/Object;");
  return (jobjectArray)env->CallObjectMethod(obj, mToArray);
}

jobject jniWrapMap(JNIEnv *env, std::map<jobject, jobject> val)
{
  jclass class_hashmap = env->FindClass("java/util/HashMap");
  jmethodID hashmap_init = env->GetMethodID(class_hashmap, "<init>", "()V");
  jobject map = env->NewObject(class_hashmap, hashmap_init);
  jmethodID hashMap_put = env->GetMethodID(class_hashmap, "put", "(Ljava/lang/Object;Ljava/lang/Object;)Ljava/lang/Object;");
  for (auto it = val.begin(); it != val.end(); ++it)
  {
    env->CallObjectMethod(map, hashMap_put, it->first, it->second);
  }
  return map;
}

template <typename T>
jobject jniWrapPrimity(JNIEnv *env, T obj);

template <>
jobject jniWrapPrimity(JNIEnv *env, jlong obj)
{
  jclass jclazz = env->FindClass("java/lang/Long");
  jmethodID jmethod = env->GetMethodID(jclazz, "<init>", "(J)V");
  return env->NewObject(jclazz, jmethod, obj);
}

template <>
jobject jniWrapPrimity(JNIEnv *env, jboolean obj)
{
  // TODO see https://github.com/flutter/flutter/issues/45066
  std::map<jobject, jobject> retMap;
  retMap[env->NewStringUTF("__js_boolean__")] = jniWrapPrimity<jlong>(env, (int64_t)obj);
  return jniWrapMap(env, retMap);
}

template <>
jobject jniWrapPrimity(JNIEnv *env, jdouble obj)
{
  jclass jclazz = env->FindClass("java/lang/Double");
  jmethodID jmethod = env->GetMethodID(jclazz, "<init>", "(D)V");
  return env->NewObject(jclazz, jmethod, obj);
}