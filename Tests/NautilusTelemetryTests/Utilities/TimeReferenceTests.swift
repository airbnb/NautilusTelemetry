//
//  TimeReferenceTests.swift
//
//
//  Created by Ladd Van Tol on 3/22/22.
//

import Foundation
import Testing
@testable import NautilusTelemetry

@Suite
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

		#expect(elapsed.asMilliseconds == -elapsedInverse.asMilliseconds)

		// Can't really assert exact timings without making the test flakey
	}

	@Test("Nanosecond rounding")
	func nanosecondsRounding() {
		// Exact nanoseconds.
		#expect(Duration.nanoseconds(0).asNanoseconds == 0)
		#expect(Duration.nanoseconds(5).asNanoseconds == 5)
		#expect(Duration.nanoseconds(-5).asNanoseconds == -5)

		// Just below the half-ns threshold (499_999_999 as) — truncates.
		#expect(Duration(secondsComponent: 1, attosecondsComponent: 499_999_999).asNanoseconds == 1_000_000_000)
		#expect(Duration(secondsComponent: -1, attosecondsComponent: -499_999_999).asNanoseconds == -1_000_000_000)

		// Exactly at the half-ns threshold (500_000_000 as) — rounds away from zero.
		#expect(Duration(secondsComponent: 1, attosecondsComponent: 500_000_000).asNanoseconds == 1_000_000_001)
		#expect(Duration(secondsComponent: -1, attosecondsComponent: -500_000_000).asNanoseconds == -1_000_000_001)
	}

	@Test("Millisecond rounding")
	func millisecondsRounding() {
		// Exact milliseconds.
		#expect(Duration.milliseconds(0).asMilliseconds == 0)
		#expect(Duration.milliseconds(5).asMilliseconds == 5)
		#expect(Duration.milliseconds(-5).asMilliseconds == -5)

		// Just below the half-ms threshold (499_999_999_999_999 as) — truncates.
		#expect(Duration(secondsComponent: 1, attosecondsComponent: 499_999_999_999_999).asMilliseconds == 1000)
		#expect(Duration(secondsComponent: -1, attosecondsComponent: -499_999_999_999_999).asMilliseconds == -1000)

		// Exactly at the half-ms threshold (500_000_000_000_000 as) — rounds away from zero.
		#expect(Duration(secondsComponent: 1, attosecondsComponent: 500_000_000_000_000).asMilliseconds == 1001)
		#expect(Duration(secondsComponent: -1, attosecondsComponent: -500_000_000_000_000).asMilliseconds == -1001)
	}

	@Test("Microsecond rounding")
	func microsecondsRounding() {
		#expect(Duration.microseconds(0).asMicroseconds == 0)
		#expect(Duration.microseconds(5).asMicroseconds == 5)
		#expect(Duration.microseconds(-5).asMicroseconds == -5)

		// Just below the half-us threshold (499_999_999_999 as) — truncates.
		#expect(Duration(secondsComponent: 1, attosecondsComponent: 499_999_999_999).asMicroseconds == 1_000_000)
		#expect(Duration(secondsComponent: -1, attosecondsComponent: -499_999_999_999).asMicroseconds == -1_000_000)

		// Exactly at the half-us threshold (500_000_000_000 as) — rounds away from zero.
		#expect(Duration(secondsComponent: 1, attosecondsComponent: 500_000_000_000).asMicroseconds == 1_000_001)
		#expect(Duration(secondsComponent: -1, attosecondsComponent: -500_000_000_000).asMicroseconds == -1_000_001)
	}

	@Test("Second rounding")
	func secondsRounding() {
		#expect(Duration.seconds(0).asSeconds == 0)
		#expect(Duration.seconds(5).asSeconds == 5)
		#expect(Duration.seconds(-5).asSeconds == -5)

		// Just below the half-second threshold — truncates toward zero.
		#expect(Duration(secondsComponent: 1, attosecondsComponent: 499_999_999_999_999_999).asSeconds == 1)
		#expect(Duration(secondsComponent: -1, attosecondsComponent: -499_999_999_999_999_999).asSeconds == -1)

		// Exactly at the half-second threshold — rounds away from zero.
		#expect(Duration(secondsComponent: 1, attosecondsComponent: 500_000_000_000_000_000).asSeconds == 2)
		#expect(Duration(secondsComponent: -1, attosecondsComponent: -500_000_000_000_000_000).asSeconds == -2)
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
