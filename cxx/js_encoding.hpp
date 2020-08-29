/*
 * @Description: 
 * @Author: ekibun
 * @Date: 2020-08-29 18:33:27
 * @LastEditors: ekibun
 * @LastEditTime: 2020-08-29 23:49:34
 */
#include "quickjs/quickjspp.hpp"
#include "libiconv/iconv.hpp"

namespace qjs
{
  class js_encoding
  {
  protected:
    iconvpp::converter *converter = nullptr;
  public:
    bool hasConverter = false;

    js_encoding(std::string from, std::string to, bool fatal)
    {
      try
      {
        converter = new iconvpp::converter(from, to, !fatal);
        hasConverter = converter != nullptr;
      }
      catch (std::runtime_error &) {}
    }

    Value encode(Value input)
    {
      auto inputStr = (std::string)input;
      try
      {
        std::string output;
        converter->convert(inputStr, output);
        return {input.ctx, JS_NewArrayBufferCopy(input.ctx, (uint8_t *)output.c_str(), output.size())};
      }
      catch (std::runtime_error &)
      {
        // TODO throw with message
        JS_ThrowTypeError(input.ctx, "Failed to execute 'encode' on 'TextEncoder': The encoded data was not valid.");
        throw exception{};
      }
    }

    std::string decode(Value input)
    {
      size_t size;
      uint8_t *buf = JS_GetArrayBuffer(input.ctx, &size, input.v);
      try
      {
        std::string output;
        converter->convert(std::string((char *)buf, size), output);
        return output;
      }
      catch (std::runtime_error &)
      {
        // TODO throw with message
        JS_ThrowTypeError(input.ctx, "Failed to execute 'decode' on 'TextDecoder': The encoded data was not valid.");
        throw exception{};
      }
    }

    ~js_encoding()
    {
      if (converter)
        delete converter;
    }
  };
} // namespace qjs