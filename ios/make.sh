###
 # @Description: 
 # @Author: ekibun
 # @Date: 2020-09-24 00:50:13
 # @LastEditors: ekibun
 # @LastEditTime: 2020-09-24 00:51:43
### 
mkdir build
cd build

cmake .. -G Xcode \
  -DCMAKE_SYSTEM_NAME=iOS \
  -DCMAKE_IOS_INSTALL_COMBINED=true \
  -DCMAKE_XCODE_ATTRIBUTE_ONLY_ACTIVE_ARCH=NO
cmake --build . --config Debug -- -arch arm64
cmake --build . --config Debug -- -sdk iphonesimulator -arch x86_64

mkdir ffiquickjs.framework
lipo -create 'Debug-iphoneos/ffiquickjs.framework/ffiquickjs' 'Debug-iphonesimulator/ffiquickjs.framework/ffiquickjs' -output 'ffiquickjs.framework/ffiquickjs'
cp -f 'Debug-iphoneos/ffiquickjs.framework/Info.plist' 'ffiquickjs.framework/Info.plist'

cd ..