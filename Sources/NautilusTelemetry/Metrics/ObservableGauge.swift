//
//  ObservableGauge.swift
//
//
//  Created by Van Tol, Ladd on 12/15/21.
//

import Foundation
import os

public class ObservableGauge<T: MetricNumeric>: Instrument, ExportableInstrument {

	// MARK: Lifecycle

	required init(name: String, unit: Unit?, description: String?, callback: @escaping (ObservableGauge<T>) -> Void) {
		self.name = name
		self.unit = unit
		self.description = description
		self.callback = callback
	}

	// MARK: Public

	public let name: String
	public let unit: Unit?
	public let description: String?
	public private(set) var startTime = ContinuousClock.now
	public private(set) var endTime: ContinuousClock.Instant? = nil
	public let aggregationTemporality = AggregationTemporality.unspecified

	public var isEmpty: Bool { false }

	public func observe(_ number: T, attributes: TelemetryAttributes = [:]) {
		lock.withLockUnchecked {
			values.set(number, attributes: attributes)
		}
	}

	public func snapshotAndReset() -> Instrument {
		let now = ContinuousClock.now
		callback(self)

		return lock.withLock {
			let copy = Self(name: name, unit: unit, description: description, callback: callback)
			copy.startTime = startTime
			copy.endTime = now
			copy.values = values.snapshotAndReset()

			// now reset
			startTime = now
			endTime = nil
			values.reset()
			return copy
		}
	}

	// MARK: Internal

	let callback: (ObservableGauge<T>) -> Void
	var values = MetricValues<T>()

	func exportOTLP(_ exporter: Exporter) -> OTLP.V1Metric {
		exporter.exportOTLP(gauge: self)
	}

	// MARK: Private

	/// Locking is handled at the Instrument level
	private let lock = OSAllocatedUnfairLock()
}
