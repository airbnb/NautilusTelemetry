//
//  ExponentialHistogramTests.swift
//
//
//  Created by Ladd Van Tol on 2026-04-17.
//

import Foundation
import Testing

@testable import NautilusTelemetry

@Suite
struct ExponentialHistogramTests {

	// MARK: - bucketIndex

	/// At scale 0, base = 2. Bucket `i` covers (2^i, 2^(i+1)].
	/// Powers of two fall at the upper (inclusive) bound, so index(2^k) = k - 1.
	@Test
	func bucketIndexScaleZero() {
		#expect(ExponentialHistogramUtils.bucketIndex(value: 1.0, scale: 0) == -1) // 1 == 2^0, upper of bucket -1
		#expect(ExponentialHistogramUtils.bucketIndex(value: 1.5, scale: 0) == 0) // in (1, 2]
		#expect(ExponentialHistogramUtils.bucketIndex(value: 2.0, scale: 0) == 0) // 2 == 2^1, upper of bucket 0
		#expect(ExponentialHistogramUtils.bucketIndex(value: 3.0, scale: 0) == 1) // in (2, 4]
		#expect(ExponentialHistogramUtils.bucketIndex(value: 4.0, scale: 0) == 1) // 4 == 2^2, upper of bucket 1
		#expect(ExponentialHistogramUtils.bucketIndex(value: 1024.0, scale: 0) == 9) // 2^10 -> bucket 9
	}

	/// At scale 1, base = sqrt(2). There are 2 buckets per power of two.
	@Test
	func bucketIndexScaleOne() {
		#expect(ExponentialHistogramUtils.bucketIndex(value: 2.0, scale: 1) == 1) // 2 == base^2, upper of bucket 1
		#expect(ExponentialHistogramUtils.bucketIndex(value: 4.0, scale: 1) == 3) // 4 == base^4, upper of bucket 3
	}

	/// At scale -1, base = 4. One bucket covers every two powers of two.
	@Test
	func bucketIndexNegativeScale() {
		#expect(ExponentialHistogramUtils.bucketIndex(value: 4.0, scale: -1) == 0) // 4 == base^1, upper of bucket 0
		#expect(ExponentialHistogramUtils.bucketIndex(value: 16.0, scale: -1) == 1) // 16 == base^2, upper of bucket 1
	}

	// MARK: - chooseScale

	@Test
	func chooseScaleSelectsMaxWhenAllEqual() {
		// All values identical => every scale fits; implementation should pick the max.
		let scale = ExponentialHistogramUtils.chooseScale(
			positiveMagnitudes: [5.0, 5.0, 5.0],
			negativeMagnitudes: [],
			bucketCount: 160
		)
		#expect(scale == ExponentialHistogramUtils.maxScale)
	}

	@Test
	func chooseScaleFitsWideRange() {
		// Range of ~20 powers of two (1e-3 to 1e3). With 160 buckets, log2 span ≈ 20,
		// so max scale is floor(log2(159/20)) ≈ 2.
		let values = [0.001, 0.1, 1.0, 100.0, 1000.0]
		let scale = ExponentialHistogramUtils.chooseScale(
			positiveMagnitudes: values,
			negativeMagnitudes: [],
			bucketCount: 160
		)
		#expect(scale >= 0, "should pick a non-negative scale for this range")
		#expect(indexSpan(values, scale: scale) <= 160)
		// And scale+1 should not fit (it's the maximum).
		if scale < ExponentialHistogramUtils.maxScale {
			#expect(indexSpan(values, scale: scale + 1) > 160)
		}
	}

	@Test
	func chooseScaleEmptyDataUsesDefault() {
		let scale = ExponentialHistogramUtils.chooseScale(positiveMagnitudes: [], negativeMagnitudes: [], bucketCount: 160)
		#expect(scale == 0)
	}

	@Test
	func chooseScaleConsidersBothSigns() {
		// Positive side is tight (3..4), negative side is wide (1e-3..1e3).
		// The chosen scale must satisfy both.
		let scale = ExponentialHistogramUtils.chooseScale(
			positiveMagnitudes: [3.0, 4.0],
			negativeMagnitudes: [0.001, 1000.0],
			bucketCount: 160
		)
		#expect(indexSpan([3.0, 4.0], scale: scale) <= 160)
		#expect(indexSpan([0.001, 1000.0], scale: scale) <= 160)
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

	@Test
	func mapPositiveValues() throws {
		let mapping = ExponentialHistogramUtils.mapToExponentialBuckets(
			values: [1.5, 1.5, 3.0, 3.0, 3.0],
			maxBuckets: 160
		)

		#expect(mapping.zeroCount == 0)
		#expect(mapping.negative.bucketCounts ?? [] == [])

		let positive = mapping.positive
		let counts = try #require(positive.bucketCounts)
		#expect(counts.reduce(0, +) == 5)

		// All values should bucketize at the chosen scale; offset points to the lowest bucket.
		let offset = try #require(positive.offset)
		let indexFor15 = ExponentialHistogramUtils.bucketIndex(value: 1.5, scale: mapping.scale)
		let indexFor3 = ExponentialHistogramUtils.bucketIndex(value: 3.0, scale: mapping.scale)
		#expect(counts[indexFor15 - offset] == 2)
		#expect(counts[indexFor3 - offset] == 3)
	}

	@Test
	func mapNegativeValuesAndZeros() throws {
		let mapping = ExponentialHistogramUtils.mapToExponentialBuckets(
			values: [-1.5, -3.0, 0.0, 0.0],
			maxBuckets: 160
		)

		#expect(mapping.zeroCount == 2)
		#expect(mapping.positive.bucketCounts ?? [] == [])

		let negative = mapping.negative
		let counts = try #require(negative.bucketCounts)
		#expect(counts.reduce(0, +) == 2)
	}

	@Test
	func mapRoundTripCountConservation() {
		let values: [Double] = [0.5, 1.0, 2.0, 4.0, 8.0, 16.0, 0.0, -1.0, -2.0]
		let mapping = ExponentialHistogramUtils.mapToExponentialBuckets(values: values, maxBuckets: 160)

		let positiveSum = mapping.positive.bucketCounts?.reduce(0, +) ?? 0
		let negativeSum = mapping.negative.bucketCounts?.reduce(0, +) ?? 0
		#expect(UInt64(values.count) == positiveSum + negativeSum + mapping.zeroCount)
	}

	@Test
	func mapEmpty() {
		let mapping = ExponentialHistogramUtils.mapToExponentialBuckets(values: [], maxBuckets: 160)
		#expect(mapping.zeroCount == 0)
		#expect(mapping.positive.bucketCounts == nil)
		#expect(mapping.negative.bucketCounts == nil)
	}

	@Test
	func mapSingleValueMaxScale() {
		let mapping = ExponentialHistogramUtils.mapToExponentialBuckets(values: [42.0], maxBuckets: 160)
		// Single value always fits at max scale.
		#expect(mapping.scale == ExponentialHistogramUtils.maxScale)
		#expect(mapping.positive.bucketCounts == [1])
	}

	// MARK: - ExponentialHistogram end-to-end

	@Test
	func recordAndSnapshot() {
		let histogram = ExponentialHistogram<Double>(name: "Test", unit: nil, description: nil)
		histogram.record(1.0)
		histogram.record(2.0)
		histogram.record(4.0)

		let snapshot = histogram.snapshotAndReset() as! ExponentialHistogram<Double>
		#expect(histogram.isEmpty)
		#expect(!snapshot.isEmpty)

		let buckets = snapshot.values.values[[:]]
		#expect(buckets?.count == 3)
		#expect(buckets?.sum == 7.0)
		#expect(buckets?.minValue == 1.0)
		#expect(buckets?.maxValue == 4.0)
	}

	@Test
	func exportProducesValidOTLP() throws {
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

		let expHist = try #require(metric.exponentialHistogram)
		let dataPoints = try #require(expHist.dataPoints)
		#expect(dataPoints.count == 1)

		let dp = dataPoints[0]
		#expect(dp.count == 6)
		#expect(dp.sum == 661.5)
		#expect(dp.min == 0.5)
		#expect(dp.max == 500.0)
		#expect(dp.zeroCount == 0)

		let positive = try #require(dp.positive)
		let counts = try #require(positive.bucketCounts)
		#expect(counts.reduce(0, +) == 6)
		// Indices must fit in the fixed bucket window.
		#expect(counts.count <= ExponentialHistogramUtils.defaultMaxBucketCount)
	}

	@Test
	func exportHandlesMixedSigns() throws {
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
		let dp = try #require(metric.exponentialHistogram?.dataPoints?.first)

		#expect(dp.count == 5)
		#expect(dp.zeroCount == 1)
		#expect(dp.positive?.bucketCounts?.reduce(0, +) == 2)
		#expect(dp.negative?.bucketCounts?.reduce(0, +) == 2)
	}

	@Test
	func exportJSONShape() throws {
		let histogram = ExponentialHistogram<Double>(
			name: "JSONShape",
			unit: Unit(symbol: "ms"),
			description: "test"
		)
		histogram.record(2.0)
		histogram.record(4.0)

		let timeReference = TimeReference(serverOffset: 0)
		let exporter = Exporter(timeReference: timeReference)

		let snapshot = try #require(histogram.snapshotAndReset() as? ExportableInstrument)
		let metric = snapshot.exportOTLP(exporter)
		let json = try exporter.encodeJSON(metric)
		let string = String(data: json, encoding: .utf8) ?? ""

		#expect(string.contains("\"exponentialHistogram\""))
		#expect(string.contains("\"positive\""))
		#expect(string.contains("\"scale\""))
		#expect(string.contains("\"count\":2"))
	}
}
