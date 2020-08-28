set(PROJECT_NAME libiconv)

set(Header_Files
    "../include/iconv.h"
    "aliases.h"
    "aliases2.h"
    "aliases_aix.h"
    "aliases_aix_sysaix.h"
    "aliases_dos.h"
    "aliases_extra.h"
    "aliases_osf1.h"
    "aliases_osf1_sysosf1.h"
    "aliases_sysaix.h"
    "aliases_syshpux.h"
    "aliases_sysosf1.h"
    "aliases_syssolaris.h"
    "armscii_8.h"
    "ascii.h"
    "atarist.h"
    "big5.h"
    "big5_2003.h"
    "big5hkscs1999.h"
    "big5hkscs2001.h"
    "big5hkscs2004.h"
    "big5hkscs2008.h"
    "c99.h"
    "canonical.h"
    "canonical_aix.h"
    "canonical_aix_sysaix.h"
    "canonical_dos.h"
    "canonical_extra.h"
    "canonical_local.h"
    "canonical_local_sysaix.h"
    "canonical_local_syshpux.h"
    "canonical_local_sysosf1.h"
    "canonical_local_syssolaris.h"
    "canonical_osf1.h"
    "canonical_osf1_sysosf1.h"
    "canonical_sysaix.h"
    "canonical_syshpux.h"
    "canonical_sysosf1.h"
    "canonical_syssolaris.h"
    "ces_big5.h"
    "ces_gbk.h"
    "cjk_variants.h"
    "cns11643.h"
    "cns11643_1.h"
    "cns11643_15.h"
    "cns11643_2.h"
    "cns11643_3.h"
    "cns11643_4.h"
    "cns11643_4a.h"
    "cns11643_4b.h"
    "cns11643_5.h"
    "cns11643_6.h"
    "cns11643_7.h"
    "cns11643_inv.h"
    "converters.h"
    "cp1046.h"
    "cp1124.h"
    "cp1125.h"
    "cp1129.h"
    "cp1131.h"
    "cp1133.h"
    "cp1161.h"
    "cp1162.h"
    "cp1163.h"
    "cp1250.h"
    "cp1251.h"
    "cp1252.h"
    "cp1253.h"
    "cp1254.h"
    "cp1255.h"
    "cp1256.h"
    "cp1257.h"
    "cp1258.h"
    "cp437.h"
    "cp737.h"
    "cp775.h"
    "cp850.h"
    "cp852.h"
    "cp853.h"
    "cp855.h"
    "cp856.h"
    "cp857.h"
    "cp858.h"
    "cp860.h"
    "cp861.h"
    "cp862.h"
    "cp863.h"
    "cp864.h"
    "cp865.h"
    "cp866.h"
    "cp869.h"
    "cp874.h"
    "cp922.h"
    "cp932.h"
    "cp932ext.h"
    "cp936.h"
    "cp936ext.h"
    "cp943.h"
    "cp949.h"
    "cp950.h"
    "cp950ext.h"
    "dec_hanyu.h"
    "dec_kanji.h"
    "utf8.h"
)
source_group("Header Files" FILES ${Header_Files})

set(Source_Files
    "iconv.c"
)
source_group("Source Files" FILES ${Source_Files})

set(ALL_FILES
    ${Header_Files}
    ${Source_Files}
)

add_library(${PROJECT_NAME} STATIC ${ALL_FILES})

target_include_directories(${PROJECT_NAME} PUBLIC
    "${CMAKE_CURRENT_SOURCE_DIR}/..;"
    "${CMAKE_CURRENT_SOURCE_DIR}/../include;"
    "${CMAKE_CURRENT_SOURCE_DIR}/../libcharset"
)

add_dependencies(${PROJECT_NAME}
    libcharset
)

target_link_libraries(${PROJECT_NAME} PUBLIC "libcharset")

