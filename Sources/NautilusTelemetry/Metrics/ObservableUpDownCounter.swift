//
//  ObservableUpDownCounter.swift
//
//
//  Created by Van Tol, Ladd on 12/15/21.
//

import Foundation
import Synchronization

public class ObservableUpDownCounter<T: MetricNumeric>: Instrument, ExportableInstrument {

	// MARK: Lifecycle

	required init(name: String, unit: Unit?, description: String?, callback: @escaping (ObservableUpDownCounter<T>) -> Void) {
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
	public var aggregationTemporality = AggregationTemporality.delta

	public var isMonotonic: Bool { false }

	public var isEmpty: Bool { lockedValues.withLock { $0.isEmpty } }

	public var exemplarSpans: [Span] { lockedExemplars.withLock { $0.map(\.span) } }

	public func addExemplar(span: Span, value: T, attributes: TelemetryAttributes = [:]) {
		lockedExemplars.withLock { $0.append(Exemplar(span: span, value: value, attributes: attributes)) }
	}

	public func observe(_ number: T, attributes: TelemetryAttributes = [:]) {
		lockedValues.withLock {
			$0.set(number, attributes: attributes)
		}
	}

	public func snapshotAndReset() -> Instrument {
		let now = ContinuousClock.now
		callback(self)

		let exemplars = lockedExemplars.withLock { exemplars in
			defer { exemplars.removeAll() }
			return exemplars
		}

		return lockedValues.withLock { values in
			let copy = Self(name: name, unit: unit, description: description, callback: callback)
			copy.startTime = startTime
			copy.endTime = now
			copy.lockedValues.withLock { $0 = values.snapshotAndReset() }
			copy.lockedExemplars.withLock { $0 = exemplars }

			// now reset
			startTime = now
			endTime = nil
			values.reset()
			return copy
		}
	}

	// MARK: Internal

	let callback: (ObservableUpDownCounter<T>) -> Void

	/// Thread-safe snapshot of the recorded values.
	var values: MetricValues<T> { lockedValues.withLock { $0 } }

	/// Thread-safe snapshot of the recorded exemplars.
	var exemplars: [Exemplar<T>] { lockedExemplars.withLock { $0 } }

	func exportOTLP(_ exporter: Exporter) -> OTLP.V1Metric {
		exporter.exportOTLP(counter: self)
	}

	// MARK: Private

	/// Locking is handled at the Instrument level
	private let lockedValues = Mutex(MetricValues<T>())

	/// Exemplars recorded in the current collection interval.
	private let lockedExemplars = Mutex<[Exemplar<T>]>([])
}
