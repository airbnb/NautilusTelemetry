//
//  HistogramValues.swift
//
//
//  Created by Van Tol, Ladd on 12/20/21.
//

import Foundation
import os

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

	var isEmpty: Bool {
		data.isEmpty || data.allSatisfy { $0 == 0 }
	}

	mutating func record(_ number: T) {
		sum += number
		count += 1
		data[bucketIndex(for: number)] += 1
	}

	/// Records `numberOfObservations` observations of `number` in a single step.
	mutating func record(_ number: T, count numberOfObservations: UInt64) {
		guard let multiplier = T(exactly: numberOfObservations) else {
			assert(false, "\(numberOfObservations) observations is not exactly representable as \(T.self)")
			return
		}

		sum += number * multiplier
		count += numberOfObservations
		data[bucketIndex(for: number)] += numberOfObservations
	}

	// MARK: Private

	/// The index in `data` holding the count for `number`. Bounds are treated as inclusive upper bounds,
	/// and `explicitBounds.count` is the overflow bucket covering (lastBound...infinity).
	private func bucketIndex(for number: T) -> Int {
		let boundsCount = explicitBounds.count
		for i in 0..<boundsCount {
			if number <= explicitBounds[i] {
				return i
			}
		}

		return boundsCount
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

	var isEmpty: Bool {
		values.isEmpty || values.values.allSatisfy { $0.isEmpty }
	}

	mutating func record(_ number: T, attributes: TelemetryAttributes = [:]) {
		var value = values[attributes] ?? HistogramBuckets<T>(explicitBounds: explicitBounds)
		value.record(number)
		values[attributes] = value
	}

	mutating func record(_ number: T, count: UInt64, attributes: TelemetryAttributes = [:]) {
		var value = values[attributes] ?? HistogramBuckets<T>(explicitBounds: explicitBounds)
		value.record(number, count: count)
		values[attributes] = value
	}

	/// Records a batch of pre-bucketed measurements against a single set of attributes, touching the
	/// backing dictionary once for the whole batch.
	mutating func record(_ measurements: [BucketedMeasurement<T>], attributes: TelemetryAttributes = [:]) {
		guard measurements.contains(where: { $0.count > 0 }) else {
			return
		}

		var value = values[attributes] ?? HistogramBuckets<T>(explicitBounds: explicitBounds)
		for measurement in measurements where measurement.count > 0 {
			value.record(measurement.value, count: measurement.count)
		}
		values[attributes] = value
	}

	mutating func reset() {
		values.removeAll()
	}

	mutating func snapshotAndReset() -> HistogramValues<T> {
		var copy = HistogramValues<T>(explicitBounds: explicitBounds)
		copy.values = values
		values.removeAll()

		return copy
	}

}
