//
//  HistogramTests.swift
//
//
//  Created by Van Tol, Ladd on 12/15/21.
//

import Foundation
import XCTest

@testable import NautilusTelemetry

final class HistogramTests: XCTestCase {

	// MARK: - Initialization Tests

	func testInitialization() {
		let explicitBounds: [Int] = [0, 10, 50, 100]
		let histogram = Histogram<Int>(
			name: "test_histogram",
			unit: Unit(symbol: "milliseconds"),
			description: "Test histogram",
			explicitBounds: explicitBounds
		)

		XCTAssertEqual(histogram.name, "test_histogram")
		XCTAssertEqual(try XCTUnwrap(histogram.unit?.symbol), "milliseconds")
		XCTAssertEqual(histogram.description, "Test histogram")
		XCTAssertEqual(histogram.aggregationTemporality, .delta)
		XCTAssertTrue(histogram.isEmpty)
		XCTAssertNil(histogram.endTime)
		XCTAssertEqual(histogram.values.explicitBounds, explicitBounds)
	}

	func testInitializationWithNilValues() {
		let explicitBounds: [Int] = [1, 5, 10]
		let histogram = Histogram<Int>(name: "test_histogram", unit: nil, description: nil, explicitBounds: explicitBounds)

		XCTAssertEqual(histogram.name, "test_histogram")
		XCTAssertNil(histogram.unit)
		XCTAssertNil(histogram.description)
		XCTAssertTrue(histogram.isEmpty)
		XCTAssertEqual(histogram.values.explicitBounds, explicitBounds)
	}

	func testInitializationWithDoubleType() {
		let explicitBounds: [Double] = [0.1, 0.5, 1.0, 5.0]
		let histogram = Histogram<Double>(
			name: "double_histogram",
			unit: Unit(symbol: "seconds"),
			description: "Double histogram",
			explicitBounds: explicitBounds
		)

		XCTAssertEqual(histogram.name, "double_histogram")
		XCTAssertEqual(try XCTUnwrap(histogram.unit?.symbol), "seconds")
		XCTAssertTrue(histogram.isEmpty)
		XCTAssertEqual(histogram.values.explicitBounds, explicitBounds)
	}

	func testInitializationWithEmptyBounds() {
		let explicitBounds: [Int] = []
		let histogram = Histogram<Int>(name: "empty_bounds", unit: nil, description: nil, explicitBounds: explicitBounds)

		XCTAssertEqual(histogram.values.explicitBounds, explicitBounds)
		XCTAssertTrue(histogram.isEmpty)
	}

	// MARK: - Record Method Tests

	func testRecordWithEmptyAttributes() {
		let explicitBounds: [Int] = [10, 20, 50]
		let histogram = Histogram<Int>(name: "test_histogram", unit: nil, description: nil, explicitBounds: explicitBounds)

		histogram.record(5)
		XCTAssertFalse(histogram.isEmpty)

		histogram.record(15)
		histogram.record(25)

		XCTAssertFalse(histogram.isEmpty)
	}

	func testRecordWithAttributes() {
		let explicitBounds: [Int] = [10, 20, 50]
		let histogram = Histogram<Int>(name: "test_histogram", unit: nil, description: nil, explicitBounds: explicitBounds)
		let attributes1: TelemetryAttributes = ["endpoint": "/api/users"]
		let attributes2: TelemetryAttributes = ["endpoint": "/api/orders"]

		histogram.record(5, attributes: attributes1)
		histogram.record(15, attributes: attributes2)
		histogram.record(25, attributes: attributes1)

		XCTAssertFalse(histogram.isEmpty)
		XCTAssertEqual(histogram.values.values.count, 2) // Two different attribute sets
	}

	func testRecordWithDoubleValues() {
		let explicitBounds: [Double] = [0.5, 1.0, 2.0]
		let histogram = Histogram<Double>(name: "test_histogram", unit: nil, description: nil, explicitBounds: explicitBounds)

		histogram.record(0.3)
		histogram.record(0.7)
		histogram.record(1.5)

		XCTAssertFalse(histogram.isEmpty)
	}

	func testRecordZeroValue() {
		let explicitBounds: [Int] = [1, 5, 10]
		let histogram = Histogram<Int>(name: "test_histogram", unit: nil, description: nil, explicitBounds: explicitBounds)

		histogram.record(0)
		XCTAssertFalse(histogram.isEmpty) // Even zero values should make histogram non-empty
	}

	func testRecordLargeValues() {
		let explicitBounds: [Int] = [100, 1000, 10000]
		let histogram = Histogram<Int>(name: "test_histogram", unit: nil, description: nil, explicitBounds: explicitBounds)

		histogram.record(Int.max - 1)
		XCTAssertFalse(histogram.isEmpty)
	}

	// MARK: - IsEmpty Tests

	func testIsEmptyInitialState() {
		let explicitBounds: [Int] = [1, 5, 10]
		let histogram = Histogram<Int>(name: "test_histogram", unit: nil, description: nil, explicitBounds: explicitBounds)
		XCTAssertTrue(histogram.isEmpty)
	}

	func testIsEmptyAfterRecording() {
		let explicitBounds: [Int] = [1, 5, 10]
		let histogram = Histogram<Int>(name: "test_histogram", unit: nil, description: nil, explicitBounds: explicitBounds)

		histogram.record(3)
		XCTAssertFalse(histogram.isEmpty)
	}

	// MARK: - SnapshotAndReset Tests

	func testSnapshotAndReset() {
		let explicitBounds: [Int] = [10, 20, 50]
		let histogram = Histogram<Int>(
			name: "test_histogram",
			unit: Unit(symbol: "milliseconds"),
			description: "Test histogram",
			explicitBounds: explicitBounds
		)
		let attributes1: TelemetryAttributes = ["method": "GET"]
		let attributes2: TelemetryAttributes = ["method": "POST"]

		histogram.record(5, attributes: attributes1)
		histogram.record(15, attributes: attributes2)
		histogram.record(25, attributes: attributes1)

		let originalStartTime = histogram.startTime

		let snapshot = histogram.snapshotAndReset() as! Histogram<Int>

		// Original histogram should be reset
		XCTAssertTrue(histogram.isEmpty)
		XCTAssertNil(histogram.endTime)
		XCTAssertGreaterThan(histogram.startTime, originalStartTime)

		// Snapshot should contain the values
		XCTAssertEqual(snapshot.name, "test_histogram")
		XCTAssertEqual(try XCTUnwrap(snapshot.unit?.symbol), "milliseconds")
		XCTAssertEqual(snapshot.description, "Test histogram")
		XCTAssertEqual(snapshot.values.explicitBounds, explicitBounds)
		XCTAssertEqual(snapshot.startTime, originalStartTime)
		XCTAssertNotNil(snapshot.endTime)
		XCTAssertEqual(snapshot.aggregationTemporality, .delta)
		XCTAssertFalse(snapshot.isEmpty)
		XCTAssertEqual(snapshot.values.values.count, 2) // Two different attribute sets
	}

	func testSnapshotAndResetEmptyHistogram() {
		let explicitBounds: [Int] = [1, 5, 10]
		let histogram = Histogram<Int>(name: "test_histogram", unit: nil, description: nil, explicitBounds: explicitBounds)

		let snapshot = histogram.snapshotAndReset() as! Histogram<Int>

		XCTAssertTrue(histogram.isEmpty)
		XCTAssertTrue(snapshot.isEmpty)
		XCTAssertEqual(snapshot.name, "test_histogram")
		XCTAssertEqual(snapshot.values.explicitBounds, explicitBounds)
	}

	// MARK: - AggregationTemporality Tests

	func testAggregationTemporality() {
		let explicitBounds: [Int] = [1, 5, 10]
		let histogram = Histogram<Int>(name: "test_histogram", unit: nil, description: nil, explicitBounds: explicitBounds)

		XCTAssertEqual(histogram.aggregationTemporality, .delta)

		histogram.aggregationTemporality = .cumulative
		XCTAssertEqual(histogram.aggregationTemporality, .cumulative)

		histogram.aggregationTemporality = .unspecified
		XCTAssertEqual(histogram.aggregationTemporality, .unspecified)
	}

	// MARK: - Threading Safety Tests

	func testConcurrentRecordOperations() {
		let explicitBounds: [Int] = [10, 50, 100]
		let histogram = Histogram<Int>(name: "test_histogram", unit: nil, description: nil, explicitBounds: explicitBounds)
		let expectation = XCTestExpectation(description: "Concurrent operations")
		expectation.expectedFulfillmentCount = 10

		// Simulate concurrent record operations
		for i in 1...10 {
			DispatchQueue.global().async {
				histogram.record(i * 5) // Values: 5, 10, 15, ..., 50
				expectation.fulfill()
			}
		}

		wait(for: [expectation], timeout: 5.0)

		XCTAssertFalse(histogram.isEmpty)
	}

	// MARK: - Complex Scenarios Tests

	func testMultipleAttributeCombinations() {
		let explicitBounds: [Int] = [5, 15, 25]
		let histogram = Histogram<Int>(name: "test_histogram", unit: nil, description: nil, explicitBounds: explicitBounds)

		// Test with different attribute combinations
		for i in 0..<10 {
			let attributes: TelemetryAttributes = [
				"service": i % 2 == 0 ? "api" : "web",
				"status": i % 3 == 0 ? "success" : "error",
				"index": i,
			]
			histogram.record(i + 1, attributes: attributes)
		}

		XCTAssertFalse(histogram.isEmpty)
		XCTAssertEqual(histogram.values.values.count, 10) // Should have 10 unique attribute combinations
	}

	func testLargeNumberOfOperations() {
		let explicitBounds: [Int] = [10, 100, 1000]
		let histogram = Histogram<Int>(name: "test_histogram", unit: nil, description: nil, explicitBounds: explicitBounds)
		let attributes: TelemetryAttributes = ["load_test": "true"]

		// Record values many times
		for i in 1...100 {
			histogram.record(i, attributes: attributes)
		}

		XCTAssertFalse(histogram.isEmpty)
		XCTAssertEqual(histogram.values.values.count, 1) // Single attribute set
	}

	// MARK: - Bucket Distribution Tests

	func testRecordingIntoDifferentBuckets() {
		let explicitBounds: [Int] = [10, 50, 100]
		let histogram = Histogram<Int>(name: "test_histogram", unit: nil, description: nil, explicitBounds: explicitBounds)

		// Record values that will fall into different buckets
		histogram.record(5) // Bucket 0 (≤ 10)
		histogram.record(25) // Bucket 1 (≤ 50)
		histogram.record(75) // Bucket 2 (≤ 100)
		histogram.record(150) // Bucket 3 (> 100)

		XCTAssertFalse(histogram.isEmpty)

		// Verify that the histogram has recorded the values
		let buckets = histogram.values.values[[:]]!
		XCTAssertEqual(buckets.count, 4) // Should have recorded 4 values
		XCTAssertEqual(buckets.sum, 255) // 5 + 25 + 75 + 150
	}

	func testBucketBoundaryValues() {
		let explicitBounds: [Int] = [10, 20, 30]
		let histogram = Histogram<Int>(name: "test_histogram", unit: nil, description: nil, explicitBounds: explicitBounds)

		// Test values exactly on boundaries
		histogram.record(10) // Should go in first bucket (≤ 10)
		histogram.record(20) // Should go in second bucket (≤ 20)
		histogram.record(30) // Should go in third bucket (≤ 30)

		XCTAssertFalse(histogram.isEmpty)

		let buckets = histogram.values.values[[:]]!
		XCTAssertEqual(buckets.count, 3)
		XCTAssertEqual(buckets.sum, 60)
	}

	// MARK: - Time Management Tests

	func testStartTimeIsSet() {
		let explicitBounds: [Int] = [1, 5, 10]
		let histogram = Histogram<Int>(name: "test_histogram", unit: nil, description: nil, explicitBounds: explicitBounds)

		// Start time should be set during initialization
		XCTAssertLessThanOrEqual(histogram.startTime, ContinuousClock.now)
	}

	func testEndTimeIsNilInitially() {
		let explicitBounds: [Int] = [1, 5, 10]
		let histogram = Histogram<Int>(name: "test_histogram", unit: nil, description: nil, explicitBounds: explicitBounds)

		XCTAssertNil(histogram.endTime)
	}

	func testEndTimeSetAfterSnapshot() {
		let explicitBounds: [Int] = [1, 5, 10]
		let histogram = Histogram<Int>(name: "test_histogram", unit: nil, description: nil, explicitBounds: explicitBounds)
		histogram.record(3)

		let snapshot = histogram.snapshotAndReset() as! Histogram<Int>

		XCTAssertNotNil(snapshot.endTime)
		XCTAssertNil(histogram.endTime) // Original should have nil endTime after reset
	}

	// MARK: - Edge Cases Tests

	func testAttributeEquality() {
		let explicitBounds: [Int] = [10, 20]
		let histogram = Histogram<Int>(name: "test_histogram", unit: nil, description: nil, explicitBounds: explicitBounds)

		// Test that attribute dictionaries with same content are treated as equal
		let attributes1: TelemetryAttributes = ["a": "1", "b": "2"]
		let attributes2: TelemetryAttributes = ["b": "2", "a": "1"] // Different order

		histogram.record(5, attributes: attributes1)
		histogram.record(15, attributes: attributes2)

		// Should record to the same bucket set since dictionaries are equal
		XCTAssertEqual(histogram.values.values.count, 1)
		let buckets = histogram.values.values[attributes1]!
		XCTAssertEqual(buckets.count, 2) // Two recordings
		XCTAssertEqual(buckets.sum, 20) // 5 + 15
	}

	func testEmptyName() {
		let explicitBounds: [Int] = [1, 5, 10]
		let histogram = Histogram<Int>(name: "", unit: nil, description: nil, explicitBounds: explicitBounds)

		XCTAssertEqual(histogram.name, "")
		histogram.record(3)
		XCTAssertFalse(histogram.isEmpty)
	}

	func testUnsortedExplicitBounds() {
		// Test with unsorted bounds - the histogram should still work
		let explicitBounds: [Int] = [50, 10, 30, 20]
		let histogram = Histogram<Int>(name: "test_histogram", unit: nil, description: nil, explicitBounds: explicitBounds)

		histogram.record(15)
		histogram.record(25)
		histogram.record(35)

		XCTAssertFalse(histogram.isEmpty)
		XCTAssertEqual(histogram.values.explicitBounds, explicitBounds) // Should preserve original order
	}
}
