// Created by Ladd Van Tol on 6/6/25.
// Copyright © 2025 Airbnb Inc. All rights reserved.

import Foundation

/// Extensions to be called by the application's URLSession delegate

extension Tracer {

	// MARK: Public

	/// Create a manually managed span to represent an URLRequest that is about to be dispatched.
	/// - Parameters:
	///   - request: the URLRequest. The `traceparent` header will be added if needed.
	///   - template: optional [`url.template`](https://opentelemetry.io/docs/specs/semconv/registry/attributes/url/#url-template) value.
	///   - captureHeaders: a set of request headers to capture, or nil to capture none. Must be lowercase strings.
	///   - attributes: optional attributes.
	///   - baggage: Optional ``Baggage``, describing parent span. If nil, will be inferred from task/thread local baggage.
	/// - Returns: A newly created span.
	public func startSpan(
		request: inout URLRequest,
		template: String? = nil,
		captureHeaders: Set<String>? = nil,
		attributes: TelemetryAttributes? = nil,
		baggage: Baggage? = nil
	) -> Span {
		let name = Span.name(forRequest: request, target: template)
		var span = startSpan(name: name, kind: .client, attributes: attributes, baggage: baggage)
		decorateSpan(
			&span,
			for: &request,
			captureHeaders: captureHeaders,
			template: template,
			isSampling: isSampling
		)
		return span
	}

	/// Creates a new subtrace span, linked to a parent span, to represent a URL request that is about to be dispatched.
	/// Subtraces allow creating a tree of traces, making visualization easier.
	/// Each subtrace should ideally represent a logical sub-area, or user activity.
	/// - Parameters:
	///   - request: the URLRequest. The `traceparent` header will be added if needed.
	///   - template: optional [`url.template`](https://opentelemetry.io/docs/specs/semconv/registry/attributes/url/#url-template) value.
	///   - captureHeaders: a set of request headers to capture, or nil to capture none. Must be lowercase strings.
	///   - attributes: optional attributes.
	///   - baggage: Optional ``Baggage``, describing parent span. If nil, will be inferred from task/thread local baggage.
	/// - Returns: A newly created span.
	public func startSubtraceSpan(
		request: inout URLRequest,
		template: String? = nil,
		captureHeaders: Set<String>? = nil,
		attributes: TelemetryAttributes? = nil,
		baggage: Baggage? = nil
	) -> Span {
		let name = Span.name(forRequest: request, target: template)
		var span = startSubtraceSpan(name: name, kind: .client, attributes: attributes, baggage: baggage)
		decorateSpan(
			&span,
			for: &request,
			captureHeaders: captureHeaders,
			template: template,
			isSampling: isSampling
		)
		return span
	}

	// MARK: Private

	private func decorateSpan(
		_ span: inout Span,
		for request: inout URLRequest,
		captureHeaders: Set<String>? = nil,
		template: String? = nil,
		isSampling: Bool
	) {
		span.addRequestAttributes(request)

		if let template {
			span.addAttribute("url.template", template)
		}

		switch traceParentMode {
		case .never:
			break

		case .ifSampling:
			span.addTraceHeadersIfSampling(&request, isSampling: isSampling)

		case .always:
			span.addTraceHeadersUnconditionally(&request, isSampling: isSampling)
		}

		span.addHeaders(request: request, captureHeaders: captureHeaders)
	}
}
