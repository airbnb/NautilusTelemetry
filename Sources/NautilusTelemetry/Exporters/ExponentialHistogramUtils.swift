// Created by Ladd Van Tol on 4/17/26.
// Copyright © 2026 Airbnb Inc. All rights reserved.

import Foundation

enum ExponentialHistogramUtils {
	/// Result of bucketizing recorded values into the OTLP exponential histogram shape.
	struct ExponentialHistogramMapping {
		let scale: Int
		let zeroCount: UInt64
		let positive: OTLP.ExponentialHistogramDataPointBuckets
		let negative: OTLP.ExponentialHistogramDataPointBuckets
	}

	/// Minimum and maximum scales permitted by the spec.
	/// https://opentelemetry.io/docs/specs/otel/metrics/data-model/#all-scales-use-the-logarithm-function
	static let exponentialHistogramMinScale = -10
	static let exponentialHistogramMaxScale = 20

	/// Default number of buckets used per positive/negative range when exporting an `ExponentialHistogram`.
	/// The scale is chosen so that all recorded values fit within this count.
	static let defaultExponentialHistogramBucketCount = 32

	/// Bucketize a list of raw values into OTLP exponential histogram buckets.
	/// https://opentelemetry.io/docs/specs/otel/metrics/data-model/#exponentialhistogram

	/// Chooses the highest `scale` in `[exponentialHistogramMinScale, exponentialHistogramMaxScale]`
	/// such that every non-zero value's bucket index fits within `bucketCount` entries
	/// (measured separately per sign). Higher scales give finer resolution but smaller dynamic range.
	///
	/// - Parameters:
	///   - values: raw recorded values.
	///   - bucketCount: maximum number of contiguous buckets permitted per sign.
	/// - Returns: scale, zero count, and positive/negative buckets ready for OTLP encoding.
	static func mapToExponentialBuckets(values: [Double], bucketCount: Int) -> ExponentialHistogramMapping {
		precondition(bucketCount > 0, "bucketCount must be positive")

		var zeroCount: UInt64 = 0
		var positiveMagnitudes = [Double]()
		var negativeMagnitudes = [Double]()

		for v in values {
			if v == 0 || !v.isFinite {
				// Treat non-finite values as zeros per the spec's note that the zero bucket
				// stores "values that cannot be expressed using the standard exponential formula".
				zeroCount += 1
			} else if v > 0 {
				positiveMagnitudes.append(v)
			} else {
				negativeMagnitudes.append(-v)
			}
		}

		let scale = chooseScale(
			positiveMagnitudes: positiveMagnitudes,
			negativeMagnitudes: negativeMagnitudes,
			bucketCount: bucketCount
		)

		let positive = makeBuckets(magnitudes: positiveMagnitudes, scale: scale, bucketCount: bucketCount)
		let negative = makeBuckets(magnitudes: negativeMagnitudes, scale: scale, bucketCount: bucketCount)

		return ExponentialHistogramMapping(
			scale: scale,
			zeroCount: zeroCount,
			positive: positive,
			negative: negative
		)
	}

	/// Pick the highest spec-permitted scale at which both the positive and negative magnitude
	/// ranges fit within `bucketCount` contiguous buckets.
	static func chooseScale(positiveMagnitudes: [Double], negativeMagnitudes: [Double], bucketCount: Int) -> Int {
		// No non-zero values -> scale is irrelevant; pick 0 (base = 2) as a neutral default.
		if positiveMagnitudes.isEmpty, negativeMagnitudes.isEmpty {
			return 0
		}

		// Walk down from the max scale and stop at the first scale where both ranges fit.
		// Range fits at a higher scale if it fits at a lower one (indices scale by 2 each step down),
		// so this is monotonic and a linear walk is cheap (31 iterations worst case).
		for scale in stride(from: exponentialHistogramMaxScale, through: exponentialHistogramMinScale, by: -1) {
			if
				rangeFits(positiveMagnitudes, scale: scale, bucketCount: bucketCount),
				rangeFits(negativeMagnitudes, scale: scale, bucketCount: bucketCount)
			{
				return scale
			}
		}
		return exponentialHistogramMinScale
	}

	/// True if the indices produced by `scale` for the given positive magnitudes span at most `bucketCount` buckets.
	static func rangeFits(_ magnitudes: [Double], scale: Int, bucketCount: Int) -> Bool {
		guard !magnitudes.isEmpty else { return true }

		var minIndex = Int.max
		var maxIndex = Int.min
		for m in magnitudes {
			let idx = bucketIndex(value: m, scale: scale)
			if idx < minIndex { minIndex = idx }
			if idx > maxIndex { maxIndex = idx }
		}

		// Protobuf restricts indices to signed 32-bit range.
		if minIndex < Int(Int32.min) || maxIndex > Int(Int32.max) {
			return false
		}

		return (maxIndex - minIndex + 1) <= bucketCount
	}

	/// Build a contiguous run of buckets covering all magnitudes at the given scale.
	static func makeBuckets(magnitudes: [Double], scale: Int, bucketCount: Int) -> OTLP.ExponentialHistogramDataPointBuckets {
		guard !magnitudes.isEmpty else {
			return OTLP.ExponentialHistogramDataPointBuckets()
		}

		var minIndex = Int.max
		var maxIndex = Int.min
		var indices = [Int]()
		indices.reserveCapacity(magnitudes.count)

		for m in magnitudes {
			let idx = bucketIndex(value: m, scale: scale)
			indices.append(idx)
			if idx < minIndex { minIndex = idx }
			if idx > maxIndex { maxIndex = idx }
		}

		let span = maxIndex - minIndex + 1
		let width = min(span, bucketCount)
		var counts = [UInt64](repeating: 0, count: width)
		for idx in indices {
			let slot = min(max(idx - minIndex, 0), width - 1)
			counts[slot] += 1
		}

		return OTLP.ExponentialHistogramDataPointBuckets(offset: minIndex, bucketCounts: counts)
	}

	/// Bucket index for a strictly-positive value at the given scale, per the OTel spec.
	/// Bucket `i` covers `(base^i, base^(i+1)]` where `base = 2^(2^-scale)`.
	/// Implemented via the logarithm form `ceil(log2(v) * 2^scale) - 1`, which handles all scales.
	static func bucketIndex(value: Double, scale: Int) -> Int {
		// Caller guarantees value > 0 and finite.
		let log2Value = log2(value)
		let scaleFactor =
			if scale >= 0 {
				Double(Int64(1) << scale)
			} else {
				1.0 / Double(Int64(1) << -scale)
			}
		let scaled = log2Value * scaleFactor
		let ceiled = ceil(scaled)
		// Exact powers of `base` should fall in the bucket *below* (upper-bound inclusive).
		// `ceil(x) - 1` handles this because for an exact power scaled lands on an integer.
		return Int(ceiled) - 1
	}

}
