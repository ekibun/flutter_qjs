cmake_minimum_required(VERSION 3.7 FATAL_ERROR)
project(ffiquickjs LANGUAGES CXX)
set(CMAKE_EXECUTABLE_SUFFIX ".html")

include("${CMAKE_CURRENT_SOURCE_DIR}/../cxx/quickjs.cmake")

add_executable(ffiquickjs ${CXX_LIB_DIR}/ffi.cpp)

set_target_properties(ffiquickjs PROPERTIES LINK_FLAGS "-o index.html")
target_link_libraries(ffiquickjs PRIVATE quickjs)