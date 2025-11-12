//
//  InstrumentationSystem.swift
//
//
//  Created by Van Tol, Ladd on 11/29/21.
//

import Foundation

public enum InstrumentationSystem {

	// MARK: Public

	static public private(set) var tracer = Tracer()
	static public private(set) var meter = Meter()

	static public private(set) var reporter: NautilusTelemetryReporter? = nil

	public static func bootstrap(reporter _reporter: NautilusTelemetryReporter) {
		NautilusTelemetry.queue.sync {
			precondition(reporter == nil, "Only bootstrap once!")

			reporter = _reporter

			let flushInterval = _reporter.flushInterval
			// Convey the flush interval.
			tracer.flushInterval = flushInterval
			tracer.idleTimeoutInterval = _reporter.idleTimeoutInterval

			meter.flushInterval = flushInterval
		}

		#if DEBUG && os(iOS)
		// not yet ready for release
		metricKitInstrument.start()
		#endif
	}

	// MARK: Internal

	#if os(iOS)
	static var metricKitInstrument = MetricKitInstrument()
	#endif

	static func resetBootstrapForTests() {
		reporter = nil
	}

}
