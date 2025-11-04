//
//  TimeReferenceTests.swift
//
//
//  Created by Ladd Van Tol on 3/22/22.
//

import Foundation
import Testing
@testable import NautilusTelemetry

@Suite("TimeReference Tests")
struct TimeReferenceTests {

	let toleranceMS: Int64 = 500

	@Test("TimeReference nanoseconds conversion")
	func timeReference() {
		let timeReference = TimeReference(serverOffset: 0)

		let time = ContinuousClock.now
		let date = Date()

		let nanosecondsSinceEpoch = timeReference.nanosecondsSinceEpoch(from: time)
		let nanosecondsSinceEpochFromDate = Int64(date.timeIntervalSince1970 * 1_000_000_000.0)
		let diff3 = abs(nanosecondsSinceEpoch - nanosecondsSinceEpochFromDate)
		#expect(diff3 < toleranceMS * 1_000_000)
	}

	@Test("Nanosecond duration conversion")
	func nanosecondConversion() {
		let time1 = ContinuousClock.now
		print("something very short")
		let time2 = ContinuousClock.now

		#expect(time1 < time2)

		let elapsed = time2 - time1
		let elapsedInverse = time1 - time2

		#expect(elapsed.asNanoseconds == -elapsedInverse.asNanoseconds)

		// Can't really assert exact timings without making the test flakey
	}

	#if os(macOS)
	@Test("Infinite and NaN")
	func infiniteAndNan() async {
		_ = await #expect(processExitsWith: .failure) {
			_ = TimeReference(serverOffset: Double.infinity)
		}

		_ = await #expect(processExitsWith: .failure) {
			_ = TimeReference(serverOffset: Double.nan)
		}
	}
	#endif

}
