// Created by Ladd Van Tol on 4/17/26.
// Copyright © 2026 Airbnb Inc. All rights reserved.

import Foundation

enum ExponentialHistogramUtils {

	// MARK: Internal

	/// Result of bucketizing recorded values into the OTLP exponential histogram shape.
	struct ExponentialHistogramMapping {
		let scale: Int
		let zeroCount: UInt64
		let positive: OTLP.ExponentialHistogramDataPointBuckets
		let negative: OTLP.ExponentialHistogramDataPointBuckets
	}

	/// Minimum and maximum scales permitted by the spec.
	/// https://opentelemetry.io/docs/specs/otel/metrics/data-model/#all-scales-use-the-logarithm-function
	static let minScale = -10
	static let maxScale = 20

	/// Default number of buckets used per positive/negative range when exporting an `ExponentialHistogram`.
	/// The scale is chosen so that all recorded values fit within this count.
	static let defaultMaxBucketCount = 64

	/// Bucketize a list of raw values into OTLP exponential histogram buckets.
	/// https://opentelemetry.io/docs/specs/otel/metrics/data-model/#exponentialhistogram

	/// Chooses the highest `scale` in `[minScale, maxScale]`
	/// such that every non-zero value's bucket index fits within `maxBuckets` entries
	/// (measured separately for positive and negative). Higher scales give finer resolution but smaller dynamic range.
	///
	/// - Parameters:
	///   - values: raw recorded values.
	///   - maxBuckets: maximum number of contiguous buckets permitted for positive and negative separately.
	/// - Returns: scale, zero count, and positive/negative buckets ready for OTLP encoding.
	static func mapToExponentialBuckets(values: [Double], maxBuckets: Int) -> ExponentialHistogramMapping {
		assert(maxBuckets > 0, "maxBuckets must be greater than zero")

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
			bucketCount: maxBuckets
		)

		let scaleFactor = scaleMultiplier(scale: scale)
		let positive = makeBuckets(magnitudes: positiveMagnitudes, scaleFactor: scaleFactor, maxBuckets: maxBuckets)
		let negative = makeBuckets(magnitudes: negativeMagnitudes, scaleFactor: scaleFactor, maxBuckets: maxBuckets)

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

		// Compute the log2 span of each side in one pass (no per-scale rescanning).
		let positive = log2Extent(magnitudes: positiveMagnitudes)
		let negative = log2Extent(magnitudes: negativeMagnitudes)
		let maxSpan = max(positive.span, negative.span)

		// Derive the maximum scale analytically:
		//   At scale s, bucket indices = ceil(log2(v) * 2^s) - 1.
		//   Number of buckets needed = ceil(log2(max)*2^s) - ceil(log2(min)*2^s) + 1.
		//   Upper bound: <= ceil(span * 2^s) + 1 <= span * 2^s + 2.
		//   We need: span * 2^s + 2 <= bucketCount  =>  s <= log2((bucketCount - 2) / span).
		//
		// When all values are identical (span == 0), every scale fits; return maxScale.
		let scale: Int
		if maxSpan == 0 {
			scale = maxScale
		} else {
			let maxScaleDouble = log2(Double(bucketCount) / maxSpan)
			scale = min(maxScale, max(minScale, Int(floor(maxScaleDouble))))
		}

		// Verify in O(1) from the precomputed log2 extents (rounding in the initial log2 could
		// put us one step over). Re-check using the same `ceil` mapping used by `bucketIndex`.
		if
			rangeFits(positive, scale: scale, bucketCount: bucketCount),
			rangeFits(negative, scale: scale, bucketCount: bucketCount)
		{
			return scale
		}
		return max(minScale, scale - 1)
	}

	/// Build a contiguous run of buckets covering all magnitudes at the given scale.
	/// `scaleFactor` must equal `scaleMultiplier(scale:)` — passed in to avoid recomputing it.
	static func makeBuckets(
		magnitudes: [Double],
		scaleFactor: Double,
		maxBuckets: Int
	) -> OTLP.ExponentialHistogramDataPointBuckets {
		guard !magnitudes.isEmpty else {
			return OTLP.ExponentialHistogramDataPointBuckets()
		}

		// First pass: find index range without allocating an intermediate array.
		var minIndex = Int.max
		var maxIndex = Int.min
		for m in magnitudes {
			let idx = bucketIndex(value: m, scaleFactor: scaleFactor)
			if idx < minIndex { minIndex = idx }
			if idx > maxIndex { maxIndex = idx }
		}

		let span = maxIndex - minIndex + 1
		let width = min(span, maxBuckets)
		var counts = [UInt64](repeating: 0, count: width)

		// Second pass: fill counts directly — no intermediate indices array.
		for m in magnitudes {
			let slot = min(max(bucketIndex(value: m, scaleFactor: scaleFactor) - minIndex, 0), width - 1)
			counts[slot] += 1
		}

		return OTLP.ExponentialHistogramDataPointBuckets(offset: minIndex, bucketCounts: counts)
	}

	/// Bucket index for a strictly-positive value at the given scale, per the OTel spec.
	/// Bucket `i` covers `(base^i, base^(i+1)]` where `base = 2^(2^-scale)`.
	/// Implemented via the logarithm form `ceil(log2(v) * 2^scale) - 1`, which handles all scales.
	static func bucketIndex(value: Double, scale: Int) -> Int {
		bucketIndex(value: value, scaleFactor: scaleMultiplier(scale: scale))
	}

	// MARK: Private

	/// Min/max `log2` of a set of magnitudes and their span. Empty set yields zero span.
	private struct Log2Extent {
		let minLog2: Double
		let maxLog2: Double
		let isEmpty: Bool
		var span: Double { isEmpty ? 0 : maxLog2 - minLog2 }
	}

	/// True if the bucket indices produced by `scale` for the given log2 extent fit in `bucketCount` buckets.
	private static func rangeFits(_ extent: Log2Extent, scale: Int, bucketCount: Int) -> Bool {
		guard !extent.isEmpty else { return true }
		let sf = scaleMultiplier(scale: scale)
		let minIndex = Int(ceil(extent.minLog2 * sf)) - 1
		let maxIndex = Int(ceil(extent.maxLog2 * sf)) - 1
		return (maxIndex - minIndex + 1) <= bucketCount
	}

	/// Returns `2^scale` as a `Double`, used to convert log2 values into bucket indices.
	/// Precompute this once per pass rather than recomputing it for every value.
	private static func scaleMultiplier(scale: Int) -> Double {
		if scale >= 0 {
			Double(Int64(1) << scale)
		} else {
			1.0 / Double(Int64(1) << -scale)
		}
	}

	/// Bucket index given a precomputed scale multiplier. Caller guarantees value > 0 and finite.
	private static func bucketIndex(value: Double, scaleFactor: Double) -> Int {
		let scaled = log2(value) * scaleFactor
		let ceiled = ceil(scaled)
		// Exact powers of `base` should fall in the bucket *below* (upper-bound inclusive).
		// `ceil(x) - 1` handles this because for an exact power scaled lands on an integer.
		return Int(ceiled) - 1
	}

	/// Returns the min/max `log2` across the magnitudes in a single pass.
	private static func log2Extent(magnitudes: [Double]) -> Log2Extent {
		guard !magnitudes.isEmpty else {
			return Log2Extent(minLog2: 0, maxLog2: 0, isEmpty: true)
		}
		var minLog2 = Double.infinity
		var maxLog2 = -Double.infinity
		for m in magnitudes {
			let l = log2(m)
			if l < minLog2 { minLog2 = l }
			if l > maxLog2 { maxLog2 = l }
		}
		return Log2Extent(minLog2: minLog2, maxLog2: maxLog2, isEmpty: false)
	}

}
