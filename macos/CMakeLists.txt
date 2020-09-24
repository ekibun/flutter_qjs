cmake_minimum_required(VERSION 3.7 FATAL_ERROR)
project(flutterqjs LANGUAGES CXX)
set(CXX_LIB_DIR ${CMAKE_CURRENT_SOURCE_DIR}/../cxx)

add_library(flutterqjs SHARED ${CXX_LIB_DIR}/ffi.cpp)

# quickjs
set(QUICK_JS_LIB_DIR ${CXX_LIB_DIR}/quickjs)
file (STRINGS "${QUICK_JS_LIB_DIR}/VERSION" QUICKJS_VERSION)
add_library(quickjs STATIC
    ${QUICK_JS_LIB_DIR}/cutils.c
    ${QUICK_JS_LIB_DIR}/libregexp.c
    ${QUICK_JS_LIB_DIR}/libunicode.c
    ${QUICK_JS_LIB_DIR}/quickjs.c
)

project(quickjs LANGUAGES C)
target_compile_options(quickjs PRIVATE "-DCONFIG_VERSION=\"${QUICKJS_VERSION}\"")
target_compile_options(quickjs PRIVATE "-DDUMP_LEAKS")

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_LIBRARY_OUTPUT_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}/output/$ENV{ABI})
set(CMAKE_XCODE_ATTRIBUTE_DEVELOPMENT_TEAM "6SA4A2R2GU" CACHE INTERNAL "")

target_link_libraries(flutterqjs PRIVATE quickjs)

set_target_properties(flutterqjs PROPERTIES
    FRAMEWORK TRUE
    FRAMEWORK_VERSION A
    MACOSX_FRAMEWORK_IDENTIFIER soko.ekibun.flutterqjs
# MACOSX_FRAMEWORK_INFO_PLIST Info.plist
# "current version" in semantic format in Mach-O binary file
    VERSION 1.0.0
# "compatibility version" in semantic format in Mach-O binary file
    SOVERSION 1.0.0
    PUBLIC_HEADER ffi.h
    XCODE_ATTRIBUTE_CODE_SIGN_IDENTITY "Apple Development"
    # RESOURCE "${RESOURCE_FILES}"
)