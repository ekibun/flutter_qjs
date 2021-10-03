if [ -d "./cxx/" ];then
    rm -r ./cxx
fi

mkdir ./cxx

sed 's/\#include \"quickjs\/quickjs.h\"/\#include \"quickjs.h\"/g' ../cxx/ffi.h > ./cxx/ffi.h
cp ../cxx/ffi.cpp ./cxx/ffi.cpp

cp ../cxx/quickjs/*.h ./cxx/
cp ../cxx/quickjs/*.c ./cxx/

quickjs_version=$(cat ../cxx/quickjs/VERSION)

sed '1i\
\#define CONFIG_VERSION \"'$quickjs_version'\"\
' ../cxx/quickjs/quickjs.c > ./cxx/quickjs.c