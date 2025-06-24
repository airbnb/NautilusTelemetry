//
//  HistogramValues.swift
//
//
//  Created by Van Tol, Ladd on 12/20/21.
//

import Foundation

// MARK: - HistogramBuckets

struct HistogramBuckets<T: MetricNumeric> {

	// MARK: Lifecycle

	init(explicitBounds: [T]) {
		self.explicitBounds = explicitBounds
		data = .init(repeating: 0, count: explicitBounds.count + 1)
	}

	// MARK: Internal

	var count: UInt64 = 0
	var sum: T = 0
	var data: [UInt64]
	let explicitBounds: [T]

	mutating func record(_ number: T) {
		sum += number
		count += 1

		let count = explicitBounds.count
		for i in 0..<count {
			let bound = explicitBounds[i]
			if number <= bound {
				data[i] += 1
				return
			}
		}

		// In the range of (lastBound...infinity).
		data[count] += 1
	}
}

// MARK: - HistogramValues

/// https://github.com/open-telemetry/opentelemetry-specification/blob/main/specification/metrics/datamodel.md#histograms
struct HistogramValues<T: MetricNumeric> {

	// MARK: Lifecycle

	/// Initialize with bounds.
	/// - Parameter explicitBounds: See `V1HistogramDataPoint.swift` for defintion.
	///  Limitation: all recorded histograms share the same `explicitBounds` in this implementation.
	init(explicitBounds: [T]) {
		self.explicitBounds = explicitBounds
	}

	// MARK: Internal

	let explicitBounds: [T]

	var values = [TelemetryAttributes: HistogramBuckets<T>]()

	var allValues: [TelemetryAttributes: HistogramBuckets<T>] { Meter.valueLock.withLockUnchecked { values } }

	mutating func record(_ number: T, attributes: TelemetryAttributes = [:]) {
		Meter.valueLock.withLockUnchecked {
			var value = values[attributes]
			if value == nil {
				value = HistogramBuckets<T>(explicitBounds: explicitBounds)
			}
			if var value {
				value.record(number)
				values[attributes] = value
			} else {
				assertionFailure("expected non-nil")
			}
		}
	}

	mutating func reset() {
		Meter.valueLock.withLockUnchecked {
			values.removeAll()
		}
	}
}
