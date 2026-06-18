//
//  Counter.swift
//
//
//  Created by Van Tol, Ladd on 12/15/21.
//

import Foundation
import Synchronization

public class Counter<T: MetricNumeric>: Instrument, ExportableInstrument {

	// MARK: Lifecycle

	required init(name: String, unit: Unit?, description: String?) {
		self.name = name
		self.unit = unit
		self.description = description
	}

	// MARK: Public

	public let name: String
	public let unit: Unit?
	public let description: String?
	public private(set) var startTime = ContinuousClock.now
	public private(set) var endTime: ContinuousClock.Instant? = nil
	public var aggregationTemporality = AggregationTemporality.delta

	public var isMonotonic: Bool { true }

	public var isEmpty: Bool { lockedValues.withLock { $0.isEmpty } }

	public func add(_ number: T, attributes: TelemetryAttributes = [:]) {
		if isMonotonic, number < 0 {
			// UpDownCounter is not monotonic
			assert(false, "monotonic counters can only be increased")
			return
		}
		lockedValues.withLock {
			$0.add(number, attributes: attributes)
		}
	}

	public func snapshotAndReset() -> Instrument {
		let now = ContinuousClock.now

		return lockedValues.withLock { values in
			let copy = Self(name: name, unit: unit, description: description)
			copy.startTime = startTime
			copy.endTime = now
			copy.aggregationTemporality = aggregationTemporality
			copy.lockedValues.withLock { $0 = values.snapshotAndReset() }

			// now reset
			startTime = now
			endTime = nil
			values.reset()
			return copy
		}
	}

	// MARK: Internal

	/// Thread-safe snapshot of the recorded values.
	var values: MetricValues<T> { lockedValues.withLock { $0 } }

	func exportOTLP(_ exporter: Exporter) -> OTLP.V1Metric {
		exporter.exportOTLP(counter: self)
	}

	// MARK: Private

	/// Locking is handled at the Instrument level
	/// The implementation must take care to avoid concurrently modifying values
	private let lockedValues = Mutex(MetricValues<T>())
}
