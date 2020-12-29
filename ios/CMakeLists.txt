cmake_minimum_required(VERSION 3.7 FATAL_ERROR)
project(ffiquickjs LANGUAGES CXX)

include("${CMAKE_CURRENT_SOURCE_DIR}/../cxx/quickjs.cmake")

add_library(ffiquickjs SHARED ${CXX_LIB_DIR}/ffi.cpp)
target_link_libraries(ffiquickjs PRIVATE quickjs)

set_target_properties(ffiquickjs PROPERTIES
    FRAMEWORK TRUE
    FRAMEWORK_VERSION A
    MACOSX_FRAMEWORK_IDENTIFIER soko.ekibun.ffiquickjs
# MACOSX_FRAMEWORK_INFO_PLIST Info.plist
# "current version" in semantic format in Mach-O binary file
    VERSION 1.0.0
# "compatibility version" in semantic format in Mach-O binary file
    SOVERSION 1.0.0
    MACOSX_FRAMEWORK_BUNDLE_VERSION 100
    MACOSX_FRAMEWORK_SHORT_VERSION_STRING 100
    XCODE_ATTRIBUTE_DYLIB_INSTALL_NAME_BASE "@rpath"
    PUBLIC_HEADER ffi.h
    XCODE_ATTRIBUTE_CODE_SIGN_IDENTITY "Apple Development"
    # RESOURCE "${RESOURCE_FILES}"
)
