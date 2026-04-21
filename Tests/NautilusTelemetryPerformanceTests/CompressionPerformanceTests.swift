//
//  CompressionPerformanceTests.swift
//
//
//  Created by Ladd Van Tol on 2026-04-20.
//

import Foundation
import XCTest

@testable import NautilusTelemetry

final class CompressionPerformanceTests: XCTestCase {

	let logString =
		#"{"resource_logs":[{"instrumentation_library_logs":[{"logs":[{"name":"com.apple.defaults","attributes":[{"key":"category","value":{"string_value":"User Defaults"}},{"key":"sender","value":{"string_value":"CoreFoundation"}},{"key":"subsystem","value":{"string_value":"com.apple.defaults"}},{"key":"process","value":{"string_value":"xctest"}}],"time_unix_nano":"1633991241959059953","span_id":"83aad29ea42ee969","flags":1,"body":{"string_value":"using backstop value (\n    en\n) to avoid returning NULL for key AppleLanguages in kCFPreferencesCurrentApplication"},"severity_number":"SEVERITY_NUMBER_INFO","trace_id":"52f6883f3edde42b093b3e69ff171e35"}],"instrumentation_library":{"name":"NautilusTelemetry","version":"1.0"},"schema_url":"https:\/\/api.ebay.com\/nautilus-tracing"}],"schema_url":"https:\/\/api.ebay.com\/nautilus-tracing","resource":{}}]}"#

	var logData: Data { logString.data(using: .utf8)! }

	func testAdlerZlibPerformance() {
		let iterations = 1000
		measure {
			for _ in 0..<iterations {
				_ = Compression.adler32_zlib(logData)
			}
		}
	}

	func testDeflatePerformance() {
		let iterations = 1000
		measure {
			do {
				for _ in 0..<iterations {
					_ = try Compression.compressDeflate(data: logData)
				}
			} catch {
				XCTFail()
			}
		}
	}

	func testBrotliPerformance() throws {
		#if os(iOS)
		if !ProcessInfo.processInfo.isOperatingSystemAtLeast(.init(majorVersion: 15, minorVersion: 0, patchVersion: 0)) {
			try XCTSkipIf(true, "Unsupported iOS version")
		}
		#endif
		#if os(macOS)
		if !ProcessInfo.processInfo.isOperatingSystemAtLeast(.init(majorVersion: 12, minorVersion: 0, patchVersion: 0)) {
			try XCTSkipIf(true, "Unsupported macOS version")
		}
		#endif

		if #available(iOS 15.0, *) {
			measure {
				do {
					_ = try Compression.compressBrotli(data: logData)
				} catch {
					XCTFail()
				}
			}
		}
	}

}
