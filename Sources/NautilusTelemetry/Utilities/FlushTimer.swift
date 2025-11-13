// Created by Ladd Van Tol on 9/9/25.
// Copyright © 2025 Airbnb Inc. All rights reserved.

import Foundation

// MARK: - FlushTimer

class FlushTimer {

	// MARK: Lifecycle

	init(flushInterval: TimeInterval, repeating: Bool, handler: @escaping () -> Void) {
		flushTimer = DispatchSource.makeTimerSource(flags: [], queue: NautilusTelemetry.queue)
		_flushInterval = max(minimumFlushInterval, flushInterval)
		self.repeating = repeating
		self.handler = handler
		// didSet doesn't run in init
		setupTimer()
	}

	deinit {
		flushTimer.cancel()
	}

	// MARK: Internal

	var handler: () -> Void

	let flushTimer: DispatchSourceTimer

	var suspended = false

	let minimumFlushInterval: TimeInterval = 0.1
	let repeating: Bool

	var flushInterval: TimeInterval {
		get { _flushInterval }
		set {
			_flushInterval = max(minimumFlushInterval, newValue)
			setupTimer()
		}
	}

	func suspend() {
		if !suspended {
			// Must match calls between suspend/resume
			flushTimer.suspend()
			suspended = true
		}
	}

	func setupTimer() {
		flushTimer.setEventHandler(handler: handler)

		let dispatchFlushInterval = DispatchTimeInterval(flushInterval)
		flushTimer.schedule(
			deadline: DispatchTime.now() + dispatchFlushInterval,
			repeating: repeating ? dispatchFlushInterval : .never,
			leeway: DispatchTimeInterval.milliseconds(100)
		)
		flushTimer.activate()
		if suspended {
			flushTimer.resume()
			suspended = false
		}
	}

	// MARK: Private

	private var _flushInterval: TimeInterval

}

extension DispatchTimeInterval {
	init(_ timeInterval: TimeInterval) {
		self = .nanoseconds(Int(timeInterval * 1_000_000_000))
	}
}
