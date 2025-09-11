//
//  Meter.swift
//
//
//  Created by Van Tol, Ladd on 12/15/21.
//

import Foundation
import os

// https://github.com/open-telemetry/opentelemetry-specification/blob/main/specification/metrics/api.md
// https://github.com/open-telemetry/opentelemetry-specification/blob/main/specification/metrics/datamodel.md

/// The meter is responsible for creating Instruments.
public final class Meter {

	// MARK: Lifecycle

	public init() {
		self.flushInterval = 60
		self.flushTimer = FlushTimer(flushInterval: flushInterval) { [weak self] in self?.flushActiveIntruments() }
	}

	// MARK: Public

	public func createCounter<T: MetricNumeric>(
		name: String,
		unit: Unit? = nil,
		description: String? = nil
	) -> Counter<T> {
		let instrument = Counter<T>(name: name, unit: unit, description: description)
		register(instrument)
		return instrument
	}

	public func createObservableCounter<T: MetricNumeric>(
		name: String,
		unit: Unit? = nil,
		description: String? = nil,
		callback: @escaping (ObservableCounter<T>) -> Void
	) -> ObservableCounter<T> {
		let instrument = ObservableCounter(name: name, unit: unit, description: description, callback: callback)
		register(instrument)
		return instrument
	}

	public func createUpDownCounter<T: MetricNumeric>(
		name: String,
		unit: Unit? = nil,
		description: String? = nil
	) -> UpDownCounter<T> {
		let instrument = UpDownCounter<T>(name: name, unit: unit, description: description)
		register(instrument)
		return instrument
	}

	public func createObservableUpDownCounter<T: MetricNumeric>(
		name: String,
		unit: Unit? = nil,
		description: String? = nil,
		callback: @escaping (ObservableUpDownCounter<T>) -> Void
	) -> ObservableUpDownCounter<T> {
		let instrument = ObservableUpDownCounter<T>(name: name, unit: unit, description: description, callback: callback)
		register(instrument)
		return instrument
	}

	public func createHistogram<T: MetricNumeric>(
		name: String,
		unit: Unit? = nil,
		description: String? = nil,
		explicitBounds: [T]
	) -> Histogram<T> {
		let instrument = Histogram<T>(name: name, unit: unit, description: description, explicitBounds: explicitBounds)
		register(instrument)
		return instrument
	}

	public func createObservableGauge<T: MetricNumeric>(
		name: String,
		unit: Unit? = nil,
		description: String? = nil,
		callback: @escaping (ObservableGauge<T>) -> Void
	) -> ObservableGauge<T> {
		let instrument = ObservableGauge<T>(name: name, unit: unit, description: description, callback: callback)
		register(instrument)
		return instrument
	}

	// MARK: Internal

	func register(_ instrument: Instrument) {
		Self.lock.withLock {
			activeInstruments.append(instrument)
		}
	}

	func unregister(_ instrument: Instrument) {
		Self.lock.withLock {
			// O(N) -- may need to improve this
			activeInstruments.removeAll { $0 === instrument }
		}
	}

	func flushActiveIntruments() {
		let instrumentsToReport: [Instrument] = Self.lock.withLock { activeInstruments }

		if instrumentsToReport.count > 0, let reporter = InstrumentationSystem.reporter {
			reporter.reportInstruments(instrumentsToReport)
		}
	}

	/// Sets the flush interval for reporting back to the configured ``Reporter``.
	var flushInterval: TimeInterval {
		didSet {
			flushTimer?.flushInterval = flushInterval
		}
	}

	/// Optional to avoid initialization order issue
	var flushTimer: FlushTimer?

	var activeInstruments = [Instrument]()

	/// Used for protecting internal state
	private static let lock = OSAllocatedUnfairLock()

}
