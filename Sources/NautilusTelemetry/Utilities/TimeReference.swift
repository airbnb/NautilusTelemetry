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
	/// Duration as a whole number of nanoseconds, rounded half-away-from-zero.
	/// Will overflow above ≈292 year duration.
	var asNanoseconds: Int64 {
		wholeUnits(attosecondsPerUnit: 1_000_000_000) // 10^9
	}

	/// Duration as a whole number of microseconds, rounded half-away-from-zero.
	/// Will overflow above ≈292 thousand year duration.
	var asMicroseconds: Int64 {
		wholeUnits(attosecondsPerUnit: 1_000_000_000_000) // 10^12
	}

	/// Duration as a whole number of milliseconds, rounded half-away-from-zero.
	/// Will overflow above 292 million years.
	var asMilliseconds: Int64 {
		wholeUnits(attosecondsPerUnit: 1_000_000_000_000_000) // 10^15
	}

	/// Duration as a whole number of seconds, rounded half-away-from-zero.
	var asSeconds: Int64 {
		wholeUnits(attosecondsPerUnit: 1_000_000_000_000_000_000) // 10^18
	}

	/// Converts the duration to a whole number of a unit, rounded half-away-from-zero.
	///
	/// Uses `Duration.attoseconds` (Int128) directly, avoiding any precision loss from intermediate
	/// truncation. The sub-unit remainder shares the sign of the duration, so the half-unit threshold
	/// check needs no sign adjustment.
	/// - Parameter attosecondsPerUnit: attoseconds in one unit (e.g. `10^15` for a millisecond).
	private func wholeUnits(attosecondsPerUnit: Int128) -> Int64 {
		let half = attosecondsPerUnit / 2
		let attos = attoseconds
		let remainder = attos % attosecondsPerUnit
		let whole = attos / attosecondsPerUnit + (remainder >= half ? 1 : remainder <= -half ? -1 : 0)
		return Int64(whole)
	}
}
