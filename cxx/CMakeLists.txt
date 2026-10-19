cmake_minimum_required(VERSION 3.16)
project(flutter_qjs LANGUAGES C CXX)

set(CMAKE_C_STANDARD 11)
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_POSITION_INDEPENDENT_CODE ON)

# quickjs-ng is vendored as a git submodule. Only its static library is needed,
# its own install rules are disabled so that `install` only installs our lib.
set(QJS_ENABLE_INSTALL OFF CACHE BOOL "" FORCE)
set(QJS_BUILD_EXAMPLES OFF CACHE BOOL "" FORCE)
set(QJS_BUILD_CLI_STATIC OFF CACHE BOOL "" FORCE)
set(QJS_BUILD_WERROR OFF CACHE BOOL "" FORCE)
add_subdirectory(quickjs EXCLUDE_FROM_ALL)

add_library(flutter_qjs SHARED ffi.cpp)
target_include_directories(flutter_qjs PRIVATE ${CMAKE_CURRENT_SOURCE_DIR})
target_link_libraries(flutter_qjs PRIVATE qjs)

if(MSVC)
    # https://github.com/ekibun/flutter_qjs/issues/7
    target_compile_options(qjs PRIVATE /Oi-)
    target_compile_options(flutter_qjs PRIVATE /Oi-)
endif()

if(ANDROID)
    # Android 15+ devices may use 16KB memory pages.
    target_link_options(flutter_qjs PRIVATE "-Wl,-z,max-page-size=16384")
    target_link_libraries(flutter_qjs PRIVATE log)
endif()

# `hook/build.dart` passes `targets: ['install']` together with a
# CMAKE_INSTALL_PREFIX inside the hook output directory, and then picks the
# library up from there.
install(TARGETS flutter_qjs
    RUNTIME DESTINATION lib
    LIBRARY DESTINATION lib
    ARCHIVE DESTINATION lib
)
