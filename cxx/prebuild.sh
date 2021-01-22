if [ -d "./cxx/" ];then
    rm -r ./cxx
fi

mkdir ./cxx

sed 's/\#include \"quickjs\/quickjs.h\"/\#include \"quickjs.h\"/g' ../cxx/ffi.h > ./cxx/ffi.h
cp ../cxx/ffi.cpp ./cxx/ffi.cpp

quickjs_version=$(cat ../cxx/quickjs/VERSION)

sed '1i\
\#define CONFIG_VERSION \"'$quickjs_version'\"\
' ../cxx/quickjs/quickjs.c > ./cxx/quickjs.c

quickjs_src=(
    "list.h"
    "cutils.c"
    "libregexp.c"
    "libunicode.c"
    "cutils.h"
    "libregexp.h"
    "libunicode.h"
    "quickjs.h"
    "quickjs-atom.h"
    "quickjs-opcode.h"
    "libregexp-opcode.h"
    "libunicode-table.h"
)
for item in ${quickjs_src[*]}
do
    cp ../cxx/quickjs/$item ./cxx/$item
done