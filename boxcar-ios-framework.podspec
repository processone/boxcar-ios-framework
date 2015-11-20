#
# Be sure to run `pod lib lint boxcar-ios-framework.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
s.name             = "boxcar-ios-framework"
s.version          = "1.0.1"
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
# s.screenshots     = "www.example.com/screenshots_1", "www.example.com/screenshots_2"
s.license          = 'MIT'
s.author           = { "ProcessOne" => "pmglemaire@gmail.com" }
s.source           = { :git => "https://github.com/processone/boxcar-ios-framework.git", :tag => s.version.to_s }
# s.social_media_url = 'https://twitter.com/<TWITTER_USERNAME>'

s.platform     = :ios, '7.0'
s.requires_arc = true

s.source_files = ['Boxcar/**/*', 'Libraries/ECLogging/**/*', 'Libraries/AFNetworking/**/*']
#, 'Libraries/**/*'

s.frameworks = 'UIKit', 'AdSupport', 'Foundation', 'SystemConfiguration', 'MobileCoreServices'
s.dependency 'OHHTTPStubs'
s.dependency 'OCMock'
end