//
//  ObservableGaugeTests.swift
//
//
//  Created by Van Tol, Ladd on 12/15/21.
//

import Foundation
import XCTest

@testable import NautilusTelemetry

final class ObservableGaugeTests: XCTestCase {

	// MARK: - Initialization Tests

	func testInitialization() {
		var callbackInvoked = false
		let callback: (ObservableGauge<Int>) -> Void = { _ in
			callbackInvoked = true
		}

		let gauge = ObservableGauge<Int>(
			name: "test_observable_gauge",
			unit: Unit(symbol: "bytes"),
			description: "Test observable gauge",
			callback: callback
		)

		XCTAssertEqual(gauge.name, "test_observable_gauge")
		XCTAssertEqual(try XCTUnwrap(gauge.unit?.symbol), "bytes")
		XCTAssertEqual(gauge.description, "Test observable gauge")
		XCTAssertEqual(gauge.aggregationTemporality, .unspecified)
		XCTAssertFalse(gauge.isEmpty) // Gauges are never empty
		XCTAssertNil(gauge.endTime)
		XCTAssertFalse(callbackInvoked) // Callback should not be invoked during initialization
	}

	func testInitializationWithNilValues() {
		let callback: (ObservableGauge<Int>) -> Void = { _ in }
		let gauge = ObservableGauge<Int>(name: "test_gauge", unit: nil, description: nil, callback: callback)

		XCTAssertEqual(gauge.name, "test_gauge")
		XCTAssertNil(gauge.unit)
		XCTAssertNil(gauge.description)
		XCTAssertFalse(gauge.isEmpty) // Gauges are never empty
	}

	func testInitializationWithDoubleType() {
		let callback: (ObservableGauge<Double>) -> Void = { _ in }
		let gauge = ObservableGauge<Double>(
			name: "double_gauge",
			unit: Unit(symbol: "celsius"),
			description: "Temperature gauge",
			callback: callback
		)

		XCTAssertEqual(gauge.name, "double_gauge")
		XCTAssertEqual(try XCTUnwrap(gauge.unit?.symbol), "celsius")
		XCTAssertFalse(gauge.isEmpty) // Gauges are never empty
	}

	// MARK: - Observe Method Tests

	func testObserveWithEmptyAttributes() {
		let callback: (ObservableGauge<Int>) -> Void = { _ in }
		let gauge = ObservableGauge<Int>(name: "test_gauge", unit: nil, description: nil, callback: callback)

		gauge.observe(42)
		XCTAssertFalse(gauge.isEmpty) // Gauges are never empty regardless
		XCTAssertEqual(gauge.values.valueFor(attributes: [:]), 42)

		// Observe uses set, not add, so observing again should replace the value
		gauge.observe(84)
		XCTAssertEqual(gauge.values.valueFor(attributes: [:]), 84)
	}

	func testObserveWithAttributes() {
		let callback: (ObservableGauge<Int>) -> Void = { _ in }
		let gauge = ObservableGauge<Int>(name: "test_gauge", unit: nil, description: nil, callback: callback)
		let attributes1: TelemetryAttributes = ["cpu": "core1"]
		let attributes2: TelemetryAttributes = ["cpu": "core2"]

		gauge.observe(45, attributes: attributes1)
		gauge.observe(78, attributes: attributes2)

		XCTAssertEqual(gauge.values.valueFor(attributes: attributes1), 45)
		XCTAssertEqual(gauge.values.valueFor(attributes: attributes2), 78)
		XCTAssertFalse(gauge.isEmpty)
	}

	func testObserveOverwritesPreviousValue() {
		let callback: (ObservableGauge<Int>) -> Void = { _ in }
		let gauge = ObservableGauge<Int>(name: "test_gauge", unit: nil, description: nil, callback: callback)
		let attributes: TelemetryAttributes = ["sensor": "temperature"]

		gauge.observe(20, attributes: attributes)
		gauge.observe(25, attributes: attributes)

		// Should overwrite, not accumulate
		XCTAssertEqual(gauge.values.valueFor(attributes: attributes), 25)
	}

	func testObserveWithDoubleValues() throws {
		let callback: (ObservableGauge<Double>) -> Void = { _ in }
		let gauge = ObservableGauge<Double>(name: "test_gauge", unit: nil, description: nil, callback: callback)

		gauge.observe(98.6)
		let value = try XCTUnwrap(gauge.values.valueFor(attributes: [:]))
		XCTAssertEqual(value, 98.6, accuracy: 0.001)
	}

	func testObserveZeroValue() {
		let callback: (ObservableGauge<Int>) -> Void = { _ in }
		let gauge = ObservableGauge<Int>(name: "test_gauge", unit: nil, description: nil, callback: callback)

		gauge.observe(0)
		XCTAssertEqual(gauge.values.valueFor(attributes: [:]), 0)
		XCTAssertFalse(gauge.isEmpty) // Gauges are never empty, even with zero values
	}

	func testObserveNegativeValues() {
		let callback: (ObservableGauge<Int>) -> Void = { _ in }
		let gauge = ObservableGauge<Int>(name: "test_gauge", unit: nil, description: nil, callback: callback)

		gauge.observe(-10)
		XCTAssertEqual(gauge.values.valueFor(attributes: [:]), -10)
		XCTAssertFalse(gauge.isEmpty) // Gauges are never empty
	}

	// MARK: - IsEmpty Tests

	func testIsEmptyAlwaysFalse() {
		let callback: (ObservableGauge<Int>) -> Void = { _ in }
		let gauge = ObservableGauge<Int>(name: "test_gauge", unit: nil, description: nil, callback: callback)

		// Gauges are never empty, even initially
		XCTAssertFalse(gauge.isEmpty)

		gauge.observe(100)
		XCTAssertFalse(gauge.isEmpty)

		gauge.observe(0)
		XCTAssertFalse(gauge.isEmpty)

		// Even after reset, gauges are never empty
		gauge.values.reset()
		XCTAssertFalse(gauge.isEmpty)
	}

	// MARK: - AggregationTemporality Tests

	func testAggregationTemporalityUnspecified() {
		let callback: (ObservableGauge<Int>) -> Void = { _ in }
		let gauge = ObservableGauge<Int>(name: "test_gauge", unit: nil, description: nil, callback: callback)

		// Gauges have unspecified aggregation temporality and it's read-only
		XCTAssertEqual(gauge.aggregationTemporality, .unspecified)
	}

	// MARK: - Callback Tests

	func testCallbackInvokedDuringSnapshotAndReset() {
		var callbackInvoked = false
		var callbackGauge: ObservableGauge<Int>?

		let callback: (ObservableGauge<Int>) -> Void = { gauge in
			callbackInvoked = true
			callbackGauge = gauge
		}

		let gauge = ObservableGauge<Int>(name: "test_gauge", unit: nil, description: nil, callback: callback)
		gauge.observe(42)

		let snapshot = gauge.snapshotAndReset()

		XCTAssertTrue(callbackInvoked)
		XCTAssertNotNil(callbackGauge)
		XCTAssertIdentical(callbackGauge, gauge)
	}

	func testCallbackCanObserveValues() {
		let callback: (ObservableGauge<Int>) -> Void = { gauge in
			// Callback can observe additional values
			gauge.observe(100, attributes: ["callback": "true"])
		}

		let gauge = ObservableGauge<Int>(name: "test_gauge", unit: nil, description: nil, callback: callback)
		gauge.observe(50, attributes: ["manual": "true"])

		let snapshot = gauge.snapshotAndReset() as! ObservableGauge<Int>

		// Snapshot should contain both the manually observed value and callback value
		XCTAssertEqual(snapshot.values.valueFor(attributes: ["manual": "true"]), 50)
		XCTAssertEqual(snapshot.values.valueFor(attributes: ["callback": "true"]), 100)
	}

	func testMultipleCallbackInvocations() {
		var callbackCount = 0
		let callback: (ObservableGauge<Int>) -> Void = { _ in
			callbackCount += 1
		}

		let gauge = ObservableGauge<Int>(name: "test_gauge", unit: nil, description: nil, callback: callback)

		gauge.snapshotAndReset()
		gauge.snapshotAndReset()
		gauge.snapshotAndReset()

		XCTAssertEqual(callbackCount, 3)
	}

	// MARK: - SnapshotAndReset Tests

	func testSnapshotAndReset() {
		var callbackInvoked = false
		let callback: (ObservableGauge<Int>) -> Void = { _ in
			callbackInvoked = true
		}

		let gauge = ObservableGauge<Int>(name: "test_gauge", unit: Unit(symbol: "bytes"), description: "Test gauge", callback: callback)
		let attributes1: TelemetryAttributes = ["disk": "sda1"]
		let attributes2: TelemetryAttributes = ["disk": "sda2"]

		gauge.observe(1024, attributes: attributes1)
		gauge.observe(2048, attributes: attributes2)

		let originalStartTime = gauge.startTime

		let snapshot = gauge.snapshotAndReset() as! ObservableGauge<Int>

		// Callback should have been invoked
		XCTAssertTrue(callbackInvoked)

		// Original gauge should be reset but still not empty
		XCTAssertFalse(gauge.isEmpty) // Gauges are never empty
		XCTAssertNil(gauge.values.valueFor(attributes: attributes1))
		XCTAssertNil(gauge.values.valueFor(attributes: attributes2))
		XCTAssertNil(gauge.endTime)
		XCTAssertGreaterThan(gauge.startTime, originalStartTime)

		// Snapshot should contain the values
		XCTAssertEqual(snapshot.name, "test_gauge")
		XCTAssertEqual(try XCTUnwrap(snapshot.unit?.symbol), "bytes")
		XCTAssertEqual(snapshot.description, "Test gauge")
		XCTAssertEqual(snapshot.values.valueFor(attributes: attributes1), 1024)
		XCTAssertEqual(snapshot.values.valueFor(attributes: attributes2), 2048)
		XCTAssertEqual(snapshot.startTime, originalStartTime)
		XCTAssertNotNil(snapshot.endTime)
		XCTAssertEqual(snapshot.aggregationTemporality, .unspecified)
		XCTAssertFalse(snapshot.isEmpty) // Gauges are never empty
	}

	func testSnapshotAndResetEmptyGauge() {
		let callback: (ObservableGauge<Int>) -> Void = { _ in }
		let gauge = ObservableGauge<Int>(name: "test_gauge", unit: nil, description: nil, callback: callback)

		let snapshot = gauge.snapshotAndReset() as! ObservableGauge<Int>

		XCTAssertFalse(gauge.isEmpty) // Gauges are never empty
		XCTAssertFalse(snapshot.isEmpty) // Gauges are never empty
		XCTAssertEqual(snapshot.name, "test_gauge")
	}

	func testSnapshotAndResetIndependence() {
		let callback: (ObservableGauge<Int>) -> Void = { _ in }
		let gauge = ObservableGauge<Int>(name: "test_gauge", unit: nil, description: nil, callback: callback)
		let attributes: TelemetryAttributes = ["test": "independence"]

		gauge.observe(100, attributes: attributes)
		let snapshot = gauge.snapshotAndReset() as! ObservableGauge<Int>

		// Modify original after snapshot
		gauge.observe(200, attributes: attributes)

		// Snapshot should be unchanged
		XCTAssertEqual(snapshot.values.valueFor(attributes: attributes), 100)
		XCTAssertEqual(gauge.values.valueFor(attributes: attributes), 200)
	}

	// MARK: - Threading Safety Tests

	func testConcurrentObserveOperations() {
		let callback: (ObservableGauge<Int>) -> Void = { _ in }
		let gauge = ObservableGauge<Int>(name: "test_gauge", unit: nil, description: nil, callback: callback)
		let expectation = XCTestExpectation(description: "Concurrent operations")
		expectation.expectedFulfillmentCount = 10

		// Simulate concurrent observe operations with different attributes
		for i in 1...10 {
			DispatchQueue.global().async {
				let attributes: TelemetryAttributes = ["sensor": i]
				gauge.observe(i * 10, attributes: attributes)
				expectation.fulfill()
			}
		}

		wait(for: [expectation], timeout: 5.0)

		XCTAssertFalse(gauge.isEmpty) // Gauges are never empty
		XCTAssertEqual(gauge.values.values.count, 10) // Each thread should have its own attribute set
	}

	// MARK: - Complex Scenarios Tests

	func testMultipleAttributeCombinations() {
		let callback: (ObservableGauge<Int>) -> Void = { _ in }
		let gauge = ObservableGauge<Int>(name: "test_gauge", unit: nil, description: nil, callback: callback)

		// Test with different attribute combinations
		for i in 0..<10 {
			let attributes: TelemetryAttributes = [
				"host": i % 2 == 0 ? "server1" : "server2",
				"metric": i % 3 == 0 ? "cpu" : "memory",
				"index": i,
			]
			gauge.observe((i + 1) * 10, attributes: attributes)
		}

		XCTAssertFalse(gauge.isEmpty) // Gauges are never empty
		XCTAssertEqual(gauge.values.values.count, 10) // Should have 10 unique attribute combinations
	}

	func testObserveWithCallbackInteraction() {
		var callbackObservationCount = 0
		let callback: (ObservableGauge<Int>) -> Void = { gauge in
			callbackObservationCount += 1
			// Callback observes current timestamp or computed value
			gauge.observe(callbackObservationCount * 1000, attributes: ["timestamp": "true"])
		}

		let gauge = ObservableGauge<Int>(name: "test_gauge", unit: nil, description: nil, callback: callback)

		// Manual observations
		gauge.observe(75, attributes: ["temperature": "cpu"])
		gauge.observe(68, attributes: ["temperature": "gpu"])

		let snapshot1 = gauge.snapshotAndReset() as! ObservableGauge<Int>

		// Check first snapshot
		XCTAssertEqual(snapshot1.values.valueFor(attributes: ["temperature": "cpu"]), 75)
		XCTAssertEqual(snapshot1.values.valueFor(attributes: ["temperature": "gpu"]), 68)
		XCTAssertEqual(snapshot1.values.valueFor(attributes: ["timestamp": "true"]), 1000)

		// Do another snapshot
		gauge.observe(72, attributes: ["temperature": "cpu"])
		let snapshot2 = gauge.snapshotAndReset() as! ObservableGauge<Int>

		// Check second snapshot
		XCTAssertEqual(snapshot2.values.valueFor(attributes: ["temperature": "cpu"]), 72)
		XCTAssertEqual(snapshot2.values.valueFor(attributes: ["timestamp": "true"]), 2000)
		XCTAssertEqual(callbackObservationCount, 2)
	}

	func testRealTimeGaugeScenario() {
		// Simulate a real-time gauge that reports system metrics
		var currentMemoryUsage = 512
		let callback: (ObservableGauge<Int>) -> Void = { gauge in
			// Simulate reading current system state
			gauge.observe(currentMemoryUsage, attributes: ["type": "memory"])
			gauge.observe(45, attributes: ["type": "cpu_percent"])
			gauge.observe(23, attributes: ["type": "disk_percent"])
		}

		let gauge = ObservableGauge<Int>(
			name: "system_metrics",
			unit: Unit(symbol: "megabytes"),
			description: "System resource usage",
			callback: callback
		)

		// First snapshot
		let snapshot1 = gauge.snapshotAndReset() as! ObservableGauge<Int>
		XCTAssertEqual(snapshot1.values.valueFor(attributes: ["type": "memory"]), 512)
		XCTAssertEqual(snapshot1.values.valueFor(attributes: ["type": "cpu_percent"]), 45)
		XCTAssertEqual(snapshot1.values.valueFor(attributes: ["type": "disk_percent"]), 23)

		// Change system state
		currentMemoryUsage = 768

		// Second snapshot should reflect new state
		let snapshot2 = gauge.snapshotAndReset() as! ObservableGauge<Int>
		XCTAssertEqual(snapshot2.values.valueFor(attributes: ["type": "memory"]), 768)
		XCTAssertEqual(snapshot2.values.valueFor(attributes: ["type": "cpu_percent"]), 45)
		XCTAssertEqual(snapshot2.values.valueFor(attributes: ["type": "disk_percent"]), 23)
	}

	// MARK: - Time Management Tests

	func testStartTimeIsSet() {
		let callback: (ObservableGauge<Int>) -> Void = { _ in }
		let gauge = ObservableGauge<Int>(name: "test_gauge", unit: nil, description: nil, callback: callback)

		// Start time should be set during initialization
		XCTAssertLessThanOrEqual(gauge.startTime, ContinuousClock.now)
	}

	func testEndTimeIsNilInitially() {
		let callback: (ObservableGauge<Int>) -> Void = { _ in }
		let gauge = ObservableGauge<Int>(name: "test_gauge", unit: nil, description: nil, callback: callback)

		XCTAssertNil(gauge.endTime)
	}

	func testEndTimeSetAfterSnapshot() {
		let callback: (ObservableGauge<Int>) -> Void = { _ in }
		let gauge = ObservableGauge<Int>(name: "test_gauge", unit: nil, description: nil, callback: callback)
		gauge.observe(10)

		let snapshot = gauge.snapshotAndReset() as! ObservableGauge<Int>

		XCTAssertNotNil(snapshot.endTime)
		XCTAssertNil(gauge.endTime) // Original should have nil endTime after reset
	}

	// MARK: - Edge Cases Tests

	func testAttributeEquality() {
		let callback: (ObservableGauge<Int>) -> Void = { _ in }
		let gauge = ObservableGauge<Int>(name: "test_gauge", unit: nil, description: nil, callback: callback)

		// Test that attribute dictionaries with same content are treated as equal
		let attributes1: TelemetryAttributes = ["a": "1", "b": "2"]
		let attributes2: TelemetryAttributes = ["b": "2", "a": "1"] // Different order

		gauge.observe(10, attributes: attributes1)
		gauge.observe(20, attributes: attributes2)

		// Should overwrite since dictionaries are equal and observe uses set
		XCTAssertEqual(gauge.values.valueFor(attributes: attributes1), 20)
		XCTAssertEqual(gauge.values.valueFor(attributes: attributes2), 20)
	}

	func testEmptyName() {
		let callback: (ObservableGauge<Int>) -> Void = { _ in }
		let gauge = ObservableGauge<Int>(name: "", unit: nil, description: nil, callback: callback)

		XCTAssertEqual(gauge.name, "")
		gauge.observe(5)
		XCTAssertFalse(gauge.isEmpty) // Gauges are never empty
	}

	func testCallbackWithException() {
		let callback: (ObservableGauge<Int>) -> Void = { _ in
			// Simulate a callback that might throw or cause issues
			// In a real scenario, callbacks should be robust
		}

		let gauge = ObservableGauge<Int>(name: "test_gauge", unit: nil, description: nil, callback: callback)
		gauge.observe(42)

		// Should not crash even if callback has issues
		XCTAssertNoThrow(gauge.snapshotAndReset())
	}

	func testExtremeLargeValues() {
		let callback: (ObservableGauge<Int>) -> Void = { _ in }
		let gauge = ObservableGauge<Int>(name: "test_gauge", unit: nil, description: nil, callback: callback)

		gauge.observe(Int.max)
		XCTAssertEqual(gauge.values.valueFor(attributes: [:]), Int.max)

		gauge.observe(Int.min)
		XCTAssertEqual(gauge.values.valueFor(attributes: [:]), Int.min)
	}

	func testFloatingPointPrecision() throws {
		let callback: (ObservableGauge<Double>) -> Void = { _ in }
		let gauge = ObservableGauge<Double>(name: "test_gauge", unit: nil, description: nil, callback: callback)

		let preciseValue = 1.23456789012345
		gauge.observe(preciseValue)
		let value = try XCTUnwrap(gauge.values.valueFor(attributes: [:]))
		XCTAssertEqual(value, preciseValue, accuracy: 1e-15)
	}
}
