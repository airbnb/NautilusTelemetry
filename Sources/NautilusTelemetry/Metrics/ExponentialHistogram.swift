//
//  ExponentialHistogram.swift
//
//
//  Created by Ladd Van Tol on 2026-04-17.
//

import Foundation
import os

/// An exponential histogram where bucket boundaries are `base^i` with `base = 2^(2^-scale)`.
/// https://opentelemetry.io/docs/specs/otel/metrics/data-model/#exponentialhistogram
///
/// Raw recorded values are retained until the next snapshot, allowing the exporter to pick
/// the scale that best represents the observed range within a fixed bucket count.
public class ExponentialHistogram<T: MetricNumeric>: Instrument, ExportableInstrument {

	// MARK: Lifecycle

	/// Initialize an exponential histogram.
	/// - Parameters:
	///   - name: the name of the histogram.
	///   - unit: the unit of measure.
	///   - description: a descriptive string.
	required init(
		name: String,
		unit: Unit?,
		description: String?,
		maxBuckets: Int = ExponentialHistogramUtils.defaultMaxBucketCount
	) {
		self.name = name
		self.unit = unit
		self.description = description
		self.maxBuckets = maxBuckets
		values = ExponentialHistogramValues<T>()
	}

	// MARK: Public

	public let name: String
	public let unit: Unit?
	public let description: String?
	public let maxBuckets: Int
	public private(set) var startTime = ContinuousClock.now
	public private(set) var endTime: ContinuousClock.Instant? = nil
	public var aggregationTemporality = AggregationTemporality.delta

	public var isEmpty: Bool { lock.withLock { values.isEmpty } }

	/// Record a value. Positive, negative, and zero values are all allowed (unlike `Histogram`),
	/// since the spec maps them into separate positive/negative/zero buckets.
	public func record(_ number: T, attributes: TelemetryAttributes = [:]) {
		lock.withLock {
			values.record(number, attributes: attributes)
		}
	}

	public func snapshotAndReset() -> Instrument {
		let now = ContinuousClock.now

		return lock.withLock {
			let copy = Self(name: name, unit: unit, description: description, maxBuckets: maxBuckets)
			copy.startTime = startTime
			copy.endTime = now
			copy.aggregationTemporality = aggregationTemporality
			copy.values = values.snapshotAndReset()

			// now reset the instrument
			startTime = now
			endTime = nil
			values.reset()
			return copy
		}
	}

	// MARK: Internal

	var values: ExponentialHistogramValues<T>

	func exportOTLP(_ exporter: Exporter) -> OTLP.V1Metric {
		exporter.exportOTLP(histogram: self)
	}

	// MARK: Private

	/// Locking is handled at the Instrument level
	/// The implementation must take care to avoid concurrently modifying values
	private let lock = OSAllocatedUnfairLock()
}
