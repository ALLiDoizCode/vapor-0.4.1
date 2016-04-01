//
//  RouterTests.swift
//  Vapor
//
//  Created by Tanner Nelson on 2/18/16.
//  Copyright © 2016 Tanner Nelson. All rights reserved.
//

import Foundation
import XCTest
@testable import Vapor

class RouterTests: XCTestCase {
    
    static var allTests : [(String, RouterTests -> () throws -> Void)] {
        return [
           ("testSingleHostRouting", testSingleHostRouting),
           ("testMultipleHostsRouting", testMultipleHostsRouting),
           ("testURLParameterDecoding", testURLParameterDecoding)
        ]
    }
    
    func testSingleHostRouting() {
        let router = BranchRouter()
        let compare = "Hello Text Data Processing Test"
        let data = [UInt8](compare.utf8)
        
        let route = Route.init(host: "other.test", method: .Get, path: "test") { request in
            return Response(status: .OK, data: data, contentType: .Text)
        }
        router.register(route)
        
        let request = Request(
            method: .Get,
            path: "test",
            address: nil,
            headers: [("Host", "other.test")],
            body: []
        )
        
        do {
            let result = router.route(request)!
            var bytes = try result(request: request).data
            
            let utf8 = NSData(bytes: &bytes , length: bytes.count)
            let string = String(data: utf8, encoding: NSUTF8StringEncoding)
            XCTAssert(string == compare)
        } catch {
            XCTFail()
        }
    }
    
    func testMultipleHostsRouting() {
        let router = BranchRouter()
        
        let data_1 = [UInt8]("1".utf8)
        let data_2 = [UInt8]("2".utf8)
        
        let route_1 = Route.init(method: .Get, path: "test") { request in
            return Response(status: .OK, data: data_1, contentType: .Text)
        }
        router.register(route_1)
        
        let route_2 = Route.init(host: "vapor.test", method: .Get, path: "test") { request in
            return Response(status: .OK, data: data_2, contentType: .Text)
        }
        router.register(route_2)
        
        let request_1 = Request(method: .Get, path: "test", address: nil, headers: [("Host", "other.test")], body: [])
        let request_2 = Request(method: .Get, path: "test", address: nil, headers: [("Host", "vapor.test")], body: [])
        
        let handler_1 = router.route(request_1)
        let handler_2 = router.route(request_2)
        
        if let response_1 = try? handler_1?(request: request_1) {
            XCTAssert(response_1!.data == data_1, "Incorrect response returned by Handler 1")
        } else {
            XCTFail("Handler 1 did not return a response")
        }
        
        if let response_2 = try? handler_2?(request: request_2) {
            XCTAssert(response_2!.data == data_2, "Incorrect response returned by Handler 2")
        } else {
            XCTFail("Handler 2 did not return a response")
        }
    }
    
    func testURLParameterDecoding() {
        let router = BranchRouter()
        
        let percentEncodedString = "testing%20parameter%21%23%24%26%27%28%29%2A%2B%2C%2F%3A%3B%3D%3F%40%5B%5D"
        let decodedString = "testing parameter!#$&'()*+,/:;=?@[]"
        
        var handlerRan = false
        
        let route = Route(method: .Get, path: "test/:string") { request in
            
            let testParameter = request.parameters["string"]
            
            XCTAssert(testParameter == decodedString, "URL parameter was not decoded properly")
            
            handlerRan = true
            
            return Response(status: .OK, data: [], contentType: .None)
        }
        router.register(route)
        
        let request = Request(method: .Get, path: "test/\(percentEncodedString)", address: nil, headers: [], body: [])
        let handler = router.route(request)
        
        let _ = try? handler?(request: request)
        
        XCTAssert(handlerRan, "The handler did not run, and the parameter test also did not run")
    }
    
}
