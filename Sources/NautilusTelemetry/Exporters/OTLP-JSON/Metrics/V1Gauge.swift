//
// V1Gauge.swift
//
// Generated by openapi-generator
// https://openapi-generator.tech
//

import Foundation

@available(*, deprecated, renamed: "OTLP.V1Gauge")
typealias V1Gauge = OTLP.V1Gauge

extension OTLP {
	/** Gauge represents the type of a scalar metric that always exports the \&quot;current value\&quot; for every data point. It should be used for an \&quot;unknown\&quot; aggregation.  A Gauge does not support different aggregation temporalities. Given the aggregation is unknown, points cannot be combined using the same aggregation, regardless of aggregation temporalities. Therefore, AggregationTemporality is not included. Consequently, this also means \&quot;StartTimeUnixNano\&quot; is ignored for all data points. */
	struct V1Gauge: Codable, Hashable {
		var dataPoints: [V1NumberDataPoint]?

		init(dataPoints: [V1NumberDataPoint]? = nil) {
			self.dataPoints = dataPoints
		}

		enum CodingKeys: String, CodingKey, CaseIterable {
			case dataPoints
		}

		// Encodable protocol methods

		func encode(to encoder: Encoder) throws {
			var container = encoder.container(keyedBy: CodingKeys.self)
			try container.encodeIfPresent(dataPoints, forKey: .dataPoints)
		}
	}
}
