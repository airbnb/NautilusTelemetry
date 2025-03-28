//
//  Identifiers.swift
//  
//
//  Created by Van Tol, Ladd on 10/4/21.
//

import Foundation

// Identifiers and shared types

public typealias MetricNumeric = Numeric & Comparable

/// https://github.com/open-telemetry/opentelemetry-specification/blob/main/specification/metrics/datamodel.md
public typealias TelemetryAttributes = [String: AnyHashable]

// These could be converted to UInt128 / UInt64, once UInt128 is widely available
public typealias SpanId = Data
public typealias TraceId = Data

public struct Identifiers {
	// MARK: utilities
	private static var random = SystemRandomNumberGenerator()

	/// Hex encodes an identifier
	/// - Parameter data: a data object
	/// - Returns: a lowercase hex encoded string, representing the data
	public static func hexEncodedString(data: Data) -> String {
		return data.hexEncodedString
	}

	/// Generates a 128 bit session GUID
	/// - Returns: 128 bit identifier as Data
    public static func generateSessionGUID() -> TraceId {
		let bytes = [random.next(), random.next()]
		return bytes.withUnsafeBufferPointer { Data(buffer: $0) }
	}

	/// Generates a 128 bit trace id
	/// - Returns: 128 bit identifier as Data
	static func generateTraceId() -> TraceId {
		let bytes = [random.next(), random.next()]
		return bytes.withUnsafeBufferPointer { Data(buffer: $0) }
	}

	/// Generates a 64 bit span id
	/// Sequential identifiers might be better for collision avoidance: https://en.wikipedia.org/wiki/Birthday_attack#Mathematics
	/// - Returns: 64 bit identifier as Data
	static func generateSpanId() -> SpanId {
		let bytes = [random.next()]
		return bytes.withUnsafeBufferPointer { Data(buffer: $0) }
	}
}

internal extension Data {
	var hexEncodedString: String {
		let hexDigits = "0123456789abcdef"
		let utf8Digits = Array(hexDigits.utf8)
		return String(unsafeUninitializedCapacity: 2 * self.count) { (ptr) -> Int in
			if var p = ptr.baseAddress {
				for byte in self {
					p[0] = utf8Digits[Int(byte / 16)]
					p[1] = utf8Digits[Int(byte % 16)]
					p += 2
				}
				return 2 * self.count
			} else {
				return 0
			}
		}
	}
}
