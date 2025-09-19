//
//  ObservableUpDownCounterTests.swift
//
//
//  Created by Van Tol, Ladd on 12/15/21.
//

import Foundation
import XCTest

@testable import NautilusTelemetry

final class ObservableUpDownCounterTests: XCTestCase {

	// MARK: - Initialization Tests

	func testInitialization() {
		var callbackInvoked = false
		let callback: (ObservableUpDownCounter<Int>) -> Void = { _ in
			callbackInvoked = true
		}

		let counter = ObservableUpDownCounter<Int>(
			name: "test_observable_updown_counter",
			unit: Unit(symbol: "count"),
			description: "Test observable up-down counter",
			callback: callback
		)

		XCTAssertEqual(counter.name, "test_observable_updown_counter")
		XCTAssertEqual(try XCTUnwrap(counter.unit?.symbol), "count")
		XCTAssertEqual(counter.description, "Test observable up-down counter")
		XCTAssertEqual(counter.aggregationTemporality, .delta)
		XCTAssertFalse(counter.isMonotonic)
		XCTAssertTrue(counter.isEmpty)
		XCTAssertNil(counter.endTime)
		XCTAssertFalse(callbackInvoked) // Callback should not be invoked during initialization
	}

	func testInitializationWithNilValues() {
		let callback: (ObservableUpDownCounter<Int>) -> Void = { _ in }
		let counter = ObservableUpDownCounter<Int>(name: "test_counter", unit: nil, description: nil, callback: callback)

		XCTAssertEqual(counter.name, "test_counter")
		XCTAssertNil(counter.unit)
		XCTAssertNil(counter.description)
		XCTAssertTrue(counter.isEmpty)
	}

	func testInitializationWithDoubleType() {
		let callback: (ObservableUpDownCounter<Double>) -> Void = { _ in }
		let counter = ObservableUpDownCounter<Double>(
			name: "double_counter",
			unit: Unit(symbol: "percentage"),
			description: "Percentage counter",
			callback: callback
		)

		XCTAssertEqual(counter.name, "double_counter")
		XCTAssertEqual(try XCTUnwrap(counter.unit?.symbol), "percentage")
		XCTAssertTrue(counter.isEmpty)
	}

	// MARK: - Observe Method Tests

	func testObserveWithEmptyAttributes() {
		let callback: (ObservableUpDownCounter<Int>) -> Void = { _ in }
		let counter = ObservableUpDownCounter<Int>(name: "test_counter", unit: nil, description: nil, callback: callback)

		counter.observe(42)
		XCTAssertFalse(counter.isEmpty)
		XCTAssertEqual(counter.values.valueFor(attributes: [:]), 42)

		// Observe uses set, not add, so observing again should replace the value
		counter.observe(-15)
		XCTAssertEqual(counter.values.valueFor(attributes: [:]), -15)
	}

	func testObserveWithAttributes() {
		let callback: (ObservableUpDownCounter<Int>) -> Void = { _ in }
		let counter = ObservableUpDownCounter<Int>(name: "test_counter", unit: nil, description: nil, callback: callback)
		let attributes1: TelemetryAttributes = ["queue": "high_priority"]
		let attributes2: TelemetryAttributes = ["queue": "low_priority"]

		counter.observe(10, attributes: attributes1)
		counter.observe(-5, attributes: attributes2)

		XCTAssertEqual(counter.values.valueFor(attributes: attributes1), 10)
		XCTAssertEqual(counter.values.valueFor(attributes: attributes2), -5)
		XCTAssertFalse(counter.isEmpty)
	}

	func testObserveOverwritesPreviousValue() {
		let callback: (ObservableUpDownCounter<Int>) -> Void = { _ in }
		let counter = ObservableUpDownCounter<Int>(name: "test_counter", unit: nil, description: nil, callback: callback)
		let attributes: TelemetryAttributes = ["connection": "active"]

		counter.observe(100, attributes: attributes)
		counter.observe(-50, attributes: attributes)

		// Should overwrite, not accumulate
		XCTAssertEqual(counter.values.valueFor(attributes: attributes), -50)
	}

	func testObserveWithDoubleValues() throws {
		let callback: (ObservableUpDownCounter<Double>) -> Void = { _ in }
		let counter = ObservableUpDownCounter<Double>(name: "test_counter", unit: nil, description: nil, callback: callback)

		counter.observe(3.14159)
		let value1 = try XCTUnwrap(counter.values.valueFor(attributes: [:]))
		XCTAssertEqual(value1, 3.14159, accuracy: 0.00001)

		counter.observe(-2.71828)
		let value2 = try XCTUnwrap(counter.values.valueFor(attributes: [:]))
		XCTAssertEqual(value2, -2.71828, accuracy: 0.00001)
	}

	func testObserveZeroValue() {
		let callback: (ObservableUpDownCounter<Int>) -> Void = { _ in }
		let counter = ObservableUpDownCounter<Int>(name: "test_counter", unit: nil, description: nil, callback: callback)

		counter.observe(0)
		XCTAssertEqual(counter.values.valueFor(attributes: [:]), 0)
		XCTAssertTrue(counter.isEmpty) // Counter with only zero values should be considered empty
	}

	func testObservePositiveAndNegativeValues() {
		let callback: (ObservableUpDownCounter<Int>) -> Void = { _ in }
		let counter = ObservableUpDownCounter<Int>(name: "test_counter", unit: nil, description: nil, callback: callback)

		// Test positive values
		counter.observe(100)
		XCTAssertEqual(counter.values.valueFor(attributes: [:]), 100)
		XCTAssertFalse(counter.isEmpty)

		// Test negative values (allowed for up-down counters)
		counter.observe(-75)
		XCTAssertEqual(counter.values.valueFor(attributes: [:]), -75)
		XCTAssertFalse(counter.isEmpty)
	}

	// MARK: - IsMonotonic Tests

	func testIsMonotonic() {
		let callback: (ObservableUpDownCounter<Int>) -> Void = { _ in }
		let counter = ObservableUpDownCounter<Int>(name: "test_counter", unit: nil, description: nil, callback: callback)
		XCTAssertFalse(counter.isMonotonic) // Up-down counters are not monotonic
	}

	// MARK: - IsEmpty Tests

	func testIsEmptyInitialState() {
		let callback: (ObservableUpDownCounter<Int>) -> Void = { _ in }
		let counter = ObservableUpDownCounter<Int>(name: "test_counter", unit: nil, description: nil, callback: callback)
		XCTAssertTrue(counter.isEmpty)
	}

	func testIsEmptyAfterObserving() {
		let callback: (ObservableUpDownCounter<Int>) -> Void = { _ in }
		let counter = ObservableUpDownCounter<Int>(name: "test_counter", unit: nil, description: nil, callback: callback)

		counter.observe(5)
		XCTAssertFalse(counter.isEmpty)

		counter.observe(-3)
		XCTAssertFalse(counter.isEmpty)
	}

	func testIsEmptyWithZeroValues() {
		let callback: (ObservableUpDownCounter<Int>) -> Void = { _ in }
		let counter = ObservableUpDownCounter<Int>(name: "test_counter", unit: nil, description: nil, callback: callback)

		counter.observe(0)
		XCTAssertTrue(counter.isEmpty) // Counter with only zero values should be empty
	}

	// MARK: - Callback Tests

	func testCallbackInvokedDuringSnapshotAndReset() {
		var callbackInvoked = false
		var callbackCounter: ObservableUpDownCounter<Int>?

		let callback: (ObservableUpDownCounter<Int>) -> Void = { counter in
			callbackInvoked = true
			callbackCounter = counter
		}

		let counter = ObservableUpDownCounter<Int>(name: "test_counter", unit: nil, description: nil, callback: callback)
		counter.observe(42)

		let snapshot = counter.snapshotAndReset()

		XCTAssertTrue(callbackInvoked)
		XCTAssertNotNil(callbackCounter)
		XCTAssertIdentical(callbackCounter, counter)
	}

	func testCallbackCanObserveValues() {
		let callback: (ObservableUpDownCounter<Int>) -> Void = { counter in
			// Callback can observe additional values, including negative ones
			counter.observe(-100, attributes: ["callback": "true"])
		}

		let counter = ObservableUpDownCounter<Int>(name: "test_counter", unit: nil, description: nil, callback: callback)
		counter.observe(50, attributes: ["manual": "true"])

		let snapshot = counter.snapshotAndReset() as! ObservableUpDownCounter<Int>

		// Snapshot should contain both the manually observed value and callback value
		XCTAssertEqual(snapshot.values.valueFor(attributes: ["manual": "true"]), 50)
		XCTAssertEqual(snapshot.values.valueFor(attributes: ["callback": "true"]), -100)
	}

	func testMultipleCallbackInvocations() {
		var callbackCount = 0
		let callback: (ObservableUpDownCounter<Int>) -> Void = { _ in
			callbackCount += 1
		}

		let counter = ObservableUpDownCounter<Int>(name: "test_counter", unit: nil, description: nil, callback: callback)

		counter.snapshotAndReset()
		counter.snapshotAndReset()
		counter.snapshotAndReset()

		XCTAssertEqual(callbackCount, 3)
	}

	// MARK: - SnapshotAndReset Tests

	func testSnapshotAndReset() {
		var callbackInvoked = false
		let callback: (ObservableUpDownCounter<Int>) -> Void = { _ in
			callbackInvoked = true
		}

		let counter = ObservableUpDownCounter<Int>(
			name: "test_counter",
			unit: Unit(symbol: "count"),
			description: "Test counter",
			callback: callback
		)
		let attributes1: TelemetryAttributes = ["operation": "add"]
		let attributes2: TelemetryAttributes = ["operation": "remove"]

		counter.observe(10, attributes: attributes1)
		counter.observe(-5, attributes: attributes2)

		let originalStartTime = counter.startTime

		let snapshot = counter.snapshotAndReset() as! ObservableUpDownCounter<Int>

		// Callback should have been invoked
		XCTAssertTrue(callbackInvoked)

		// Original counter should be reset
		XCTAssertTrue(counter.isEmpty)
		XCTAssertNil(counter.values.valueFor(attributes: attributes1))
		XCTAssertNil(counter.values.valueFor(attributes: attributes2))
		XCTAssertNil(counter.endTime)
		XCTAssertGreaterThan(counter.startTime, originalStartTime)

		// Snapshot should contain the values
		XCTAssertEqual(snapshot.name, "test_counter")
		XCTAssertEqual(try XCTUnwrap(snapshot.unit?.symbol), "count")
		XCTAssertEqual(snapshot.description, "Test counter")
		XCTAssertEqual(snapshot.values.valueFor(attributes: attributes1), 10)
		XCTAssertEqual(snapshot.values.valueFor(attributes: attributes2), -5)
		XCTAssertEqual(snapshot.startTime, originalStartTime)
		XCTAssertNotNil(snapshot.endTime)
		XCTAssertEqual(snapshot.aggregationTemporality, .delta)
		XCTAssertFalse(snapshot.isEmpty)
	}

	func testSnapshotAndResetEmptyCounter() {
		let callback: (ObservableUpDownCounter<Int>) -> Void = { _ in }
		let counter = ObservableUpDownCounter<Int>(name: "test_counter", unit: nil, description: nil, callback: callback)

		let snapshot = counter.snapshotAndReset() as! ObservableUpDownCounter<Int>

		XCTAssertTrue(counter.isEmpty)
		XCTAssertTrue(snapshot.isEmpty)
		XCTAssertEqual(snapshot.name, "test_counter")
	}

	func testSnapshotAndResetIndependence() {
		let callback: (ObservableUpDownCounter<Int>) -> Void = { _ in }
		let counter = ObservableUpDownCounter<Int>(name: "test_counter", unit: nil, description: nil, callback: callback)
		let attributes: TelemetryAttributes = ["test": "independence"]

		counter.observe(100, attributes: attributes)
		let snapshot = counter.snapshotAndReset() as! ObservableUpDownCounter<Int>

		// Modify original after snapshot
		counter.observe(-200, attributes: attributes)

		// Snapshot should be unchanged
		XCTAssertEqual(snapshot.values.valueFor(attributes: attributes), 100)
		XCTAssertEqual(counter.values.valueFor(attributes: attributes), -200)
	}

	// MARK: - AggregationTemporality Tests

	func testAggregationTemporality() {
		let callback: (ObservableUpDownCounter<Int>) -> Void = { _ in }
		let counter = ObservableUpDownCounter<Int>(name: "test_counter", unit: nil, description: nil, callback: callback)

		XCTAssertEqual(counter.aggregationTemporality, .delta)

		counter.aggregationTemporality = .cumulative
		XCTAssertEqual(counter.aggregationTemporality, .cumulative)

		counter.aggregationTemporality = .unspecified
		XCTAssertEqual(counter.aggregationTemporality, .unspecified)
	}

	// MARK: - Threading Safety Tests

	func testConcurrentObserveOperations() {
		let callback: (ObservableUpDownCounter<Int>) -> Void = { _ in }
		let counter = ObservableUpDownCounter<Int>(name: "test_counter", unit: nil, description: nil, callback: callback)
		let expectation = XCTestExpectation(description: "Concurrent operations")
		expectation.expectedFulfillmentCount = 10

		// Simulate concurrent observe operations with different attributes
		for i in 1...10 {
			DispatchQueue.global().async {
				let attributes: TelemetryAttributes = ["thread": i]
				// Mix positive and negative values
				let value = i % 2 == 0 ? i * 10 : -(i * 10)
				counter.observe(value, attributes: attributes)
				expectation.fulfill()
			}
		}

		wait(for: [expectation], timeout: 5.0)

		XCTAssertFalse(counter.isEmpty)
		XCTAssertEqual(counter.values.values.count, 10) // Each thread should have its own attribute set
	}

	// MARK: - Complex Scenarios Tests

	func testMultipleAttributeCombinations() {
		let callback: (ObservableUpDownCounter<Int>) -> Void = { _ in }
		let counter = ObservableUpDownCounter<Int>(name: "test_counter", unit: nil, description: nil, callback: callback)

		// Test with different attribute combinations and mixed positive/negative values
		for i in 0..<10 {
			let attributes: TelemetryAttributes = [
				"service": i % 2 == 0 ? "api" : "web",
				"status": i % 3 == 0 ? "success" : "error",
				"index": i,
			]
			// Mix positive and negative values
			let value = i % 2 == 0 ? (i + 1) * 10 : -((i + 1) * 10)
			counter.observe(value, attributes: attributes)
		}

		XCTAssertFalse(counter.isEmpty)
		XCTAssertEqual(counter.values.values.count, 10) // Should have 10 unique attribute combinations
	}

	func testObserveWithCallbackInteraction() {
		var callbackObservationCount = 0
		let callback: (ObservableUpDownCounter<Int>) -> Void = { counter in
			callbackObservationCount += 1
			// Callback observes a computed value that can be negative
			let value = callbackObservationCount % 2 == 0 ? callbackObservationCount * 1000 : -(callbackObservationCount * 1000)
			counter.observe(value, attributes: ["computed": "true"])
		}

		let counter = ObservableUpDownCounter<Int>(name: "test_counter", unit: nil, description: nil, callback: callback)

		// Manual observations
		counter.observe(100, attributes: ["manual": "1"])
		counter.observe(-200, attributes: ["manual": "2"])

		let snapshot1 = counter.snapshotAndReset() as! ObservableUpDownCounter<Int>

		// Check first snapshot (callbackObservationCount = 1, so value = -1000)
		XCTAssertEqual(snapshot1.values.valueFor(attributes: ["manual": "1"]), 100)
		XCTAssertEqual(snapshot1.values.valueFor(attributes: ["manual": "2"]), -200)
		XCTAssertEqual(snapshot1.values.valueFor(attributes: ["computed": "true"]), -1000)

		// Do another snapshot
		counter.observe(300, attributes: ["manual": "3"])
		let snapshot2 = counter.snapshotAndReset() as! ObservableUpDownCounter<Int>

		// Check second snapshot (callbackObservationCount = 2, so value = 2000)
		XCTAssertEqual(snapshot2.values.valueFor(attributes: ["manual": "3"]), 300)
		XCTAssertEqual(snapshot2.values.valueFor(attributes: ["computed": "true"]), 2000)
		XCTAssertEqual(callbackObservationCount, 2)
	}

	func testQueueLengthScenario() {
		// Simulate observing queue lengths that can go up and down
		var currentQueueLength = 0
		let callback: (ObservableUpDownCounter<Int>) -> Void = { counter in
			// Simulate reading current queue states
			counter.observe(currentQueueLength, attributes: ["queue": "high_priority"])
			counter.observe(currentQueueLength / 2, attributes: ["queue": "low_priority"])
		}

		let counter = ObservableUpDownCounter<Int>(
			name: "queue_length",
			unit: Unit(symbol: "count"),
			description: "Current queue lengths",
			callback: callback
		)

		// Initial state
		currentQueueLength = 50
		let snapshot1 = counter.snapshotAndReset() as! ObservableUpDownCounter<Int>
		XCTAssertEqual(snapshot1.values.valueFor(attributes: ["queue": "high_priority"]), 50)
		XCTAssertEqual(snapshot1.values.valueFor(attributes: ["queue": "low_priority"]), 25)

		// Queue grows
		currentQueueLength = 120
		let snapshot2 = counter.snapshotAndReset() as! ObservableUpDownCounter<Int>
		XCTAssertEqual(snapshot2.values.valueFor(attributes: ["queue": "high_priority"]), 120)
		XCTAssertEqual(snapshot2.values.valueFor(attributes: ["queue": "low_priority"]), 60)

		// Queue shrinks
		currentQueueLength = 10
		let snapshot3 = counter.snapshotAndReset() as! ObservableUpDownCounter<Int>
		XCTAssertEqual(snapshot3.values.valueFor(attributes: ["queue": "high_priority"]), 10)
		XCTAssertEqual(snapshot3.values.valueFor(attributes: ["queue": "low_priority"]), 5)
	}

	// MARK: - Time Management Tests

	func testStartTimeIsSet() {
		let callback: (ObservableUpDownCounter<Int>) -> Void = { _ in }
		let counter = ObservableUpDownCounter<Int>(name: "test_counter", unit: nil, description: nil, callback: callback)

		// Start time should be set during initialization
		XCTAssertLessThanOrEqual(counter.startTime, ContinuousClock.now)
	}

	func testEndTimeIsNilInitially() {
		let callback: (ObservableUpDownCounter<Int>) -> Void = { _ in }
		let counter = ObservableUpDownCounter<Int>(name: "test_counter", unit: nil, description: nil, callback: callback)

		XCTAssertNil(counter.endTime)
	}

	func testEndTimeSetAfterSnapshot() {
		let callback: (ObservableUpDownCounter<Int>) -> Void = { _ in }
		let counter = ObservableUpDownCounter<Int>(name: "test_counter", unit: nil, description: nil, callback: callback)
		counter.observe(10)

		let snapshot = counter.snapshotAndReset() as! ObservableUpDownCounter<Int>

		XCTAssertNotNil(snapshot.endTime)
		XCTAssertNil(counter.endTime) // Original should have nil endTime after reset
	}

	// MARK: - Edge Cases Tests

	func testAttributeEquality() {
		let callback: (ObservableUpDownCounter<Int>) -> Void = { _ in }
		let counter = ObservableUpDownCounter<Int>(name: "test_counter", unit: nil, description: nil, callback: callback)

		// Test that attribute dictionaries with same content are treated as equal
		let attributes1: TelemetryAttributes = ["a": "1", "b": "2"]
		let attributes2: TelemetryAttributes = ["b": "2", "a": "1"] // Different order

		counter.observe(10, attributes: attributes1)
		counter.observe(-20, attributes: attributes2)

		// Should overwrite since dictionaries are equal and observe uses set
		XCTAssertEqual(counter.values.valueFor(attributes: attributes1), -20)
		XCTAssertEqual(counter.values.valueFor(attributes: attributes2), -20)
	}

	func testEmptyName() {
		let callback: (ObservableUpDownCounter<Int>) -> Void = { _ in }
		let counter = ObservableUpDownCounter<Int>(name: "", unit: nil, description: nil, callback: callback)

		XCTAssertEqual(counter.name, "")
		counter.observe(-5)
		XCTAssertFalse(counter.isEmpty)
	}

	func testCallbackWithException() {
		let callback: (ObservableUpDownCounter<Int>) -> Void = { _ in
			// Simulate a callback that might throw or cause issues
			// In a real scenario, callbacks should be robust
		}

		let counter = ObservableUpDownCounter<Int>(name: "test_counter", unit: nil, description: nil, callback: callback)
		counter.observe(42)

		// Should not crash even if callback has issues
		XCTAssertNoThrow(counter.snapshotAndReset())
	}

	func testExtremeLargeValues() {
		let callback: (ObservableUpDownCounter<Int>) -> Void = { _ in }
		let counter = ObservableUpDownCounter<Int>(name: "test_counter", unit: nil, description: nil, callback: callback)

		counter.observe(Int.max)
		XCTAssertEqual(counter.values.valueFor(attributes: [:]), Int.max)

		counter.observe(Int.min)
		XCTAssertEqual(counter.values.valueFor(attributes: [:]), Int.min)
		XCTAssertFalse(counter.isEmpty) // Even extreme values make it non-empty
	}

	func testFloatingPointPrecision() throws {
		let callback: (ObservableUpDownCounter<Double>) -> Void = { _ in }
		let counter = ObservableUpDownCounter<Double>(name: "test_counter", unit: nil, description: nil, callback: callback)

		let precisePositiveValue = 123.456789012345
		counter.observe(precisePositiveValue)
		let value1 = try XCTUnwrap(counter.values.valueFor(attributes: [:]))
		XCTAssertEqual(value1, precisePositiveValue, accuracy: 1e-15)

		let preciseNegativeValue = -987.654321098765
		counter.observe(preciseNegativeValue)
		let value2 = try XCTUnwrap(counter.values.valueFor(attributes: [:]))
		XCTAssertEqual(value2, preciseNegativeValue, accuracy: 1e-15)
	}
}
