// Created by Ladd Van Tol on 2026-05-01.
// Copyright © 2026 Airbnb Inc. All rights reserved.

import Foundation
import Testing

@testable import NautilusTelemetry

/// Compile-time Sendable check: this function would not compile if `T` weren't `Sendable`.
private func requireSendable(_: (some Sendable).Type) { }

// MARK: - AttributeValueTests

@Suite
struct AttributeValueTests {

	@Test
	func attributeValueIsSendable() {
		requireSendable(AttributeValue.self)
		requireSendable(TelemetryAttributes.self)
	}

	@Test
	func literalConstruction() {
		let string: AttributeValue = "hello"
		#expect(string == .string("hello"))

		let int: AttributeValue = 42
		#expect(int == .int(42))

		let double: AttributeValue = 3.14
		#expect(double == .double(3.14))

		let bool: AttributeValue = true
		#expect(bool == .bool(true))

		let array: AttributeValue = ["a", 1, true]
		#expect(array == .array([.string("a"), .int(1), .bool(true)]))

		let dict: AttributeValue = ["a": 1, "b": "two"]
		if case .keyValueList(let v) = dict {
			#expect(v["a"] == .int(1))
			#expect(v["b"] == .string("two"))
		} else {
			Issue.record("expected keyValueList")
		}
	}

	@Test
	func integerInitializerNormalizesToInt64() {
		#expect(AttributeValue(Int32(7)) == .int(7))
		#expect(AttributeValue(UInt8(7)) == .int(7))
		#expect(AttributeValue(Int64(-1)) == .int(-1))
	}

	/// Integers that don't fit in `Int64` fall back to `.string(...)` so no value is
	/// lost (matches the ProtoJSON string-fallback behavior). Exercises both sides
	/// of the `Int64(exactly:)` guard in `AttributeValue.init(_:FixedWidthInteger)`.
	@Test
	func oversizedIntegerFallsBackToString() {
		// `UInt64.max` exceeds `Int64.max`, so it can't round-trip as `.int(_)`.
		#expect(AttributeValue(UInt64.max) == .string("\(UInt64.max)"))
		// `Int128.max` (when available on the target) is also out of range.
		if #available(iOS 18.0, macOS 15.0, *) {
			#expect(AttributeValue(Int128.max) == .string("\(Int128.max)"))
		}
		// Values that DO fit still go through `.int(...)`.
		#expect(AttributeValue(UInt64(Int64.max)) == .int(Int64.max))
	}

	@Test
	func payloadAccessorsExtractValues() {
		#expect(AttributeValue.string("x").stringValue == "x")
		#expect(AttributeValue.int(5).intValue == 5)
		#expect(AttributeValue.double(2.5).doubleValue == 2.5)
		#expect(AttributeValue.bool(false).boolValue == false)

		// Type-mismatched accessors return nil rather than crashing.
		#expect(AttributeValue.string("x").intValue == nil)
		#expect(AttributeValue.int(5).stringValue == nil)
	}

	/// Deprecated conversion from a `[String: String]` to `TelemetryAttributes`.
	@Test
	@available(*, deprecated)
	func deprecatedStringDictionaryConversion() {
		let source: [String: String] = ["a": "1", "b": "2"]
		let attributes = source.asTelemetryAttributes
		#expect(attributes["a"] == .string("1"))
		#expect(attributes["b"] == .string("2"))
	}

	@Test
	func groupedBuilderConstructsMixedTypeAttributes() {
		let userId = "abc123"
		let retryAttempt = 2
		let isRetry = true

		let attributes = TelemetryAttributes(
			string: ["user.id": userId],
			int: ["retry.attempt": retryAttempt],
			bool: ["http.is_retry": isRetry]
		)

		#expect(attributes["user.id"] == .string("abc123"))
		#expect(attributes["retry.attempt"] == .int(2))
		#expect(attributes["http.is_retry"] == .bool(true))
	}

	@Test
	func groupedBuilderLaterKeysOverwriteEarlier() {
		// Per doc comment: last-write-wins across groups.
		let attributes = TelemetryAttributes(
			string: ["key": "from-string"],
			int: ["key": 42]
		)
		#expect(attributes["key"] == .int(42))
	}
}
