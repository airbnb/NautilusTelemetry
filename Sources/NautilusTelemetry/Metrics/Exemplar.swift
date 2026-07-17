//
//  Exemplar.swift
//
//
//  Created by Ladd Van Tol on 2026-07-15.
//

import Foundation

/// A sample measurement recorded alongside the span that produced it.
/// Exemplars link an aggregated metric data point back to a specific trace when it is sampled.
/// https://opentelemetry.io/docs/specs/otel/metrics/data-model/#exemplars
public struct Exemplar<T: MetricNumeric> {

	/// The span active when the measurement was recorded.
	public let span: Span

	/// The recorded measurement value.
	public let value: T

	/// The aggregation attributes the measurement was recorded under.
	/// Used to associate the exemplar with the matching data point.
	public let attributes: TelemetryAttributes

	public init(span: Span, value: T, attributes: TelemetryAttributes = [:]) {
		self.span = span
		self.value = value
		self.attributes = attributes
	}
}
