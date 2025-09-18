// Created by Ladd Van Tol on 9/9/25.
// Copyright © 2025 Airbnb Inc. All rights reserved.

import Foundation

struct FlushTimer {

	// MARK: Lifecycle

	init(flushInterval: TimeInterval, handler: @escaping () -> Void) {
		flushTimer = DispatchSource.makeTimerSource(flags: [], queue: NautilusTelemetry.queue)
		self.flushInterval = flushInterval
		self.handler = handler
		// didSet doesn't run in init
		setupTimer()
	}

	// MARK: Internal

	var handler: () -> Void

	let flushTimer: DispatchSourceTimer

	var flushInterval: TimeInterval {
		didSet {
			setupTimer()
		}
	}

	func setupTimer() {
		flushTimer.setEventHandler(handler: handler)
		flushTimer.schedule(
			deadline: DispatchTime.now() + flushInterval,
			repeating: flushInterval,
			leeway: DispatchTimeInterval.milliseconds(100)
		)
		flushTimer.activate()
	}
}
