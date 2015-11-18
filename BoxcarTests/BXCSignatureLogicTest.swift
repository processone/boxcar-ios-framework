//
//  BXCSignatureLogicTest.swift
//  Boxcar
//
//  Created by Paul on 29/10/2015.
//  Copyright © 2015 ProcessOne. All rights reserved.
//

import Foundation
import XCTest

let kDomain = "http://api.boxcar.io"

class BXCSignatureLogicTests: XCTestCase {
	var signature: BXCSignature?

	override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
		print("Setup \(name)")
		
		measureBlock() {
			self.signature = BXCSignature()
			XCTAssertNotNil(self.signature, "Cannot create signature instance")
		}
    }

    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
		print("tearDown \(name)")
    }
	
	func generatePayloadForDeviceRegistration() {
		//Should generate payload for device registration
		measureBlock() {
			let signature = BXCSignature.signatureWithMethod("PUT", andHost: "localhost", andPath: "/api/device_tokens/TOKEN", andBody: "JSONCONTENT", andSecret: "Flf0KWw663x5LpRteIEZttgTQwrWg97Hf5fEVF3g9CtIy1YnRQQXCPghjbp7I30I")
			XCTAssertTrue(signature == "174fcdfcb83a17c40215200608d3db27b6fbfbdc", "")
		}
	}

	func generateSignedUrl() {
		//Should generate signed URL
		let baseURL = NSURL(fileURLWithPath: kDomain)
		
		measureBlock() {
			let signedURL = BXCSignature.buildSignedURLWithKey("key", andSecret: "secret", forUrl: baseURL, path: "/api/device_tokens/TOKEN", method: "POST", payload: "JSONCONTENT")
			XCTAssertNotNil(signedURL, "Cannot create signature instance")
			XCTAssertTrue(signedURL.absoluteString == "http://api.boxcar.io/api/device_tokens/TOKEN?clientkey=key&signature=348809d921be63deb79267d609cdc80c31f89167", "")
		}
	}
	
	func properlyAppendKeyAndSignatureToUrlParameters() {
		//Should properly append key and signature to existing url parameters
		let baseURL = NSURL(fileURLWithPath: kDomain)
		
		measureBlock() {
			let signedURL = BXCSignature.buildSignedURLWithKey("key", andSecret: "secret", forUrl: baseURL, path: "/api/device_tokens/TOKEN/?myparam=test", method: "GET", payload: "")
			XCTAssertNotNil(signedURL, "Cannot create signature instance")
			XCTAssertTrue(signedURL.absoluteString == "http://api.boxcar.io/api/device_tokens/TOKEN/?myparam=test&clientkey=key&signature=6405d4d214d4fc9d12fdbfa38b6a516d18715dee", "")
		}
	}
	
	func removeTrailingSlashInBaseUrl() {
		//Should remove trailing slash in base URL (avoid double slashes)
		let baseURL = NSURL(fileURLWithPath: kDomain)
		
		measureBlock() {
			let signedURL = BXCSignature.buildSignedURLWithKey("key", andSecret:"secret", forUrl:baseURL, path:"/api/device_tokens/TOKEN/?myparam=test", method:"GET", payload:"")
			XCTAssertNotNil(signedURL, "Cannot create signature instance")
			XCTAssertTrue(signedURL.absoluteString == "http://api.boxcar.io/api/device_tokens/TOKEN/?myparam=test&clientkey=key&signature=6405d4d214d4fc9d12fdbfa38b6a516d18715dee", "")
		}
	}
}