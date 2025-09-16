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
	var flushTimer: DispatchSourceTimer? = nil

	var flushInterval: TimeInterval {
		didSet {
			if flushTimer == nil {
				flushTimer = DispatchSource.makeTimerSource(flags: [], queue: NautilusTelemetry.queue)
			}

			if let flushTimer {
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
}
