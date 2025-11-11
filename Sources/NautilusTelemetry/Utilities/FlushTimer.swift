// Created by Ladd Van Tol on 9/9/25.
// Copyright © 2025 Airbnb Inc. All rights reserved.

import Foundation

struct FlushTimer {

	// MARK: Lifecycle

	init(flushInterval: TimeInterval, repeating: Bool, handler: @escaping () -> Void) {
		flushTimer = DispatchSource.makeTimerSource(flags: [], queue: NautilusTelemetry.queue)
		self._flushInterval = max(minimumFlushInterval, flushInterval)
		self.repeating = repeating
		self.handler = handler
		// didSet doesn't run in init
		setupTimer()
	}

	// MARK: Internal

	var handler: () -> Void

	let flushTimer: DispatchSourceTimer

	var flushInterval: TimeInterval {
		get { _flushInterval }
		set {
			_flushInterval = max(minimumFlushInterval, newValue)
			setupTimer()
		}
	}

	func setupTimer() {
		flushTimer.setEventHandler(handler: handler)
		flushTimer.schedule(
			deadline: DispatchTime.now() + flushInterval,
			repeating: repeating ? flushInterval : .infinity,
			leeway: DispatchTimeInterval.milliseconds(100)
		)
		flushTimer.activate()
	}

	// MARK: Private

	var _flushInterval: TimeInterval
	let minimumFlushInterval: TimeInterval = 0.1
	let repeating: Bool
}
