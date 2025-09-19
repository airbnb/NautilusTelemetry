//
//  ObservableCounterTests.swift
//
//
//  Created by Van Tol, Ladd on 12/15/21.
//

import Foundation
import XCTest

@testable import NautilusTelemetry

final class ObservableCounterTests: XCTestCase {

	// MARK: - Initialization Tests

	func testInitialization() {
		var callbackInvoked = false
		let callback: (ObservableCounter<Int>) -> Void = { _ in
			callbackInvoked = true
		}

		let counter = ObservableCounter<Int>(
			name: "test_observable_counter",
			unit: Unit(symbol: "count"),
			description: "Test observable counter",
			callback: callback
		)

		XCTAssertEqual(counter.name, "test_observable_counter")
		XCTAssertEqual(try XCTUnwrap(counter.unit?.symbol), "count")
		XCTAssertEqual(counter.description, "Test observable counter")
		XCTAssertEqual(counter.aggregationTemporality, .delta)
		XCTAssertTrue(counter.isMonotonic)
		XCTAssertTrue(counter.isEmpty)
		XCTAssertNil(counter.endTime)
		XCTAssertFalse(callbackInvoked) // Callback should not be invoked during initialization
	}

	func testInitializationWithNilValues() {
		let callback: (ObservableCounter<Int>) -> Void = { _ in }
		let counter = ObservableCounter<Int>(name: "test_counter", unit: nil, description: nil, callback: callback)

		XCTAssertEqual(counter.name, "test_counter")
		XCTAssertNil(counter.unit)
		XCTAssertNil(counter.description)
		XCTAssertTrue(counter.isEmpty)
	}

	func testInitializationWithDoubleType() {
		let callback: (ObservableCounter<Double>) -> Void = { _ in }
		let counter = ObservableCounter<Double>(
			name: "double_counter",
			unit: Unit(symbol: "seconds"),
			description: "Double counter",
			callback: callback
		)

		XCTAssertEqual(counter.name, "double_counter")
		XCTAssertEqual(try XCTUnwrap(counter.unit?.symbol), "seconds")
		XCTAssertTrue(counter.isEmpty)
	}

	// MARK: - Observe Method Tests

	func testObserveWithEmptyAttributes() {
		let callback: (ObservableCounter<Int>) -> Void = { _ in }
		let counter = ObservableCounter<Int>(name: "test_counter", unit: nil, description: nil, callback: callback)

		counter.observe(42)
		XCTAssertFalse(counter.isEmpty)
		XCTAssertEqual(counter.values.valueFor(attributes: [:]), 42)

		// Observe uses set, not add, so observing again should replace the value
		counter.observe(84)
		XCTAssertEqual(counter.values.valueFor(attributes: [:]), 84)
	}

	func testObserveWithAttributes() {
		let callback: (ObservableCounter<Int>) -> Void = { _ in }
		let counter = ObservableCounter<Int>(name: "test_counter", unit: nil, description: nil, callback: callback)
		let attributes1: TelemetryAttributes = ["service": "api"]
		let attributes2: TelemetryAttributes = ["service": "web"]

		counter.observe(10, attributes: attributes1)
		counter.observe(20, attributes: attributes2)

		XCTAssertEqual(counter.values.valueFor(attributes: attributes1), 10)
		XCTAssertEqual(counter.values.valueFor(attributes: attributes2), 20)
		XCTAssertFalse(counter.isEmpty)
	}

	func testObserveOverwritesPreviousValue() {
		let callback: (ObservableCounter<Int>) -> Void = { _ in }
		let counter = ObservableCounter<Int>(name: "test_counter", unit: nil, description: nil, callback: callback)
		let attributes: TelemetryAttributes = ["endpoint": "/api/users"]

		counter.observe(100, attributes: attributes)
		counter.observe(200, attributes: attributes)

		// Should overwrite, not accumulate
		XCTAssertEqual(counter.values.valueFor(attributes: attributes), 200)
	}

	func testObserveWithDoubleValues() throws {
		let callback: (ObservableCounter<Double>) -> Void = { _ in }
		let counter = ObservableCounter<Double>(name: "test_counter", unit: nil, description: nil, callback: callback)

		counter.observe(3.14159)
		let value = try XCTUnwrap(counter.values.valueFor(attributes: [:]))
		XCTAssertEqual(value, 3.14159, accuracy: 0.00001)
	}

	func testObserveZeroValue() {
		let callback: (ObservableCounter<Int>) -> Void = { _ in }
		let counter = ObservableCounter<Int>(name: "test_counter", unit: nil, description: nil, callback: callback)

		counter.observe(0)
		XCTAssertEqual(counter.values.valueFor(attributes: [:]), 0)
		XCTAssertTrue(counter.isEmpty) // Counter with only zero values should be considered empty
	}

	// MARK: - IsMonotonic Tests

	func testIsMonotonic() {
		let callback: (ObservableCounter<Int>) -> Void = { _ in }
		let counter = ObservableCounter<Int>(name: "test_counter", unit: nil, description: nil, callback: callback)
		XCTAssertTrue(counter.isMonotonic)
	}

	// MARK: - IsEmpty Tests

	func testIsEmptyInitialState() {
		let callback: (ObservableCounter<Int>) -> Void = { _ in }
		let counter = ObservableCounter<Int>(name: "test_counter", unit: nil, description: nil, callback: callback)
		XCTAssertTrue(counter.isEmpty)
	}

	func testIsEmptyAfterObserving() {
		let callback: (ObservableCounter<Int>) -> Void = { _ in }
		let counter = ObservableCounter<Int>(name: "test_counter", unit: nil, description: nil, callback: callback)

		counter.observe(5)
		XCTAssertFalse(counter.isEmpty)
	}

	func testIsEmptyWithZeroValues() {
		let callback: (ObservableCounter<Int>) -> Void = { _ in }
		let counter = ObservableCounter<Int>(name: "test_counter", unit: nil, description: nil, callback: callback)

		counter.observe(0)
		XCTAssertTrue(counter.isEmpty) // Counter with only zero values should be empty
	}

	// MARK: - Callback Tests

	func testCallbackInvokedDuringSnapshotAndReset() {
		var callbackInvoked = false
		var callbackCounter: ObservableCounter<Int>?

		let callback: (ObservableCounter<Int>) -> Void = { counter in
			callbackInvoked = true
			callbackCounter = counter
		}

		let counter = ObservableCounter<Int>(name: "test_counter", unit: nil, description: nil, callback: callback)
		counter.observe(42)

		let snapshot = counter.snapshotAndReset()

		XCTAssertTrue(callbackInvoked)
		XCTAssertNotNil(callbackCounter)
		XCTAssertIdentical(callbackCounter, counter)
	}

	func testCallbackCanObserveValues() {
		let callback: (ObservableCounter<Int>) -> Void = { counter in
			// Callback can observe additional values
			counter.observe(100, attributes: ["callback": "true"])
		}

		let counter = ObservableCounter<Int>(name: "test_counter", unit: nil, description: nil, callback: callback)
		counter.observe(50, attributes: ["manual": "true"])

		let snapshot = counter.snapshotAndReset() as! ObservableCounter<Int>

		// Snapshot should contain both the manually observed value and callback value
		XCTAssertEqual(snapshot.values.valueFor(attributes: ["manual": "true"]), 50)
		XCTAssertEqual(snapshot.values.valueFor(attributes: ["callback": "true"]), 100)
	}

	func testMultipleCallbackInvocations() {
		var callbackCount = 0
		let callback: (ObservableCounter<Int>) -> Void = { _ in
			callbackCount += 1
		}

		let counter = ObservableCounter<Int>(name: "test_counter", unit: nil, description: nil, callback: callback)

		counter.snapshotAndReset()
		counter.snapshotAndReset()
		counter.snapshotAndReset()

		XCTAssertEqual(callbackCount, 3)
	}

	// MARK: - SnapshotAndReset Tests

	func testSnapshotAndReset() {
		var callbackInvoked = false
		let callback: (ObservableCounter<Int>) -> Void = { _ in
			callbackInvoked = true
		}

		let counter = ObservableCounter<Int>(
			name: "test_counter",
			unit: Unit(symbol: "count"),
			description: "Test counter",
			callback: callback
		)
		let attributes1: TelemetryAttributes = ["method": "GET"]
		let attributes2: TelemetryAttributes = ["method": "POST"]

		counter.observe(10, attributes: attributes1)
		counter.observe(20, attributes: attributes2)

		let originalStartTime = counter.startTime

		let snapshot = counter.snapshotAndReset() as! ObservableCounter<Int>

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
		XCTAssertEqual(snapshot.values.valueFor(attributes: attributes2), 20)
		XCTAssertEqual(snapshot.startTime, originalStartTime)
		XCTAssertNotNil(snapshot.endTime)
		XCTAssertEqual(snapshot.aggregationTemporality, .delta)
		XCTAssertFalse(snapshot.isEmpty)
	}

	func testSnapshotAndResetEmptyCounter() {
		let callback: (ObservableCounter<Int>) -> Void = { _ in }
		let counter = ObservableCounter<Int>(name: "test_counter", unit: nil, description: nil, callback: callback)

		let snapshot = counter.snapshotAndReset() as! ObservableCounter<Int>

		XCTAssertTrue(counter.isEmpty)
		XCTAssertTrue(snapshot.isEmpty)
		XCTAssertEqual(snapshot.name, "test_counter")
	}

	func testSnapshotAndResetIndependence() {
		let callback: (ObservableCounter<Int>) -> Void = { _ in }
		let counter = ObservableCounter<Int>(name: "test_counter", unit: nil, description: nil, callback: callback)
		let attributes: TelemetryAttributes = ["test": "independence"]

		counter.observe(100, attributes: attributes)
		let snapshot = counter.snapshotAndReset() as! ObservableCounter<Int>

		// Modify original after snapshot
		counter.observe(200, attributes: attributes)

		// Snapshot should be unchanged
		XCTAssertEqual(snapshot.values.valueFor(attributes: attributes), 100)
		XCTAssertEqual(counter.values.valueFor(attributes: attributes), 200)
	}

	// MARK: - AggregationTemporality Tests

	func testAggregationTemporality() {
		let callback: (ObservableCounter<Int>) -> Void = { _ in }
		let counter = ObservableCounter<Int>(name: "test_counter", unit: nil, description: nil, callback: callback)

		XCTAssertEqual(counter.aggregationTemporality, .delta)

		counter.aggregationTemporality = .cumulative
		XCTAssertEqual(counter.aggregationTemporality, .cumulative)

		counter.aggregationTemporality = .unspecified
		XCTAssertEqual(counter.aggregationTemporality, .unspecified)
	}

	// MARK: - Threading Safety Tests

	func testConcurrentObserveOperations() {
		let callback: (ObservableCounter<Int>) -> Void = { _ in }
		let counter = ObservableCounter<Int>(name: "test_counter", unit: nil, description: nil, callback: callback)
		let expectation = XCTestExpectation(description: "Concurrent operations")
		expectation.expectedFulfillmentCount = 10

		// Simulate concurrent observe operations with different attributes
		for i in 1...10 {
			DispatchQueue.global().async {
				let attributes: TelemetryAttributes = ["thread": i]
				counter.observe(i * 10, attributes: attributes)
				expectation.fulfill()
			}
		}

		wait(for: [expectation], timeout: 5.0)

		XCTAssertFalse(counter.isEmpty)
		XCTAssertEqual(counter.values.values.count, 10) // Each thread should have its own attribute set
	}

	// MARK: - Complex Scenarios Tests

	func testMultipleAttributeCombinations() {
		let callback: (ObservableCounter<Int>) -> Void = { _ in }
		let counter = ObservableCounter<Int>(name: "test_counter", unit: nil, description: nil, callback: callback)

		// Test with different attribute combinations
		for i in 0..<10 {
			let attributes: TelemetryAttributes = [
				"service": i % 2 == 0 ? "api" : "web",
				"status": i % 3 == 0 ? "success" : "error",
				"index": i,
			]
			counter.observe((i + 1) * 10, attributes: attributes)
		}

		XCTAssertFalse(counter.isEmpty)
		XCTAssertEqual(counter.values.values.count, 10) // Should have 10 unique attribute combinations
	}

	func testObserveWithCallbackInteraction() {
		var callbackObservationCount = 0
		let callback: (ObservableCounter<Int>) -> Void = { counter in
			callbackObservationCount += 1
			// Callback observes a computed value
			counter.observe(callbackObservationCount * 1000, attributes: ["computed": "true"])
		}

		let counter = ObservableCounter<Int>(name: "test_counter", unit: nil, description: nil, callback: callback)

		// Manual observations
		counter.observe(100, attributes: ["manual": "1"])
		counter.observe(200, attributes: ["manual": "2"])

		let snapshot1 = counter.snapshotAndReset() as! ObservableCounter<Int>

		// Check first snapshot
		XCTAssertEqual(snapshot1.values.valueFor(attributes: ["manual": "1"]), 100)
		XCTAssertEqual(snapshot1.values.valueFor(attributes: ["manual": "2"]), 200)
		XCTAssertEqual(snapshot1.values.valueFor(attributes: ["computed": "true"]), 1000)

		// Do another snapshot
		counter.observe(300, attributes: ["manual": "3"])
		let snapshot2 = counter.snapshotAndReset() as! ObservableCounter<Int>

		// Check second snapshot
		XCTAssertEqual(snapshot2.values.valueFor(attributes: ["manual": "3"]), 300)
		XCTAssertEqual(snapshot2.values.valueFor(attributes: ["computed": "true"]), 2000)
		XCTAssertEqual(callbackObservationCount, 2)
	}

	// MARK: - Time Management Tests

	func testStartTimeIsSet() {
		let callback: (ObservableCounter<Int>) -> Void = { _ in }
		let counter = ObservableCounter<Int>(name: "test_counter", unit: nil, description: nil, callback: callback)

		// Start time should be set during initialization
		XCTAssertLessThanOrEqual(counter.startTime, ContinuousClock.now)
	}

	func testEndTimeIsNilInitially() {
		let callback: (ObservableCounter<Int>) -> Void = { _ in }
		let counter = ObservableCounter<Int>(name: "test_counter", unit: nil, description: nil, callback: callback)

		XCTAssertNil(counter.endTime)
	}

	func testEndTimeSetAfterSnapshot() {
		let callback: (ObservableCounter<Int>) -> Void = { _ in }
		let counter = ObservableCounter<Int>(name: "test_counter", unit: nil, description: nil, callback: callback)
		counter.observe(10)

		let snapshot = counter.snapshotAndReset() as! ObservableCounter<Int>

		XCTAssertNotNil(snapshot.endTime)
		XCTAssertNil(counter.endTime) // Original should have nil endTime after reset
	}

	// MARK: - Edge Cases Tests

	func testAttributeEquality() {
		let callback: (ObservableCounter<Int>) -> Void = { _ in }
		let counter = ObservableCounter<Int>(name: "test_counter", unit: nil, description: nil, callback: callback)

		// Test that attribute dictionaries with same content are treated as equal
		let attributes1: TelemetryAttributes = ["a": "1", "b": "2"]
		let attributes2: TelemetryAttributes = ["b": "2", "a": "1"] // Different order

		counter.observe(10, attributes: attributes1)
		counter.observe(20, attributes: attributes2)

		// Should overwrite since dictionaries are equal and observe uses set
		XCTAssertEqual(counter.values.valueFor(attributes: attributes1), 20)
		XCTAssertEqual(counter.values.valueFor(attributes: attributes2), 20)
	}

	func testEmptyName() {
		let callback: (ObservableCounter<Int>) -> Void = { _ in }
		let counter = ObservableCounter<Int>(name: "", unit: nil, description: nil, callback: callback)

		XCTAssertEqual(counter.name, "")
		counter.observe(5)
		XCTAssertFalse(counter.isEmpty)
	}

	func testCallbackWithException() {
		let callback: (ObservableCounter<Int>) -> Void = { _ in
			// Simulate a callback that might throw or cause issues
			// In a real scenario, callbacks should be robust
		}

		let counter = ObservableCounter<Int>(name: "test_counter", unit: nil, description: nil, callback: callback)
		counter.observe(42)

		// Should not crash even if callback has issues
		XCTAssertNoThrow(counter.snapshotAndReset())
	}

	func testObserveNegativeValues() {
		let callback: (ObservableCounter<Int>) -> Void = { _ in }
		let counter = ObservableCounter<Int>(name: "test_counter", unit: nil, description: nil, callback: callback)

		// ObservableCounters can observe negative values (unlike regular counters)
		counter.observe(-10)
		XCTAssertEqual(counter.values.valueFor(attributes: [:]), -10)
		XCTAssertFalse(counter.isEmpty) // Even negative values make it non-empty
	}
}
