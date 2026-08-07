//
//  BucketedMeasurement.swift
//
//
//  Created by Ladd Van Tol on 8/5/26.
//

import Foundation

// MARK: - BucketedMeasurement

/// A count of observations that another source has already placed in a single bucket, such as one
/// `MXHistogramBucket` of a MetricKit `MXHistogram`.
///
/// The source's buckets are expected to line up with the receiving histogram's `explicitBounds`. `value`
/// selects the destination bucket and contributes `value * count` to the histogram's `sum`.
public struct BucketedMeasurement<T: MetricNumeric>: Equatable {

	// MARK: Lifecycle

	/// - Parameters:
	///   - value: stands in for every observation in the bucket.
	///   - count: the number of observations in the bucket.
	public init(value: T, count: UInt64) {
		self.value = value
		self.count = count
	}

	// MARK: Public

	/// Stands in for every observation in the bucket.
	public let value: T

	/// The number of observations in the bucket.
	public let count: UInt64

	// MARK: Internal

	/// Whether a histogram can represent a bucket with these bounds. Callers assert on `false`, so that the
	/// failure reports at the initializer rather than here.
	static func boundsAreUsable(_ lowerBound: T, _ upperBound: T) -> Bool {
		// NaN is not finite, so it never reaches the ordering comparisons.
		isFiniteMetricValue(lowerBound) && isFiniteMetricValue(upperBound) && lowerBound >= 0 && lowerBound <= upperBound
	}
}

// MARK: Sendable

extension BucketedMeasurement: Sendable where T: Sendable { }

extension BucketedMeasurement where T: BinaryFloatingPoint {
	/// Initialize from a source bucket's bounds, recording at the midpoint.
	///
	/// The midpoint is the mean of a uniformly distributed bucket, so it keeps the histogram's `sum`
	/// unbiased. Recording at a bound instead would select the same destination bucket, but would skew `sum`
	/// by up to a bucket width per observation, and with it anything derived from `sum` such as a rate or a
	/// mean.
	///
	/// The bounds are separate parameters rather than a `ClosedRange` because forming `lower...upper` traps
	/// when they are reversed, which would put the crash at the call site where no guard here could reach it.
	/// - Parameters:
	///   - lowerBound: the lowest value the source bucket covers.
	///   - upperBound: the highest value the source bucket covers.
	///   - count: the number of observations in the bucket.
	/// - Returns: `nil` for bounds a histogram cannot represent — non-finite, negative, or reversed —
	/// asserting in debug builds.
	public init?(lowerBound: T, upperBound: T, count: UInt64) {
		guard Self.boundsAreUsable(lowerBound, upperBound) else {
			assert(false, "unusable bucket bounds")
			return nil
		}

		// Written to avoid overflowing on a wide bucket.
		self.init(value: lowerBound + (upperBound - lowerBound) / 2, count: count)
	}
}

extension BucketedMeasurement where T: BinaryInteger {
	/// Initialize from a source bucket's bounds, recording at the midpoint, truncated.
	///
	/// The midpoint is the mean of a uniformly distributed bucket, so it keeps the histogram's `sum`
	/// unbiased. Recording at a bound instead would select the same destination bucket, but would skew `sum`
	/// by up to a bucket width per observation, and with it anything derived from `sum` such as a rate or a
	/// mean.
	///
	/// The bounds are separate parameters rather than a `ClosedRange` because forming `lower...upper` traps
	/// when they are reversed, which would put the crash at the call site where no guard here could reach it.
	/// - Parameters:
	///   - lowerBound: the lowest value the source bucket covers.
	///   - upperBound: the highest value the source bucket covers.
	///   - count: the number of observations in the bucket.
	/// - Returns: `nil` for bounds a histogram cannot represent — negative or reversed — asserting in debug
	/// builds.
	public init?(lowerBound: T, upperBound: T, count: UInt64) {
		guard Self.boundsAreUsable(lowerBound, upperBound) else {
			assert(false, "unusable bucket bounds")
			return nil
		}

		// Written to avoid overflowing on a wide bucket.
		self.init(value: lowerBound + (upperBound - lowerBound) / 2, count: count)
	}
}
