//
// V1Summary.swift
//
// Generated by openapi-generator
// https://openapi-generator.tech
//

import Foundation
#if canImport(AnyCodable)
	import AnyCodable
#endif

@available(*, deprecated, renamed: "OTLP.V1Summary")
typealias V1Summary = OTLP.V1Summary

extension OTLP {
	/** Summary metric data are used to convey quantile summaries, a Prometheus (see: https://prometheus.io/docs/concepts/metric_types/#summary) and OpenMetrics (see: https://github.com/OpenObservability/OpenMetrics/blob/4dbf6075567ab43296eed941037c12951faafb92/protos/prometheus.proto#L45) data type. These data points cannot always be merged in a meaningful way. While they can be useful in some applications, histogram data points are recommended for new applications. */
	struct V1Summary: Codable, Hashable {
		var dataPoints: [V1SummaryDataPoint]?

		init(dataPoints: [V1SummaryDataPoint]? = nil) {
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
