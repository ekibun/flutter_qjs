# For more information about using CMake with Android Studio, read the
# documentation: https://d.android.com/studio/projects/add-native-code.html

# Sets the minimum version of CMake required to build the native library.

cmake_minimum_required(VERSION 3.4.1)
set(JNI_LIB_NAME libjsengine)

# Creates and names a library, sets it as either STATIC
# or SHARED, and provides the relative paths to its source code.
# You can define multiple libraries, and CMake builds them for you.
# Gradle automatically packages shared libraries with your APK.

add_library( # Sets the name of the library.
             ${JNI_LIB_NAME}

             # Sets the library as a shared library.
             SHARED

             # Provides a relative path to your source file(s).
             native-lib.cpp )

#iconv
add_subdirectory(../../../../cxx/libiconv libiconv.out)

# quickjs
set(QUICK_JS_LIB_DIR ../../../../cxx/quickjs)
file (STRINGS "${QUICK_JS_LIB_DIR}/VERSION" QUICKJS_VERSION)
set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -DDUMP_LEAKS -DCONFIG_VERSION=\\\"${QUICKJS_VERSION}\\\"")
target_sources(${JNI_LIB_NAME} PUBLIC
    ${QUICK_JS_LIB_DIR}/cutils.c
    ${QUICK_JS_LIB_DIR}/libregexp.c
    ${QUICK_JS_LIB_DIR}/libunicode.c
    ${QUICK_JS_LIB_DIR}/quickjs.c
)
target_compile_features(${JNI_LIB_NAME} PUBLIC cxx_std_17)

# Searches for a specified prebuilt library and stores the path as a
# variable. Because CMake includes system libraries in the search path by
# default, you only need to specify the name of the public NDK library
# you want to add. CMake verifies that the library exists before
# completing its build.

find_library( # Sets the name of the path variable.
              log-lib

              # Specifies the name of the NDK library that
              # you want CMake to locate.
              log )

# Specifies libraries CMake should link to your target library. You
# can link multiple libraries, such as libraries you define in this
# build script, prebuilt third-party libraries, or system libraries.

target_link_libraries( # Specifies the target library.
                       ${JNI_LIB_NAME}
                       libiconv
                       # Links the target library to the log library
                       # included in the NDK.
                       ${log-lib} )