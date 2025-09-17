//
//  OTLP.swift
//
//
//  Created by Van Tol, Ladd on 10/4/21.
//

import Foundation

/// enum provides the `OTLP` namespace.
/// The models in `OLTP-JSON` are codegenned from protobuf -> openapi -> swift.
enum OTLP {
	static func configure(encoder: JSONEncoder) {
		encoder.dataEncodingStrategy = .custom(hexDataEncoder)
	}

	// Would normally be base64, but is encoded as hex due to:
	// https://github.com/open-telemetry/opentelemetry-specification/pull/911
	@Sendable
	static func hexDataEncoder(data: Data, encoder: Encoder) throws {
		let hexString = data.hexEncodedString
		var container = encoder.singleValueContainer()
		try container.encode(hexString)
	}
}
