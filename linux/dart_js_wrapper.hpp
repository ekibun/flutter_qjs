/*
 * @Description: 
 * @Author: ekibun
 * @Date: 2020-08-14 21:45:02
 * @LastEditors: ekibun
 * @LastEditTime: 2020-08-19 00:34:43
 */
#include "../cxx/js_engine.hpp"
#include <flutter_linux/flutter_linux.h>

namespace std
{
  template <>
  struct hash<qjs::Value>
  {
    size_t operator()(const qjs::Value &key) const
    {
      return JS_VALUE_GET_TAG(key.v);
    }
  };
} // namespace std

namespace qjs
{
  JSValue dartToJs(JSContext *ctx, FlValue *val)
  {
    if (val == nullptr)
      return JS_UNDEFINED;
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
      return JS_NewArrayBufferCopy(ctx, (uint8_t *)fl_value_get_int32_list(val), fl_value_get_length(val) * 4);
    case FL_VALUE_TYPE_INT64_LIST:
      return JS_NewArrayBufferCopy(ctx, (uint8_t *)fl_value_get_int64_list(val), fl_value_get_length(val) * 8);
    case FL_VALUE_TYPE_FLOAT_LIST:
    {
      auto buf = fl_value_get_float_list(val);
      auto size = (uint32_t)fl_value_get_length(val);
      JSValue array = JS_NewArray(ctx);
      for (uint32_t i = 0; i < size; ++i)
        JS_DefinePropertyValue(
            ctx, array, JS_NewAtomUInt32(ctx, i), JS_NewFloat64(ctx, buf[i]),
            JS_PROP_C_W_E);
      return array;
    }
    case FL_VALUE_TYPE_LIST:
    {
      auto size = (uint32_t)fl_value_get_length(val);
      JSValue array = JS_NewArray(ctx);
      for (uint32_t i = 0; i < size; ++i)
        JS_DefinePropertyValue(
            ctx, array, JS_NewAtomUInt32(ctx, i),
            dartToJs(ctx, fl_value_get_list_value(val, i)),
            JS_PROP_C_W_E);
      return array;
    }
    case FL_VALUE_TYPE_MAP:
    {
      auto size = (uint32_t)fl_value_get_length(val);
      JSValue obj = JS_NewObject(ctx);
      for (uint32_t i = 0; i < size; ++i)
        JS_DefinePropertyValue(
            ctx, obj,
            JS_ValueToAtom(ctx, dartToJs(ctx, fl_value_get_map_key(val, i))),
            dartToJs(ctx, fl_value_get_map_value(val, i)),
            JS_PROP_C_W_E);
      return obj;
    }
    default:
      return JS_UNDEFINED;
    }
  }

  FlValue *jsToDart(Value val, std::unordered_map<Value, FlValue *> cache = std::unordered_map<Value, FlValue *>())
  {
    int tag = JS_VALUE_GET_TAG(val.v);
    if (JS_TAG_IS_FLOAT64(tag))
      return fl_value_new_float((double)val);
    switch (tag)
    {
    case JS_TAG_BOOL:
      return fl_value_new_bool((bool)val);
    case JS_TAG_INT:
      return fl_value_new_int((int64_t)val);
    case JS_TAG_STRING:
      return fl_value_new_string(((std::string)val).c_str());
    case JS_TAG_OBJECT:
    { // ArrayBuffer
      size_t size;
      uint8_t *buf = JS_GetArrayBuffer(val.ctx, &size, val.v);
      if (buf)
        return fl_value_new_uint8_list(buf, size);
    }
      if (JS_IsFunction(val.ctx, val.v))
      {
        FlValue *retMap = fl_value_new_map();
        fl_value_set_string_take(retMap, "__js_function__", fl_value_new_int((int64_t) new JSValue{JS_DupValue(val.ctx, val.v)}));
        return retMap;
      }
      else if (JS_IsArray(val.ctx, val.v) > 0)
      {
        FlValue *retList = fl_value_new_list();
        cache[val] = retList;
        uint32_t arrlen = (uint32_t)val["length"];
        for (uint32_t i = 0; i < arrlen; i++)
        {
          fl_value_append_take(retList, jsToDart(val[i], cache));
        }
        return retList;
      }
      else
      {
        qjs::JSPropertyEnum *ptab;
        uint32_t plen;
        if (JS_GetOwnPropertyNames(val.ctx, &ptab, &plen, val.v, -1))
          return fl_value_new_null();
        FlValue *retMap = fl_value_new_map();
        cache[val] = retMap;
        for (uint32_t i = 0; i < plen; i++)
        {
          fl_value_set_take(
              retMap,
              jsToDart({val.ctx, JS_AtomToValue(val.ctx, ptab[i].atom)}, cache),
              jsToDart({val.ctx, JS_GetProperty(val.ctx, val.v, ptab[i].atom)}, cache));
          JS_FreeAtom(val.ctx, ptab[i].atom);
        }
        js_free(val.ctx, ptab);
        return retMap;
      }
    default:
      return fl_value_new_null();
    }
  }
} // namespace qjs
