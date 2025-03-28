//
//  IdentifiersTests.swift
//  
//
//  Created by Ladd Van Tol on 3/22/22.
//

import Foundation
import XCTest
@testable import NautilusTelemetry

final class IdentifiersTests: XCTestCase {

	func test() {
		let test = Data(repeating: 0x00, count: 8)
		XCTAssertEqual(Identifiers.hexEncodedString(data: test), "0000000000000000")
	}

	func testGenerateTraceId() {
		let traceId = Identifiers.generateTraceId()
		XCTAssertEqual(traceId.count, 16)
	}

	func testGenerateSpanId() {
		let spanId = Identifiers.generateSpanId()
		XCTAssertEqual(spanId.count, 8)
	}
	
	func testHexEncoding() {
		let test = Data(repeating: 0xFF, count: 8)
		
		let hex1 = test.hexEncodedString
		XCTAssertEqual(hex1, "ffffffffffffffff")
	}
}

