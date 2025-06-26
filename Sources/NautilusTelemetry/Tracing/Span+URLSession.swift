// Created by Ladd Van Tol on 3/17/25.
// Copyright © 2025 Airbnb Inc. All rights reserved.

import Foundation

// https://opentelemetry.io/docs/specs/semconv/http/http-spans/

/// Extensions to be called by the application's URLSession delegate
extension Span {

	// MARK: Public

	/// Provides a span name.
	/// - Parameters:
	/// 	- request: the request to construct from.
	/// 	- target: an optional (low-cardinality) target (e.g. a `url.template` value for HTTP client spans)
	/// - Returns: a span name.
	public static func name(forRequest request: URLRequest, target: String? = nil) -> String {
		// https://opentelemetry.io/docs/specs/semconv/http/http-spans/#name
		// HTTP spans MUST follow the overall guidelines for span names.
		// HTTP span names SHOULD be {method} {target} if there is a (low-cardinality) target available. If there is no (low-cardinality) {target} available, HTTP span names SHOULD be {method}.
		//	The {method} MUST be {http.request.method} if the method represents the original method known to the instrumentation. In other cases (when {http.request.method} is set to _OTHER), {method} MUST be HTTP.
		let method = request.httpMethod ?? "HTTP"
		guard let target else { return method }
		return "\(method) \(target)"
	}

	/// Add `traceparent` header to a URLRequest if we're sampling
	/// - Parameter isSampling: whether we are sampling, defaults to InstrumentationSystem.tracer.isSampling
	/// - Parameter urlRequest: urlRequest to modify
	public func addTraceHeadersIfSampling(
		_ urlRequest: inout URLRequest,
		isSampling: Bool = InstrumentationSystem.tracer.isSampling
	) {
		if isSampling {
			let value = traceParentHeaderValue(sampled: true)
			urlRequest.addValue(value.1, forHTTPHeaderField: value.0)
		}
	}

	/// Add `traceparent` header to a URLRequest regardless of sampling state
	/// Sampled flag determined from InstrumentationSystem.tracer.isSampling
	/// - Parameter urlRequest: urlRequest to modify
	public func addTraceHeadersUnconditionally(
		_ urlRequest: inout URLRequest,
		isSampling: Bool = InstrumentationSystem.tracer.isSampling
	) {
		let value = traceParentHeaderValue(sampled: isSampling)
		urlRequest.addValue(value.1, forHTTPHeaderField: value.0)
	}

	/// Annotates the span with attributes from URLSessionTaskMetrics.
	/// - Parameter metrics: collected task metrics.
	public func addMetrics(_ metrics: URLSessionTaskMetrics) {
		if metrics.redirectCount > 0 {
			addAttribute("http.request.resend_count", metrics.redirectCount)
		}

		guard let metric = metrics.transactionMetrics.first else { return }

		// https://opentelemetry.io/docs/specs/semconv/attributes-registry/http/
		// https://opentelemetry.io/docs/specs/semconv/attributes-registry/network/
		// https://opentelemetry.io/docs/specs/semconv/attributes-registry/server/
		// https://opentelemetry.io/docs/specs/semconv/attributes-registry/tls/

		addAttribute("http.request.size", metric.countOfRequestHeaderBytesSent + metric.countOfRequestBodyBytesSent)
		addAttribute("http.request.body.size", metric.countOfRequestBodyBytesSent)

		addAttribute("http.response.size", metric.countOfResponseHeaderBytesReceived + metric.countOfResponseBodyBytesReceived)
		addAttribute("http.response.body.size", metric.countOfResponseBodyBytesReceived)

		if let remoteAddress = metric.remoteAddress {
			addAttribute("network.peer.address", remoteAddress)

			let isV6 = remoteAddress.contains(":")
			addAttribute("network.type", isV6 ? "ipv6" : "ipv4")

			if let remotePort = metric.remotePort {
				addAttribute("network.peer.port", remotePort)
			}
		}

		if let negotiatedTLSProtocolVersion = metric.negotiatedTLSProtocolVersion {
			let tlsVersionString: String? =
				switch negotiatedTLSProtocolVersion {
				case .TLSv10: "1.0"
				case .TLSv11: "1.1"
				case .TLSv12: "1.2"
				case .TLSv13: "1.3"
				default: nil
				}

			addAttribute("tls.protocol.version", tlsVersionString)
		}

		addAttribute("tls.cipher", Self.cipherSuiteName(metric.negotiatedTLSCipherSuite))

		// We can't provide more detail without groveling into NWPath and
		// CTTelephonyNetworkInfo.serviceCurrentRadioAccessTechnology.
		addAttribute("network.connection.type", metric.isCellular ? "cell" : "wifi")
		addAttribute("network.protocol.version", Self.networkProtocolVersion(metric.networkProtocolName))
	}

	/// Annotates the span with attributes from the task's URLRequest.
	/// - Parameters:
	///   - _:  the URLSession instance.
	///   - task: the task.
	///   - captureHeaders: a set of request headers to capture, or nil to capture none.
	public func urlSession(_: URLSession, didCreateTask task: URLSessionTask, captureHeaders: Set<String>? = nil) {
		if let request = task.currentRequest {
			addAttribute("http.request.method", request.httpMethod ?? "_OTHER")

			if let url = request.url {
				addAttribute("server.address", url.host)
				addAttribute("server.port", url.port)
				addAttribute("url.full", url.absoluteString)
			}

			addAttribute("user_agent.original", request.value(forHTTPHeaderField: "user-agent"))
			addHeaders(request: request, captureHeaders: captureHeaders)
		}
	}

	/// Annotates the span with attributes from the task's response.
	/// - Parameters:
	///   - _:  the URLSession instance.
	///   - task: the task.
	///   - error: an optional error.
	///   - recordAsStatusCodeFailure: whether to record as a failure due to status code when error == nil.
	///   - captureHeaders: a set of response headers to capture, or nil to capture none.
	public func urlSession(
		_: URLSession,
		task: URLSessionTask,
		didCompleteWithError error: Error?,
		recordAsStatusCodeFailure: Bool = false,
		captureHeaders: Set<String>? = nil
	) {
		if let error {
			recordError(error)
		}

		guard let response = task.response as? HTTPURLResponse else { return }

		addAttribute("http.response.status_code", response.statusCode)

		if error == nil, recordAsStatusCodeFailure {
			status = .error(message: Self.message(statusCode: response.statusCode))
		}

		addHeaders(response: response, captureHeaders: captureHeaders)
	}

	/// Annotates the span with attributes from URLSessionTaskMetrics.
	/// - Parameters:
	///   - _:  the URLSession instance.
	///   - task: the task.
	///   - metrics: collected metrics.
	public func urlSession(_: URLSession, task _: URLSessionTask, didFinishCollecting metrics: URLSessionTaskMetrics) {
		addMetrics(metrics)
	}

	/// Adds specified headers from a URLRequest to this span
	/// - Parameters:
	///   - request: URLRequest containing headers
	///   - captureHeaders: Headers to capture. Must be lowercase strings.
	public func addHeaders(request: URLRequest, captureHeaders: Set<String>? = nil) {
		//  [1] http.request.header: Instrumentations SHOULD require an explicit configuration of which headers are to be captured. Including all request headers can be a security risk - explicit configuration helps avoid leaking sensitive information. The User-Agent header is already captured in the user_agent.original attribute. Users MAY explicitly configure instrumentations to capture them even though it is not recommended. The attribute value MUST consist of either multiple header values as an array of strings or a single-item array containing a possibly comma-concatenated string, depending on the way the HTTP library provides access to headers.

		guard let captureHeaders else { return }
		validate(captureHeaders: captureHeaders)

		for key in captureHeaders {
			if let value = request.value(forHTTPHeaderField: key) {
				addAttribute("http.request.header.\(key)", value)
			}
		}
	}

	/// Adds specified headers from a HTTPURLResponse to this span
	/// - Parameters:
	///   - request: HTTPURLResponse containing headers
	///   - captureHeaders: Headers to capture. Must be lowercase strings.
	public func addHeaders(response: HTTPURLResponse, captureHeaders: Set<String>? = nil) {
		guard let captureHeaders else { return }
		validate(captureHeaders: captureHeaders)

		for key in captureHeaders {
			if let value = response.value(forHTTPHeaderField: key) {
				addAttribute("http.response.header.\(key)", value)
			}
		}
	}

	public func validate(captureHeaders: Set<String>) {
		#if DEBUG
		for header in captureHeaders {
			assert(header.lowercased() == header, "expected all header names to be lowercased")
		}
		#endif
	}

	/// Returns the name / value pair for the traceparent header
	/// - Parameter sampled: Whether we are sampling
	/// - Returns: a traceparent header
	public func traceParentHeaderValue(sampled: Bool) -> (String, String) {
		// https://www.w3.org/TR/trace-context/#traceparent-header-field-values
		var flags: UInt8 = 0x00
		flags |= sampled ? 1 : 0

		let hexFlags = Data([flags]).hexEncodedString
		/// version, trace-id, parent-id, trace-flags
		return ("traceparent", "00-\(traceId.hexEncodedString)-\(id.hexEncodedString)-\(hexFlags)")
	}

	// MARK: Internal

	static func message(statusCode: Int) -> String {
		Span.statusCodeMap[statusCode] ?? "Unassigned"
	}

	/// Derived from https://www.iana.org/assignments/tls-extensiontype-values/tls-extensiontype-values.xhtml#alpn-protocol-ids
	static func networkProtocolVersion(_ networkProtocolName: String?) -> String? {
		switch networkProtocolName {
		case "http/1.0": "1.0"
		case "http/1.1": "1.1"
		case "h2": "2"
		case "h3": "3"
		default: nil
		}
	}

	/// Derived from Security/SecProtocolTypes.h
	static func cipherSuiteName(_ cipherSuite: tls_ciphersuite_t?) -> String? {
		switch cipherSuite {
		case .AES_128_GCM_SHA256: "TLS_AES_128_GCM_SHA256"
		case .AES_256_GCM_SHA384: "TLS_AES_256_GCM_SHA384"
		case .CHACHA20_POLY1305_SHA256: "TLS_CHACHA20_POLY1305_SHA256"
		case .ECDHE_ECDSA_WITH_3DES_EDE_CBC_SHA: "TLS_ECDHE_ECDSA_WITH_3DES_EDE_CBC_SHA"
		case .ECDHE_ECDSA_WITH_AES_128_CBC_SHA: "TLS_ECDHE_ECDSA_WITH_AES_128_CBC_SHA"
		case .ECDHE_ECDSA_WITH_AES_128_CBC_SHA256: "TLS_ECDHE_ECDSA_WITH_AES_128_CBC_SHA256"
		case .ECDHE_ECDSA_WITH_AES_128_GCM_SHA256: "TLS_ECDHE_ECDSA_WITH_AES_128_GCM_SHA256"
		case .ECDHE_ECDSA_WITH_AES_256_CBC_SHA: "TLS_ECDHE_ECDSA_WITH_AES_256_CBC_SHA"
		case .ECDHE_ECDSA_WITH_AES_256_CBC_SHA384: "TLS_ECDHE_ECDSA_WITH_AES_256_CBC_SHA384"
		case .ECDHE_ECDSA_WITH_AES_256_GCM_SHA384: "TLS_ECDHE_ECDSA_WITH_AES_256_GCM_SHA384"
		case .ECDHE_ECDSA_WITH_CHACHA20_POLY1305_SHA256: "TLS_ECDHE_ECDSA_WITH_CHACHA20_POLY1305_SHA256"
		case .ECDHE_RSA_WITH_3DES_EDE_CBC_SHA: "TLS_ECDHE_RSA_WITH_3DES_EDE_CBC_SHA"
		case .ECDHE_RSA_WITH_AES_128_CBC_SHA: "TLS_ECDHE_RSA_WITH_AES_128_CBC_SHA"
		case .ECDHE_RSA_WITH_AES_128_CBC_SHA256: "TLS_ECDHE_RSA_WITH_AES_128_CBC_SHA256"
		case .ECDHE_RSA_WITH_AES_128_GCM_SHA256: "TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256"
		case .ECDHE_RSA_WITH_AES_256_CBC_SHA: "TLS_ECDHE_RSA_WITH_AES_256_CBC_SHA"
		case .ECDHE_RSA_WITH_AES_256_CBC_SHA384: "TLS_ECDHE_RSA_WITH_AES_256_CBC_SHA384"
		case .ECDHE_RSA_WITH_AES_256_GCM_SHA384: "TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384"
		case .ECDHE_RSA_WITH_CHACHA20_POLY1305_SHA256: "TLS_ECDHE_RSA_WITH_CHACHA20_POLY1305_SHA256"
		case .RSA_WITH_3DES_EDE_CBC_SHA: "TLS_RSA_WITH_3DES_EDE_CBC_SHA"
		case .RSA_WITH_AES_128_CBC_SHA: "TLS_RSA_WITH_AES_128_CBC_SHA"
		case .RSA_WITH_AES_128_CBC_SHA256: "TLS_RSA_WITH_AES_128_CBC_SHA256"
		case .RSA_WITH_AES_128_GCM_SHA256: "TLS_RSA_WITH_AES_128_GCM_SHA256"
		case .RSA_WITH_AES_256_CBC_SHA: "TLS_RSA_WITH_AES_256_CBC_SHA"
		case .RSA_WITH_AES_256_CBC_SHA256: "TLS_RSA_WITH_AES_256_CBC_SHA256"
		case .RSA_WITH_AES_256_GCM_SHA384: "TLS_RSA_WITH_AES_256_GCM_SHA384"
		case nil: nil
		@unknown default: nil
		}
	}

	// MARK: Private

	/// Derived from https://developer.mozilla.org/en-US/docs/Web/HTTP/Reference/Status
	private static let statusCodeMap = [
		100: "Continue",
		101: "Switching Protocols",
		102: "Processing",
		103: "Early Hints",
		200: "OK",
		201: "Created",
		202: "Accepted",
		203: "Non-Authoritative Information",
		204: "No Content",
		205: "Reset Content",
		206: "Partial Content",
		207: "Multi-Status",
		208: "Already Reported",
		226: "IM Used",
		300: "Multiple Choices",
		301: "Moved Permanently",
		302: "Found",
		303: "See Other",
		304: "Not Modified",
		305: "Use Proxy",
		306: "Reserved",
		307: "Temporary Redirect",
		308: "Permanent Redirect",
		400: "Bad Request",
		401: "Unauthorized",
		402: "Payment Required",
		403: "Forbidden",
		404: "Not Found",
		405: "Method Not Allowed",
		406: "Not Acceptable",
		407: "Proxy Authentication Required",
		408: "Request Timeout",
		409: "Conflict",
		410: "Gone",
		411: "Length Required",
		412: "Precondition Failed",
		413: "Request Entity Too Large",
		414: "Request-URI Too Long",
		415: "Unsupported Media Type",
		416: "Requested Range Not Satisfiable",
		417: "Expectation Failed",
		418: "I'm a teapot",
		421: "Misdirected Request",
		422: "Unprocessable Entity",
		423: "Locked",
		424: "Failed Dependency",
		425: "Too Early",
		426: "Upgrade Required",
		428: "Precondition Required",
		429: "Too Many Requests",
		431: "Request Header Fields Too Large",
		500: "Internal Server Error",
		501: "Not Implemented",
		502: "Bad Gateway",
		503: "Service Unavailable",
		504: "Gateway Timeout",
		505: "HTTP Version Not Supported",
		506: "Variant Also Negotiates",
		507: "Insufficient Storage",
		508: "Loop Detected",
		510: "Not Extended",
		511: "Network Authentication Required",
	]
}
