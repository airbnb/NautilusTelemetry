//
//  MeterTests.swift
//
//
//  Created by Ladd Van Tol on 3/22/22.
//

import Foundation
import XCTest

@testable import NautilusTelemetry

final class MeterTests: XCTestCase {

	func testCreate() {
		let meter = InstrumentationSystem.meter

		let counter1: Counter<Int> = meter.createCounter(name: "counter1", description: "hello")
		XCTAssert(counter1.values.values.isEmpty)

		let counter2: UpDownCounter<Int> = meter.createUpDownCounter(name: "counter2", description: "hello")
		XCTAssert(counter2.values.values.isEmpty)

		let counter3: ObservableCounter<Int> = meter.createObservableCounter(name: "counter3", description: "hello") { counter in
			counter.observe(100)
		}
		XCTAssert(counter3.values.values.isEmpty)

		let counter4: ObservableUpDownCounter<Int> = meter
			.createObservableUpDownCounter(name: "counter4", description: "hello") { counter in
				counter.observe(100)
			}
		XCTAssert(counter4.values.values.isEmpty)

		let histogram: Histogram<Int> = meter.createHistogram(name: "histogram", explicitBounds: [0, 10, 20])
		XCTAssert(histogram.values.values.isEmpty)

		let gauge: ObservableGauge<Int> = meter.createObservableGauge(name: "gauge") { gauge in
			gauge.observe(100)
		}
		XCTAssert(gauge.values.values.isEmpty)
	}

	func testFlushMetrics() throws {
		let meter = Meter()

		// Test that the flushMetrics method exists and can be called
		// This tests the new public method added in the commit
		meter.flushMetrics()

		// The method should not crash when called with no instruments
		XCTAssertNoThrow(meter.flushMetrics())
	}

	func testFlushIntervalWiring() throws {
		let meter = Meter()

		// Test that flush interval can be set
		let originalInterval = meter.flushInterval
		let newInterval: TimeInterval = 30.0

		meter.flushInterval = newInterval
		XCTAssertEqual(meter.flushInterval, newInterval)
		XCTAssertNotEqual(meter.flushInterval, originalInterval)
	}
}
