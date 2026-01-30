// Created by Ladd Van Tol on 2026-01-29.
// Copyright © 2026 Airbnb Inc. All rights reserved.

import XCTest
@testable import NautilusTelemetry

final class BaggageTests: XCTestCase {

	let tracer = Tracer()

	// MARK: - Baggage Attributes Tests

	func testBaggageAddAttribute() {
		let span = tracer.startSpan(name: "test")
		let baggage = Baggage(span: span)

		XCTAssertNil(baggage.attributes)

		baggage.addAttribute("key1", "value1")

		XCTAssertEqual(baggage["key1"], "value1")

		// test subscripts
		baggage["key2"] = "value2"

		XCTAssertEqual(baggage["key2"], "value2")

		// test overwriting
		baggage["overwrite"] = "original"
		baggage["overwrite"] = "updated"

		XCTAssertEqual(baggage["overwrite"], "updated")
	}

	func testBaggageAddNilAttributeIsIgnored() {
		let span = tracer.startSpan(name: "test")
		let baggage = Baggage(span: span)

		baggage.addAttribute("key", nil)

		XCTAssertNil(baggage.attributes)
	}

	// MARK: - Thread Safety Tests

	func testBaggageConcurrentAttributeAccess() {
		let span = tracer.startSpan(name: "concurrent")
		let baggage = Baggage(span: span)

		DispatchQueue.concurrentPerform(iterations: 100) { i in
			baggage["key\(i)"] = "value\(i)"
		}

		// Verify at least some attributes were written
		var count = 0
		for i in 0..<100 {
			if baggage["key\(i)"] != nil {
				count += 1
			}
		}
		XCTAssertEqual(count, 100)
	}
}
