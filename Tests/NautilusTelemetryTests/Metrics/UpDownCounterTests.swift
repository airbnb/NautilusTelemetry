//
//  UpDownCounterTests.swift
//
//
//  Created by Van Tol, Ladd on 12/15/21.
//

import Foundation
import XCTest

@testable import NautilusTelemetry

final class UpDownCounterTests: XCTestCase {

	// MARK: - Initialization Tests

	func testInitialization() {
		let counter = UpDownCounter<Int>(name: "test_updown_counter", unit: Unit(symbol: "count"), description: "Test up-down counter")

		XCTAssertEqual(counter.name, "test_updown_counter")
		XCTAssertEqual(try XCTUnwrap(counter.unit?.symbol), "count")
		XCTAssertEqual(counter.description, "Test up-down counter")
		XCTAssertEqual(counter.aggregationTemporality, .delta)
		XCTAssertFalse(counter.isMonotonic) // Up-down counters are not monotonic
		XCTAssertTrue(counter.isEmpty)
		XCTAssertNil(counter.endTime)
	}

	func testInitializationWithNilValues() {
		let counter = UpDownCounter<Int>(name: "test_counter", unit: nil, description: nil)

		XCTAssertEqual(counter.name, "test_counter")
		XCTAssertNil(counter.unit)
		XCTAssertNil(counter.description)
		XCTAssertTrue(counter.isEmpty)
	}

	func testInitializationWithDoubleType() {
		let counter = UpDownCounter<Double>(name: "double_counter", unit: Unit(symbol: "percentage"), description: "Percentage counter")

		XCTAssertEqual(counter.name, "double_counter")
		XCTAssertEqual(try XCTUnwrap(counter.unit?.symbol), "percentage")
		XCTAssertTrue(counter.isEmpty)
	}

	// MARK: - Add Method Tests

	func testAddWithEmptyAttributes() {
		let counter = UpDownCounter<Int>(name: "test_counter", unit: nil, description: nil)

		counter.add(5)
		XCTAssertFalse(counter.isEmpty)
		XCTAssertEqual(counter.values.valueFor(attributes: [:]), 5)

		counter.add(3)
		XCTAssertEqual(counter.values.valueFor(attributes: [:]), 8)
	}

	func testAddWithAttributes() {
		let counter = UpDownCounter<Int>(name: "test_counter", unit: nil, description: nil)
		let attributes1: TelemetryAttributes = ["operation": "increment"]
		let attributes2: TelemetryAttributes = ["operation": "decrement"]

		counter.add(10, attributes: attributes1)
		counter.add(-5, attributes: attributes2)

		XCTAssertEqual(counter.values.valueFor(attributes: attributes1), 10)
		XCTAssertEqual(counter.values.valueFor(attributes: attributes2), -5)
		XCTAssertFalse(counter.isEmpty)
	}

	func testAddAccumulation() {
		let counter = UpDownCounter<Int>(name: "test_counter", unit: nil, description: nil)
		let attributes: TelemetryAttributes = ["resource": "connections"]

		counter.add(5, attributes: attributes)
		counter.add(-2, attributes: attributes)
		counter.add(3, attributes: attributes)

		XCTAssertEqual(counter.values.valueFor(attributes: attributes), 6) // 5 - 2 + 3 = 6
	}

	func testAddWithDoubleValues() throws {
		let counter = UpDownCounter<Double>(name: "test_counter", unit: nil, description: nil)

		counter.add(1.5)
		counter.add(-0.7)
		counter.add(2.3)

		let total = try XCTUnwrap(counter.values.valueFor(attributes: [:]))
		XCTAssertEqual(total, 3.1, accuracy: 0.001)
	}

	func testAddZeroValue() {
		let counter = UpDownCounter<Int>(name: "test_counter", unit: nil, description: nil)

		counter.add(0)
		XCTAssertEqual(counter.values.valueFor(attributes: [:]), 0)
		XCTAssertTrue(counter.isEmpty) // Counter with only zero values should be considered empty
	}

	func testAddNegativeValues() {
		let counter = UpDownCounter<Int>(name: "test_counter", unit: nil, description: nil)

		// UpDownCounter allows negative values (unlike regular Counter)
		counter.add(-10)
		XCTAssertEqual(counter.values.valueFor(attributes: [:]), -10)
		XCTAssertFalse(counter.isEmpty)

		counter.add(-5)
		XCTAssertEqual(counter.values.valueFor(attributes: [:]), -15)
	}

	func testAddLargeValues() {
		let counter = UpDownCounter<Int>(name: "test_counter", unit: nil, description: nil)

		counter.add(Int.max - 1)
		XCTAssertEqual(counter.values.valueFor(attributes: [:]), Int.max - 1)

		// Add a small negative value
		counter.add(-1)
		XCTAssertEqual(counter.values.valueFor(attributes: [:]), Int.max - 2)
	}

	// MARK: - IsMonotonic Tests

	func testIsMonotonic() {
		let counter = UpDownCounter<Int>(name: "test_counter", unit: nil, description: nil)
		XCTAssertFalse(counter.isMonotonic) // Up-down counters are not monotonic
	}

	// MARK: - IsEmpty Tests

	func testIsEmptyInitialState() {
		let counter = UpDownCounter<Int>(name: "test_counter", unit: nil, description: nil)
		XCTAssertTrue(counter.isEmpty)
	}

	func testIsEmptyAfterAddingValues() {
		let counter = UpDownCounter<Int>(name: "test_counter", unit: nil, description: nil)

		counter.add(5)
		XCTAssertFalse(counter.isEmpty)

		counter.add(-3)
		XCTAssertFalse(counter.isEmpty)
	}

	func testIsEmptyWithZeroValues() {
		let counter = UpDownCounter<Int>(name: "test_counter", unit: nil, description: nil)

		counter.add(0)
		XCTAssertTrue(counter.isEmpty) // Counter with only zero values should be empty
	}

	func testIsEmptyAfterCancellation() {
		let counter = UpDownCounter<Int>(name: "test_counter", unit: nil, description: nil)

		counter.add(10)
		counter.add(-10)
		XCTAssertTrue(counter.isEmpty) // Values cancel out to zero
	}

	// MARK: - SnapshotAndReset Tests

	func testSnapshotAndReset() {
		let counter = UpDownCounter<Int>(name: "test_counter", unit: Unit(symbol: "count"), description: "Test counter")
		let attributes1: TelemetryAttributes = ["direction": "up"]
		let attributes2: TelemetryAttributes = ["direction": "down"]

		counter.add(10, attributes: attributes1)
		counter.add(-5, attributes: attributes2)

		let originalStartTime = counter.startTime

		let snapshot = counter.snapshotAndReset() as! UpDownCounter<Int>

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
		XCTAssertFalse(snapshot.isMonotonic)
	}

	func testSnapshotAndResetEmptyCounter() {
		let counter = UpDownCounter<Int>(name: "test_counter", unit: nil, description: nil)

		let snapshot = counter.snapshotAndReset() as! UpDownCounter<Int>

		XCTAssertTrue(counter.isEmpty)
		XCTAssertTrue(snapshot.isEmpty)
		XCTAssertEqual(snapshot.name, "test_counter")
		XCTAssertFalse(snapshot.isMonotonic)
	}

	func testSnapshotAndResetIndependence() {
		let counter = UpDownCounter<Int>(name: "test_counter", unit: nil, description: nil)
		let attributes: TelemetryAttributes = ["test": "independence"]

		counter.add(100, attributes: attributes)
		let snapshot = counter.snapshotAndReset() as! UpDownCounter<Int>

		// Modify original after snapshot
		counter.add(-200, attributes: attributes)

		// Snapshot should be unchanged
		XCTAssertEqual(snapshot.values.valueFor(attributes: attributes), 100)
		XCTAssertEqual(counter.values.valueFor(attributes: attributes), -200)
	}

	// MARK: - AggregationTemporality Tests

	func testAggregationTemporality() {
		let counter = UpDownCounter<Int>(name: "test_counter", unit: nil, description: nil)

		XCTAssertEqual(counter.aggregationTemporality, .delta)

		counter.aggregationTemporality = .cumulative
		XCTAssertEqual(counter.aggregationTemporality, .cumulative)

		counter.aggregationTemporality = .unspecified
		XCTAssertEqual(counter.aggregationTemporality, .unspecified)
	}

	// MARK: - Threading Safety Tests

	func testConcurrentAddOperations() {
		let counter = UpDownCounter<Int>(name: "test_counter", unit: nil, description: nil)
		let expectation = XCTestExpectation(description: "Concurrent operations")
		expectation.expectedFulfillmentCount = 20

		// Simulate concurrent add operations with mixed positive and negative values
		for i in 1...10 {
			DispatchQueue.global().async {
				counter.add(i)
				expectation.fulfill()
			}
			DispatchQueue.global().async {
				counter.add(-i)
				expectation.fulfill()
			}
		}

		wait(for: [expectation], timeout: 5.0)

		// The sum should be 0: (1-1) + (2-2) + ... + (10-10) = 0
		XCTAssertEqual(counter.values.valueFor(attributes: [:]), 0)
		XCTAssertTrue(counter.isEmpty) // Should be empty since sum is zero
	}

	// MARK: - Complex Scenarios Tests

	func testMultipleAttributeCombinations() {
		let counter = UpDownCounter<Int>(name: "test_counter", unit: nil, description: nil)

		// Test with different attribute combinations and mixed positive/negative values
		for i in 0..<10 {
			let attributes: TelemetryAttributes = [
				"service": i % 2 == 0 ? "api" : "web",
				"operation": i % 3 == 0 ? "create" : "delete",
				"index": i,
			]
			// Mix positive and negative values
			let value = i % 2 == 0 ? (i + 1) : -(i + 1)
			counter.add(value, attributes: attributes)
		}

		XCTAssertFalse(counter.isEmpty)
		XCTAssertEqual(counter.values.values.count, 10) // Should have 10 unique attribute combinations
	}

	func testLargeNumberOfOperations() {
		let counter = UpDownCounter<Int>(name: "test_counter", unit: nil, description: nil)
		let attributes: TelemetryAttributes = ["load_test": "true"]

		// Add and subtract values many times
		for i in 1...1000 {
			counter.add(i % 2 == 0 ? 1 : -1, attributes: attributes)
		}

		// Should have 500 additions of 1 and 500 subtractions of 1, resulting in 0
		XCTAssertEqual(counter.values.valueFor(attributes: attributes), 0)
		XCTAssertTrue(counter.isEmpty)
	}

	func testConnectionPoolScenario() {
		let counter = UpDownCounter<Int>(name: "connection_pool", unit: Unit(symbol: "count"), description: "Active connections")
		let poolAttributes: TelemetryAttributes = ["pool": "database"]

		// Simulate connection pool operations
		counter.add(10, attributes: poolAttributes) // 10 connections opened
		XCTAssertEqual(counter.values.valueFor(attributes: poolAttributes), 10)

		counter.add(5, attributes: poolAttributes) // 5 more opened
		XCTAssertEqual(counter.values.valueFor(attributes: poolAttributes), 15)

		counter.add(-3, attributes: poolAttributes) // 3 closed
		XCTAssertEqual(counter.values.valueFor(attributes: poolAttributes), 12)

		counter.add(-12, attributes: poolAttributes) // All closed
		XCTAssertEqual(counter.values.valueFor(attributes: poolAttributes), 0)
		XCTAssertTrue(counter.isEmpty)
	}

	func testInventoryScenario() {
		let counter = UpDownCounter<Int>(name: "inventory", unit: Unit(symbol: "count"), description: "Inventory changes")

		// Different product inventories
		let product1: TelemetryAttributes = ["product": "laptop"]
		let product2: TelemetryAttributes = ["product": "mouse"]

		// Initial stock additions
		counter.add(50, attributes: product1)
		counter.add(200, attributes: product2)

		// Sales (negative additions)
		counter.add(-5, attributes: product1) // 5 laptops sold
		counter.add(-25, attributes: product2) // 25 mice sold

		// Restocking
		counter.add(10, attributes: product1) // 10 more laptops
		counter.add(50, attributes: product2) // 50 more mice

		XCTAssertEqual(counter.values.valueFor(attributes: product1), 55) // 50 - 5 + 10
		XCTAssertEqual(counter.values.valueFor(attributes: product2), 225) // 200 - 25 + 50
		XCTAssertFalse(counter.isEmpty)
	}

	// MARK: - Time Management Tests

	func testStartTimeIsSet() {
		let counter = UpDownCounter<Int>(name: "test_counter", unit: nil, description: nil)

		// Start time should be set during initialization
		XCTAssertLessThanOrEqual(counter.startTime, ContinuousClock.now)
	}

	func testEndTimeIsNilInitially() {
		let counter = UpDownCounter<Int>(name: "test_counter", unit: nil, description: nil)

		XCTAssertNil(counter.endTime)
	}

	func testEndTimeSetAfterSnapshot() {
		let counter = UpDownCounter<Int>(name: "test_counter", unit: nil, description: nil)
		counter.add(10)

		let snapshot = counter.snapshotAndReset() as! UpDownCounter<Int>

		XCTAssertNotNil(snapshot.endTime)
		XCTAssertNil(counter.endTime) // Original should have nil endTime after reset
	}

	// MARK: - Edge Cases Tests

	func testAttributeEquality() {
		let counter = UpDownCounter<Int>(name: "test_counter", unit: nil, description: nil)

		// Test that attribute dictionaries with same content are treated as equal
		let attributes1: TelemetryAttributes = ["a": "1", "b": "2"]
		let attributes2: TelemetryAttributes = ["b": "2", "a": "1"] // Different order

		counter.add(10, attributes: attributes1)
		counter.add(-5, attributes: attributes2)

		// Should accumulate since dictionaries are equal
		XCTAssertEqual(counter.values.valueFor(attributes: attributes1), 5)
		XCTAssertEqual(counter.values.valueFor(attributes: attributes2), 5)
	}

	func testEmptyName() {
		let counter = UpDownCounter<Int>(name: "", unit: nil, description: nil)

		XCTAssertEqual(counter.name, "")
		counter.add(-5)
		XCTAssertFalse(counter.isEmpty)
	}

	func testExtremeLargeValues() {
		let counter = UpDownCounter<Int>(name: "test_counter", unit: nil, description: nil)

		counter.add(Int.max)
		XCTAssertEqual(counter.values.valueFor(attributes: [:]), Int.max)

		// Reset and test minimum value
		counter.values.reset()
		counter.add(Int.min)
		XCTAssertEqual(counter.values.valueFor(attributes: [:]), Int.min)
		XCTAssertFalse(counter.isEmpty)
	}

	func testFloatingPointPrecision() throws {
		let counter = UpDownCounter<Double>(name: "test_counter", unit: nil, description: nil)

		let preciseValue1 = 123.456789012345
		let preciseValue2 = -987.654321098765

		counter.add(preciseValue1)
		counter.add(preciseValue2)

		let expectedSum = preciseValue1 + preciseValue2
		let actualSum = try XCTUnwrap(counter.values.valueFor(attributes: [:]))
		XCTAssertEqual(actualSum, expectedSum, accuracy: 1e-15)
	}

	func testOverflowBehavior() {
		let counter = UpDownCounter<Int>(name: "test_counter", unit: nil, description: nil)

		// Test near overflow conditions
		counter.add(Int.max - 10)
		XCTAssertEqual(counter.values.valueFor(attributes: [:]), Int.max - 10)

		// Adding a small positive value should work
		counter.add(5)
		XCTAssertEqual(counter.values.valueFor(attributes: [:]), Int.max - 5)
	}

	func testZeroSumWithManyOperations() {
		let counter = UpDownCounter<Int>(name: "test_counter", unit: nil, description: nil)
		let attributes: TelemetryAttributes = ["balanced": "true"]

		// Add many operations that sum to zero
		let operations = [10, -5, 3, -8, 15, -20, 7, -2]
		for value in operations {
			counter.add(value, attributes: attributes)
		}

		// Sum should be: 10 - 5 + 3 - 8 + 15 - 20 + 7 - 2 = 0
		XCTAssertEqual(counter.values.valueFor(attributes: attributes), 0)
		XCTAssertTrue(counter.isEmpty)
	}

	// MARK: - Inheritance Tests

	func testInheritsFromCounter() {
		let counter = UpDownCounter<Int>(name: "test_counter", unit: nil, description: nil)

		// Should inherit Counter properties but override isMonotonic
		XCTAssertFalse(counter.isMonotonic) // Overridden behavior

		// Should have access to Counter methods
		XCTAssertNotNil(counter.values)
		XCTAssertNotNil(counter.name)
		XCTAssertEqual(counter.aggregationTemporality, .delta)
	}
}
