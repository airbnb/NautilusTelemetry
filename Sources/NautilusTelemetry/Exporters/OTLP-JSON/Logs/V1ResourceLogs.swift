//
// V1ResourceLogs.swift
//
// Generated by openapi-generator
// https://openapi-generator.tech
//

import Foundation

@available(*, deprecated, renamed: "OTLP.V1ResourceLogs")
typealias V1ResourceLogs = OTLP.V1ResourceLogs

extension OTLP {
	/** A collection of ScopeLogs from a Resource. */
	struct V1ResourceLogs: Codable, Hashable {
		var resource: V1Resource?
		/** A list of ScopeLogs that originate from a resource. */
		var scopeLogs: [V1ScopeLogs]?
		/** The Schema URL, if known. This is the identifier of the Schema that the resource data is recorded in. To learn more about Schema URL see https://opentelemetry.io/docs/specs/otel/schemas/#schema-url This schema_url applies to the data in the \"resource\" field. It does not apply to the data in the \"scope_logs\" field which have their own schema_url field. */
		var schemaUrl: String?

		init(resource: V1Resource? = nil, scopeLogs: [V1ScopeLogs]? = nil, schemaUrl: String? = nil) {
			self.resource = resource
			self.scopeLogs = scopeLogs
			self.schemaUrl = schemaUrl
		}

		enum CodingKeys: String, CodingKey, CaseIterable {
			case resource
			case scopeLogs
			case schemaUrl
		}

		// Encodable protocol methods

		func encode(to encoder: Encoder) throws {
			var container = encoder.container(keyedBy: CodingKeys.self)
			try container.encodeIfPresent(resource, forKey: .resource)
			try container.encodeIfPresent(scopeLogs, forKey: .scopeLogs)
			try container.encodeIfPresent(schemaUrl, forKey: .schemaUrl)
		}
	}
}
