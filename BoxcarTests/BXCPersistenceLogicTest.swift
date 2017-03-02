//
//  BXCPersistenceLogicTest.swift
//  Boxcar
//
//  Created by Paul on 29/10/2015.
//  Copyright © 2017 ProcessOne. All rights reserved.
//

import Foundation
import XCTest

let filename = "BXCSettings.bin"

class BXCPersistenceLogicTests : XCTestCase {
	var persistence: BXCPersistence?

	override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
		print("Setup \(name)")
	
		measureBlock() {
			let settings = BXCPersistence.loadSettingsFromDisk()
			XCTAssertNotNil(settings, "Cannot create settings instance")
			XCTAssertTrue(settings.mode == "development", "")
		}
		
		measureBlock() {
			BoxcarLogicTests.removeSettingsFile()
			//BXCTestHelper.removeSettingsFile()
		}
    }

    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
		print("tearDown \(name)")
    }

	func saveDataToDiskAndReload() {
		//Should save data to disk and reload the same values
		let settings = BXCSettings()
		
		measureBlock() {
			settings.deviceToken = "deviceToken"
			settings.alias = "username"
			settings.mode = "development"
			settings.udid = "udid"
			settings.tags = ["tag1", "tag2"]
			settings.needUpdate = true
		}

		measureBlock() {
			BXCPersistence.saveSettingsToDisk(settings)
		}


		let reloadedSettings = BXCPersistence.loadSettingsFromDisk()
	
		XCTAssertNotNil(reloadedSettings, "Cannot create settings instance")
		XCTAssertTrue(reloadedSettings.deviceToken == settings.deviceToken, "")
		XCTAssertTrue(reloadedSettings.alias == settings.alias, "")
		XCTAssertTrue(reloadedSettings.udid == settings.udid, "")
		XCTAssertTrue(reloadedSettings.mode == settings.mode, "")
		XCTAssertTrue(reloadedSettings.tags == settings.tags as NSArray, "")
		XCTAssertTrue(reloadedSettings.needUpdate, "")

		measureBlock() {
			BoxcarLogicTests.removeSettingsFile()
		}
	}
}
