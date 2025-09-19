//
//  MetricValuesTests.swift
//
//
//  Created by Van Tol, Ladd on 12/20/21.
//

import Foundation
import XCTest

@testable import NautilusTelemetry

final class MetricValuesTests: XCTestCase {

	// MARK: - Initialization Tests

	func testInitialization() {
		let intMetrics = MetricValues<Int>()
		XCTAssertTrue(intMetrics.values.isEmpty)
		XCTAssertTrue(intMetrics.isEmpty)

		let doubleMetrics = MetricValues<Double>()
		XCTAssertTrue(doubleMetrics.values.isEmpty)
		XCTAssertTrue(doubleMetrics.isEmpty)
	}

	// MARK: - Add Tests

	func testAddWithEmptyAttributes() {
		var metrics = MetricValues<Int>()

		metrics.add(5)
		XCTAssertEqual(metrics.valueFor(attributes: [:]), 5)
		XCTAssertFalse(metrics.isEmpty)

		metrics.add(3)
		XCTAssertEqual(metrics.valueFor(attributes: [:]), 8)
	}

	func testAddWithAttributes() {
		var metrics = MetricValues<Int>()
		let attributes1: TelemetryAttributes = ["key1": "value1"]
		let attributes2: TelemetryAttributes = ["key2": "value2"]

		metrics.add(10, attributes: attributes1)
		metrics.add(20, attributes: attributes2)

		XCTAssertEqual(metrics.valueFor(attributes: attributes1), 10)
		XCTAssertEqual(metrics.valueFor(attributes: attributes2), 20)
		XCTAssertFalse(metrics.isEmpty)
	}

	func testAddAccumulation() {
		var metrics = MetricValues<Int>()
		let attributes: TelemetryAttributes = ["environment": "test"]

		metrics.add(1, attributes: attributes)
		metrics.add(2, attributes: attributes)
		metrics.add(3, attributes: attributes)

		XCTAssertEqual(metrics.valueFor(attributes: attributes), 6)
	}

	func testAddWithDoubleValues() throws {
		var metrics = MetricValues<Double>()

		metrics.add(1.5)
		metrics.add(2.7)

		let total = try XCTUnwrap(metrics.valueFor(attributes: [:]))
		XCTAssertEqual(total, 4.2, accuracy: 0.001)
	}

	func testAddWithNegativeValues() throws {
		var metrics = MetricValues<Int>()

		metrics.add(10)
		metrics.add(-3)

		let total = try XCTUnwrap(metrics.valueFor(attributes: [:]))
		XCTAssertEqual(total, 7)
	}

	// MARK: - Set Tests

	func testSetWithEmptyAttributes() {
		var metrics = MetricValues<Int>()

		metrics.set(42)
		XCTAssertEqual(metrics.valueFor(attributes: [:]), 42)
		XCTAssertFalse(metrics.isEmpty)

		metrics.set(100)
		XCTAssertEqual(metrics.valueFor(attributes: [:]), 100)
	}

	func testSetWithAttributes() {
		var metrics = MetricValues<Int>()
		let attributes1: TelemetryAttributes = ["service": "api"]
		let attributes2: TelemetryAttributes = ["service": "web"]

		metrics.set(50, attributes: attributes1)
		metrics.set(75, attributes: attributes2)

		XCTAssertEqual(metrics.valueFor(attributes: attributes1), 50)
		XCTAssertEqual(metrics.valueFor(attributes: attributes2), 75)
	}

	func testSetOverwritesPreviousValue() {
		var metrics = MetricValues<Int>()
		let attributes: TelemetryAttributes = ["method": "GET"]

		metrics.set(10, attributes: attributes)
		metrics.set(20, attributes: attributes)

		XCTAssertEqual(metrics.valueFor(attributes: attributes), 20)
	}

	func testSetWithDoubleValues() throws {
		var metrics = MetricValues<Double>()

		let pi = 3.14159
		metrics.set(pi)
		let value = try XCTUnwrap(metrics.valueFor(attributes: [:]))
		XCTAssertEqual(value, pi, accuracy: 0.00001)
	}

	// MARK: - Reset Tests

	func testReset() {
		var metrics = MetricValues<Int>()
		let attributes1: TelemetryAttributes = ["key1": "value1"]
		let attributes2: TelemetryAttributes = ["key2": "value2"]

		metrics.add(10, attributes: attributes1)
		metrics.add(20, attributes: attributes2)
		XCTAssertFalse(metrics.isEmpty)

		metrics.reset()

		XCTAssertTrue(metrics.values.isEmpty)
		XCTAssertTrue(metrics.isEmpty)
		XCTAssertNil(metrics.valueFor(attributes: attributes1))
		XCTAssertNil(metrics.valueFor(attributes: attributes2))
	}

	func testResetEmptyMetrics() {
		var metrics = MetricValues<Int>()

		metrics.reset()

		XCTAssertTrue(metrics.values.isEmpty)
		XCTAssertTrue(metrics.isEmpty)
	}

	// MARK: - SnapshotAndReset Tests

	func testSnapshotAndReset() {
		var metrics = MetricValues<Int>()
		let attributes1: TelemetryAttributes = ["key1": "value1"]
		let attributes2: TelemetryAttributes = ["key2": "value2"]

		metrics.add(15, attributes: attributes1)
		metrics.add(25, attributes: attributes2)

		let snapshot = metrics.snapshotAndReset()

		// Original should be empty
		XCTAssertTrue(metrics.values.isEmpty)
		XCTAssertTrue(metrics.isEmpty)

		// Snapshot should contain the values
		XCTAssertEqual(snapshot.valueFor(attributes: attributes1), 15)
		XCTAssertEqual(snapshot.valueFor(attributes: attributes2), 25)
		XCTAssertFalse(snapshot.isEmpty)
	}

	func testSnapshotAndResetEmptyMetrics() {
		var metrics = MetricValues<Int>()

		let snapshot = metrics.snapshotAndReset()

		XCTAssertTrue(metrics.values.isEmpty)
		XCTAssertTrue(metrics.isEmpty)
		XCTAssertTrue(snapshot.values.isEmpty)
		XCTAssertTrue(snapshot.isEmpty)
	}

	func testSnapshotAndResetIndependence() {
		var metrics = MetricValues<Int>()
		let attributes: TelemetryAttributes = ["test": "independence"]

		metrics.add(100, attributes: attributes)
		let snapshot = metrics.snapshotAndReset()

		// Modify original after snapshot
		metrics.add(200, attributes: attributes)

		// Snapshot should be unchanged
		XCTAssertEqual(snapshot.valueFor(attributes: attributes), 100)
		XCTAssertEqual(metrics.valueFor(attributes: attributes), 200)
	}

	// MARK: - ValueFor Tests

	func testValueForExistingAttributes() {
		var metrics = MetricValues<Int>()
		let attributes: TelemetryAttributes = ["status": "success"]

		metrics.add(42, attributes: attributes)

		XCTAssertEqual(metrics.valueFor(attributes: attributes), 42)
	}

	func testValueForNonExistentAttributes() {
		let metrics = MetricValues<Int>()
		let attributes: TelemetryAttributes = ["nonexistent": "key"]

		XCTAssertNil(metrics.valueFor(attributes: attributes))
	}

	func testValueForEmptyAttributes() {
		var metrics = MetricValues<Int>()

		metrics.add(123)

		XCTAssertEqual(metrics.valueFor(attributes: [:]), 123)
	}

	// MARK: - IsEmpty Tests

	func testIsEmptyInitialState() {
		let metrics = MetricValues<Int>()
		XCTAssertTrue(metrics.isEmpty)
	}

	func testIsEmptyAfterAddingValues() {
		var metrics = MetricValues<Int>()

		metrics.add(5)
		XCTAssertFalse(metrics.isEmpty)
	}

	func testIsEmptyAfterReset() {
		var metrics = MetricValues<Int>()

		metrics.add(10)
		XCTAssertFalse(metrics.isEmpty)

		metrics.reset()
		XCTAssertTrue(metrics.isEmpty)
	}

	func testIsEmptyWithZeroValues() {
		var metrics = MetricValues<Int>()
		let attributes1: TelemetryAttributes = ["key1": "value1"]
		let attributes2: TelemetryAttributes = ["key2": "value2"]

		metrics.set(0, attributes: attributes1)
		metrics.set(0, attributes: attributes2)

		XCTAssertTrue(metrics.isEmpty)
	}

	func testIsEmptyWithMixedZeroAndNonZeroValues() {
		var metrics = MetricValues<Int>()
		let attributes1: TelemetryAttributes = ["key1": "value1"]
		let attributes2: TelemetryAttributes = ["key2": "value2"]

		metrics.set(0, attributes: attributes1)
		metrics.set(5, attributes: attributes2)

		XCTAssertFalse(metrics.isEmpty)
	}

	func testIsEmptyWithDoubleZeroValues() {
		var metrics = MetricValues<Double>()

		metrics.set(0.0)
		metrics.add(0.0)

		XCTAssertTrue(metrics.isEmpty)
	}

	// MARK: - Complex Scenarios Tests

	func testMixedOperations() {
		var metrics = MetricValues<Int>()
		let attributes1: TelemetryAttributes = ["operation": "read"]
		let attributes2: TelemetryAttributes = ["operation": "write"]

		// Mix of add and set operations
		metrics.add(10, attributes: attributes1)
		metrics.set(20, attributes: attributes2)
		metrics.add(5, attributes: attributes1)

		XCTAssertEqual(metrics.valueFor(attributes: attributes1), 15)
		XCTAssertEqual(metrics.valueFor(attributes: attributes2), 20)
		XCTAssertFalse(metrics.isEmpty)
	}

	func testAttributeKeyTypes() {
		var metrics = MetricValues<Int>()

		// Test different attribute value types
		let stringAttr: TelemetryAttributes = ["string": "value"]
		let intAttr: TelemetryAttributes = ["int": 42]
		let doubleAttr: TelemetryAttributes = ["double": 3.14]
		let boolAttr: TelemetryAttributes = ["bool": true]

		metrics.add(1, attributes: stringAttr)
		metrics.add(2, attributes: intAttr)
		metrics.add(3, attributes: doubleAttr)
		metrics.add(4, attributes: boolAttr)

		XCTAssertEqual(metrics.valueFor(attributes: stringAttr), 1)
		XCTAssertEqual(metrics.valueFor(attributes: intAttr), 2)
		XCTAssertEqual(metrics.valueFor(attributes: doubleAttr), 3)
		XCTAssertEqual(metrics.valueFor(attributes: boolAttr), 4)
	}

	func testLargeNumberOfAttributes() {
		var metrics = MetricValues<Int>()

		// Test with many different attribute combinations
		for i in 0..<100 {
			let attributes: TelemetryAttributes = ["index": i]
			metrics.add(i, attributes: attributes)
		}

		for i in 0..<100 {
			let attributes: TelemetryAttributes = ["index": i]
			XCTAssertEqual(metrics.valueFor(attributes: attributes), i)
		}

		XCTAssertFalse(metrics.isEmpty)
		XCTAssertEqual(metrics.values.count, 100)
	}

	// MARK: - Edge Cases Tests

	func testAttributeEquality() {
		var metrics = MetricValues<Int>()

		// Test that attribute dictionaries with same content are treated as equal
		let attributes1: TelemetryAttributes = ["a": "1", "b": "2"]
		let attributes2: TelemetryAttributes = ["b": "2", "a": "1"] // Different order

		metrics.add(10, attributes: attributes1)
		metrics.add(5, attributes: attributes2)

		// Should accumulate since dictionaries are equal
		XCTAssertEqual(metrics.valueFor(attributes: attributes1), 15)
		XCTAssertEqual(metrics.valueFor(attributes: attributes2), 15)
	}

	func testEmptyAttributesDictionary() {
		var metrics = MetricValues<Int>()
		let emptyAttributes: TelemetryAttributes = [:]

		metrics.add(100, attributes: emptyAttributes)
		metrics.add(50) // Default empty attributes

		// Both should accumulate to the same entry
		XCTAssertEqual(metrics.valueFor(attributes: [:]), 150)
	}
}
