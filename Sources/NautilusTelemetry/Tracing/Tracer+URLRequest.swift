// Created by Ladd Van Tol on 6/6/25.
// Copyright © 2025 Airbnb Inc. All rights reserved.

import Foundation

/// Extensions to be called by the application's URLSession delegate

public extension Tracer {
	
	/// Create a manually managed span to represent an URLRequest that is about to be dispatched.
	/// - Parameters:
	///   - request: the URLRequest. The `traceparent` header will be added if needed.
	///   - template: optional [`url.template`](https://opentelemetry.io/docs/specs/semconv/registry/attributes/url/#url-template) value.
	///   - captureHeaders: a set of request headers to capture, or nil to capture none.
	///   - attributes: optional attributes.
	///   - baggage: Optional ``Baggage``, describing parent span. If nil, will be inferred from task/thread local baggage.
	/// - Returns: A newly created span.
	func startSpan(request: inout URLRequest, template: String? = nil, captureHeaders: Set<String>? = nil, attributes: TelemetryAttributes? = nil, baggage: Baggage? = nil) -> Span {
		let name = Span.name(forRequest: request, target: template)
		let span = startSpan(name: name, kind: .client, attributes: attributes, baggage: baggage)
		span.addAttribute("http.request.method", request.httpMethod ?? "_OTHER")
		span.addAttribute("user_agent.original", request.value(forHTTPHeaderField: "user-agent"))

		if let url = request.url {
			span.addAttribute("server.address", url.host)
			span.addAttribute("server.port", url.port)
			span.addAttribute("url.full", url.absoluteString)
		}
		if let template {
			span.addAttribute("url.template", template)
		}

		span.addHeaders(
			prefix: "http.request.header",
			headers: request.allHTTPHeaderFields,
			captureHeaders: captureHeaders
		)
		span.addTraceHeadersIfSampling(&request, isSampling: isSampling)

		return span
	}
}
