//
//  BucketedMeasurementTests.swift
//
//
//  Created by Ladd Van Tol on 8/5/26.
//

import Foundation
import Testing

@testable import NautilusTelemetry

@Suite
struct BucketedMeasurementTests {

	// MARK: - BucketedMeasurement

	@Test
	func explicitValue() {
		let measurement = BucketedMeasurement(value: 42, count: 7)

		#expect(measurement.value == 42)
		#expect(measurement.count == 7)
	}

	@Test
	func boundsRecordAtMidpoint() throws {
		#expect(try #require(BucketedMeasurement(lowerBound: 10, upperBound: 20, count: 1)).value == 15)
		#expect(try #require(BucketedMeasurement<Double>(lowerBound: 1.0, upperBound: 2.0, count: 1)).value == 1.5)

		// Truncating midpoint
		#expect(try #require(BucketedMeasurement(lowerBound: 10, upperBound: 21, count: 1)).value == 15)

		// Degenerate bucket
		#expect(try #require(BucketedMeasurement(lowerBound: 10, upperBound: 10, count: 1)).value == 10)
	}

	@Test
	func midpointDoesNotOverflowOnAWideBucket() throws {
		let measurement = try #require(BucketedMeasurement(lowerBound: 0, upperBound: Int.max, count: 1))

		#expect(measurement.value == Int.max / 2)
	}

	// MARK: - Guards against unusable external bounds

	// Rejection asserts, so the guards are verified by trapping in a child process rather than by observing
	// the return value, which only a build with assertions disabled would see. Matches `TimeReferenceTests`.
	#if os(macOS)
	@Test("Reversed bounds trap")
	func reversedBoundsTrap() async {
		// Reversed bounds would trap at the call site if they were formed into a ClosedRange, which is why
		// they are separate parameters.
		_ = await #expect(processExitsWith: .failure) {
			_ = BucketedMeasurement<Double>(lowerBound: 3.0, upperBound: 1.0, count: 1)
		}

		_ = await #expect(processExitsWith: .failure) {
			_ = BucketedMeasurement<Int>(lowerBound: 20, upperBound: 10, count: 1)
		}
	}

	@Test("Non-finite bounds trap")
	func nonFiniteBoundsTrap() async {
		_ = await #expect(processExitsWith: .failure) {
			_ = BucketedMeasurement<Double>(lowerBound: 0.0, upperBound: .nan, count: 1)
		}

		_ = await #expect(processExitsWith: .failure) {
			_ = BucketedMeasurement<Double>(lowerBound: .nan, upperBound: 1.0, count: 1)
		}

		_ = await #expect(processExitsWith: .failure) {
			_ = BucketedMeasurement<Double>(lowerBound: 0.0, upperBound: .infinity, count: 1)
		}
	}

	@Test("Negative bounds trap")
	func negativeBoundsTrap() async {
		// A histogram cannot represent a negative value.
		_ = await #expect(processExitsWith: .failure) {
			_ = BucketedMeasurement<Double>(lowerBound: -2.0, upperBound: -1.0, count: 1)
		}

		_ = await #expect(processExitsWith: .failure) {
			_ = BucketedMeasurement<Double>(lowerBound: -1.0, upperBound: 5.0, count: 1)
		}

		_ = await #expect(processExitsWith: .failure) {
			_ = BucketedMeasurement<Int>(lowerBound: -10, upperBound: -5, count: 1)
		}
	}

	@Test("Recording an unusable value traps")
	func unusableRecordedValueTraps() async {
		_ = await #expect(processExitsWith: .failure) {
			let histogram = Histogram<Double>(name: "test", unit: nil, description: nil, explicitBounds: [10.0])
			histogram.record([BucketedMeasurement(value: .nan, count: 5)])
		}

		_ = await #expect(processExitsWith: .failure) {
			let histogram = Histogram<Double>(name: "test", unit: nil, description: nil, explicitBounds: [10.0])
			histogram.record([BucketedMeasurement(value: -1.0, count: 5)])
		}
	}
	#endif

	@Test
	func zeroLowerBoundIsAccepted() throws {
		// Zero is a legitimate bucket floor, and is distinct from the negative case.
		#expect(try #require(BucketedMeasurement<Double>(lowerBound: 0.0, upperBound: 4.0, count: 1)).value == 2.0)
		#expect(try #require(BucketedMeasurement(lowerBound: 0, upperBound: 0, count: 1)).value == 0)
	}

	@Test
	func guardedInitPreservesCount() throws {
		// A zero count is not a reason to reject; the histogram skips it at record time.
		#expect(try #require(BucketedMeasurement(lowerBound: 1.0, upperBound: 2.0, count: 0)).count == 0)
		#expect(try #require(BucketedMeasurement(lowerBound: 1.0, upperBound: 2.0, count: 99)).count == 99)
	}

	// MARK: - Histogram.record(_ measurements:)

	@Test
	func recordBucketedMeasurements() throws {
		let histogram = Histogram<Int>(name: "test", unit: nil, description: nil, explicitBounds: [10, 20, 30])

		histogram.record([
			BucketedMeasurement(value: 5, count: 3),
			BucketedMeasurement(value: 15, count: 2),
			BucketedMeasurement(value: 100, count: 1),
		])

		let buckets = try #require(histogram.values.values[[:]])
		#expect(buckets.count == 6)
		#expect(buckets.sum == 3 * 5 + 2 * 15 + 100)
		#expect(buckets.data == [3, 2, 0, 1])
	}

	@Test
	func recordBucketedMeasurementsFromBounds() throws {
		// Shaped like a MetricKit MXHistogram, with buckets lined up against the destination bounds.
		let bounds: [Double] = [0.5, 1.0, 2.0]
		let histogram = Histogram<Double>(name: "hang_time", unit: nil, description: nil, explicitBounds: bounds)

		histogram.record([
			BucketedMeasurement(lowerBound: 0.0, upperBound: 0.5, count: 12),
			BucketedMeasurement(lowerBound: 0.5, upperBound: 1.0, count: 4),
			BucketedMeasurement(lowerBound: 1.0, upperBound: 2.0, count: 2),
			BucketedMeasurement(lowerBound: 2.0, upperBound: 10.0, count: 1),
		].compactMap { $0 })

		let buckets = try #require(histogram.values.values[[:]])
		#expect(buckets.count == 19)

		// Midpoints 0.25, 0.75 and 1.5 land in the bucket their source bucket lines up with, and 6.0 overflows.
		#expect(buckets.data == [12, 4, 2, 1])

		let expectedSum = 12 * 0.25 + 4 * 0.75 + 2 * 1.5 + 1 * 6.0
		#expect(abs(buckets.sum - expectedSum) < 0.0001)
	}

	/// The midpoint is the mean of a uniformly distributed bucket, so `sum` matches what the individual
	/// observations would have produced. Recording at the upper bound overstates it.
	@Test
	func midpointKeepsSumUnbiased() throws {
		let bounds: [Double] = [10.0, 20.0, 30.0]
		let observations: [Double] = [2.0, 4.0, 6.0, 8.0, 12.0, 14.0, 16.0, 18.0]

		let individual = Histogram<Double>(name: "individual", unit: nil, description: nil, explicitBounds: bounds)
		for observation in observations {
			individual.record(observation)
		}

		// The same observations handed over pre-bucketed, uniformly spread across two buckets.
		let bucketed = Histogram<Double>(name: "bucketed", unit: nil, description: nil, explicitBounds: bounds)
		bucketed.record([
			BucketedMeasurement(lowerBound: 0.0, upperBound: 10.0, count: 4),
			BucketedMeasurement(lowerBound: 10.0, upperBound: 20.0, count: 4),
		].compactMap { $0 })

		let individualBuckets = try #require(individual.values.values[[:]])
		let bucketedBuckets = try #require(bucketed.values.values[[:]])

		#expect(individualBuckets.data == bucketedBuckets.data)
		#expect(abs(individualBuckets.sum - bucketedBuckets.sum) < 0.0001)
	}

	@Test
	func recordBucketedMeasurementsAccumulatesWithSingleRecords() throws {
		let histogram = Histogram<Int>(name: "test", unit: nil, description: nil, explicitBounds: [10, 20])

		histogram.record(5)
		histogram.record([BucketedMeasurement(value: 5, count: 2)])
		histogram.record(15)

		let buckets = try #require(histogram.values.values[[:]])
		#expect(buckets.count == 4)
		#expect(buckets.sum == 5 + 10 + 15)
		#expect(buckets.data == [3, 1, 0])
	}

	@Test
	func recordBucketedMeasurementsWithAttributes() throws {
		let histogram = Histogram<Int>(name: "test", unit: nil, description: nil, explicitBounds: [10, 20])
		let getAttributes: TelemetryAttributes = ["method": "GET"]
		let postAttributes: TelemetryAttributes = ["method": "POST"]

		histogram.record([BucketedMeasurement(value: 5, count: 2)], attributes: getAttributes)
		histogram.record([BucketedMeasurement(value: 15, count: 3)], attributes: postAttributes)

		#expect(histogram.values.values.count == 2)
		#expect(try #require(histogram.values.values[getAttributes]).count == 2)
		#expect(try #require(histogram.values.values[postAttributes]).count == 3)
	}

	@Test
	func recordEmptyMeasurementsLeavesHistogramEmpty() {
		let histogram = Histogram<Int>(name: "test", unit: nil, description: nil, explicitBounds: [10, 20])

		histogram.record([BucketedMeasurement<Int>]())
		#expect(histogram.isEmpty)
		#expect(histogram.values.values.isEmpty)
	}

	@Test
	func recordZeroCountMeasurementsLeavesHistogramEmpty() {
		// MetricKit payloads routinely include buckets with no observations.
		let histogram = Histogram<Int>(name: "test", unit: nil, description: nil, explicitBounds: [10, 20])

		histogram.record([
			BucketedMeasurement(value: 5, count: 0),
			BucketedMeasurement(value: 15, count: 0),
		])

		#expect(histogram.isEmpty)
		#expect(histogram.values.values.isEmpty)
	}

	@Test
	func recordSkipsZeroCountEntriesWithinABatch() throws {
		let histogram = Histogram<Int>(name: "test", unit: nil, description: nil, explicitBounds: [10, 20])

		histogram.record([
			BucketedMeasurement(value: 5, count: 0),
			BucketedMeasurement(value: 15, count: 4),
		])

		let buckets = try #require(histogram.values.values[[:]])
		#expect(buckets.count == 4)
		#expect(buckets.data == [0, 4, 0])
	}

	// MARK: - Histogram.record(_:count:)

	@Test
	func recordWithCount() throws {
		let histogram = Histogram<Int>(name: "test", unit: nil, description: nil, explicitBounds: [10, 20])

		histogram.record(15, count: 4)

		let buckets = try #require(histogram.values.values[[:]])
		#expect(buckets.count == 4)
		#expect(buckets.sum == 60)
		#expect(buckets.data == [0, 4, 0])
	}

	@Test
	func recordWithZeroCountRecordsNothing() {
		let histogram = Histogram<Int>(name: "test", unit: nil, description: nil, explicitBounds: [10, 20])

		histogram.record(15, count: 0)

		#expect(histogram.isEmpty)
		#expect(histogram.values.values.isEmpty)
	}

	@Test
	func recordWithCountMatchesRepeatedSingleRecords() throws {
		let bounds: [Double] = [1.0, 5.0, 10.0]
		let bulk = Histogram<Double>(name: "bulk", unit: nil, description: nil, explicitBounds: bounds)
		let individual = Histogram<Double>(name: "individual", unit: nil, description: nil, explicitBounds: bounds)

		bulk.record(2.5, count: 100)
		for _ in 0..<100 {
			individual.record(2.5)
		}

		let bulkBuckets = try #require(bulk.values.values[[:]])
		let individualBuckets = try #require(individual.values.values[[:]])

		#expect(bulkBuckets.count == individualBuckets.count)
		#expect(bulkBuckets.data == individualBuckets.data)
		#expect(abs(bulkBuckets.sum - individualBuckets.sum) < 0.0001)
	}

	// MARK: - Snapshot

	@Test
	func snapshotAndResetAfterBulkRecord() throws {
		let histogram = Histogram<Int>(name: "test", unit: nil, description: nil, explicitBounds: [10, 20])

		histogram.record([BucketedMeasurement(value: 5, count: 3)])

		let snapshot = try #require(histogram.snapshotAndReset() as? Histogram<Int>)

		#expect(histogram.isEmpty)

		let buckets = try #require(snapshot.values.values[[:]])
		#expect(buckets.count == 3)
		#expect(buckets.sum == 15)
	}

	// MARK: - HistogramBuckets

	@Test
	func bucketsRecordWithCountLandsInOverflowBucket() {
		var buckets = HistogramBuckets<Int>(explicitBounds: [10, 20])

		buckets.record(100, count: 5)

		#expect(buckets.count == 5)
		#expect(buckets.sum == 500)
		#expect(buckets.data == [0, 0, 5])
	}

	@Test
	func bucketsRecordWithCountOnBoundary() {
		var buckets = HistogramBuckets<Int>(explicitBounds: [10, 20])

		buckets.record(10, count: 2)
		buckets.record(20, count: 3)

		#expect(buckets.count == 5)
		#expect(buckets.data == [2, 3, 0])
	}

	@Test
	func bucketsRecordWithEmptyBounds() {
		var buckets = HistogramBuckets<Int>(explicitBounds: [])

		buckets.record(7, count: 3)

		#expect(buckets.count == 3)
		#expect(buckets.sum == 21)
		#expect(buckets.data == [3])
	}
}
