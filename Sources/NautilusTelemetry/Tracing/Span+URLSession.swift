// Created by Ladd Van Tol on 3/17/25.
// Copyright © 2025 Airbnb Inc. All rights reserved.

import Foundation

// https://opentelemetry.io/docs/specs/semconv/http/http-spans/

/// Extensions to be called by the application's URLSession delegate
public extension Span {

	/// Provides a span name
	/// - Parameter request: the request to construct from
	/// - Returns: a span name
	static func name(forRequest request: URLRequest) -> String {
		// https://opentelemetry.io/docs/specs/semconv/http/http-spans/#name
		// HTTP spans MUST follow the overall guidelines for span names.
		// HTTP span names SHOULD be {method} {target} if there is a (low-cardinality) target available. If there is no (low-cardinality) {target} available, HTTP span names SHOULD be {method}.
		//	The {method} MUST be {http.request.method} if the method represents the original method known to the instrumentation. In other cases (when {http.request.method} is set to _OTHER), {method} MUST be HTTP.

		// Note: we don't have a way to determine a low cardinality template-based target
		return request.httpMethod ?? "HTTP"
	}

	/// Annotates the span with attributes from the task's URLRequest
	/// - Parameters:
	///   - _:  the URLSession instance
	///   - task: the task
	///   - requestHeaderCaptureList: a set of request headers to capture, or nil to capture none
	func urlSession(_: URLSession, didCreateTask task: URLSessionTask, requestHeaderCaptureList: Set<String>? = nil) {
		if let request = task.currentRequest {
			self.addAttribute("http.request.method", request.httpMethod ?? "_OTHER")

			if let url = request.url {
				self.addAttribute("server.address", url.host)
				self.addAttribute("server.port", url.port)
				self.addAttribute("url.full", url.absoluteString)

			}

			addAttribute("user_agent.original", request.value(forHTTPHeaderField: "user-agent"))
			addHeaders(prefix: "http.request.header", headers: request.allHTTPHeaderFields, headerCaptureList: requestHeaderCaptureList)
		}
	}

	/// Annotates the span with attributes from the task's response
	/// - Parameters:
	///   - _:  the URLSession instance
	///   - task: the task
	///   - error: an optional error
	///   - recordAsStatusCodeFailure: whether to record as a failure due to status code when error == nil
	///   - responseHeaderCaptureList: a set of response headers to capture, or nil to capture none
	func urlSession(_: URLSession, task: URLSessionTask, didCompleteWithError error: Error?, recordAsStatusCodeFailure: Bool = false, responseHeaderCaptureList: Set<String>? = nil) {

		if let error = error {
			self.recordError(error)
		}

		guard let response = task.response as? HTTPURLResponse else { return }

		addAttribute("http.response.status_code", response.statusCode)

		if error == nil, recordAsStatusCodeFailure {
			status = .error(message: message(statusCode: response.statusCode))
		}

		if let headers = response.allHeaderFields as? [String: String] {
			addHeaders(prefix: "http.response.header", headers: headers, headerCaptureList: responseHeaderCaptureList)
		}
	}

	/// Annotates the span with attributes from URLSessionTaskMetrics
	/// - Parameters:
	///   - _:  the URLSession instance
	///   - task: the task
	///   - metrics: collected metrics
	func urlSession(_: URLSession, task: URLSessionTask, didFinishCollecting metrics: URLSessionTaskMetrics) {

		if metrics.redirectCount > 0 {
			addAttribute("http.request.resend_count", metrics.redirectCount)
		}

		guard let metric = metrics.transactionMetrics.first else { return }

		// https://opentelemetry.io/docs/specs/semconv/attributes-registry/http/
		// https://opentelemetry.io/docs/specs/semconv/attributes-registry/network/
		// https://opentelemetry.io/docs/specs/semconv/attributes-registry/server/
		// https://opentelemetry.io/docs/specs/semconv/attributes-registry/tls/

		addAttribute("http.request.size", metric.countOfRequestHeaderBytesSent+metric.countOfRequestBodyBytesSent)
		addAttribute("http.request.body.size", metric.countOfRequestBodyBytesSent)

		addAttribute("http.response.size", metric.countOfResponseHeaderBytesReceived+metric.countOfResponseBodyBytesReceived)
		addAttribute("http.response.body.size", metric.countOfResponseBodyBytesReceived)

		if let remoteAddress = metric.remoteAddress {
			addAttribute("server.address", remoteAddress)

			let isV6 = remoteAddress.contains(":")
			addAttribute("network.type", isV6 ? "ipv6" : "ipv4")
		}

		if let remoteAddress = metric.remoteAddress {
			addAttribute("network.peer.address", remoteAddress)

			if let remotePort = metric.remotePort {
				addAttribute("network.peer.port", remotePort)
			}
		}

		if let negotiatedTLSProtocolVersion = metric.negotiatedTLSProtocolVersion {
			let tlsVersionString: String? = switch negotiatedTLSProtocolVersion {
			case .TLSv10: "1.0"
			case .TLSv11: "1.1"
			case .TLSv12: "1.2"
			case .TLSv13: "1.3"
			default: nil
			}

			addAttribute("tls.protocol.version", tlsVersionString)
		}

		addAttribute("tls.cipher", cipherSuiteName(metric.negotiatedTLSCipherSuite))

		// We can't provide more detail without groveling into NWPath and
		// CTTelephonyNetworkInfo.serviceCurrentRadioAccessTechnology
		addAttribute("network.connection.type", metric.isCellular ? "cell" : "wifi")
		addAttribute("network.protocol.version", networkProtocolVersion(metric.networkProtocolName))
	}

	private func addHeaders(prefix: String, headers: [String: String]?, headerCaptureList: Set<String>? = nil) {
		//	[1] http.request.header: Instrumentations SHOULD require an explicit configuration of which headers are to be captured. Including all request headers can be a security risk - explicit configuration helps avoid leaking sensitive information. The User-Agent header is already captured in the user_agent.original attribute. Users MAY explicitly configure instrumentations to capture them even though it is not recommended. The attribute value MUST consist of either multiple header values as an array of strings or a single-item array containing a possibly comma-concatenated string, depending on the way the HTTP library provides access to headers.
		if let headerCaptureList = headerCaptureList,
		   let headers = headers {

			for (key, value) in headers {
				let normalizedKey = key.lowercased()
				if headerCaptureList.contains(normalizedKey) {
					self.addAttribute("\(prefix).\(normalizedKey)", value)
				}
			}
		}
	}

	private func message(statusCode: Int) -> String {
		Span.statusCodeMap[statusCode] ?? "Unassigned"
	}

	// Derived from https://www.iana.org/assignments/tls-extensiontype-values/tls-extensiontype-values.xhtml#alpn-protocol-ids
	private func networkProtocolVersion(_ networkProtocolName: String?) -> String? {
		switch networkProtocolName {
			case "http/1.0": "1.0"
			case "http/1.1": "1.1"
			case "h2": "2"
			case "h3": "3"
			default: nil
		}
	}

	// Derived from https://developer.mozilla.org/en-US/docs/Web/HTTP/Reference/Status
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
		511: "Network Authentication Required"
	]

	// Derived from Security/SecProtocolTypes.h
	private func cipherSuiteName(_ cipherSuite: tls_ciphersuite_t?) -> String? {
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
}
