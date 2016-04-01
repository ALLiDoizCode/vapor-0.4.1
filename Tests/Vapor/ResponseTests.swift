//
//  Response.swift
//  Vapor
//
//  Created by Tanner Nelson on 2/3/16.
//  Copyright © 2016 Tanner Nelson. All rights reserved.
//

import XCTest
@testable import Vapor

class ResponseTests: XCTestCase {
    static var allTests : [(String, ResponseTests -> () throws -> Void)] {
        return [
           ("testRedirect", testRedirect)
        ]
    }

    func testRedirect() {
        let url = "http://tanner.xyz"
        
        let redirect = Redirect(to: url)
        XCTAssert(redirect.redirectLocation == url, "redirect location should be url")


        var found = false
        for (key, val) in redirect.headers {
            if key == "Location" && val == url {
                found = true
            }
        }
        XCTAssert(found, "Location header should be in headers")
    }

}
