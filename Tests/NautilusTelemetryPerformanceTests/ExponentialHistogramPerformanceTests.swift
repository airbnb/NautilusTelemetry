//
//  ExponentialHistogramPerformanceTests.swift
//
//
//  Created by Ladd Van Tol on 2026-04-20.
//

import Foundation
import XCTest

@testable import NautilusTelemetry

final class ExponentialHistogramPerformanceTests: XCTestCase {

	func testMapToExponentialBucketsPerformance_large() {
		let iterations = 1000
		// Values spanning ~6 orders of magnitude to exercise scale selection and bucket mapping.
		let values: [Double] = (0..<160).map { i in pow(10.0, Double(i % 7) - 3) * Double(i + 1) }
		measure {
			for _ in 0..<iterations {
				_ = ExponentialHistogramUtils.mapToExponentialBuckets(
					values: values,
					maxBuckets: ExponentialHistogramUtils.defaultMaxBucketCount
				)
			}
		}
	}

	func testMapToExponentialBucketsPerformance_small() {
		let iterations = 1000
		// Values spanning a small range.
		let values: [Double] = (0..<100).map { Double($0) }
		measure {
			for _ in 0..<iterations {
				_ = ExponentialHistogramUtils.mapToExponentialBuckets(
					values: values,
					maxBuckets: ExponentialHistogramUtils.defaultMaxBucketCount
				)
			}
		}
	}

}
