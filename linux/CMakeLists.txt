cmake_minimum_required(VERSION 3.10)

include("${CMAKE_CURRENT_SOURCE_DIR}/../cxx/quickjs.cmake")
target_compile_options(quickjs PRIVATE "-fPIC")

set(PROJECT_NAME "flutter_qjs")
project(${PROJECT_NAME} LANGUAGES CXX)

set(PLUGIN_NAME "${PROJECT_NAME}_plugin")

add_library(${PLUGIN_NAME} SHARED
  "${PLUGIN_NAME}.cc"
  "${CXX_LIB_DIR}/ffi.cpp"
)

apply_standard_settings(${PLUGIN_NAME})
target_compile_features(${PLUGIN_NAME} PUBLIC cxx_std_17)
set_target_properties(${PLUGIN_NAME} PROPERTIES
  CXX_VISIBILITY_PRESET hidden)
target_compile_definitions(${PLUGIN_NAME} PRIVATE FLUTTER_PLUGIN_IMPL)
target_include_directories(${PLUGIN_NAME} INTERFACE
  "${CMAKE_CURRENT_SOURCE_DIR}/include")
target_link_libraries(${PLUGIN_NAME} PRIVATE flutter)
target_link_libraries(${PLUGIN_NAME} PRIVATE quickjs)
target_link_libraries(${PLUGIN_NAME} PRIVATE PkgConfig::GTK)

# List of absolute paths to libraries that should be bundled with the plugin
set(flutter_qjs_bundled_libraries
  ""
  PARENT_SCOPE
)
