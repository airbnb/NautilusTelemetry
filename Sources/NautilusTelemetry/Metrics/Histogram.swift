//
//  Histogram.swift
//
//
//  Created by Van Tol, Ladd on 12/15/21.
//

import Foundation
import Synchronization

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
		lockedValues = Mutex(HistogramValues<T>(explicitBounds: explicitBounds))
	}

	// MARK: Public

	public let name: String
	public let unit: Unit?
	public let description: String?
	public private(set) var startTime = ContinuousClock.now
	public private(set) var endTime: ContinuousClock.Instant? = nil
	public var aggregationTemporality = AggregationTemporality.delta

	public var isEmpty: Bool { lockedValues.withLock { $0.isEmpty } }

	public var exemplarSpans: [Span] { lockedExemplars.withLock { $0.map(\.span) } }

	public func addExemplar(span: Span, value: T, attributes: TelemetryAttributes = [:]) {
		lockedExemplars.withLock { $0.append(Exemplar(span: span, value: value, attributes: attributes)) }
	}

	public func record(_ number: T, attributes: TelemetryAttributes = [:]) {
		guard Self.isRecordable(number) else {
			return
		}

		lockedValues.withLock {
			$0.record(number, attributes: attributes)
		}
	}

	/// Records `count` observations of `number` in a single step.
	/// - Parameters:
	///   - number: the value to record.
	///   - count: the number of observations of `number`. A count of zero records nothing.
	///   - attributes: attributes to associate with the measurements.
	public func record(_ number: T, count: UInt64, attributes: TelemetryAttributes = [:]) {
		guard Self.isRecordable(number), count > 0 else {
			return
		}

		lockedValues.withLock {
			$0.record(number, count: count, attributes: attributes)
		}
	}

	/// Records measurements that another source has already bucketed, such as a MetricKit `MXHistogram`,
	/// under one lock acquisition for the whole batch. See ``BucketedMeasurement``.
	/// - Parameters:
	///   - measurements: the source buckets. Entries with a count of zero are skipped, as are entries with a
	///   non-finite or negative value, which assert in debug builds.
	///   - attributes: attributes to associate with the measurements.
	public func record(_ measurements: [BucketedMeasurement<T>], attributes: TelemetryAttributes = [:]) {
		let recordable = measurements.filter { $0.count > 0 && Self.isRecordable($0.value) }

		guard !recordable.isEmpty else {
			return
		}

		lockedValues.withLock {
			$0.record(recordable, attributes: attributes)
		}
	}

	public func snapshotAndReset() -> Instrument {
		let now = ContinuousClock.now
		let exemplars = lockedExemplars.withLock { exemplars in
			defer { exemplars.removeAll() }
			return exemplars
		}

		return lockedValues.withLock { values in
			let copy = Self(name: name, unit: unit, description: description, explicitBounds: values.explicitBounds)
			copy.startTime = startTime
			copy.endTime = now
			copy.aggregationTemporality = aggregationTemporality
			copy.lockedValues.withLock { $0 = values.snapshotAndReset() }
			copy.lockedExemplars.withLock { $0 = exemplars }

			// now reset the instrument
			startTime = now
			endTime = nil
			values.reset()
			return copy
		}
	}

	// MARK: Internal

	/// Thread-safe snapshot of the recorded values.
	var values: HistogramValues<T> { lockedValues.withLock { $0 } }

	/// Thread-safe snapshot of the recorded exemplars.
	var exemplars: [Exemplar<T>] { lockedExemplars.withLock { $0 } }

	func exportOTLP(_ exporter: Exporter) -> OTLP.V1Metric {
		exporter.exportOTLP(histogram: self)
	}

	// MARK: Private

	/// Locking is handled at the Instrument level
	/// The implementation must take care to avoid concurrently modifying values
	private let lockedValues: Mutex<HistogramValues<T>>

	/// Exemplars recorded in the current collection interval.
	private let lockedExemplars = Mutex<[Exemplar<T>]>([])

	/// Whether `number` can be placed in a bucket. Asserts in debug builds so bad data surfaces during
	/// development, and reports the rejection without trapping in release.
	private static func isRecordable(_ number: T) -> Bool {
		// NaN compares false against every bound, so it would otherwise land in the overflow bucket
		// and leave `sum` unusable.
		guard isFiniteMetricValue(number) else {
			assert(false, "histograms can only record finite values")
			return false
		}

		if number < 0 {
			assert(false, "histograms can only be increased")
			return false
		}

		return true
	}
}
