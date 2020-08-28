cmake_minimum_required(VERSION 3.10.0)

project(libiconv)

include_directories(
  ${CMAKE_CURRENT_SOURCE_DIR}
  ${CMAKE_CURRENT_SOURCE_DIR}/include
  ${CMAKE_CURRENT_SOURCE_DIR}/libcharset
  ${CMAKE_CURRENT_SOURCE_DIR}/libiconv
)

add_library( # Sets the name of the library.
  libiconv

  # Sets the library as a static library.
  STATIC

  # Provides a relative path to your source file(s).
  ${CMAKE_CURRENT_SOURCE_DIR}/libiconv/iconv.c
  ${CMAKE_CURRENT_SOURCE_DIR}/libcharset/localcharset.c
  ${CMAKE_CURRENT_SOURCE_DIR}/libiconv/relocatable.c
)

if( MSVC )
  target_compile_options(libiconv PRIVATE "/wd4311")
else()
  target_compile_options(libiconv PRIVATE "-Wno-parentheses-equality")
endif()