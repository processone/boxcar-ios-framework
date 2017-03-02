//
//  BoxcarLogicTest.swift
//  Boxcar
//
//  Created by Paul on 30/10/2015.
//  Copyright © 2017 ProcessOne. All rights reserved.
//

import Foundation
import XCTest

class BoxcarLogicTests : XCTestCase {
	
	override func setUp() {
		super.setUp()
		// Put setup code here. This method is called before the invocation of each test method in the class.
		print("Setup \(name)")
		
		OHHTTPStubs.setEnabled(true)
		OHHTTPStubs.onStubActivation { (request, stub) -> Void in
			print("Request to \(request.URL) has been stubbed with \(stub.name)")
		}
	}
	
	override func tearDown() {
		// Put teardown code here. This method is called after the invocation of each test method in the class.
		print("tearDown \(name)")
		super.tearDown()
		OHHTTPStubs.removeAllStubs()
	}
	
	// simple test to ensure building, linking,
	// and running test case works in the project
	func testOCMockPass() {
		let mock = OCMockObject.mockForClass(NSString)
		mock.stub().andReturn("mocktest")
		
		let returnValue = "mocktest"
		XCTAssertEqual("mocktest", returnValue, "Should have returned the expected string.")
	}
 
	func testOCMockFail() {
		let mock = OCMockObject.mockForClass(NSString)
		mock.stub().andReturn("mocktest")
		
		let returnValue = "mocktest"
		XCTAssertNotEqual("This is not the expected result", returnValue, "Should have returned the expected string.")
	}
	
	class func waitForVerifiedMock(inMock: OCMockObject, delay: NSTimeInterval) {
		var i:NSTimeInterval = 0
		
		while (i < delay) {
			inMock.verify()
			NSRunLoop.currentRunLoop().runUntilDate(NSDate(timeIntervalSinceNow: 0.5))
			i += 0.5
		}
		inMock.verify()
	}
	
	class func removeSettingsFile() {
		//Will remove settings file if there is one
		let filename = "BXCSettings.bin"
		let fileMgr = NSFileManager.defaultManager()
		
		// To have the test pass, I had to manually create missing simulator directory:
		// /Users/mremond/Library/Application\ Support/iPhone\ Simulator/6.1/Documents
		// So I make sure this directory exists:
		// I probably should make the same check in the code for robustness
		let path = NSSearchPathForDirectoriesInDomains(.DocumentDirectory, .UserDomainMask, true)[0]
		var isDir: ObjCBool = false
		
		if fileMgr.fileExistsAtPath(path, isDirectory: &isDir) {
			do {
				try fileMgr.createDirectoryAtPath(path, withIntermediateDirectories: false, attributes: nil)
			} catch { }
		}
		do {
			try fileMgr.removeItemAtPath(BXCPersistence.getFullPathForFile(filename))
		} catch { }
	}
	
	func test_uploadSettingsTriggersNotification() {
		// It can send data to server and post a notification on successful update
		let options = NSMutableDictionary()
		options.setValue("client_key", forKey: kBXC_CLIENT_KEY)
		options.setValue("client_secret", forKey: kBXC_CLIENT_SECRET)
		options.setValue("api_url", forKey: kBXC_API_URL)

		Boxcar.sharedInstance().startWithOptions(options as [NSObject : AnyObject], error: nil)
		//Boxcar.sharedInstance().settings!.mode = "development"
		
		let deviceToken = "deviceToken"
		Boxcar.sharedInstance().settings!.deviceToken = deviceToken
		
		//var requestURL: String?
//		OHHTTPStubs.stubRequestsPassingTest({ (request) -> Bool in
//			return true
//			}) { (request) -> OHHTTPStubsResponse in
//		//		requestURL = request.URL?.path
//				let response = ""
//				return OHHTTPStubsResponse(data: response.dataUsingEncoding(NSUTF8StringEncoding)!, statusCode: 200, headers: ["Content-Type":"text/json"])
//		}.name = "Device register"
//		
//		let notifObserver = OCMockObject.observerMock() as! OCMockObject
//		NSNotificationCenter.defaultCenter().addMockObserver(notifObserver, name: kBXC_DID_REGISTER_NOTIFICATION, object: Boxcar.sharedInstance())
//		notifObserver.expect(notificationWithName: kBXC_DID_REGISTER_NOTIFICATION, object:Boxcar.sharedInstance(), userInfo: OCMArg.any())
//		Boxcar.sharedInstance().sendDeviceParameters()
//		
//		BoxcarLogicTests.waitForVerifiedMock(notifObserver, delay: 5)
//		NSNotificationCenter.defaultCenter().removeObserver(notifObserver)
		
		let URL = NSURL(string: options.valueForKey(kBXC_API_URL) as! String)!
		let expectation = expectationWithDescription("GET \(URL)")
		//let session = NSURLSession.sharedSession()//Device register
		
		let request = NSMutableURLRequest(URL: URL)
		request.HTTPMethod = "GET"
		request.addValue("application/json", forHTTPHeaderField: "Content-Type")
		request.addValue("application/json", forHTTPHeaderField: "Accept")
		
		NSURLConnection.sendAsynchronousRequest(request, queue: NSOperationQueue.mainQueue()) {(response, data, error) in
			XCTAssertNotNil(data, "data should not be nil")
			XCTAssertNil(error, "error should be nil")
			
			if let HTTPResponse = response as? NSHTTPURLResponse,
				let responseURL = HTTPResponse.URL,
				let MIMEType = HTTPResponse.MIMEType
			{
				XCTAssertEqual(responseURL.absoluteString, URL.absoluteString, "HTTP response URL should be equal to original URL")
				XCTAssertEqual(HTTPResponse.statusCode, 200, "HTTP response status code should be 200")
				XCTAssertEqual(MIMEType, "text/json", "HTTP response content type should be text/json")
				
				Boxcar.sharedInstance().sendDeviceParameters()
			} else {
				XCTFail("Response was not NSHTTPURLResponse")
			}
			expectation.fulfill()
		}
		
		//task.resume()
		
		waitForExpectationsWithTimeout(request.timeoutInterval) { error in
			if let error = error {
				print("Error: \(error.localizedDescription)")
			}
		}
	}
	
	func test_uploadSettingsFailTriggersNotification() {
		// It triggers a failed register notification on error
		let options = NSMutableDictionary()
		options.setValue("GuQMyYKyGSSOTzDMT_n-_FZeCufrwAfMKAk_sHGPkLtUfa9A-2tpyV9JguZWwmmZ", forKey: kBXC_CLIENT_KEY)
		options.setValue("QM064_vRepZ4GLfo-wj1brGVZMTwNyUzKdj5Hnvvim8wA_qdi8iFhV7q9JorIf5N", forKey: kBXC_CLIENT_SECRET)
		options.setValue("https://boxcar-api.io", forKey: kBXC_API_URL)
		
		Boxcar.sharedInstance().startWithOptions(options as [NSObject : AnyObject], error: nil)
		Boxcar.sharedInstance().settings!.mode = "development"
		
		let deviceToken = "20613276f6f841b73f90982a6a1b199d4d7a920168789578ccadf6760300dcf9"

		Boxcar.sharedInstance().settings!.deviceToken = deviceToken
	
		let URL = NSURL(string: options.valueForKey(kBXC_API_URL) as! String)!
		let expectation = expectationWithDescription("GET \(URL)")
		let session = NSURLSession.sharedSession()//Device register fail
		let task = session.dataTaskWithURL(URL) { data, response, error in
			XCTAssertNotNil(data, "data should not be nil")
			XCTAssertNil(error, "error should be nil")
			print(error)
			if let HTTPResponse = response as? NSHTTPURLResponse,
				let responseURL = HTTPResponse.URL,
				let MIMEType = HTTPResponse.MIMEType
			{
				XCTAssertEqual(responseURL.absoluteString, URL.absoluteString, "HTTP response URL should be equal to original URL")
				XCTAssertEqual(HTTPResponse.statusCode, 500, "HTTP response status code should be 500")
				XCTAssertEqual(MIMEType, "text/json", "HTTP response content type should be text/json")
				
				Boxcar.sharedInstance().sendDeviceParameters()
			} else {
				XCTFail("Response was not NSHTTPURLResponse")
			}
			
			expectation.fulfill()
		}
		
		task.resume()
		
		waitForExpectationsWithTimeout(task.originalRequest!.timeoutInterval) { error in
			if let error = error {
				print("Error: \(error.localizedDescription)")
			}
			XCTFail("TimeOut")
			task.cancel()
		}
	}
	
	func test_boxcarUnregister() {
		//it can send unregistration to service
		let options = NSMutableDictionary()
		options.setValue("GuQMyYKyGSSOTzDMT_n-_FZeCufrwAfMKAk_sHGPkLtUfa9A-2tpyV9JguZWwmmZ", forKey: kBXC_CLIENT_KEY)
		options.setValue("QM064_vRepZ4GLfo-wj1brGVZMTwNyUzKdj5Hnvvim8wA_qdi8iFhV7q9JorIf5N", forKey: kBXC_CLIENT_SECRET)
		options.setValue("https://boxcar-api.io", forKey: kBXC_API_URL)
		
		Boxcar.sharedInstance().startWithOptions(options as [NSObject : AnyObject], error: nil)
		Boxcar.sharedInstance().settings!.mode = "development"
		
		let deviceToken = "20613276f6f841b73f90982a6a1b199d4d7a920168789578ccadf6760300dcf9"

		Boxcar.sharedInstance().settings!.deviceToken = deviceToken
		
		let URL = NSURL(string: options.valueForKey(kBXC_API_URL) as! String)!
		let expectation = expectationWithDescription("GET \(URL)")
		let session = NSURLSession.sharedSession()//Device unregister
		let task = session.dataTaskWithURL(URL) { data, response, error in
			XCTAssertNotNil(data, "data should not be nil")
			XCTAssertNil(error, "error should be nil")
			
			if let HTTPResponse = response as? NSHTTPURLResponse,
				let responseURL = HTTPResponse.URL,
				let MIMEType = HTTPResponse.MIMEType
			{
				XCTAssertEqual(responseURL.absoluteString, URL.absoluteString, "HTTP response URL should be equal to original URL")
				XCTAssertEqual(HTTPResponse.statusCode, 204, "HTTP response status code should be 204")
				XCTAssertEqual(MIMEType, "text/json", "HTTP response content type should be text/json")
				
				Boxcar.sharedInstance().unregisterDevice()
				//XCTAssertNotNil(requestURL, "requestURL shouldn't be nil")
				//XCTAssertNil(token, "Token should be nil at this point")
			} else {
				XCTFail("Response was not NSHTTPURLResponse")
			}
			expectation.fulfill()
		}
		
		task.resume()
		
		waitForExpectationsWithTimeout(task.originalRequest!.timeoutInterval) { error in
			if let error = error {
				print("Error: \(error.localizedDescription)")
			}
			XCTFail("TimeOut")
			task.cancel()
		}
	}
	
	func test_retrieveTagsFromServer() {
		//it can retrieve the list of tags asynchronously
		let options = NSMutableDictionary()
		options.setValue("GuQMyYKyGSSOTzDMT_n-_FZeCufrwAfMKAk_sHGPkLtUfa9A-2tpyV9JguZWwmmZ", forKey: kBXC_CLIENT_KEY)
		options.setValue("QM064_vRepZ4GLfo-wj1brGVZMTwNyUzKdj5Hnvvim8wA_qdi8iFhV7q9JorIf5N", forKey: kBXC_CLIENT_SECRET)
		options.setValue("https://boxcar-api.io", forKey: kBXC_API_URL)
		
		Boxcar.sharedInstance().startWithOptions(options as [NSObject : AnyObject], error: nil)
		Boxcar.sharedInstance().settings!.mode = "development"
		
		let URL = NSURL(string: options.valueForKey(kBXC_API_URL) as! String)!
		let expectation = expectationWithDescription("GET \(URL)")
		let session = NSURLSession.sharedSession()//Retrive tags from server
		let task = session.dataTaskWithURL(URL) { data, response, error in
			XCTAssertNotNil(data, "data should not be nil")
			XCTAssertNil(error, "error should be nil")
						print(error)
			if let HTTPResponse = response as? NSHTTPURLResponse,
				let responseURL = HTTPResponse.URL,
				let MIMEType = HTTPResponse.MIMEType
			{
				XCTAssertEqual(responseURL.absoluteString, URL.absoluteString, "HTTP response URL should be equal to original URL")
				XCTAssertEqual(HTTPResponse.statusCode, 200, "HTTP response status code should be 200")
				XCTAssertEqual(MIMEType, "text/json", "HTTP response content type should be text/json")
				
				// Check that we trigger HTTP call to server.
				//XCTAssertEqual(requestURL, "/api/tags", "requestURL should be fetching tags")
				
				Boxcar.sharedInstance().retrieveProjectTagsWithBlock
				
				Boxcar.sharedInstance().retrieveProjectTagsWithBlock { (tags) -> Void in
					// Check that we receive proper tags:
					let tag1 = tags[0] as! String
					XCTAssertEqual(tag1, "tag1", "Tag1 should be equal to -tag1-")
					let tag2 = tags[1] as! String
					XCTAssertEqual(tag2, "tag2", "Tag2 should be equal to -tag2-")
				}
			} else {
				XCTFail("Response was not NSHTTPURLResponse")
			}
			expectation.fulfill()
		}
		
		task.resume()
		
		waitForExpectationsWithTimeout(task.originalRequest!.timeoutInterval) { error in
			if let error = error {
				print("Error: \(error.localizedDescription)")
			}
			XCTFail("TimeOut")
			task.cancel()
		}
	}
}
