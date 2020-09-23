#import "FlutterQjsPlugin.h"
#if __has_include(<flutter_qjs/flutter_qjs-Swift.h>)
#import <flutter_qjs/flutter_qjs-Swift.h>
#else
// Support project import fallback if the generated compatibility header
// is not copied when this plugin is created as a library.
// https://forums.swift.org/t/swift-static-libraries-dont-copy-generated-objective-c-header/19816
#import "flutter_qjs-Swift.h"
#endif

@implementation FlutterQjsPlugin
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
  [SwiftFlutterQjsPlugin registerWithRegistrar:registrar];
}
@end
