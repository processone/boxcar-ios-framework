#
# Be sure to run `pod lib lint boxcar-ios-framework.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
s.name             = "boxcar-ios-framework"
s.version          = "1.0.3"
s.summary          = "iOS Push Framework for Boxcar"

s.osx.deployment_target = '10.7'
s.ios.deployment_target = '7.0'
s.platform = :osx, '10.7'
s.platform = :ios, '6.0'

s.description      = <<-DESC
iOS Push Framework for Boxcar
Enable push notification in your app easily with Boxcar framework
DESC

s.homepage         = "https://github.com/processone/boxcar-ios-framework"
s.license          = 'MIT'
s.author           = { "ProcessOne" => "pmglemaire@gmail.com" }
s.source           = { :git => "https://github.com/processone/boxcar-ios-framework.git", :tag => s.version.to_s }

s.platform     = :ios, '7.0'
s.requires_arc = true

s.module_map = 'module/module.modulemap'
s.preserve_path = 'module/module.modulemap'
s.xcconfig = { 'HEADER_SEARCH_PATHS' => '$(inherited)' '"${PODS_ROOT}/module"' '"$(SRCROOT)/module"' "$(SRCROOT)/Pods/Headers/", 'CLANG_ALLOW_NON_MODULAR_INCLUDES_IN_FRAMEWORK_MODULES' => 'YES' }

s.source_files = ['Boxcar/**/*', 'Libraries/ECLogging/**/*', 'Libraries/AFNetworking/**/*', 'module/module.modulemap']

s.frameworks = 'UIKit', 'AdSupport', 'Foundation', 'SystemConfiguration', 'MobileCoreServices'
s.dependency 'OHHTTPStubs'
s.dependency 'OCMock'

end