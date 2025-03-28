//
//  TimeReferenceTests.swift
//  
//
//  Created by Ladd Van Tol on 3/22/22.
//

import XCTest
@testable import NautilusTelemetry

final class TimeReferenceTests: XCTestCase {

	let toleranceMS: Int64 = 500
	
	func testTimeReference() {
		let timeReference = TimeReference(serverOffset: 0)
		
		let time = ContinuousClock.now
		let date = Date()

		let nanosecondsSinceEpoch = timeReference.nanosecondsSinceEpoch(from: time)
		let nanosecondsSinceEpochFromDate = Int64(date.timeIntervalSince1970 * 1_000_000_000.0)
		let diff3 = abs(nanosecondsSinceEpoch-nanosecondsSinceEpochFromDate)
		XCTAssertLessThan(diff3, toleranceMS*1_000_000)
	}

	func testNanosecondConversion() {
		let time1 = ContinuousClock.now
		print("something very short")
		let time2 = ContinuousClock.now

		XCTAssert(time1 < time2)

		let elapsed = time2-time1
		let elapsedInverse = time1-time2

		XCTAssertEqual(elapsed.asNanoseconds, -elapsedInverse.asNanoseconds)

		// Can't really assert exact timings without making the test flakey
	}
}

