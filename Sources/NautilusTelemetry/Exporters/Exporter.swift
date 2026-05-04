//
//  Exporter.swift
//
//
//  Created by Van Tol, Ladd on 10/4/21.
//

import Foundation

// MARK: - Exporter

/// Provides conversions to OTLP-JSON format
public struct Exporter {

	// MARK: Lifecycle

	/// Initialize the exporter with a time reference.
	/// - Parameter timeReference: describes the computed offset to server time.
	public init(timeReference: TimeReference, prettyPrint: Bool = false) {
		self.timeReference = timeReference
		self.prettyPrint = prettyPrint
	}

	// MARK: Internal

	let schemaUrl: String? = nil

	/// Provides a mapping between absolute locale time and remote clock time, including server offset.
	let timeReference: TimeReference

	/// Should the JSON output be pretty printed? Defaults to false.
	let prettyPrint: Bool

	/// Encodes JSON, with Data objects encoded as hex.
	/// - Returns: JSON data.
	func encodeJSON(_ value: some Encodable) throws -> Data {
		let encoder = JSONEncoder()
		OTLP.configure(encoder: encoder) // setup hex

		// Forward slash escaping is only needed for HTML embedding.
		var outputFormatting: JSONEncoder.OutputFormatting = [.withoutEscapingSlashes]

		if prettyPrint {
			outputFormatting.insert(.prettyPrinted)
		}

		encoder.outputFormatting = outputFormatting

		return try encoder.encode(value)
	}

	/// Convert `ContinuousClock.Instant` to OTLP nanoseconds since epoch format.
	/// - Parameter time: `ContinuousClock.Instant` object.
	/// - Returns: String describing nanoseconds since epoch (avoids JSON numeric precision issue).
	func convertToOTLP(time: ContinuousClock.Instant?) -> String? {
		guard let time else {
			return nil
		}

		return String(timeReference.nanosecondsSinceEpoch(from: time))
	}

	/// Converts an `AttributeValue` to OTLP format.
	/// - Parameter value: an `AttributeValue`.
	/// - Returns: OTLP wrapped type.
	func convertToOTLP(value: AttributeValue) -> OTLP.V1AnyValue {
		switch value {
		case .string(let v):
			OTLP.V1AnyValue(stringValue: v)
		case .int(let v):
			OTLP.V1AnyValue(intValue: v)
		case .double(let v):
			OTLP.V1AnyValue(doubleValue: v)
		case .bool(let v):
			OTLP.V1AnyValue(boolValue: v)
		case .data(let v):
			OTLP.V1AnyValue(bytesValue: v)
		case .array(let v):
			OTLP.V1AnyValue(arrayValue: OTLP.V1ArrayValue(values: v.map { convertToOTLP(value: $0) }))
		case .keyValueList(let v):
			OTLP.V1AnyValue(kvlistValue: OTLP.V1KeyValueList(
				values: v.map { OTLP.V1KeyValue(key: $0.key, value: convertToOTLP(value: $0.value)) }
			))
		}
	}

	/// Converts `TelemetryAttributes` to OTLP format.
	/// - Parameter attributes: TelemetryAttributes.
	/// - Returns: attributes converted to OTLP format.
	func convertToOTLP(attributes: TelemetryAttributes?) -> [OTLP.V1KeyValue]? {
		guard let attributes else {
			return nil
		}

		let otlpAttributes = attributes.map { key, value in
			OTLP.V1KeyValue(key: key, value: convertToOTLP(value: value))
		}

		// Sort by key for deterministic output
		return otlpAttributes.sorted { ($0.key ?? "") < ($1.key ?? "") }
	}

}
