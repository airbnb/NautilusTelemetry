//
//  HistogramValuesTests.swift
//
//
//  Created by Van Tol, Ladd on 12/20/21.
//

import Foundation
import XCTest

@testable import NautilusTelemetry

final class HistogramValuesTests: XCTestCase {

	// MARK: - HistogramBuckets Tests

	func testHistogramBucketsInitialization() {
		let explicitBounds: [Int] = [10, 50, 100]
		let buckets = HistogramBuckets<Int>(explicitBounds: explicitBounds)

		XCTAssertEqual(buckets.explicitBounds, explicitBounds)
		XCTAssertEqual(buckets.count, 0)
		XCTAssertEqual(buckets.sum, 0)
		XCTAssertEqual(buckets.data.count, 4) // bounds.count + 1
		XCTAssertTrue(buckets.data.allSatisfy { $0 == 0 })
		XCTAssertTrue(buckets.isEmpty)
	}

	func testHistogramBucketsEmptyBounds() {
		let explicitBounds: [Int] = []
		let buckets = HistogramBuckets<Int>(explicitBounds: explicitBounds)

		XCTAssertEqual(buckets.explicitBounds, explicitBounds)
		XCTAssertEqual(buckets.data.count, 1) // Always at least one bucket for infinity
		XCTAssertTrue(buckets.isEmpty)
	}

	func testHistogramBucketsRecord() {
		let explicitBounds: [Int] = [10, 50, 100]
		var buckets = HistogramBuckets<Int>(explicitBounds: explicitBounds)

		buckets.record(5)

		XCTAssertEqual(buckets.count, 1)
		XCTAssertEqual(buckets.sum, 5)
		XCTAssertEqual(buckets.data[0], 1) // First bucket (≤ 10)
		XCTAssertEqual(buckets.data[1], 0)
		XCTAssertEqual(buckets.data[2], 0)
		XCTAssertEqual(buckets.data[3], 0)
		XCTAssertFalse(buckets.isEmpty)
	}

	func testHistogramBucketsRecordMultipleBuckets() {
		let explicitBounds: [Int] = [10, 50, 100]
		var buckets = HistogramBuckets<Int>(explicitBounds: explicitBounds)

		buckets.record(5) // Bucket 0 (≤ 10)
		buckets.record(25) // Bucket 1 (≤ 50)
		buckets.record(75) // Bucket 2 (≤ 100)
		buckets.record(150) // Bucket 3 (> 100)

		XCTAssertEqual(buckets.count, 4)
		XCTAssertEqual(buckets.sum, 255) // 5 + 25 + 75 + 150
		XCTAssertEqual(buckets.data[0], 1)
		XCTAssertEqual(buckets.data[1], 1)
		XCTAssertEqual(buckets.data[2], 1)
		XCTAssertEqual(buckets.data[3], 1)
		XCTAssertFalse(buckets.isEmpty)
	}

	func testHistogramBucketsRecordBoundaryValues() {
		let explicitBounds: [Int] = [10, 20, 30]
		var buckets = HistogramBuckets<Int>(explicitBounds: explicitBounds)

		buckets.record(10) // Exactly on boundary, should go in first bucket
		buckets.record(20) // Exactly on boundary, should go in second bucket
		buckets.record(30) // Exactly on boundary, should go in third bucket

		XCTAssertEqual(buckets.count, 3)
		XCTAssertEqual(buckets.sum, 60)
		XCTAssertEqual(buckets.data[0], 1)
		XCTAssertEqual(buckets.data[1], 1)
		XCTAssertEqual(buckets.data[2], 1)
		XCTAssertEqual(buckets.data[3], 0) // Nothing in infinity bucket
	}

	func testHistogramBucketsRecordAccumulation() {
		let explicitBounds: [Int] = [10, 20]
		var buckets = HistogramBuckets<Int>(explicitBounds: explicitBounds)

		buckets.record(5)
		buckets.record(3)
		buckets.record(7)

		XCTAssertEqual(buckets.count, 3)
		XCTAssertEqual(buckets.sum, 15) // 5 + 3 + 7
		XCTAssertEqual(buckets.data[0], 3) // All three values in first bucket
		XCTAssertEqual(buckets.data[1], 0)
		XCTAssertEqual(buckets.data[2], 0)
	}

	func testHistogramBucketsRecordWithDoubles() {
		let explicitBounds: [Double] = [1.0, 5.0, 10.0]
		var buckets = HistogramBuckets<Double>(explicitBounds: explicitBounds)

		buckets.record(0.5)
		buckets.record(3.2)
		buckets.record(7.8)
		buckets.record(15.5)

		XCTAssertEqual(buckets.count, 4)
		XCTAssertEqual(buckets.sum, 27.0, accuracy: 0.001)
		XCTAssertEqual(buckets.data[0], 1) // 0.5 ≤ 1.0
		XCTAssertEqual(buckets.data[1], 1) // 3.2 ≤ 5.0
		XCTAssertEqual(buckets.data[2], 1) // 7.8 ≤ 10.0
		XCTAssertEqual(buckets.data[3], 1) // 15.5 > 10.0
	}

	func testHistogramBucketsIsEmpty() {
		let explicitBounds: [Int] = [10, 20]
		var buckets = HistogramBuckets<Int>(explicitBounds: explicitBounds)

		XCTAssertTrue(buckets.isEmpty)

		buckets.record(5)
		XCTAssertFalse(buckets.isEmpty)
	}

	// MARK: - HistogramValues Tests

	func testHistogramValuesInitialization() {
		let explicitBounds: [Int] = [10, 50, 100]
		let histogramValues = HistogramValues<Int>(explicitBounds: explicitBounds)

		XCTAssertEqual(histogramValues.explicitBounds, explicitBounds)
		XCTAssertTrue(histogramValues.values.isEmpty)
		XCTAssertTrue(histogramValues.isEmpty)
	}

	func testHistogramValuesRecord() {
		let explicitBounds: [Int] = [10, 50, 100]
		var histogramValues = HistogramValues<Int>(explicitBounds: explicitBounds)

		histogramValues.record(25)
		XCTAssertFalse(histogramValues.isEmpty)
		XCTAssertEqual(histogramValues.values.count, 1)

		let buckets = histogramValues.values[[:]]!
		XCTAssertEqual(buckets.count, 1)
		XCTAssertEqual(buckets.sum, 25)
	}

	func testHistogramValuesRecordWithAttributes() {
		let explicitBounds: [Int] = [10, 50, 100]
		var histogramValues = HistogramValues<Int>(explicitBounds: explicitBounds)
		let attributes1: TelemetryAttributes = ["endpoint": "/api/users"]
		let attributes2: TelemetryAttributes = ["endpoint": "/api/orders"]

		histogramValues.record(15, attributes: attributes1)
		histogramValues.record(25, attributes: attributes2)
		histogramValues.record(35, attributes: attributes1)

		XCTAssertFalse(histogramValues.isEmpty)
		XCTAssertEqual(histogramValues.values.count, 2)

		let buckets1 = histogramValues.values[attributes1]!
		XCTAssertEqual(buckets1.count, 2) // Two recordings
		XCTAssertEqual(buckets1.sum, 50) // 15 + 35

		let buckets2 = histogramValues.values[attributes2]!
		XCTAssertEqual(buckets2.count, 1) // One recording
		XCTAssertEqual(buckets2.sum, 25) // 25
	}

	func testHistogramValuesRecordAccumulation() {
		let explicitBounds: [Int] = [10, 20]
		var histogramValues = HistogramValues<Int>(explicitBounds: explicitBounds)
		let attributes: TelemetryAttributes = ["service": "api"]

		histogramValues.record(5, attributes: attributes)
		histogramValues.record(15, attributes: attributes)
		histogramValues.record(25, attributes: attributes)

		XCTAssertEqual(histogramValues.values.count, 1)
		let buckets = histogramValues.values[attributes]!
		XCTAssertEqual(buckets.count, 3)
		XCTAssertEqual(buckets.sum, 45) // 5 + 15 + 25
		XCTAssertEqual(buckets.data[0], 1) // 5 ≤ 10
		XCTAssertEqual(buckets.data[1], 1) // 15 ≤ 20
		XCTAssertEqual(buckets.data[2], 1) // 25 > 20
	}

	func testHistogramValuesReset() {
		let explicitBounds: [Int] = [10, 50, 100]
		var histogramValues = HistogramValues<Int>(explicitBounds: explicitBounds)
		let attributes1: TelemetryAttributes = ["method": "GET"]
		let attributes2: TelemetryAttributes = ["method": "POST"]

		histogramValues.record(15, attributes: attributes1)
		histogramValues.record(25, attributes: attributes2)
		XCTAssertFalse(histogramValues.isEmpty)

		histogramValues.reset()

		XCTAssertTrue(histogramValues.values.isEmpty)
		XCTAssertTrue(histogramValues.isEmpty)
	}

	func testHistogramValuesResetEmptyValues() {
		let explicitBounds: [Int] = [10, 50, 100]
		var histogramValues = HistogramValues<Int>(explicitBounds: explicitBounds)

		histogramValues.reset()

		XCTAssertTrue(histogramValues.values.isEmpty)
		XCTAssertTrue(histogramValues.isEmpty)
	}

	func testHistogramValuesSnapshotAndReset() {
		let explicitBounds: [Int] = [10, 50, 100]
		var histogramValues = HistogramValues<Int>(explicitBounds: explicitBounds)
		let attributes1: TelemetryAttributes = ["method": "GET"]
		let attributes2: TelemetryAttributes = ["method": "POST"]

		histogramValues.record(15, attributes: attributes1)
		histogramValues.record(25, attributes: attributes2)

		let snapshot = histogramValues.snapshotAndReset()

		// Original should be empty
		XCTAssertTrue(histogramValues.values.isEmpty)
		XCTAssertTrue(histogramValues.isEmpty)

		// Snapshot should contain the values
		XCTAssertEqual(snapshot.explicitBounds, explicitBounds)
		XCTAssertEqual(snapshot.values.count, 2)
		XCTAssertFalse(snapshot.isEmpty)

		let buckets1 = snapshot.values[attributes1]!
		XCTAssertEqual(buckets1.count, 1)
		XCTAssertEqual(buckets1.sum, 15)

		let buckets2 = snapshot.values[attributes2]!
		XCTAssertEqual(buckets2.count, 1)
		XCTAssertEqual(buckets2.sum, 25)
	}

	func testHistogramValuesSnapshotAndResetEmpty() {
		let explicitBounds: [Int] = [10, 50, 100]
		var histogramValues = HistogramValues<Int>(explicitBounds: explicitBounds)

		let snapshot = histogramValues.snapshotAndReset()

		XCTAssertTrue(histogramValues.values.isEmpty)
		XCTAssertTrue(histogramValues.isEmpty)
		XCTAssertTrue(snapshot.values.isEmpty)
		XCTAssertTrue(snapshot.isEmpty)
		XCTAssertEqual(snapshot.explicitBounds, explicitBounds)
	}

	func testHistogramValuesSnapshotAndResetIndependence() {
		let explicitBounds: [Int] = [10, 50, 100]
		var histogramValues = HistogramValues<Int>(explicitBounds: explicitBounds)
		let attributes: TelemetryAttributes = ["test": "independence"]

		histogramValues.record(25, attributes: attributes)
		let snapshot = histogramValues.snapshotAndReset()

		// Modify original after snapshot
		histogramValues.record(35, attributes: attributes)

		// Snapshot should be unchanged
		let snapshotBuckets = snapshot.values[attributes]!
		XCTAssertEqual(snapshotBuckets.count, 1)
		XCTAssertEqual(snapshotBuckets.sum, 25)

		// Original should have new data
		let originalBuckets = histogramValues.values[attributes]!
		XCTAssertEqual(originalBuckets.count, 1)
		XCTAssertEqual(originalBuckets.sum, 35)
	}

	func testHistogramValuesIsEmpty() {
		let explicitBounds: [Int] = [10, 50, 100]
		var histogramValues = HistogramValues<Int>(explicitBounds: explicitBounds)

		XCTAssertTrue(histogramValues.isEmpty)

		histogramValues.record(25)
		XCTAssertFalse(histogramValues.isEmpty)

		histogramValues.reset()
		XCTAssertTrue(histogramValues.isEmpty)
	}

	func testHistogramValuesIsEmptyWithEmptyBuckets() {
		let explicitBounds: [Int] = [10, 50, 100]
		var histogramValues = HistogramValues<Int>(explicitBounds: explicitBounds)

		// Create empty bucket entries (shouldn't normally happen, but test edge case)
		histogramValues.values[[:]] = HistogramBuckets<Int>(explicitBounds: explicitBounds)

		// Should still be considered empty since buckets are empty
		XCTAssertTrue(histogramValues.isEmpty)
	}

	// MARK: - Complex Scenarios Tests

	func testMultipleAttributeCombinations() {
		let explicitBounds: [Int] = [5, 15, 25]
		var histogramValues = HistogramValues<Int>(explicitBounds: explicitBounds)

		// Test with different attribute combinations
		for i in 0..<10 {
			let attributes: TelemetryAttributes = [
				"service": i % 2 == 0 ? "api" : "web",
				"status": i % 3 == 0 ? "success" : "error",
				"index": i,
			]
			histogramValues.record(i + 1, attributes: attributes)
		}

		XCTAssertFalse(histogramValues.isEmpty)
		XCTAssertEqual(histogramValues.values.count, 10) // Should have 10 unique attribute combinations
	}

	func testLargeNumberOfRecordings() {
		let explicitBounds: [Int] = [100, 500, 1000]
		var histogramValues = HistogramValues<Int>(explicitBounds: explicitBounds)
		let attributes: TelemetryAttributes = ["load_test": "true"]

		// Record many values
		for i in 1...1000 {
			histogramValues.record(i, attributes: attributes)
		}

		XCTAssertFalse(histogramValues.isEmpty)
		XCTAssertEqual(histogramValues.values.count, 1) // Single attribute set

		let buckets = histogramValues.values[attributes]!
		XCTAssertEqual(buckets.count, 1000)
		XCTAssertEqual(buckets.sum, 500500) // Sum of 1 to 1000 = n(n+1)/2
	}

	func testBucketDistribution() {
		let explicitBounds: [Int] = [10, 20, 30]
		var histogramValues = HistogramValues<Int>(explicitBounds: explicitBounds)

		// Record specific values to test bucket distribution
		let valuesToRecord = [5, 8, 15, 18, 25, 28, 35, 40] // Mix across all buckets
		for value in valuesToRecord {
			histogramValues.record(value)
		}

		let buckets = histogramValues.values[[:]]!
		XCTAssertEqual(buckets.count, 8)
		XCTAssertEqual(buckets.sum, 174) // Sum of all values

		// Check bucket distribution:
		// Bucket 0 (≤ 10): 5, 8 = 2 values
		// Bucket 1 (≤ 20): 15, 18 = 2 values
		// Bucket 2 (≤ 30): 25, 28 = 2 values
		// Bucket 3 (> 30): 35, 40 = 2 values
		XCTAssertEqual(buckets.data[0], 2)
		XCTAssertEqual(buckets.data[1], 2)
		XCTAssertEqual(buckets.data[2], 2)
		XCTAssertEqual(buckets.data[3], 2)
	}

	// MARK: - Edge Cases Tests

	func testAttributeEquality() {
		let explicitBounds: [Int] = [10, 20]
		var histogramValues = HistogramValues<Int>(explicitBounds: explicitBounds)

		// Test that attribute dictionaries with same content are treated as equal
		let attributes1: TelemetryAttributes = ["a": "1", "b": "2"]
		let attributes2: TelemetryAttributes = ["b": "2", "a": "1"] // Different order

		histogramValues.record(5, attributes: attributes1)
		histogramValues.record(15, attributes: attributes2)

		// Should accumulate to same bucket set since dictionaries are equal
		XCTAssertEqual(histogramValues.values.count, 1)
		let buckets = histogramValues.values[attributes1]!
		XCTAssertEqual(buckets.count, 2) // Two recordings
		XCTAssertEqual(buckets.sum, 20) // 5 + 15
	}

	func testEmptyAttributesDictionary() {
		let explicitBounds: [Int] = [10, 20]
		var histogramValues = HistogramValues<Int>(explicitBounds: explicitBounds)
		let emptyAttributes: TelemetryAttributes = [:]

		histogramValues.record(15, attributes: emptyAttributes)
		histogramValues.record(25) // Default empty attributes

		// Both should accumulate to the same bucket set
		XCTAssertEqual(histogramValues.values.count, 1)
		let buckets = histogramValues.values[[:]]!
		XCTAssertEqual(buckets.count, 2)
		XCTAssertEqual(buckets.sum, 40) // 15 + 25
	}

	func testSingleBoundValue() {
		let explicitBounds = [50]
		var histogramValues = HistogramValues<Int>(explicitBounds: explicitBounds)

		histogramValues.record(25) // ≤ 50
		histogramValues.record(75) // > 50

		let buckets = histogramValues.values[[:]]!
		XCTAssertEqual(buckets.count, 2)
		XCTAssertEqual(buckets.sum, 100)
		XCTAssertEqual(buckets.data[0], 1) // ≤ 50
		XCTAssertEqual(buckets.data[1], 1) // > 50
	}

	func testZeroValues() {
		let explicitBounds: [Int] = [0, 10, 20]
		var histogramValues = HistogramValues<Int>(explicitBounds: explicitBounds)

		histogramValues.record(0)

		let buckets = histogramValues.values[[:]]!
		XCTAssertEqual(buckets.count, 1)
		XCTAssertEqual(buckets.sum, 0)
		XCTAssertEqual(buckets.data[0], 1) // 0 ≤ 0, should go in first bucket
		XCTAssertFalse(histogramValues.isEmpty) // Even zero values should make it non-empty
	}
}
