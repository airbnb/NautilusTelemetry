//
//  Counter.swift
//
//
//  Created by Van Tol, Ladd on 12/15/21.
//

import Foundation

public class Counter<T: MetricNumeric>: Instrument, ExportableInstrument {

	// MARK: Lifecycle

	init(name: String, unit: Unit?, description: String?) {
		self.name = name
		self.unit = unit
		self.description = description
	}

	// MARK: Public

	public let name: String
	public let unit: Unit?
	public let description: String?
	public private(set) var startTime = ContinuousClock.now
	public var aggregationTemporality = AggregationTemporality.delta

	public var isMonotonic: Bool { true }

	public func add(_ number: T, attributes: TelemetryAttributes = [:]) {
		precondition(number >= 0, "counters can only be increased")
		values.add(number, attributes: attributes)
	}

	public func reset() {
		startTime = ContinuousClock.now
		values.reset()
	}

	// MARK: Internal

	var values = MetricValues<T>()

	func exportOTLP(_ exporter: Exporter) -> OTLP.V1Metric {
		exporter.exportOTLP(counter: self)
	}
}
