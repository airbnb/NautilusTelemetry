//
//  Instrument.swift
//
//
//  Created by Van Tol, Ladd on 12/20/21.
//

import Foundation

// MARK: - Instrument

public protocol Instrument: AnyObject {
	/// The name of the instrument.
	var name: String { get }

	/// Optional unit of measurement.
	var unit: Unit? { get }

	/// Optional description.
	var description: String? { get }

	/// A timestamp (start_time_unix_nano) which best represents the first possible moment a measurement could be recorded. This is commonly set to the timestamp when a metric collection system started.
	var startTime: ContinuousClock.Instant { get }

	var endTime: ContinuousClock.Instant? { get }

	var aggregationTemporality: AggregationTemporality { get }

	/// In a thread safe manner:
	///  - Invokes callback, if observable
	///  - Captures a copy of the instrument at this moment in time
	///  - Resets the original values to zero
	///  - Returns the copy
	/// In the copy: `endTime` is set to now
	/// In the original: `startTime` is moved forward to now, values are reset to zero.
	/// This model assumes delta mode metrics.
	/// TBD: figure out aggregation model: https://opentelemetry.io/docs/specs/otel/metrics/data-model/#sums-delta-to-cumulative
	func snapshotAndReset() -> Instrument

	var isEmpty: Bool { get }
}

// MARK: - ExportableInstrument

protocol ExportableInstrument {
	func exportOTLP(_ exporter: Exporter) -> OTLP.V1Metric
}

// MARK: - AggregationTemporality

public enum AggregationTemporality {
	/// The gauge has no aggregation
	case unspecified
	case delta
	case cumulative
}
