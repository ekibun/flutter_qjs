/*
 * @Description: 
 * @Author: ekibun
 * @Date: 2020-08-29 18:33:27
 * @LastEditors: ekibun
 * @LastEditTime: 2020-08-29 19:36:33
 */
#include "quickjs/quickjspp.hpp"
#include "libiconv/iconv.hpp"

namespace qjs
{
  class js_encoding
  {
  protected:
    iconvpp::converter *converter = nullptr;
    std::string __encoding;
  public:

    js_encoding(std::string encoding)
    {
      __encoding = encoding;
      try
      {
        converter = new iconvpp::converter(encoding, "utf-8", true);
      }
      catch (std::runtime_error &)
      {
        __encoding = "utf-8";
      }
    }

    ~js_encoding()
    {
      if (converter)
        delete converter;
    }
  };

  class js_text_encoder : public js_encoding {
  public:
    std::string encoding;
    js_text_encoder(std::string encoding) : js_encoding(encoding) {
      this->encoding = __encoding;
    }
    
    Value encode(Value input)
    {
      auto inputStr = (std::string)input;
      try
      {
        if (!converter)
          throw std::runtime_error("no match encoding");
        std::string output;
        converter->convert(inputStr, output);
        return {input.ctx, JS_NewArrayBufferCopy(input.ctx, (uint8_t *)output.c_str(), output.size())};
      }
      catch (std::runtime_error &)
      {
        return {input.ctx, JS_NewArrayBufferCopy(input.ctx, (uint8_t *)inputStr.c_str(), inputStr.size())};
      }
    }
  };

  class js_text_decoder : public js_encoding
  {
  public:
    std::string encoding;
    js_text_decoder(std::string encoding) : js_encoding(encoding) {
      this->encoding = __encoding;
    }

    std::string decode(Value input)
    {
      size_t size;
      uint8_t *buf = JS_GetArrayBuffer(input.ctx, &size, input.v);
      if (!buf)
      {
        JS_ThrowTypeError(input.ctx, "The provided value is not of type '(ArrayBuffer or ArrayBufferView)'");
        throw exception();
      }
      std::string inputStr((char *)buf, size);
      try
      {
        std::string output;
        if (!converter)
          throw std::runtime_error("no match encoding");
        converter->convert(inputStr, output);
        return output;
      }
      catch (std::runtime_error &)
      {
        return inputStr;
      }
    }
  };
} // namespace qjs