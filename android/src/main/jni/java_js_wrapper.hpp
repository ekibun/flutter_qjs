/*
 * @Description: 
 * @Author: ekibun
 * @Date: 2020-08-16 11:08:23
 * @LastEditors: ekibun
 * @LastEditTime: 2020-08-25 18:06:08
 */
#include <string>
#include <unordered_map>
#include "jni_helper.hpp"
#include "../../../../cxx/js_engine.hpp"

namespace qjs
{

  JSValue javaToJs(JSContext *ctx, JNIEnv *env, jobject val, std::unordered_map<jobject, JSValue> cache = std::unordered_map<jobject, JSValue>())
  {
    if (val == nullptr)
      return JS_UNDEFINED;
    if (cache.find(val) != cache.end())
      return cache[val];
    jclass objclass = env->GetObjectClass(val);
    jclass classclass = env->GetObjectClass((jobject)objclass);
    jmethodID mid = env->GetMethodID(classclass, "getName", "()Ljava/lang/String;");
    jobject clsObj = env->CallObjectMethod(objclass, mid);
    std::string className(env->GetStringUTFChars((jstring)clsObj, 0));
    if (className.compare("[B") == 0)
    {
      jsize len = env->GetArrayLength((jbyteArray)val);
      return JS_NewArrayBufferCopy(ctx, (uint8_t *)env->GetByteArrayElements((jbyteArray)val, 0), len);
    }
    else if (className.compare("[I") == 0)
    {
      jsize len = env->GetArrayLength((jintArray)val);
      return JS_NewArrayBufferCopy(ctx, (uint8_t *)env->GetIntArrayElements((jintArray)val, 0), len * 4);
    }
    else if (className.compare("[J") == 0)
    {
      jsize len = env->GetArrayLength((jlongArray)val);
      return JS_NewArrayBufferCopy(ctx, (uint8_t *)env->GetLongArrayElements((jlongArray)val, 0), len * 8);
    }
    else if (className.compare("[D") == 0)
    {
      jsize size = env->GetArrayLength((jdoubleArray)val);
      JSValue array = JS_NewArray(ctx);
      auto buf = env->GetDoubleArrayElements((jdoubleArray)val, 0);
      for (uint32_t i = 0; i < size; i++)
      {
        auto atom = JS_NewAtomUInt32(ctx, i);
        JS_DefinePropertyValue(
            ctx, array, atom,
            JS_NewFloat64(ctx, buf[i]),
            JS_PROP_C_W_E);
        JS_FreeAtom(ctx, atom);
      }

      return array;
    }
    else if (className.compare("java.lang.Boolean") == 0)
    {
      jmethodID getVal = env->GetMethodID(objclass, "booleanValue", "()Z");
      return JS_NewBool(ctx, env->CallBooleanMethod(val, getVal));
    }
    else if (className.compare("java.lang.Integer") == 0)
    {
      jmethodID getVal = env->GetMethodID(objclass, "intValue", "()I");
      return JS_NewInt32(ctx, env->CallIntMethod(val, getVal));
    }
    else if (className.compare("java.lang.Long") == 0)
    {
      jmethodID getVal = env->GetMethodID(objclass, "longValue", "()J");
      return JS_NewInt64(ctx, env->CallLongMethod(val, getVal));
    }
    else if (className.compare("java.lang.Double") == 0)
    {
      jmethodID getVal = env->GetMethodID(objclass, "doubleValue", "()D");
      return JS_NewFloat64(ctx, env->CallDoubleMethod(val, getVal));
    }
    else if (className.compare("java.lang.String") == 0)
    {
      return JS_NewString(ctx, env->GetStringUTFChars((jstring)val, 0));
    }
    else if (className.compare("java.util.ArrayList") == 0)
    {
      jobjectArray list = jniToArray(env, val);
      jsize size = env->GetArrayLength(list);
      JSValue array = JS_NewArray(ctx);
      cache[val] = array;
      for (uint32_t i = 0; i < size; i++)
      {
        auto atom = JS_NewAtomUInt32(ctx, i);
        JS_DefinePropertyValue(
          ctx, array, atom,
          javaToJs(ctx, env, env->GetObjectArrayElement(list, i), cache),
          JS_PROP_C_W_E);
        JS_FreeAtom(ctx, atom);
      }
      
      return array;
    }
    else if (className.compare("java.util.HashMap") == 0)
    {
      // 获取HashMap类entrySet()方法ID
      jmethodID entrySetMID = env->GetMethodID(objclass, "entrySet", "()Ljava/util/Set;");
      // 调用entrySet()方法获取Set对象
      jobject setObj = env->CallObjectMethod(val, entrySetMID);
      // 获取Set类中iterator()方法ID
      jclass setClass = env->FindClass("java/util/Set");
      jmethodID iteratorMID = env->GetMethodID(setClass, "iterator", "()Ljava/util/Iterator;");
      // 调用iterator()方法获取Iterator对象
      jobject iteratorObj = env->CallObjectMethod(setObj, iteratorMID);
      // 获取Iterator类中hasNext()方法ID
      // 用于while循环判断HashMap中是否还有数据
      jclass iteratorClass = env->FindClass("java/util/Iterator");
      jmethodID hasNextMID = env->GetMethodID(iteratorClass, "hasNext", "()Z");
      // 获取Iterator类中next()方法ID
      // 用于读取HashMap中的每一条数据
      jmethodID nextMID = env->GetMethodID(iteratorClass, "next", "()Ljava/lang/Object;");
      // 获取Map.Entry类中getKey()和getValue()的方法ID
      // 用于读取“K-V”键值对，注意：内部类使用$符号表示
      jclass entryClass = env->FindClass("java/util/Map$Entry");
      jmethodID getKeyMID = env->GetMethodID(entryClass, "getKey", "()Ljava/lang/Object;");
      jmethodID getValueMID = env->GetMethodID(entryClass, "getValue", "()Ljava/lang/Object;");
      // JSObject
      JSValue obj = JS_NewObject(ctx);
      cache[val] = obj;
      // 循环检测HashMap中是否还有数据
      while (env->CallBooleanMethod(iteratorObj, hasNextMID))
      {
        // 读取一条数据
        jobject entryObj = env->CallObjectMethod(iteratorObj, nextMID);
        auto atomvalue = javaToJs(ctx, env, env->CallObjectMethod(entryObj, getKeyMID), cache);
        auto atom = JS_ValueToAtom(ctx, atomvalue);
        JS_DefinePropertyValue(
            ctx, obj, atom,
            javaToJs(ctx, env, env->CallObjectMethod(entryObj, getValueMID), cache),
            JS_PROP_C_W_E);
        JS_FreeAtom(ctx, atom);
        JS_FreeValue(ctx, atomvalue);
      }
      return obj;
    }
    return JS_UNDEFINED;
  }

  jobject jsToJava(JNIEnv *env, qjs::Value val, std::unordered_map<Value, jobject> cache = std::unordered_map<Value, jobject>())
  {
    int tag = JS_VALUE_GET_TAG(val.v);
    if (JS_TAG_IS_FLOAT64(tag))
      return jniWrapPrimity<jdouble>(env, (double)val);
    switch (tag)
    {
    case JS_TAG_BOOL:
      return jniWrapPrimity<jboolean>(env, (bool)val);
    case JS_TAG_INT:
      return jniWrapPrimity<jlong>(env, (int64_t)val);
    case JS_TAG_STRING:
      return env->NewStringUTF(((std::string)val).c_str());
    case JS_TAG_OBJECT:
    { // ArrayBuffer
      size_t size;
      uint8_t *buf = JS_GetArrayBuffer(val.ctx, &size, val.v);
      if (buf)
      {
        jbyteArray arr = env->NewByteArray(size);
        env->SetByteArrayRegion(arr, 0, size, (int8_t *)buf);
        return arr;
      }
    }
      if (cache.find(val) != cache.end())
        return cache[val];
      if (JS_IsFunction(val.ctx, val.v))
      {
        std::map<jobject, jobject> retMap;
        retMap[env->NewStringUTF("__js_function__")] = jniWrapPrimity<jlong>(env, (int64_t) new JSValue{js_add_ref(val)});
        return jniWrapMap(env, retMap);
      }
      else if (JS_IsArray(val.ctx, val.v) > 0)
      {
        uint32_t arrlen = (uint32_t)val["length"];
        jclass class_arraylist = env->FindClass("java/util/ArrayList");
        jmethodID arraylist_init = env->GetMethodID(class_arraylist, "<init>", "()V");
        jobject list = env->NewObject(class_arraylist, arraylist_init);
        jmethodID arraylist_add = env->GetMethodID(class_arraylist, "add", "(Ljava/lang/Object;)Z");
        for (uint32_t i = 0; i < arrlen; i++)
        {
          env->CallBooleanMethod(list, arraylist_add, jsToJava(env, val[i], cache));
        }
        cache[val] = list;
        return list;
      }
      else
      {
        qjs::JSPropertyEnum *ptab;
        uint32_t plen;
        if (JS_GetOwnPropertyNames(val.ctx, &ptab, &plen, val.v, -1))
          return nullptr;
        std::map<jobject, jobject> retMap;
        for (uint32_t i = 0; i < plen; i++)
        {
          retMap[jsToJava(env, {val.ctx, JS_AtomToValue(val.ctx, ptab[i].atom)}, cache)] =
              jsToJava(env, {val.ctx, JS_GetProperty(val.ctx, val.v, ptab[i].atom)}, cache);
          JS_FreeAtom(val.ctx, ptab[i].atom);
        }
        js_free(val.ctx, ptab);
        jobject ret = jniWrapMap(env, retMap);
        cache[val] = ret;
        return ret;
      }
    default:
      return nullptr;
    }
  }
} // namespace qjs
