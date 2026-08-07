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
		let firstFire = XCTestExpectation(description: "Timer handler called before the interval change")
		let firedAfterChange = XCTestExpectation(description: "Timer handler called after the interval change")
		// The re-armed timer keeps firing, so allow the post-change expectation to be met more than once.
		firedAfterChange.assertForOverFulfill = false

		// The handler runs on a background queue, so guard the shared state against the test thread.
		// `changeBaseline` is captured just after the interval change; fires past it prove the timer re-armed.
		struct State {
			var handlerCallCount = 0
			var changeBaseline = Int.max
		}
		let state = Mutex(State())

		let timer = FlushTimer(flushInterval: 0.1, repeating: true) {
			state.withLock { state in
				state.handlerCallCount += 1
				if state.handlerCallCount == 1 {
					firstFire.fulfill()
				}
				if state.handlerCallCount > state.changeBaseline {
					firedAfterChange.fulfill()
				}
			}
		}

		// The timer repeats, so it may fire again before the test thread resumes. Assert that it fired at
		// all rather than an exact count.
		wait(for: [firstFire], timeout: timeout)
		XCTAssertGreaterThanOrEqual(state.withLock { $0.handlerCallCount }, 1)

		// Check minimum enforced
		let tooSmallFlushInterval = 0.05
		XCTAssertNotEqual(tooSmallFlushInterval, timer.minimumFlushInterval)
		timer.flushInterval = tooSmallFlushInterval
		XCTAssertEqual(timer.flushInterval, timer.minimumFlushInterval)

		// Setting the interval re-schedules from now, so drain any handler still queued from the old
		// schedule (the queue is serial) before taking the baseline. Fires counted past it are the new one's.
		NautilusTelemetry.queue.sync { }
		state.withLock { $0.changeBaseline = $0.handlerCallCount }

		wait(for: [firedAfterChange], timeout: timeout)
	}

	func testFlushTimerSetupCalledOnInit() throws {
		let expectation = XCTestExpectation(description: "Timer setup correctly on init")

		let timer = FlushTimer(flushInterval: 0.05, repeating: true) {
			expectation.fulfill()
		}

		wait(for: [expectation], timeout: timeout)

		XCTAssertNotNil(timer) // keep timer alive
	}

	/// libdispatch traps on the release of a suspended source ("BUG IN CLIENT OF LIBDISPATCH: Release of a
	/// suspended object"), so `deinit` has to balance any outstanding `suspend()`. Without that, releasing
	/// the timer here aborts the whole test process rather than failing this test.
	func testDeallocatingWhileSuspendedDoesNotTrap() throws {
		var timer: FlushTimer? = FlushTimer(flushInterval: 0.1, repeating: true) { }
		timer?.suspend()
		XCTAssertTrue(try XCTUnwrap(timer).suspended)

		timer = nil
		XCTAssertNil(timer)
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
