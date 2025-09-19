//
//  Histogram.swift
//
//
//  Created by Van Tol, Ladd on 12/15/21.
//

import Foundation
import os

public class Histogram<T: MetricNumeric>: Instrument, ExportableInstrument {

	// MARK: Lifecycle

	/// Initialize a histogram.
	/// - Parameters:
	///   - name: the name of the histogram.
	///   - unit: the unit of measure.
	///   - description: a descriptive string.
	///   - explicitBounds: See definition in `V1HistogramDataPoint.swift`.
	required init(name: String, unit: Unit?, description: String?, explicitBounds: [T]) {
		self.name = name
		self.unit = unit
		self.description = description
		values = HistogramValues<T>(explicitBounds: explicitBounds)
	}

	// MARK: Public

	public let name: String
	public let unit: Unit?
	public let description: String?
	public private(set) var startTime = ContinuousClock.now
	public private(set) var endTime: ContinuousClock.Instant? = nil
	public var aggregationTemporality = AggregationTemporality.delta

	public var isEmpty: Bool { lock.withLock { values.isEmpty } }

	public func record(_ number: T, attributes: TelemetryAttributes = [:]) {
		if number < 0 {
			assert(false, "histograms can only be increased")
			return
		}

		lock.withLockUnchecked {
			values.record(number, attributes: attributes)
		}
	}

	public func snapshotAndReset() -> Instrument {
		let now = ContinuousClock.now

		return lock.withLock {
			let copy = Self(name: name, unit: unit, description: description, explicitBounds: values.explicitBounds)
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

	var values: HistogramValues<T>

	func exportOTLP(_ exporter: Exporter) -> OTLP.V1Metric {
		exporter.exportOTLP(histogram: self)
	}

	// MARK: Private

	/// Locking is handled at the Instrument level
	/// The implementation must take care to avoid concurrently modifying values
	private let lock = OSAllocatedUnfairLock()
}
