//
//  BXCJSONLogicTest.swift
//  Boxcar
//
//  Created by Paul on 30/10/2015.
//  Copyright © 2015 ProcessOne. All rights reserved.
//

import Foundation
import XCTest

class BXCJSONLogicTests : XCTestCase {
	
	override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
		print("Setup \(name)")
    }

    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
		print("tearDown \(name)")
    }

	func generatePayloadForDeviceRegistration() {
		//Should generate payload for device registration
		let params = NSDictionary()
		
		measureBlock() {
			params.setValue("username@process-one.net", forKey: "alias")
			params.setValue("production", forKey: "mode")
			params.setValue("MYUDID", forKey: "udid")
			params.setValue(true, forKey: "push")
		}
		measureBlock() {
			let payload = BXCJSON.getRegisterPayloadWith(params as [NSObject : AnyObject])
			XCTAssertNotNil(payload, "Cannot create payload instance")
			print("\(payload)")
		}
	}
	
	func generatePayloadWithExpireField() {
		//Should generate payload with proper expires field
		let params = NSDictionary()
		
		measureBlock() {
			params.setValue("username@process-one.net", forKey: "alias")
			params.setValue("production", forKey: "mode")
			params.setValue("MYUDID", forKey: "udid")
			params.setValue(true, forKey: "push")
		}

		let payload = BXCJSON.getRegisterPayloadWith(params as [NSObject : AnyObject])
		XCTAssertNotNil(payload, "Cannot create payload instance")
		
		// Parse payload
		measureBlock() {
			do {
				let json: NSDictionary? = try NSJSONSerialization.JSONObjectWithData(payload.dataUsingEncoding(NSUTF8StringEncoding)!, options: .AllowFragments) as! NSDictionary
				// We can parse the payload:
				let expirationTimestamp = json!.objectForKey("expires")
				let decimal = round(json!.objectForKey("expires")!.doubleValue)
				// expires timestamp is an integer:
				XCTAssertTrue(expirationTimestamp as! Double == decimal, "")
				
				// expires timestamp is in the future:
				XCTAssertLessThan(NSDate().timeIntervalSince1970 + 25, expirationTimestamp as! Double, "")
				//	[[futuretimeStamp should] beLessThan:expirationTimestamp];
			} catch let error as NSError {
				XCTAssertNil(error, "Error should be nil")
			} catch {
				print("Error data")
			}
		}
	}
	
	func checkNullableUUID() {
		//Should not pass nil udid as '(null)' string
		let params = NSDictionary()
		
		measureBlock() {
			params.setValue("username@process-one.net", forKey: "alias")
			params.setValue("production", forKey: "mode")
			params.setValue("MYUDID", forKey: "udid")
			params.setValue(true, forKey: "push")
		}
		
		let payload = BXCJSON.getRegisterPayloadWith(params as [NSObject : AnyObject])
		XCTAssertNotNil(payload, "Cannot create payload instance")
		print("Payload = \(payload)")
		
		// Parse payload
		measureBlock() {
			do {
				let json: NSDictionary? = try NSJSONSerialization.JSONObjectWithData(payload.dataUsingEncoding(NSUTF8StringEncoding)!, options: .AllowFragments) as! NSDictionary
				// Nil or empty values have their keys removed from JSON:
				XCTAssertNil(json!.objectForKey("udid"), "Error should be nil")
				XCTAssertNil(json!.objectForKey("alias"), "Error should be nil")
			} catch let error as NSError {
				XCTAssertNil(error, "Error should be nil")
			} catch {
				print("Error data")
			}
		}
	}
}