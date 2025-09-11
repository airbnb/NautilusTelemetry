//
//  MetricValues.swift
//
//
//  Created by Van Tol, Ladd on 12/20/21.
//

import Foundation
import os

struct MetricValues<T: MetricNumeric> {

	// MARK: Internal

	mutating func add(_ number: T, attributes: TelemetryAttributes = [:]) {
			var metricValue = values[attributes] ?? number
			metricValue += number
			values[attributes] = metricValue
	}

	mutating func set(_ number: T, attributes: TelemetryAttributes = [:]) {
			values[attributes] = number
	}

	mutating func reset() {
			values.removeAll()
	}

	mutating func snapshotAndReset() -> MetricValues<T> {
		var copy = MetricValues<T>()
			copy.values = values
			values.removeAll()

		return copy
	}

	func valueFor(attributes: TelemetryAttributes) -> T? {
		values[attributes]
	}

	// MARK: Private

	var values = [TelemetryAttributes: T]()

}
