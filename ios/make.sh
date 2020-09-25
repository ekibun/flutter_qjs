###
 # @Description: 
 # @Author: ekibun
 # @Date: 2020-09-24 00:50:13
 # @LastEditors: ekibun
 # @LastEditTime: 2020-09-24 00:51:43
### 
mkdir build
cd build

# IOSTODO -DPLATFORM: for simulators use SIMULATOR64, for real devices use OS64COMBINED
cmake .. -G Xcode -DCMAKE_TOOLCHAIN_FILE=../ios.toolchain.cmake -DPLATFORM=OS64COMBINED
cmake --build . --config Debug
