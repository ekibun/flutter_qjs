cmake_minimum_required(VERSION 3.7 FATAL_ERROR)
project(ffi_library LANGUAGES CXX)
set(CXX_LIB_DIR ${CMAKE_CURRENT_SOURCE_DIR}/../cxx)

add_library(flutter_qjs SHARED ${CXX_LIB_DIR}/ffi.cpp)

# quickjs
set(QUICK_JS_LIB_DIR ${CXX_LIB_DIR}/quickjs)
file (STRINGS "${QUICK_JS_LIB_DIR}/VERSION" QUICKJS_VERSION)
add_library(libquickjs STATIC
    ${QUICK_JS_LIB_DIR}/cutils.c
    ${QUICK_JS_LIB_DIR}/libregexp.c
    ${QUICK_JS_LIB_DIR}/libunicode.c
    ${QUICK_JS_LIB_DIR}/quickjs.c
)

project(libquickjs LANGUAGES C)
target_compile_options(libquickjs PRIVATE "-DCONFIG_VERSION=\"${QUICKJS_VERSION}\"")
target_compile_options(libquickjs PRIVATE "-DDUMP_LEAKS")

target_link_libraries(flutter_qjs PRIVATE libquickjs)
