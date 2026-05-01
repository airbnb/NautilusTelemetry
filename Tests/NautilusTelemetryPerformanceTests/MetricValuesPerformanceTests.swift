//
//  MetricValuesPerformanceTests.swift
//
//
//  Created by Ladd Van Tol on 2026-05-01.
//

import Foundation
import XCTest

@testable import NautilusTelemetry

/// Micro-benchmarks for the hot attribute-sink paths: `MetricValues.add`,
/// `HistogramValues.record`, and `ExponentialHistogramValues.record`.
/// These are where a caller-built `TelemetryAttributes` dictionary flows into
/// the instrument on every `Counter.add` / `Histogram.record` / `ExponentialHistogram.record`.
final class MetricValuesPerformanceTests: XCTestCase {

	static let iterations = 100_000

	/// ≈580 ns/call on M4 Max (down from ≈634 ns with `AnyHashable`).
	func testCounterAddPerformance() {
		let counter = Counter<Int>(name: "test", unit: nil, description: nil)
		let attributes: TelemetryAttributes = ["endpoint": "/foo", "status": 200, "region": "us-east-1"]

		measure {
			for _ in 0..<Self.iterations {
				counter.add(1, attributes: attributes)
			}
		}
	}

	/// ≈670 ns/call on M4 Max (down from ≈727 ns with `AnyHashable`).
	func testHistogramRecordPerformance() {
		let histogram = Histogram<Double>(
			name: "test",
			unit: nil,
			description: nil,
			explicitBounds: [0.01, 0.1, 1, 10, 100]
		)
		let attributes: TelemetryAttributes = ["endpoint": "/foo", "status": 200, "region": "us-east-1"]

		measure {
			for _ in 0..<Self.iterations {
				histogram.record(0.42, attributes: attributes)
			}
		}
	}

	/// ≈6.12 µs/call on M4 Max (down from ≈6.23 µs with `AnyHashable`).
	/// Dominated by `recordedValues.append(Double)`; the attribute-hash improvement
	/// contributes only a small fraction of the wall clock.
	func testExponentialHistogramRecordPerformance() {
		let attributes: TelemetryAttributes = ["endpoint": "/foo", "status": 200, "region": "us-east-1"]

		measure {
			// Fresh histogram per iteration so `recordedValues` array doesn't grow unboundedly
			// across measurement runs.
			let histogram = ExponentialHistogram<Double>(name: "test", unit: nil, description: nil)
			for _ in 0..<Self.iterations {
				histogram.record(0.42, attributes: attributes)
			}
		}
	}
}
