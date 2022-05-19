<!--
 * @Description: 
 * @Author: ekibun
 * @Date: 2020-08-08 08:16:50
 * @LastEditors: ekibun
 * @LastEditTime: 2020-12-02 11:36:40
-->

## 0.3.7

* add timeout and memory limit
* fixed compiler error in windows release
* fixed crash when encoding Error object
* updated to latest quickjs

## 0.3.6

* upgrade ffi to 1.0.0.
* nullsafety.

## 0.3.5

* downgrade ffi to 0.1.3.

## 0.3.4

* upgrade ffi to 1.0.0.

## 0.3.3

* remove `JSInvokable.call`.
* fix crash when throw error.
* add reference count and leak detection.

## 0.3.2

* fix Promise reject cannot get Exception string.
* wrap JSError.

## 0.3.1

* code clean up.
* fix isolate wrap error.

## 0.3.0

* breakdown change to remove `channel`.
* convert dart function to js.

## 0.2.7

* fix error in ios build.

## 0.2.6

* fix stack overflow in jsToCString.

## 0.2.5

* remove dart object when jsfree.

## 0.2.4

* wrap dart object to js.
* fix stack overflow when use jsCall nesting.

## 0.2.3

* fix compiler error in windows release.

## 0.2.2

* add option to change max stack size.

## 0.2.1

* code cleanup.

## 0.2.0

* breakdown change with new constructor.
* fix make release in ios.
* fix crash in wrapping js Promise.

## 0.1.4

* fix crash on android x86.

## 0.1.3

* fix randomly crash by stack overflow.

## 0.1.2

* fix qjs memory leak.

## 0.1.1

* run on isolate.

## 0.1.0

* refactor with ffi.

## 0.0.6

* remove handler when destroy.

## 0.0.5

* add js module.

## 0.0.4

* remove C++ std limitation for linux and android.

## 0.0.3

* fix js memory leak.

## 0.0.2

* update example.

## 0.0.1

* initial publish.
