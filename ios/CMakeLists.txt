cmake_minimum_required(VERSION 3.7 FATAL_ERROR)
project(ffiquickjs LANGUAGES CXX)

include("${CMAKE_CURRENT_SOURCE_DIR}/../cxx/quickjs.cmake")

add_library(ffiquickjs SHARED ${CXX_LIB_DIR}/ffi.cpp)
target_link_libraries(ffiquickjs PRIVATE quickjs)

# IOSTODO change to your team id
set(CMAKE_XCODE_ATTRIBUTE_DEVELOPMENT_TEAM "6SA4A2R2GU" CACHE INTERNAL "")

set_target_properties(ffiquickjs PROPERTIES
    FRAMEWORK TRUE
    FRAMEWORK_VERSION A
    MACOSX_FRAMEWORK_IDENTIFIER soko.ekibun.ffiquickjs
# MACOSX_FRAMEWORK_INFO_PLIST Info.plist
# "current version" in semantic format in Mach-O binary file
    VERSION 1.0.0
# "compatibility version" in semantic format in Mach-O binary file
    SOVERSION 1.0.0
    PUBLIC_HEADER ffi.h
    XCODE_ATTRIBUTE_CODE_SIGN_IDENTITY "Apple Development"
    # RESOURCE "${RESOURCE_FILES}"
)