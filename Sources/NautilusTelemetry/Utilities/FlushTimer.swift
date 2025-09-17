// Created by Ladd Van Tol on 9/9/25.
// Copyright © 2025 Airbnb Inc. All rights reserved.

import Foundation

struct FlushTimer {

	// MARK: Lifecycle

	init(flushInterval: TimeInterval, handler: @escaping () -> Void) {
		self.flushInterval = flushInterval
		self.handler = handler
	}

	// MARK: Internal

	var handler: () -> Void

	lazy var flushTimer: DispatchSourceTimer = DispatchSource.makeTimerSource(flags: [], queue: NautilusTelemetry.queue)

	var flushInterval: TimeInterval {
		didSet {
			flushTimer.setEventHandler(handler: handler)
			flushTimer.schedule(
				deadline: DispatchTime.now() + flushInterval,
				repeating: flushInterval,
				leeway: DispatchTimeInterval.milliseconds(100)
			)
			flushTimer.activate()
		}
	}
}
