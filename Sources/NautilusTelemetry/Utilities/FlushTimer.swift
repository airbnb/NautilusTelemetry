// Created by Ladd Van Tol on 9/9/25.
// Copyright © 2025 Airbnb Inc. All rights reserved.

import Foundation
import Synchronization

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
		// Cancel first so resuming can't deliver the event handler, then balance any outstanding
		// `suspend()`: libdispatch traps on the release of a source that is still suspended.
		flushTimer.cancel()
		_suspended.withLock { suspended in
			if suspended {
				flushTimer.resume()
				suspended = false
			}
		}
	}

	// MARK: Internal

	var handler: () -> Void

	let flushTimer: DispatchSourceTimer

	let minimumFlushInterval: TimeInterval = 0.1
	let repeating: Bool

	var suspended: Bool { _suspended.withLock { $0 } }

	var flushInterval: TimeInterval {
		get { _flushInterval }
		set {
			_flushInterval = max(minimumFlushInterval, newValue)
			setupTimer()
		}
	}

	/// Stops the timer firing until `setupTimer()` re-arms it, which is the only counterpart —
	/// suspensions must be balanced, and `deinit` clears an outstanding one before releasing the source.
	func suspend() {
		_suspended.withLock { suspended in
			if !suspended {
				// Must match calls between suspend/resume
				flushTimer.suspend()
				suspended = true
			}
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
		_suspended.withLock { suspended in
			if suspended {
				flushTimer.resume()
				suspended = false
			}
		}
	}

	// MARK: Private

	private var _flushInterval: TimeInterval
	private let _suspended = Mutex(false)
}

extension DispatchTimeInterval {
	init(_ timeInterval: TimeInterval) {
		self = .nanoseconds(Int(timeInterval * 1_000_000_000))
	}
}
