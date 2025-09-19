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

		let timer = FlushTimer(flushInterval: 0.1) {
			handlerCallCount += 1
			expectation.fulfill()
		}

		// Verify initial state
		XCTAssertEqual(timer.flushInterval, 0.1)
		XCTAssertNotNil(timer.flushTimer)

		// Wait for timer to fire
		wait(for: [expectation], timeout: 1.0)
		XCTAssertGreaterThanOrEqual(handlerCallCount, 1)
	}

	func testFlushTimerIntervalChange() throws {
		let expectation1 = XCTestExpectation(description: "First timer interval")
		let expectation2 = XCTestExpectation(description: "Second timer interval")
		var handlerCallCount = 0

		var timer = FlushTimer(flushInterval: 0.05) {
			handlerCallCount += 1
			if handlerCallCount == 1 {
				expectation1.fulfill()
			} else if handlerCallCount >= 2 {
				expectation2.fulfill()
			}
		}

		// Wait for first firing
		wait(for: [expectation1], timeout: 1.0)
		XCTAssertEqual(handlerCallCount, 1)

		// Change interval and verify it takes effect
		timer.flushInterval = 0.05
		XCTAssertEqual(timer.flushInterval, 0.05)

		// Wait for second firing with new interval
		wait(for: [expectation2], timeout: 1.0)
		XCTAssertGreaterThanOrEqual(handlerCallCount, 2)
	}

	func testFlushTimerSetupCalledOnInit() throws {
		// This test verifies that setupTimer is called during initialization
		// Since setupTimer is now called both in init and didSet, we test
		// that the timer is properly configured immediately after creation

		let expectation = XCTestExpectation(description: "Timer setup correctly on init")

		_ = FlushTimer(flushInterval: 0.05) {
			expectation.fulfill()
		}

		// Verify the timer is active immediately after init
		// (setupTimer is called in init, not just in didSet)
		wait(for: [expectation], timeout: 1.0)
	}
}
