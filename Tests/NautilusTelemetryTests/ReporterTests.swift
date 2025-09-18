//
//  ReporterTests.swift
//
//
//  Created by Ladd Van Tol on 3/22/22.
//

import Foundation
import XCTest

@testable import NautilusTelemetry

final class ReporterTests: XCTestCase {

	func testNoOpReporter() {
		InstrumentationSystem.resetBootstrapForTests()
		let reporter = NoOpReporter()
		InstrumentationSystem.bootstrap(reporter: reporter)
		XCTAssert((InstrumentationSystem.reporter as? NoOpReporter) === reporter)

		XCTAssertEqual(reporter.flushInterval, 1)
		reporter.reportSpans([])
		reporter.reportInstruments([])
		reporter.subscribeToLifecycleEvents()
	}

	func testMeterFlushIntervalWiring() {
		InstrumentationSystem.resetBootstrapForTests()
		// Test that the meter flush interval gets wired up during bootstrap
		let reporter = NoOpReporter()

		// Bootstrap the instrumentation system
		InstrumentationSystem.bootstrap(reporter: reporter)

		// Verify that both tracer and meter got the flush interval from the reporter
		let expectedInterval = reporter.flushInterval
		XCTAssertEqual(InstrumentationSystem.tracer.flushInterval, expectedInterval)
		XCTAssertEqual(InstrumentationSystem.meter.flushInterval, expectedInterval)
	}
}
