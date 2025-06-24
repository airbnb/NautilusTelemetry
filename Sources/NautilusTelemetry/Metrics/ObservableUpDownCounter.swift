//
//  ObservableUpDownCounter.swift
//
//
//  Created by Van Tol, Ladd on 12/15/21.
//

import Foundation

public class ObservableUpDownCounter<T: MetricNumeric>: Instrument, ExportableInstrument {

	// MARK: Lifecycle

	init(name: String, unit: Unit?, description: String?, callback: @escaping (ObservableUpDownCounter<T>) -> Void) {
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
	public var aggregationTemporality = AggregationTemporality.delta

	public var isMonotonic: Bool { false }

	public func observe(_ number: T, attributes: TelemetryAttributes = [:]) {
		values.set(number, attributes: attributes)
	}

	public func reset() {
		startTime = ContinuousClock.now
		values.reset()
	}

	// MARK: Internal

	let callback: (ObservableUpDownCounter<T>) -> Void
	var values = MetricValues<T>()

	func invokeCallback() {
		callback(self)
	}

	func exportOTLP(_ exporter: Exporter) -> OTLP.V1Metric {
		exporter.exportOTLP(counter: self)
	}
}
