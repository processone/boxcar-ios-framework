target :BoxcarTests, :exclusive => true do
   pod 'Kiwi/XCTest'
   pod 'OHHTTPStubs'
   pod 'OCMock'
   pod "xctest-assert-eventually"
end

post_install do |installer|
  installer.project.targets.each do |target|
    target.build_configurations.each do |config|
      config.build_settings['ARCHS'] = "$(ARCHS_STANDARD_INCLUDING_64_BIT)"
    end
  end
end
