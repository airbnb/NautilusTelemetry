//
//  ExponentialHistogramTests.swift
//
//
//  Created by Ladd Van Tol on 2026-04-17.
//

import Foundation
import XCTest

@testable import NautilusTelemetry

final class ExponentialHistogramTests: XCTestCase {

	// MARK: - bucketIndex

	/// At scale 0, base = 2. Bucket `i` covers (2^i, 2^(i+1)].
	/// Powers of two fall at the upper (inclusive) bound, so index(2^k) = k - 1.
	func testBucketIndexScaleZero() {
		XCTAssertEqual(ExponentialHistogramUtils.bucketIndex(value: 1.0, scale: 0), -1) // 1 == 2^0, upper of bucket -1
		XCTAssertEqual(ExponentialHistogramUtils.bucketIndex(value: 1.5, scale: 0), 0) // in (1, 2]
		XCTAssertEqual(ExponentialHistogramUtils.bucketIndex(value: 2.0, scale: 0), 0) // 2 == 2^1, upper of bucket 0
		XCTAssertEqual(ExponentialHistogramUtils.bucketIndex(value: 3.0, scale: 0), 1) // in (2, 4]
		XCTAssertEqual(ExponentialHistogramUtils.bucketIndex(value: 4.0, scale: 0), 1) // 4 == 2^2, upper of bucket 1
		XCTAssertEqual(ExponentialHistogramUtils.bucketIndex(value: 1024.0, scale: 0), 9) // 2^10 -> bucket 9
	}

	/// At scale 1, base = sqrt(2). There are 2 buckets per power of two.
	func testBucketIndexScaleOne() {
		XCTAssertEqual(ExponentialHistogramUtils.bucketIndex(value: 2.0, scale: 1), 1) // 2 == base^2, upper of bucket 1
		XCTAssertEqual(ExponentialHistogramUtils.bucketIndex(value: 4.0, scale: 1), 3) // 4 == base^4, upper of bucket 3
	}

	/// At scale -1, base = 4. One bucket covers every two powers of two.
	func testBucketIndexNegativeScale() {
		XCTAssertEqual(ExponentialHistogramUtils.bucketIndex(value: 4.0, scale: -1), 0) // 4 == base^1, upper of bucket 0
		XCTAssertEqual(ExponentialHistogramUtils.bucketIndex(value: 16.0, scale: -1), 1) // 16 == base^2, upper of bucket 1
	}

	// MARK: - chooseScale

	func testChooseScaleSelectsMaxWhenAllEqual() {
		// All values identical => every scale fits; implementation should pick the max.
		let scale = ExponentialHistogramUtils.chooseScale(
			positiveMagnitudes: [5.0, 5.0, 5.0],
			negativeMagnitudes: [],
			bucketCount: 160
		)
		XCTAssertEqual(scale, ExponentialHistogramUtils.maxScale)
	}

	func testChooseScaleFitsWideRange() {
		// Range of ~20 powers of two (1e-3 to 1e3). With 160 buckets, log2 span ≈ 20,
		// so max scale is floor(log2(159/20)) ≈ 2.
		let values = [0.001, 0.1, 1.0, 100.0, 1000.0]
		let scale = ExponentialHistogramUtils.chooseScale(
			positiveMagnitudes: values,
			negativeMagnitudes: [],
			bucketCount: 160
		)
		XCTAssertTrue(scale >= 0, "should pick a non-negative scale for this range")
		XCTAssertTrue(indexSpan(values, scale: scale) <= 160)
		// And scale+1 should not fit (it's the maximum).
		if scale < ExponentialHistogramUtils.maxScale {
			XCTAssertGreaterThan(indexSpan(values, scale: scale + 1), 160)
		}
	}

	func testChooseScaleEmptyDataUsesDefault() {
		let scale = ExponentialHistogramUtils.chooseScale(positiveMagnitudes: [], negativeMagnitudes: [], bucketCount: 160)
		XCTAssertEqual(scale, 0)
	}

	func testChooseScaleConsidersBothSigns() {
		// Positive side is tight (3..4), negative side is wide (1e-3..1e3).
		// The chosen scale must satisfy both.
		let scale = ExponentialHistogramUtils.chooseScale(
			positiveMagnitudes: [3.0, 4.0],
			negativeMagnitudes: [0.001, 1000.0],
			bucketCount: 160
		)
		XCTAssertTrue(indexSpan([3.0, 4.0], scale: scale) <= 160)
		XCTAssertTrue(indexSpan([0.001, 1000.0], scale: scale) <= 160)
	}

	/// Count of contiguous buckets spanned by `magnitudes` at `scale`, computed from `bucketIndex`.
	private func indexSpan(_ magnitudes: [Double], scale: Int) -> Int {
		guard !magnitudes.isEmpty else { return 0 }
		var minIdx = Int.max
		var maxIdx = Int.min
		for m in magnitudes {
			let i = ExponentialHistogramUtils.bucketIndex(value: m, scale: scale)
			if i < minIdx { minIdx = i }
			if i > maxIdx { maxIdx = i }
		}
		return maxIdx - minIdx + 1
	}

	// MARK: - mapToExponentialBuckets

	func testMapPositiveValues() {
		let mapping = ExponentialHistogramUtils.mapToExponentialBuckets(
			values: [1.5, 1.5, 3.0, 3.0, 3.0],
			maxBuckets: 160
		)

		XCTAssertEqual(mapping.zeroCount, 0)
		XCTAssertEqual(mapping.negative.bucketCounts ?? [], [])

		let positive = mapping.positive
		let counts = try! XCTUnwrap(positive.bucketCounts)
		XCTAssertEqual(counts.reduce(0, +), 5)

		// All values should bucketize at the chosen scale; offset points to the lowest bucket.
		let offset = try! XCTUnwrap(positive.offset)
		let indexFor15 = ExponentialHistogramUtils.bucketIndex(value: 1.5, scale: mapping.scale)
		let indexFor3 = ExponentialHistogramUtils.bucketIndex(value: 3.0, scale: mapping.scale)
		XCTAssertEqual(counts[indexFor15 - offset], 2)
		XCTAssertEqual(counts[indexFor3 - offset], 3)
	}

	func testMapNegativeValuesAndZeros() {
		let mapping = ExponentialHistogramUtils.mapToExponentialBuckets(
			values: [-1.5, -3.0, 0.0, 0.0],
			maxBuckets: 160
		)

		XCTAssertEqual(mapping.zeroCount, 2)
		XCTAssertEqual(mapping.positive.bucketCounts ?? [], [])

		let negative = mapping.negative
		let counts = try! XCTUnwrap(negative.bucketCounts)
		XCTAssertEqual(counts.reduce(0, +), 2)
	}

	func testMapRoundTripCountConservation() {
		let values: [Double] = [0.5, 1.0, 2.0, 4.0, 8.0, 16.0, 0.0, -1.0, -2.0]
		let mapping = ExponentialHistogramUtils.mapToExponentialBuckets(values: values, maxBuckets: 160)

		let positiveSum = mapping.positive.bucketCounts?.reduce(0, +) ?? 0
		let negativeSum = mapping.negative.bucketCounts?.reduce(0, +) ?? 0
		XCTAssertEqual(UInt64(values.count), positiveSum + negativeSum + mapping.zeroCount)
	}

	func testMapEmpty() {
		let mapping = ExponentialHistogramUtils.mapToExponentialBuckets(values: [], maxBuckets: 160)
		XCTAssertEqual(mapping.zeroCount, 0)
		XCTAssertNil(mapping.positive.bucketCounts)
		XCTAssertNil(mapping.negative.bucketCounts)
	}

	func testMapSingleValueMaxScale() {
		let mapping = ExponentialHistogramUtils.mapToExponentialBuckets(values: [42.0], maxBuckets: 160)
		// Single value always fits at max scale.
		XCTAssertEqual(mapping.scale, ExponentialHistogramUtils.maxScale)
		XCTAssertEqual(mapping.positive.bucketCounts, [1])
	}

	// MARK: - ExponentialHistogram end-to-end

	func testRecordAndSnapshot() {
		let histogram = ExponentialHistogram<Double>(name: "Test", unit: nil, description: nil)
		histogram.record(1.0)
		histogram.record(2.0)
		histogram.record(4.0)

		let snapshot = histogram.snapshotAndReset() as! ExponentialHistogram<Double>
		XCTAssertTrue(histogram.isEmpty)
		XCTAssertFalse(snapshot.isEmpty)

		let buckets = snapshot.values.values[[:]]
		XCTAssertEqual(buckets?.count, 3)
		XCTAssertEqual(buckets?.sum, 7.0)
		XCTAssertEqual(buckets?.minValue, 1.0)
		XCTAssertEqual(buckets?.maxValue, 4.0)
	}

	func testExportProducesValidOTLP() throws {
		let histogram = ExponentialHistogram<Double>(
			name: "LatencyHist",
			unit: Unit(symbol: "ms"),
			description: "Request latency"
		)
		// Spread values across ~3 orders of magnitude.
		for v in [0.5, 1.0, 10.0, 50.0, 100.0, 500.0] {
			histogram.record(v)
		}

		let timeReference = TimeReference(serverOffset: 0)
		let exporter = Exporter(timeReference: timeReference)

		let snapshot = histogram.snapshotAndReset() as! ExponentialHistogram<Double>
		let metric = exporter.exportOTLP(histogram: snapshot)

		let expHist = try XCTUnwrap(metric.exponentialHistogram)
		let dataPoints = try XCTUnwrap(expHist.dataPoints)
		XCTAssertEqual(dataPoints.count, 1)

		let dp = dataPoints[0]
		XCTAssertEqual(dp.count, 6)
		XCTAssertEqual(dp.sum, 661.5)
		XCTAssertEqual(dp.min, 0.5)
		XCTAssertEqual(dp.max, 500.0)
		XCTAssertEqual(dp.zeroCount, 0)

		let positive = try XCTUnwrap(dp.positive)
		let counts = try XCTUnwrap(positive.bucketCounts)
		XCTAssertEqual(counts.reduce(0, +), 6)
		// Indices must fit in the fixed bucket window.
		XCTAssertLessThanOrEqual(counts.count, ExponentialHistogramUtils.defaultMaxBucketCount)
	}

	func testExportHandlesMixedSigns() throws {
		let histogram = ExponentialHistogram<Double>(name: "Mixed", unit: nil, description: nil)
		histogram.record(-5.0)
		histogram.record(-10.0)
		histogram.record(0.0)
		histogram.record(5.0)
		histogram.record(10.0)

		let timeReference = TimeReference(serverOffset: 0)
		let exporter = Exporter(timeReference: timeReference)

		let snapshot = histogram.snapshotAndReset() as! ExponentialHistogram<Double>
		let metric = exporter.exportOTLP(histogram: snapshot)
		let dp = try XCTUnwrap(metric.exponentialHistogram?.dataPoints?.first)

		XCTAssertEqual(dp.count, 5)
		XCTAssertEqual(dp.zeroCount, 1)
		XCTAssertEqual(dp.positive?.bucketCounts?.reduce(0, +), 2)
		XCTAssertEqual(dp.negative?.bucketCounts?.reduce(0, +), 2)
	}

	func testExportJSONShape() throws {
		let histogram = ExponentialHistogram<Double>(
			name: "JSONShape",
			unit: Unit(symbol: "ms"),
			description: "test"
		)
		histogram.record(2.0)
		histogram.record(4.0)

		let timeReference = TimeReference(serverOffset: 0)
		let exporter = Exporter(timeReference: timeReference)

		let snapshot = try XCTUnwrap(histogram.snapshotAndReset() as? ExportableInstrument)
		let metric = snapshot.exportOTLP(exporter)
		let json = try exporter.encodeJSON(metric)
		let string = String(data: json, encoding: .utf8) ?? ""

		XCTAssertTrue(string.contains("\"exponentialHistogram\""))
		XCTAssertTrue(string.contains("\"positive\""))
		XCTAssertTrue(string.contains("\"scale\""))
		XCTAssertTrue(string.contains("\"count\":2"))
	}
}
