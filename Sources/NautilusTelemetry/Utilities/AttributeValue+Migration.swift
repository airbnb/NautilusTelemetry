// Created by Ladd Van Tol on 2026-05-01.
// Copyright © 2026 Airbnb Inc. All rights reserved.

import Foundation

// Transitional helpers to smooth migration from `[String: AnyHashable]` /
// `[String: String]`-style call sites to `TelemetryAttributes` (keyed by
// `AttributeValue`). Everything in this file is `@available(*, deprecated, ...)`
// so callers get a compiler pointer to the replacement pattern.
//
// Subscript-style assignments (`attributes[key] = someStringVar`) cannot be
// smoothed: Swift's stdlib `Dictionary` subscript isn't overridable by return
// type via extension, so those call sites must convert manually
// (e.g. `attributes[key] = .string(someStringVar)`).

// MARK: - `[String: String]` conversion

extension [String: String] {
	/// Convert a string-valued dictionary to `TelemetryAttributes`.
	@available(*, deprecated, message: "Construct a TelemetryAttributes directly with AttributeValue values.")
	public var asTelemetryAttributes: TelemetryAttributes {
		mapValues(AttributeValue.string)
	}
}

// MARK: - Exporter overloads accepting `[String: String]`

extension Exporter {
	@available(
		*,
		deprecated,
		message: "Pass TelemetryAttributes (Dictionary<String, AttributeValue>) instead of [String: String]."
	)
	public func exportOTLPToJSON(
		spans: [Span],
		additionalAttributes: [String: String],
		resourceAttributeOptions: ResourceAttributeOptions = .all
	) throws -> Data {
		try exportOTLPToJSON(
			spans: spans,
			additionalAttributes: additionalAttributes.mapValues(AttributeValue.string),
			resourceAttributeOptions: resourceAttributeOptions
		)
	}

	@available(
		*,
		deprecated,
		message: "Pass TelemetryAttributes (Dictionary<String, AttributeValue>) instead of [String: String]."
	)
	public func exportOTLPToJSON(
		instruments: [Instrument],
		additionalAttributes: [String: String],
		resourceAttributeOptions: ResourceAttributeOptions = ResourceAttributeOptions.metricSubset
	) throws -> Data {
		try exportOTLPToJSON(
			instruments: instruments,
			additionalAttributes: additionalAttributes.mapValues(AttributeValue.string),
			resourceAttributeOptions: resourceAttributeOptions
		)
	}
}
