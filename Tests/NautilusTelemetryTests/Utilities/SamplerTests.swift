//
//  SamplerTests.swift
//
//
//  Created by Ladd Van Tol on 1/13/22.
//

import Foundation
import XCTest
@testable import NautilusTelemetry

final class SamplerTests: XCTestCase {

	func testStableGuidSampler() {
		let seed = Data([0x00])
		let guid = Data([0xFF])

		let sampler1 = StableGuidSampler(sampleRate: 1.0, seed: seed, guid: guid)
		XCTAssert(!sampler1.shouldSample)

		sampler1.sampleRate = 100.0
		XCTAssert(sampler1.shouldSample)

		let sampler2 = StableGuidSampler(sampleRate: 25.0, seed: seed, guid: guid)
		XCTAssert(!sampler2.shouldSample)

		sampler2.guid = Data([0x04])
		XCTAssert(sampler2.shouldSample) // should be true with the new GUID
	}

	func testStableGuidSamplerSampleRates() throws {
		guard TestUtils.testEnabled("testStableGuidSamplerSampleRates") else {
			throw XCTSkip("This is a local-only test, not needed on CI")
		}

		let targetSampleRates = [0.1, 1.0, 50, 100]

		for targetSampleRate in targetSampleRates {
			let seed = Data([0x00])
			let sampleCount = 100_000
			var sampledCount = 0
			var rng = SystemRandomNumberGenerator()

			// Generate many random GUIDs and count how many are sampled
			for _ in 0..<sampleCount {
				// Generate a random 16-byte GUID using SystemRandomNumberGenerator
				var guidBytes = [UInt8]()
				for _ in 0..<16 {
					guidBytes.append(UInt8.random(in: 0...255, using: &rng))
				}
				let guid = Data(guidBytes)

				let sampler = StableGuidSampler(sampleRate: targetSampleRate, seed: seed, guid: guid)
				if sampler.shouldSample {
					sampledCount += 1
				}
			}

			let actualSampleRate = Double(sampledCount) / Double(sampleCount) * 100.0

			// Statistical tolerance using binomial distribution:
			// Standard deviation = sqrt(n * p * (1-p)), where p = targetSampleRate/100
			// Using 3 sigma (99.7% confidence interval) for the tolerance
			// Examples: 0.1% → ±0.03%, 1.0% → ±0.09%, 50% → ±0.47%, 100% → ±0%
			let expectedCount = Double(sampleCount) * (targetSampleRate / 100.0)
			let tolerance = 3.0 * sqrt(Double(sampleCount) * (targetSampleRate / 100.0) * (1.0 - targetSampleRate / 100.0))
			let tolerancePercent = (tolerance / Double(sampleCount)) * 100.0

			print("Target sample rate: \(targetSampleRate)%")
			print("Actual sample rate: \(actualSampleRate)%")
			print("Sampled: \(sampledCount) out of \(sampleCount)")
			print("Expected: \(expectedCount) ± \(tolerance) (tolerance: ±\(tolerancePercent)%)")

			// Assert that the actual sample rate is within the statistical tolerance
			XCTAssertEqual(
				actualSampleRate,
				targetSampleRate,
				accuracy: tolerancePercent,
				"Sample rate \(actualSampleRate)% should be within ±\(tolerancePercent)% of target \(targetSampleRate)%"
			)
		}
	}
}
