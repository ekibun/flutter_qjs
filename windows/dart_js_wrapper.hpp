/*
 * @Description: 
 * @Author: ekibun
 * @Date: 2020-08-14 21:45:02
 * @LastEditors: ekibun
 * @LastEditTime: 2020-08-16 19:52:35
 */
#include "../cxx/js_engine.hpp"
#include <flutter/standard_method_codec.h>
#include <variant>

namespace std
{
  template <>
  struct hash<qjs::Value>
  {
    std::size_t operator()(const qjs::Value &key) const
    {
      return std::hash<std::string>()((std::string)key);
    }
  };

  template <>
  struct hash<flutter::EncodableValue>
  {
    std::size_t operator()(const flutter::EncodableValue &key) const
    {
      return key.index();
    }
  };
} // namespace std

namespace qjs
{
  JSValue dartToJs(JSContext *ctx, flutter::EncodableValue val, std::unordered_map<flutter::EncodableValue, JSValue> cache = std::unordered_map<flutter::EncodableValue, JSValue>())
  {
    if (val.IsNull())
      return JS_UNDEFINED;
    if (cache.find(val) != cache.end())
      return cache[val];
    if (std::holds_alternative<bool>(val))
      return JS_NewBool(ctx, std::get<bool>(val));
    if (std::holds_alternative<int32_t>(val))
      return JS_NewInt32(ctx, std::get<int32_t>(val));
    if (std::holds_alternative<int64_t>(val))
      return JS_NewInt64(ctx, std::get<int64_t>(val));
    if (std::holds_alternative<double>(val))
      return JS_NewFloat64(ctx, std::get<double>(val));
    if (std::holds_alternative<std::string>(val))
      return JS_NewString(ctx, std::get<std::string>(val).c_str());
    if (std::holds_alternative<std::vector<uint8_t>>(val))
    {
      auto buf = std::get<std::vector<uint8_t>>(val);
      return JS_NewArrayBufferCopy(ctx, buf.data(), buf.size());
    }
    if (std::holds_alternative<std::vector<int32_t>>(val))
    {
      auto buf = std::get<std::vector<int32_t>>(val);
      return JS_NewArrayBufferCopy(ctx, (uint8_t *)buf.data(), buf.size() * 4);
    }
    if (std::holds_alternative<std::vector<int64_t>>(val))
    {
      auto buf = std::get<std::vector<int64_t>>(val);
      return JS_NewArrayBufferCopy(ctx, (uint8_t *)buf.data(), buf.size() * 8);
    }
    if (std::holds_alternative<std::vector<double>>(val))
    {
      auto buf = std::get<std::vector<double>>(val);
      JSValue array = JS_NewArray(ctx);
      cache[val] = array;
      auto size = (uint32_t)buf.size();
      for (uint32_t i = 0; i < size; i++)
        JS_DefinePropertyValue(
            ctx, array, JS_NewAtomUInt32(ctx, i), JS_NewFloat64(ctx, buf[i]),
            JS_PROP_C_W_E);
      return array;
    }
    if (std::holds_alternative<flutter::EncodableList>(val))
    {
      auto list = std::get<flutter::EncodableList>(val);
      JSValue array = JS_NewArray(ctx);
      cache[val] = array;
      auto size = (uint32_t)list.size();
      for (uint32_t i = 0; i < size; i++)
        JS_DefinePropertyValue(
            ctx, array, JS_NewAtomUInt32(ctx, i), dartToJs(ctx, list[i], cache),
            JS_PROP_C_W_E);
      return array;
    }
    if (std::holds_alternative<flutter::EncodableMap>(val))
    {
      auto map = std::get<flutter::EncodableMap>(val);
      JSValue obj = JS_NewObject(ctx);
      cache[val] = obj;
      for (auto iter = map.begin(); iter != map.end(); ++iter)
        JS_DefinePropertyValue(
            ctx, obj, JS_ValueToAtom(ctx, dartToJs(ctx, iter->first, cache)), dartToJs(ctx, iter->second, cache),
            JS_PROP_C_W_E);
      return obj;
    }
    return JS_UNDEFINED;
  }

  flutter::EncodableValue jsToDart(Value val, std::unordered_map<Value, flutter::EncodableValue> cache = std::unordered_map<Value, flutter::EncodableValue>())
  {
    if (cache.find(val) != cache.end())
      return cache[val];
    if (JS_IsBool(val.v))
      return (bool)val;
    {
      int tag = JS_VALUE_GET_TAG(val.v);
      if (tag == JS_TAG_INT)
      {
        return (int64_t)val;
      }
      else if (JS_TAG_IS_FLOAT64(tag))
      {
        return (double)val;
      }
    }
    if (JS_IsString(val.v))
      return (std::string)val;
    { // ArrayBuffer
      size_t size;
      uint8_t *buf = JS_GetArrayBuffer(val.ctx, &size, val.v);
      if (buf)
        return (std::vector<uint8_t>(buf, buf + size));
    }
    flutter::EncodableValue ret;
    if (JS_IsUndefined(val.v) || JS_IsNull(val.v) || JS_IsUninitialized(val.v))
      goto exception;
    if (JS_IsObject(val.v))
    {
      if (JS_IsFunction(val.ctx, val.v))
      {
        flutter::EncodableMap retMap;
        retMap[std::string("__js_function__")] = (int64_t) new JSValue{JS_DupValue(val.ctx, val.v)};
        ret = retMap;
      }
      else if (JS_IsArray(val.ctx, val.v) > 0)
      {
        flutter::EncodableList retList;
        cache[val] = retList;
        uint32_t arrlen = (uint32_t)val["length"];
        for (uint32_t i = 0; i < arrlen; i++)
        {
          retList.push_back(jsToDart(val[i], cache));
        }
        ret = retList;
      }
      else
      {
        qjs::JSPropertyEnum *ptab;
        uint32_t plen;
        if (JS_GetOwnPropertyNames(val.ctx, &ptab, &plen, val.v, -1))
          goto exception;
        flutter::EncodableMap retMap;
        cache[val] = retMap;
        for (uint32_t i = 0; i < plen; i++)
        {
          retMap[jsToDart({val.ctx, JS_AtomToValue(val.ctx, ptab[i].atom)}, cache)] =
              jsToDart({val.ctx, JS_GetProperty(val.ctx, val.v, ptab[i].atom)}, cache);
          JS_FreeAtom(val.ctx, ptab[i].atom);
        }
        js_free(val.ctx, ptab);
        ret = retMap;
      }
      goto done;
    }
  exception:
    ret = flutter::EncodableValue();
  done:
    return ret;
  }
} // namespace qjs
