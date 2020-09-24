###
 # @Description: 
 # @Author: ekibun
 # @Date: 2020-09-24 00:50:13
 # @LastEditors: ekibun
 # @LastEditTime: 2020-09-24 00:51:43
### 
mkdir build
cd build
cmake .. -G Xcode -DCMAKE_OSX_ARCHITECTURES=x86_64
cmake --build . --config Debug
