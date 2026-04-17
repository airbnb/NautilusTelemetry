//
//  ExponentialHistogramValues.swift
//
//
//  Created by Ladd Van Tol on 2026-04-17.
//

import Foundation

// MARK: - ExponentialHistogramBuckets

/// Holds the raw values recorded for a single attribute key.
/// Raw values are retained so the exporter can choose a `scale` that best fits the observed range.
struct ExponentialHistogramBuckets<T: MetricNumeric> {

	var count: UInt64 = 0
	var sum: T = 0
	var minValue: T? = nil
	var maxValue: T? = nil
	var recordedValues = [T]()

	var isEmpty: Bool { count == 0 }

	mutating func record(_ number: T) {
		sum += number
		count += 1
		recordedValues.append(number)

		if let currentMin = minValue {
			if number < currentMin { minValue = number }
		} else {
			minValue = number
		}

		if let currentMax = maxValue {
			if number > currentMax { maxValue = number }
		} else {
			maxValue = number
		}
	}
}

// MARK: - ExponentialHistogramValues

/// https://opentelemetry.io/docs/specs/otel/metrics/data-model/#exponentialhistogram
struct ExponentialHistogramValues<T: MetricNumeric> {

	var values = [TelemetryAttributes: ExponentialHistogramBuckets<T>]()

	var isEmpty: Bool {
		values.isEmpty || values.values.allSatisfy { $0.isEmpty }
	}

	mutating func record(_ number: T, attributes: TelemetryAttributes = [:]) {
		var buckets = values[attributes] ?? ExponentialHistogramBuckets<T>()
		buckets.record(number)
		values[attributes] = buckets
	}

	mutating func reset() {
		values.removeAll()
	}

	mutating func snapshotAndReset() -> ExponentialHistogramValues<T> {
		var copy = ExponentialHistogramValues<T>()
		copy.values = values
		values.removeAll()

		return copy
	}
}
