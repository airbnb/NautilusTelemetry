//
//  TimeReference.swift
//
//
//  Created by Ladd Van Tol on 9/23/21.
//

import Darwin.C.time
import Foundation

// MARK: - TimeReference

/// Pins wall clock time to an absolute time.
public struct TimeReference {

	// MARK: Lifecycle

	/// Initialize a time reference with the offset to the server
	///  This is the TimeInterval amount that must be added to correct local time to server time.
	///  I.e., if the server clock is exactly one hour ahead, this value should be `3600.0`.
	/// - Parameter serverOffset: time offset to server.
	public init(serverOffset: TimeInterval) {
		if serverOffset.isFinite {
			serverOffsetNanos = Int64(serverOffset * Double(NSEC_PER_SEC))
		} else {
			assertionFailure("expected finite serverOffset")
			serverOffsetNanos = 0
		}
	}

	// MARK: Internal

	let serverOffsetNanos: Int64
	let wallTimeReference = clock_gettime_nsec_np(CLOCK_REALTIME)
	let absoluteTimeReference = ContinuousClock.now

	/// Overflows in the year 2262.
	func nanosecondsSinceEpoch(from time: ContinuousClock.Instant) -> Int64 {
		let delta = (time - absoluteTimeReference).asNanoseconds
		return Int64(wallTimeReference) + delta + serverOffsetNanos
	}

	func nanosecondsSinceEpoch(from date: Date) -> Int64 {
		// Reduce precision loss by splitting into the integer and fractional parts.
		let timeInterval = date.timeIntervalSince1970
		let seconds = Int64(timeInterval)
		let fractionalComponent = modf(timeInterval).1

		let nanos = seconds * Int64(NSEC_PER_SEC) + Int64(fractionalComponent * Double(NSEC_PER_SEC))
		return Int64(nanos) + serverOffsetNanos
	}
}

/// Will overflow for very large durations, and are permitted to be negative.
extension Duration {
	/// Convert to truncated integer nanoseconds.
	/// Will overflow above ≈292 year duration.
	var asNanoseconds: Int64 {
		(components.seconds &* 1_000_000_000) + (components.attoseconds / 1_000_000_000)
	}
}
