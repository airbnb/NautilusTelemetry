// Created by Ladd Van Tol on 2026-05-01.
// Copyright © 2026 Airbnb Inc. All rights reserved.

import Foundation

// MARK: - AttributeValue

/// A closed set of value types permitted in `TelemetryAttributes`.
///
/// Models the types accepted by OTLP attribute values:
/// https://opentelemetry.io/docs/specs/otel/common/#attribute
///
/// Using a closed enum instead of `AnyHashable` avoids existential dispatch on hashing
/// (attributes form dictionary keys throughout the hot path) and makes `TelemetryAttributes`
/// `Sendable`.
public enum AttributeValue: Hashable, Sendable {
	case string(String)
	case int(Int64)
	case double(Double)
	case bool(Bool)
	case data(Data)
	indirect case array([AttributeValue])
	indirect case keyValueList([String: AttributeValue])
}

// MARK: - Payload accessors

/// Non-throwing accessors for the underlying payload. Return `nil` if the case does not match.
extension AttributeValue {
	public var stringValue: String? {
		if case .string(let v) = self { v } else { nil }
	}

	public var intValue: Int64? {
		if case .int(let v) = self { v } else { nil }
	}

	public var doubleValue: Double? {
		if case .double(let v) = self { v } else { nil }
	}

	public var boolValue: Bool? {
		if case .bool(let v) = self { v } else { nil }
	}

	public var dataValue: Data? {
		if case .data(let v) = self { v } else { nil }
	}
}

// MARK: ExpressibleByStringLiteral, ExpressibleByStringInterpolation

/// Enables `span["k"] = "value"`, `span["k"] = 42`, etc. without explicit case construction.
extension AttributeValue: ExpressibleByStringLiteral, ExpressibleByStringInterpolation {
	public init(stringLiteral value: String) { self = .string(value) }
}

// MARK: ExpressibleByIntegerLiteral

extension AttributeValue: ExpressibleByIntegerLiteral {
	public init(integerLiteral value: Int64) { self = .int(value) }
}

// MARK: ExpressibleByFloatLiteral

extension AttributeValue: ExpressibleByFloatLiteral {
	public init(floatLiteral value: Double) { self = .double(value) }
}

// MARK: ExpressibleByBooleanLiteral

extension AttributeValue: ExpressibleByBooleanLiteral {
	public init(booleanLiteral value: Bool) { self = .bool(value) }
}

// MARK: ExpressibleByArrayLiteral

extension AttributeValue: ExpressibleByArrayLiteral {
	public init(arrayLiteral elements: AttributeValue...) { self = .array(elements) }
}

// MARK: ExpressibleByDictionaryLiteral

extension AttributeValue: ExpressibleByDictionaryLiteral {
	public init(dictionaryLiteral elements: (String, AttributeValue)...) {
		self = .keyValueList(Dictionary(uniqueKeysWithValues: elements))
	}
}

// MARK: - Convenience initializers

/// Convenience initializers for non-literal values (e.g. variables of `String`, `Int`, `Bool`, `Data`).
/// The literal conformances above handle the common inline-literal case.
extension AttributeValue {
	public init(_ value: String) { self = .string(value) }
	public init(_ value: some FixedWidthInteger) { self = .int(Int64(truncatingIfNeeded: value)) }
	public init(_ value: Double) { self = .double(value) }
	public init(_ value: Float) { self = .double(Double(value)) }
	public init(_ value: Bool) { self = .bool(value) }
	public init(_ value: Data) { self = .data(value) }
	public init(_ value: [AttributeValue]) { self = .array(value) }
	public init(_ value: [String: AttributeValue]) { self = .keyValueList(value) }
}

// MARK: - AttributeValueRepresentable

/// Types that can be stored as an ``AttributeValue``.
/// Used by the generic `addAttribute` overload so callers can pass `String`, `Int`, `Bool`, etc. directly.
public protocol AttributeValueRepresentable: Sendable {
	var attributeValue: AttributeValue { get }
}

// MARK: - AttributeValue + AttributeValueRepresentable

extension AttributeValue: AttributeValueRepresentable {
	public var attributeValue: AttributeValue { self }
}

// MARK: - String + AttributeValueRepresentable

extension String: AttributeValueRepresentable {
	public var attributeValue: AttributeValue { .string(self) }
}

// MARK: - Bool + AttributeValueRepresentable

extension Bool: AttributeValueRepresentable {
	public var attributeValue: AttributeValue { .bool(self) }
}

// MARK: - Int + AttributeValueRepresentable

extension Int: AttributeValueRepresentable {
	public var attributeValue: AttributeValue { .int(Int64(self)) }
}

// MARK: - Int8 + AttributeValueRepresentable

extension Int8: AttributeValueRepresentable {
	public var attributeValue: AttributeValue { .int(Int64(self)) }
}

// MARK: - Int16 + AttributeValueRepresentable

extension Int16: AttributeValueRepresentable {
	public var attributeValue: AttributeValue { .int(Int64(self)) }
}

// MARK: - Int32 + AttributeValueRepresentable

extension Int32: AttributeValueRepresentable {
	public var attributeValue: AttributeValue { .int(Int64(self)) }
}

// MARK: - Int64 + AttributeValueRepresentable

extension Int64: AttributeValueRepresentable {
	public var attributeValue: AttributeValue { .int(self) }
}

// MARK: - UInt + AttributeValueRepresentable

extension UInt: AttributeValueRepresentable {
	public var attributeValue: AttributeValue { .int(Int64(truncatingIfNeeded: self)) }
}

// MARK: - UInt8 + AttributeValueRepresentable

extension UInt8: AttributeValueRepresentable {
	public var attributeValue: AttributeValue { .int(Int64(self)) }
}

// MARK: - UInt16 + AttributeValueRepresentable

extension UInt16: AttributeValueRepresentable {
	public var attributeValue: AttributeValue { .int(Int64(self)) }
}

// MARK: - UInt32 + AttributeValueRepresentable

extension UInt32: AttributeValueRepresentable {
	public var attributeValue: AttributeValue { .int(Int64(self)) }
}

// MARK: - UInt64 + AttributeValueRepresentable

extension UInt64: AttributeValueRepresentable {
	public var attributeValue: AttributeValue { .int(Int64(truncatingIfNeeded: self)) }
}

// MARK: - Float + AttributeValueRepresentable

extension Float: AttributeValueRepresentable {
	public var attributeValue: AttributeValue { .double(Double(self)) }
}

// MARK: - Double + AttributeValueRepresentable

extension Double: AttributeValueRepresentable {
	public var attributeValue: AttributeValue { .double(self) }
}

// MARK: - Data + AttributeValueRepresentable

extension Data: AttributeValueRepresentable {
	public var attributeValue: AttributeValue { .data(self) }
}

// MARK: - Builder for mixed-type attribute sets

extension [String: AttributeValue] {
	/// Build a `TelemetryAttributes` grouped by value type. Useful when values are
	/// typed variables: a dictionary literal like `["k": stringVar, "n": intVar]`
	/// fails to compile because Swift won't implicitly lift variables to
	/// `AttributeValue`.
	///
	/// ```swift
	/// TelemetryAttributes(
	///   string: ["app.release_stage": buildInfo.apiBuildType, "app.language": buildInfo.dynamicLanguageID],
	///   int: ["retry.attempt": retryAttempt]
	/// )
	/// ```
	///
	/// Later keys overwrite earlier keys if the same key appears in multiple groups.
	public init(
		string: [String: String] = [:],
		int: [String: Int] = [:],
		bool: [String: Bool] = [:],
		double: [String: Double] = [:],
		data: [String: Data] = [:]
	) {
		// Pre-size to avoid rehashing as we merge the groups.
		self.init(minimumCapacity: string.count + int.count + bool.count + double.count + data.count)
		for (k, v) in string { self[k] = .string(v) }
		for (k, v) in int { self[k] = .int(Int64(v)) }
		for (k, v) in bool { self[k] = .bool(v) }
		for (k, v) in double { self[k] = .double(v) }
		for (k, v) in data { self[k] = .data(v) }
	}
}
