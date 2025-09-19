//
//  CounterTests.swift
//
//
//  Created by Van Tol, Ladd on 12/15/21.
//

import Foundation
import XCTest

@testable import NautilusTelemetry

final class CounterTests: XCTestCase {

	// MARK: - Initialization Tests

	func testInitialization() {
		let counter = Counter<Int>(name: "test_counter", unit: Unit(symbol: "count"), description: "Test counter")

		XCTAssertEqual(counter.name, "test_counter")
		XCTAssertEqual(try XCTUnwrap(counter.unit?.symbol), "count")
		XCTAssertEqual(counter.description, "Test counter")
		XCTAssertEqual(counter.aggregationTemporality, .delta)
		XCTAssertTrue(counter.isMonotonic)
		XCTAssertTrue(counter.isEmpty)
		XCTAssertNil(counter.endTime)
	}

	func testInitializationWithNilValues() {
		let counter = Counter<Int>(name: "test_counter", unit: nil, description: nil)

		XCTAssertEqual(counter.name, "test_counter")
		XCTAssertNil(counter.unit)
		XCTAssertNil(counter.description)
		XCTAssertTrue(counter.isEmpty)
	}

	func testInitializationWithDoubleType() {
		let counter = Counter<Double>(name: "double_counter", unit: Unit(symbol: "seconds"), description: "Double counter")

		XCTAssertEqual(counter.name, "double_counter")
		XCTAssertEqual(try XCTUnwrap(counter.unit?.symbol), "seconds")
		XCTAssertTrue(counter.isEmpty)
	}

	// MARK: - Add Method Tests

	func testAddWithEmptyAttributes() {
		let counter = Counter<Int>(name: "test_counter", unit: nil, description: nil)

		counter.add(5)
		XCTAssertFalse(counter.isEmpty)
		XCTAssertEqual(counter.values.valueFor(attributes: [:]), 5)

		counter.add(3)
		XCTAssertEqual(counter.values.valueFor(attributes: [:]), 8)
	}

	func testAddWithAttributes() {
		let counter = Counter<Int>(name: "test_counter", unit: nil, description: nil)
		let attributes1: TelemetryAttributes = ["method": "GET"]
		let attributes2: TelemetryAttributes = ["method": "POST"]

		counter.add(10, attributes: attributes1)
		counter.add(20, attributes: attributes2)

		XCTAssertEqual(counter.values.valueFor(attributes: attributes1), 10)
		XCTAssertEqual(counter.values.valueFor(attributes: attributes2), 20)
		XCTAssertFalse(counter.isEmpty)
	}

	func testAddAccumulation() {
		let counter = Counter<Int>(name: "test_counter", unit: nil, description: nil)
		let attributes: TelemetryAttributes = ["endpoint": "/api/users"]

		counter.add(1, attributes: attributes)
		counter.add(2, attributes: attributes)
		counter.add(3, attributes: attributes)

		XCTAssertEqual(counter.values.valueFor(attributes: attributes), 6)
	}

	func testAddWithDoubleValues() throws {
		let counter = Counter<Double>(name: "test_counter", unit: nil, description: nil)

		counter.add(1.5)
		counter.add(2.7)

		let total = try XCTUnwrap(counter.values.valueFor(attributes: [:]))
		XCTAssertEqual(total, 4.2, accuracy: 0.001)
	}

	func testAddZeroValue() {
		let counter = Counter<Int>(name: "test_counter", unit: nil, description: nil)

		counter.add(0)
		XCTAssertEqual(counter.values.valueFor(attributes: [:]), 0)
		XCTAssertTrue(counter.isEmpty) // Counter with zero values should be considered empty
	}

	func testAddLargeValues() {
		let counter = Counter<Int>(name: "test_counter", unit: nil, description: nil)

		counter.add(Int.max - 1)
		XCTAssertEqual(counter.values.valueFor(attributes: [:]), Int.max - 1)
	}

	// MARK: - IsMonotonic Tests

	func testIsMonotonic() {
		let counter = Counter<Int>(name: "test_counter", unit: nil, description: nil)
		XCTAssertTrue(counter.isMonotonic)
	}

	// MARK: - IsEmpty Tests

	func testIsEmptyInitialState() {
		let counter = Counter<Int>(name: "test_counter", unit: nil, description: nil)
		XCTAssertTrue(counter.isEmpty)
	}

	func testIsEmptyAfterAddingValues() {
		let counter = Counter<Int>(name: "test_counter", unit: nil, description: nil)

		counter.add(5)
		XCTAssertFalse(counter.isEmpty)
	}

	func testIsEmptyWithZeroValues() {
		let counter = Counter<Int>(name: "test_counter", unit: nil, description: nil)

		counter.add(0)
		XCTAssertTrue(counter.isEmpty) // Counter with only zero values should be empty
	}

	// MARK: - SnapshotAndReset Tests

	func testSnapshotAndReset() {
		let counter = Counter<Int>(name: "test_counter", unit: Unit(symbol: "count"), description: "Test counter")
		let attributes1: TelemetryAttributes = ["method": "GET"]
		let attributes2: TelemetryAttributes = ["method": "POST"]

		counter.add(10, attributes: attributes1)
		counter.add(20, attributes: attributes2)

		let originalStartTime = counter.startTime

		let snapshot = counter.snapshotAndReset() as! Counter<Int>

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
		let counter = Counter<Int>(name: "test_counter", unit: nil, description: nil)

		let snapshot = counter.snapshotAndReset() as! Counter<Int>

		XCTAssertTrue(counter.isEmpty)
		XCTAssertTrue(snapshot.isEmpty)
		XCTAssertEqual(snapshot.name, "test_counter")
	}

	func testSnapshotAndResetIndependence() {
		let counter = Counter<Int>(name: "test_counter", unit: nil, description: nil)
		let attributes: TelemetryAttributes = ["test": "independence"]

		counter.add(100, attributes: attributes)
		let snapshot = counter.snapshotAndReset() as! Counter<Int>

		// Modify original after snapshot
		counter.add(200, attributes: attributes)

		// Snapshot should be unchanged
		XCTAssertEqual(snapshot.values.valueFor(attributes: attributes), 100)
		XCTAssertEqual(counter.values.valueFor(attributes: attributes), 200)
	}

	// MARK: - AggregationTemporality Tests

	func testAggregationTemporality() {
		let counter = Counter<Int>(name: "test_counter", unit: nil, description: nil)

		XCTAssertEqual(counter.aggregationTemporality, .delta)

		counter.aggregationTemporality = .cumulative
		XCTAssertEqual(counter.aggregationTemporality, .cumulative)

		counter.aggregationTemporality = .unspecified
		XCTAssertEqual(counter.aggregationTemporality, .unspecified)
	}

	// MARK: - Threading Safety Tests

	func testConcurrentAddOperations() {
		let counter = Counter<Int>(name: "test_counter", unit: nil, description: nil)
		let expectation = XCTestExpectation(description: "Concurrent operations")
		expectation.expectedFulfillmentCount = 10

		// Simulate concurrent add operations
		for i in 1...10 {
			DispatchQueue.global().async {
				counter.add(i)
				expectation.fulfill()
			}
		}

		wait(for: [expectation], timeout: 5.0)

		// The sum should be 1+2+3+...+10 = 55
		XCTAssertEqual(counter.values.valueFor(attributes: [:]), 55)
	}

	// MARK: - Complex Scenarios Tests

	func testMultipleAttributeCombinations() {
		let counter = Counter<Int>(name: "test_counter", unit: nil, description: nil)

		// Test with different attribute combinations
		for i in 0..<10 {
			let attributes: TelemetryAttributes = [
				"method": i % 2 == 0 ? "GET" : "POST",
				"status": i % 3 == 0 ? "success" : "error",
				"index": i,
			]
			counter.add(i + 1, attributes: attributes)
		}

		XCTAssertFalse(counter.isEmpty)
		XCTAssertEqual(counter.values.values.count, 10) // Should have 10 unique attribute combinations
	}

	func testLargeNumberOfOperations() {
		let counter = Counter<Int>(name: "test_counter", unit: nil, description: nil)
		let attributes: TelemetryAttributes = ["load_test": "true"]

		// Add values many times
		for _ in 1...1000 {
			counter.add(1, attributes: attributes)
		}

		XCTAssertEqual(counter.values.valueFor(attributes: attributes), 1000)
		XCTAssertFalse(counter.isEmpty)
	}

	// MARK: - Time Management Tests

	func testStartTimeIsSet() {
		let counter = Counter<Int>(name: "test_counter", unit: nil, description: nil)

		// Start time should be set during initialization
		XCTAssertLessThanOrEqual(counter.startTime, ContinuousClock.now)
	}

	func testEndTimeIsNilInitially() {
		let counter = Counter<Int>(name: "test_counter", unit: nil, description: nil)

		XCTAssertNil(counter.endTime)
	}

	func testEndTimeSetAfterSnapshot() {
		let counter = Counter<Int>(name: "test_counter", unit: nil, description: nil)
		counter.add(10)

		let snapshot = counter.snapshotAndReset() as! Counter<Int>

		XCTAssertNotNil(snapshot.endTime)
		XCTAssertNil(counter.endTime) // Original should have nil endTime after reset
	}

	// MARK: - Edge Cases Tests

	func testAttributeEquality() {
		let counter = Counter<Int>(name: "test_counter", unit: nil, description: nil)

		// Test that attribute dictionaries with same content are treated as equal
		let attributes1: TelemetryAttributes = ["a": "1", "b": "2"]
		let attributes2: TelemetryAttributes = ["b": "2", "a": "1"] // Different order

		counter.add(10, attributes: attributes1)
		counter.add(5, attributes: attributes2)

		// Should accumulate since dictionaries are equal
		XCTAssertEqual(counter.values.valueFor(attributes: attributes1), 15)
		XCTAssertEqual(counter.values.valueFor(attributes: attributes2), 15)
	}

	func testEmptyName() {
		let counter = Counter<Int>(name: "", unit: nil, description: nil)

		XCTAssertEqual(counter.name, "")
		counter.add(5)
		XCTAssertFalse(counter.isEmpty)
	}
}
