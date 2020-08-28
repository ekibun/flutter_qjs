set(PROJECT_NAME libcharset)

add_library(${PROJECT_NAME} STATIC
    "localcharset.h"
    "relocatable.h"
    "localcharset.c"
    "relocatable.c"
)

target_include_directories(${PROJECT_NAME} PUBLIC
    "${CMAKE_CURRENT_SOURCE_DIR}/.."
)