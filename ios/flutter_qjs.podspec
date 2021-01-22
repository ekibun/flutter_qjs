#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint flutter_qjs.podspec' to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'flutter_qjs'
  s.version          = '0.0.1'
  s.summary          = 'A quickjs engine for flutter.'
  s.description      = <<-DESC
This plugin is a simple js engine for flutter using the `quickjs` project. Plugin currently supports all the platforms except web!
                       DESC
  s.homepage         = 'https://github.com/ekibun/flutter_qjs'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'ekibun' => 'soekibun@gmail.com' }
  s.source           = { :path => '.' }
  s.compiler_flags = '-DDUMP_LEAKS'
  s.source_files = ['Classes/**/*', 'cxx/*.{c,cpp}']
  s.dependency 'Flutter'
  s.platform = :ios, '8.0'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.prepare_command = 'sh ../cxx/prebuild.sh'
  s.swift_version = '5.0'
end
