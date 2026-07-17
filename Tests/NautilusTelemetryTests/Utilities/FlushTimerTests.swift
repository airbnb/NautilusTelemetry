//
//  FlushTimerTests.swift
//
//
//  Created by Ladd Van Tol on 9/18/25.
//

import Foundation
import Synchronization
import XCTest

@testable import NautilusTelemetry

final class FlushTimerTests: XCTestCase {

	let timeout: TimeInterval = 10

	func testFlushTimerInitialization() throws {
		let expectation = XCTestExpectation(description: "Timer handler called")
		var handlerCallCount = 0

		let timer = FlushTimer(flushInterval: 0.1, repeating: true) {
			handlerCallCount += 1
			expectation.fulfill()
		}

		XCTAssertEqual(timer.flushInterval, 0.1)
		XCTAssertNotNil(timer.flushTimer)

		wait(for: [expectation], timeout: timeout)
		XCTAssertGreaterThanOrEqual(handlerCallCount, 1)
	}

	func testFlushTimerNonRepeating() throws {
		let expectation = XCTestExpectation(description: "Timer handler called")
		var handlerCallCount = 0

		let timer = FlushTimer(flushInterval: 0.1, repeating: false) {
			handlerCallCount += 1
			expectation.fulfill()
		}

		XCTAssertEqual(timer.flushInterval, 0.1)
		XCTAssertNotNil(timer.flushTimer)

		wait(for: [expectation], timeout: timeout)
		XCTAssertGreaterThanOrEqual(handlerCallCount, 1)
	}

	func testFlushTimerIntervalChange() throws {
		let expectation1 = XCTestExpectation(description: "First timer interval")
		let expectation2 = XCTestExpectation(description: "Second timer interval")
		var handlerCallCount = 0

		let timer = FlushTimer(flushInterval: 0.1, repeating: true) {
			handlerCallCount += 1
			if handlerCallCount == 1 {
				expectation1.fulfill()
			} else if handlerCallCount >= 2 {
				expectation2.fulfill()
			}
		}

		wait(for: [expectation1], timeout: timeout)
		XCTAssertEqual(handlerCallCount, 1)

		// Check minimum enforced
		let tooSmallFlushInterval = 0.05
		XCTAssertNotEqual(tooSmallFlushInterval, timer.minimumFlushInterval)
		timer.flushInterval = tooSmallFlushInterval
		XCTAssertEqual(timer.flushInterval, timer.minimumFlushInterval)

		wait(for: [expectation2], timeout: 1.0)
		XCTAssertGreaterThanOrEqual(handlerCallCount, 2)
	}

	func testFlushTimerSetupCalledOnInit() throws {
		let expectation = XCTestExpectation(description: "Timer setup correctly on init")

		let timer = FlushTimer(flushInterval: 0.05, repeating: true) {
			expectation.fulfill()
		}

		wait(for: [expectation], timeout: timeout)

		XCTAssertNotNil(timer) // keep timer alive
	}

	func testFlushTimerSuspendAndResume() throws {
		let firstFire = XCTestExpectation(description: "Timer handler called before suspend")
		let resumedFire = XCTestExpectation(description: "Timer handler called after resume")
		// The resumed timer keeps firing, so allow the post-resume expectation to be met more than once.
		resumedFire.assertForOverFulfill = false

		// The handler runs on a background queue, so guard the shared state against the test thread.
		// `resumeBaseline` is captured just before resuming; fires past it prove the timer resumed.
		struct State {
			var handlerCallCount = 0
			var resumeBaseline = Int.max
		}
		let state = Mutex(State())

		let timer = FlushTimer(flushInterval: 0.2, repeating: true) {
			state.withLock { state in
				state.handlerCallCount += 1
				if state.handlerCallCount == 1 {
					firstFire.fulfill()
				}
				if state.handlerCallCount > state.resumeBaseline {
					resumedFire.fulfill()
				}
			}
		}

		// 1. The running timer fires at least once.
		wait(for: [firstFire], timeout: timeout)

		// 2. While suspended, the timer must not fire again. Snapshot the count at suspend
		// rather than asserting an exact value, since the running timer may have fired more
		// than once before suspend took effect.
		timer.suspend()
		XCTAssertTrue(timer.suspended)

		// Drain any handler invocation already in flight when we suspended, so the
		// snapshot below reflects a quiesced timer (the queue is serial).
		NautilusTelemetry.queue.sync { }
		let countAtSuspend = state.withLock { $0.handlerCallCount }
		Thread.sleep(forTimeInterval: 0.3)
		XCTAssertEqual(state.withLock { $0.handlerCallCount }, countAtSuspend, "suspended timer must not fire")

		// 3. Changing the interval resumes the timer, which fires again.
		state.withLock { $0.resumeBaseline = countAtSuspend }
		timer.flushInterval = 0.1
		XCTAssertFalse(timer.suspended)

		wait(for: [resumedFire], timeout: timeout)
	}
}
