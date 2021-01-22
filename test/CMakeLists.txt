cmake_minimum_required(VERSION 3.7 FATAL_ERROR)
project(ffiquickjs LANGUAGES CXX)

include("${CMAKE_CURRENT_SOURCE_DIR}/../cxx/quickjs.cmake")

add_library(ffiquickjs SHARED ${CXX_LIB_DIR}/ffi.cpp)
target_compile_features(ffiquickjs PUBLIC cxx_std_17)
target_link_libraries(ffiquickjs PRIVATE quickjs)