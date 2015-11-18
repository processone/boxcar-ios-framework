//
//  BXCEventStreamLogicTest.swift
//  Boxcar
//
//  Created by Paul on 30/10/2015.
//  Copyright © 2015 ProcessOne. All rights reserved.
//

import Foundation
import XCTest

class BXCEventStreamLogicTests : XCTestCase {
	
	var eventStream: BXCEventStream?
	
	override func setUp() {
		super.setUp()
		// Put setup code here. This method is called before the invocation of each test method in the class.
		print("Setup \(name)")
		
		measureBlock() {
			self.eventStream = BXCEventStream(streamId: "TestUID")
		}
		XCTAssertNotNil(self.eventStream, "Cannot create BXCEventStream instance")
	}
	
	override func tearDown() {
		// Put teardown code here. This method is called after the invocation of each test method in the class.
		super.tearDown()
		print("tearDown \(name)")
	}
	
	func testEventStreamParsing() {
		XCTAssertTrue(eventStream!.parseEventData("id: 122\ndata: zog\n\n") == "zog", "BXCEventStream should parse basic message")
		XCTAssertTrue(eventStream!.parseEventData("id: 7qot9\ndata: {\"myfield1\":[\"Test\"],\"field2\":\"zogzog\"}\n\n") == "{\"myfield1\":[\"Test\"],\"field2\":\"zogzog\"}",
	"BXCEventStream should parse JSON message")
	}
}
