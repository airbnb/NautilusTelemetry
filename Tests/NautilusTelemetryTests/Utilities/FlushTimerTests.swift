//
//  FlushTimerTests.swift
//
//
//  Created by Ladd Van Tol on 9/18/25.
//

import Foundation
import XCTest

@testable import NautilusTelemetry

final class FlushTimerTests: XCTestCase {

	func testFlushTimerInitialization() throws {
		let expectation = XCTestExpectation(description: "Timer handler called")
		var handlerCallCount = 0

		let timer = FlushTimer(flushInterval: 0.1, repeating: true) {
			handlerCallCount += 1
			expectation.fulfill()
		}

		XCTAssertEqual(timer.flushInterval, 0.1)
		XCTAssertNotNil(timer.flushTimer)

		wait(for: [expectation], timeout: 1.0)
		XCTAssertGreaterThanOrEqual(handlerCallCount, 1)
	}

	func testFlushTimerIntervalChange() throws {
		let expectation1 = XCTestExpectation(description: "First timer interval")
		let expectation2 = XCTestExpectation(description: "Second timer interval")
		var handlerCallCount = 0

		var timer = FlushTimer(flushInterval: 0.1, repeating: true) {
			handlerCallCount += 1
			if handlerCallCount == 1 {
				expectation1.fulfill()
			} else if handlerCallCount >= 2 {
				expectation2.fulfill()
			}
		}

		wait(for: [expectation1], timeout: 1.0)
		XCTAssertEqual(handlerCallCount, 1)

		// Check minimum enforced
		timer.flushInterval = 0.05
		XCTAssertEqual(timer.flushInterval, timer.minimumFlushInterval)

		wait(for: [expectation2], timeout: 1.0)
		XCTAssertGreaterThanOrEqual(handlerCallCount, 2)
	}

	func testFlushTimerSetupCalledOnInit() throws {
		let expectation = XCTestExpectation(description: "Timer setup correctly on init")

		let timer = FlushTimer(flushInterval: 0.05, repeating: true) {
			expectation.fulfill()
		}

		wait(for: [expectation], timeout: 1.0)

		XCTAssertNotNil(timer) // keep timer alive
	}
}
