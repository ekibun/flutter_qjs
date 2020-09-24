###
 # @Description: 
 # @Author: ekibun
 # @Date: 2020-09-24 00:50:13
 # @LastEditors: ekibun
 # @LastEditTime: 2020-09-24 00:51:43
### 
mkdir build
cd build
cmake .. -G Xcode -DCMAKE_TOOLCHAIN_FILE=../ios.toolchain.cmake -DPLATFORM=OS64COMBINED
cmake --build . --config Debug
