//
//  BXCSettingsLogicTest.swift
//  Boxcar
//
//  Created by Paul on 29/10/2015.
//  Copyright © 2017 ProcessOne. All rights reserved.
//

import Foundation
import XCTest

class BXCSettingsLogicTests: XCTestCase {

 var settings: BXCSettings?

	override func setUp() {
		super.setUp()
			// Put setup code here. This method is called before the invocation of each test method in the class.
		print("Setup \(name)")
		
		measureBlock() {
			self.settings = BXCSettings()
		}
		XCTAssertNotNil(self.settings, "Cannot create settings instance")
	}
	
	override func tearDown() {
		// Put teardown code here. This method is called after the invocation of each test method in the class.
		super.tearDown()
		print("tearDown \(name)")
	}
	
	func acceptValidProperties() {
		//Should accept valid properties
		measureBlock() {
			self.settings = BXCSettings()
	
			self.settings!.deviceToken = "deviceToken"
			self.settings!.alias = "alias"
			self.settings!.mode = "development"
			self.settings!.udid = "udid"
			self.settings!.tags = ["tag1", "tag2"]
		}
		XCTAssertNotNil(settings, "Cannot create settings instance")
		XCTAssertTrue(self.settings!.deviceToken == "deviceToken", "")
		XCTAssertTrue(self.settings!.alias == "alias", "")
		XCTAssertTrue(self.settings!.mode == "development", "")
		XCTAssertTrue(self.settings!.udid == "udid", "")
		XCTAssertTrue(self.settings!.tags == ["tag1", "tag2"] as NSArray, "")
	}
	
	func ignoreInvalidMode() {
		//Should ignore invalid mode
		measureBlock() {
			self.settings = BXCSettings()
			self.settings!.mode = "invalidmode"
		}
		XCTAssertTrue(self.settings!.mode == "development", "")
	}
}
