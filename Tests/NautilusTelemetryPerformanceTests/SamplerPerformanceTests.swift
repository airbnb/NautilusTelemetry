// Created by Ladd Van Tol on 2026-04-21.
// Copyright © 2026 Airbnb Inc. All rights reserved.

import Foundation
import XCTest

@testable import NautilusTelemetry

final class SamplerPerformanceTests: XCTestCase {

	// ≈1µs/sample decision in debug, ≈.5µs in release.
	func testStableGuidSamplerPerformance() {
		let seed = Data([0x00])
		let guid = Data([0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08,
		                 0x09, 0x0A, 0x0B, 0x0C, 0x0D, 0x0E, 0x0F, 0x10])

		measure {
			for _ in 0..<1_000_000 {
				let sampler = StableGuidSampler(sampleRate: 50.0, seed: seed, guid: guid)
				_ = sampler.shouldSample
			}
		}
	}
}
