//
// StatusStatusCode.swift
//
// Generated by openapi-generator
// https://openapi-generator.tech
//

import Foundation

@available(*, deprecated, renamed: "OTLP.StatusStatusCode")
typealias StatusStatusCode = OTLP.StatusStatusCode

extension OTLP {
	/** - STATUS_CODE_UNSET: The default status.  - STATUS_CODE_OK: The Span has been validated by an Application developer or Operator to  have completed successfully.  - STATUS_CODE_ERROR: The Span contains an error. */

	// Enums are now numeric, per:
	// https://opentelemetry.io/docs/specs/otlp/#json-protobuf-encoding
	enum StatusStatusCode: Int, Codable, CaseIterable {
		case unset = 0
		case ok = 1
		case error = 2
	}
}
