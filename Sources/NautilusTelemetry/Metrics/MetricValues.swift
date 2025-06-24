//
//  MetricValues.swift
//
//
//  Created by Van Tol, Ladd on 12/20/21.
//

import Foundation

struct MetricValues<T: MetricNumeric> {

	// MARK: Internal

	var allValues: [TelemetryAttributes: T] { Meter.valueLock.withLockUnchecked { values } }

	mutating func add(_ number: T, attributes: TelemetryAttributes = [:]) {
		Meter.valueLock.withLockUnchecked {
			var metricValue = values[attributes] ?? number
			metricValue += number
			values[attributes] = metricValue
		}
	}

	mutating func set(_ number: T, attributes: TelemetryAttributes = [:]) {
		Meter.valueLock.withLockUnchecked {
			values[attributes] = number
		}
	}

	mutating func reset() {
		Meter.valueLock.withLockUnchecked {
			values.removeAll()
		}
	}

	func valueFor(attributes: TelemetryAttributes) -> T? {
		Meter.valueLock.withLockUnchecked { values[attributes] }
	}

	// MARK: Private

	private var values = [TelemetryAttributes: T]()

}
