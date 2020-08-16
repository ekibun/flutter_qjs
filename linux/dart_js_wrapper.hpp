/*
 * @Description: 
 * @Author: ekibun
 * @Date: 2020-08-14 21:45:02
 * @LastEditors: ekibun
 * @LastEditTime: 2020-08-15 15:42:55
 */
#include "../cxx/js_engine.hpp"
// #include <flutter/standard_method_codec.h>
#include <flutter_linux/flutter_linux.h>
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
  struct hash<FlValue>
  {
    std::size_t operator()(const FlValue *&key) const
    {
      return 0;
    }
  };
} // namespace std

namespace qjs
{
  JSValue dartToJsAtom(JSContext *ctx, FlValue *val)
  {
    FlValueType valType = fl_value_get_type(val);
    switch (valType)
    {
    case FL_VALUE_TYPE_BOOL:
      return JS_NewBool(ctx, fl_value_get_bool(val));
    case FL_VALUE_TYPE_INT:
      return JS_NewInt64(ctx, fl_value_get_int(val));
    case FL_VALUE_TYPE_FLOAT:
      return JS_NewFloat64(ctx, fl_value_get_float(val));
    case FL_VALUE_TYPE_STRING:
      return JS_NewString(ctx, fl_value_get_string(val));
    case FL_VALUE_TYPE_UINT8_LIST:
      return JS_NewArrayBufferCopy(ctx, fl_value_get_uint8_list(val), fl_value_get_length(val));
    case FL_VALUE_TYPE_INT32_LIST:
      return JS_NewArrayBufferCopy(ctx, (uint8_t *)fl_value_get_int32_list(val), fl_value_get_length(val));
    case FL_VALUE_TYPE_INT64_LIST:
      return JS_NewArrayBufferCopy(ctx, (uint8_t *)fl_value_get_int64_list(val), fl_value_get_length(val));
    // case FL_VALUE_TYPE_FLOAT_LIST:
    //   auto buf = fl_value_get_float_list(val);
    //   auto size = fl_value_get_length(val);
    //       JSValue array = JS_NewArray(ctx);
    //   for (size_t i = 0; i < size; i++)
    //     JS_DefinePropertyValue(
    //         ctx, array, JS_NewAtomUInt32(ctx, i), JS_NewFloat64(ctx, buf[i]),
    //         JS_PROP_C_W_E);
    //   return array;
    default:
      return JS_UNDEFINED;
    }
  }

  JSValue dartToJs(JSContext *ctx, FlValue *val, std::unordered_map<FlValue *, JSValue> cache = std::unordered_map<FlValue *, JSValue>())
  {
    if (fl_value_get_type(val) == FL_VALUE_TYPE_NULL)
      return JS_UNDEFINED;
    if (cache.find(val) != cache.end())
      return cache[val];
    {
      JSValue atomValue = dartToJsAtom(ctx, val);
      if (!JS_IsUndefined(atomValue))
        return atomValue;
    }
    // if (std::holds_alternative<flutter::EncodableList>(val))
    // {
    //   auto list = std::get<flutter::EncodableList>(val);
    //   JSValue array = JS_NewArray(ctx);
    //   cache[val] = array;
    //   auto size = (uint32_t)list.size();
    //   for (uint32_t i = 0; i < size; i++)
    //     JS_DefinePropertyValue(
    //         ctx, array, JS_NewAtomUInt32(ctx, i), dartToJs(ctx, list[i], cache),
    //         JS_PROP_C_W_E);
    //   return array;
    // }
    // if (std::holds_alternative<flutter::EncodableMap>(val))
    // {
    //   auto map = std::get<flutter::EncodableMap>(val);
    //   JSValue obj = JS_NewObject(ctx);
    //   cache[val] = obj;
    //   for (auto iter = map.begin(); iter != map.end(); ++iter)
    //     JS_DefinePropertyValue(
    //         ctx, obj, JS_ValueToAtom(ctx, dartToJs(ctx, iter->first, cache)), dartToJs(ctx, iter->second, cache),
    //         JS_PROP_C_W_E);
    //   return obj;
    // }
    return JS_UNDEFINED;
  }

  FlValue *jsToDart(Value val, std::unordered_map<Value, FlValue *> cache = std::unordered_map<Value, FlValue *>())
  {
    if (cache.find(val) != cache.end())
      return cache[val];
    if (JS_IsBool(val.v))
      return fl_value_new_bool((bool)val);
    if (JS_IsNumber(val.v))
      return fl_value_new_float((double)val);
    if (JS_IsString(val.v))
      return fl_value_new_string(((std::string)val).c_str());
    { // ArrayBuffer
      size_t size;
      uint8_t *buf = JS_GetArrayBuffer(val.ctx, &size, val.v);
      if (buf)
        // return (std::vector<uint8_t>(buf, buf + size));
        return fl_value_new_uint8_list(buf, size);
    }
    FlValue *ret;
    if (JS_IsUndefined(val.v) || JS_IsNull(val.v) || JS_IsUninitialized(val.v))
      goto exception;
    // if (JS_IsObject(val.v))
    // {
    //   if (JS_IsFunction(val.ctx, val.v))
    //   {
    //     flutter::EncodableMap retMap;
    //     retMap[std::string("__js_function__")] = (int64_t) new JSValue{JS_DupValue(val.ctx, val.v)};
    //     ret = retMap;
    //   }
    //   else if (JS_IsArray(val.ctx, val.v) > 0)
    //   {
    //     flutter::EncodableList retList;
    //     cache[val] = retList;
    //     uint32_t arrlen = (uint32_t)val["length"];
    //     for (uint32_t i = 0; i < arrlen; i++)
    //     {
    //       retList.push_back(jsToDart(val[i], cache));
    //     }
    //     ret = retList;
    //   }
    //   else
    //   {
    //     qjs::JSPropertyEnum *ptab;
    //     uint32_t plen;
    //     if (JS_GetOwnPropertyNames(val.ctx, &ptab, &plen, val.v, -1))
    //       goto exception;
    //     flutter::EncodableMap retMap;
    //     cache[val] = retMap;
    //     for (uint32_t i = 0; i < plen; i++)
    //     {
    //       retMap[jsToDart({val.ctx, JS_AtomToValue(val.ctx, ptab[i].atom)}, cache)] =
    //           jsToDart({val.ctx, JS_GetProperty(val.ctx, val.v, ptab[i].atom)}, cache);
    //       JS_FreeAtom(val.ctx, ptab[i].atom);
    //     }
    //     js_free(val.ctx, ptab);
    //     ret = retMap;
    //   }
    //   goto done;
    // }
  exception:
    ret = fl_value_new_null();
  done:
    return ret;
  }
} // namespace qjs
