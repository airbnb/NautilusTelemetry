// Created by Ladd Van Tol on 3/28/25.
// Copyright © 2025 Airbnb Inc. All rights reserved.

import Foundation
import XCTest

@testable import NautilusTelemetry

final class SpanURLSessionTests: XCTestCase {

	let tracer = Tracer()

	let urlSession = URLSession.shared

	func testName() throws {
		let url = try makeURL("/")
		var urlRequest = URLRequest(url: url)
		urlRequest.httpMethod = "GET"
		XCTAssertEqual(Span.name(forRequest: urlRequest), "GET")
	}

	func testNameWithTarget() throws {
		let url = try makeURL("/")
		var urlRequest = URLRequest(url: url)
		urlRequest.httpMethod = "GET"
		XCTAssertEqual(Span.name(forRequest: urlRequest, target: "/users/:id"), "GET /users/:id")
	}

	func testUrlSessionDidCreateTask() throws {
		let span = tracer.startSpan(name: #function)
		let url = try makeURL("/")
		var urlRequest = URLRequest(url: url)
		urlRequest.addValue("application/json", forHTTPHeaderField: "Content-Type")
		let task = urlSession.dataTask(with: urlRequest)
		span.urlSession(urlSession, didCreateTask: task, captureHeaders: Set(["content-type"]))

		let attributes = try XCTUnwrap(span.attributes as? [String: String])
		XCTAssertEqual(attributes["url.full"], url.absoluteString)
		XCTAssertEqual(attributes["http.request.header.content-type"], "application/json")
	}

	func testUrlSessionDidCompleteWithError() throws {
		let span = tracer.startSpan(name: #function)
		let url = try makeURL("/")
		var urlRequest = URLRequest(url: url)
		urlRequest.addValue("application/json", forHTTPHeaderField: "Content-Type")

		let task = urlSession.dataTask(with: urlRequest)

		let message = "The operation couldn’t be completed."
		let error = NSError(domain: "test", code: 1, userInfo: [NSLocalizedDescriptionKey: message])

		span.urlSession(urlSession, task: task, didCompleteWithError: error)

		XCTAssertEqual(span.status, .error(message: message))
		let exceptionEvent = try XCTUnwrap(span.events?.first)
		let exceptionAttributes = try XCTUnwrap(exceptionEvent.attributes)
		XCTAssertEqual(exceptionAttributes["exception.type"], "NSError.test.1")
		XCTAssertEqual(exceptionAttributes["exception.message"], message)
	}

	// URLSessionTaskMetrics is annoying to mock

	func testMessage() throws {
		XCTAssertEqual(Span.message(statusCode: 200), "OK")
	}

	func testNetworkProtocolVersion() throws {
		XCTAssertEqual(Span.networkProtocolVersion("http/1.0"), "1.0")
		XCTAssertEqual(Span.networkProtocolVersion("http/1.1"), "1.1")
		XCTAssertEqual(Span.networkProtocolVersion("h2"), "2")
		XCTAssertEqual(Span.networkProtocolVersion("h3"), "3")
		XCTAssertNil(Span.networkProtocolVersion("gopher"))
	}

	func testCipherSuiteName() throws {
		XCTAssertNil(Span.cipherSuiteName(nil))

		// Not CaseIterable, but we can run the whole numeric range
		for i in 0...UInt16.max {
			let cipherSuiteName = Span.cipherSuiteName(tls_ciphersuite_t(rawValue: i))

			if let cipherSuiteName {
				XCTAssert(cipherSuiteName.hasPrefix("TLS_"))
			}
		}
	}

	func testRequestAddHeaders() throws {
		let span = tracer.startSpan(name: #function)
		let url = try makeURL("/")
		var urlRequest = URLRequest(url: url)
		urlRequest.addValue("Hello", forHTTPHeaderField: "Greeting")
		urlRequest.addValue("content-encoding", forHTTPHeaderField: "br")
		span.addHeaders(request: urlRequest, captureHeaders: Set(["greeting"]))
		let attributes = try XCTUnwrap(span.attributes)
		XCTAssertEqual(attributes["http.request.header.greeting"], "Hello")
		XCTAssertNil(attributes["http.request.header.content-encoding"])
	}

	func testResponseAddHeaders() throws {
		let span = tracer.startSpan(name: #function)
		let url = try makeURL("/")
		let headers = ["Fruit": "Banana", "Content-Encoding": "gzip"]
		let urlResponse = try XCTUnwrap(HTTPURLResponse(url: url, statusCode: 200, httpVersion: "2", headerFields: headers))
		span.addHeaders(response: urlResponse, captureHeaders: Set(["fruit"]))
		let attributes = try XCTUnwrap(span.attributes)
		XCTAssertEqual(attributes["http.response.header.fruit"], "Banana")
		XCTAssertNil(attributes["http.response.header.content-encoding"])
	}

	func testNilDateElapsedNanosecondAttribute() throws {
		let span = tracer.startSpan(name: #function)
		let now = Date()

		span.addAttribute("duration_nils", span.elapsedNanoseconds(nil, nil))
		span.addAttribute("duration_start_in_future", span.elapsedNanoseconds(NSDate.distantFuture, NSDate.distantPast))
		span.addAttribute("duration_zero", span.elapsedNanoseconds(now, now))
		span.addAttribute("duration_one_second", span.elapsedNanoseconds(now, now + 1.0))

		let attributes = try XCTUnwrap(span.attributes)
		XCTAssertNil(attributes["duration_nils"])
		XCTAssertNil(attributes["duration_start_in_future"])
		XCTAssertEqual(attributes["duration_zero"], 0)
		XCTAssertEqual(attributes["duration_one_second"], 1_000_000_000)
	}

	func testUrlSchemeAttributeCaptured() throws {
		let span = tracer.startSpan(name: #function)
		let url = try makeURL("/test")
		let urlRequest = URLRequest(url: url)

		span.addRequestAttributes(urlRequest)

		let attributes = try XCTUnwrap(span.attributes)
		XCTAssertEqual(attributes["url.scheme"], url.scheme)
	}

	func testDefaultUrlRedactionRedactsUserAndPassword() throws {
		let span = tracer.startSpan(name: #function)
		let url = try XCTUnwrap(URL(string: "https://user:password@example.com/path"))

		let redacted = span.defaultUrlRedaction(url)

		XCTAssertEqual(redacted, "https://REDACTED:REDACTED@example.com/path")
	}

	func testDefaultUrlRedactionRedactsAmzQueryParams() throws {
		let span = tracer.startSpan(name: #function)
		let url =
			try XCTUnwrap(
				URL(string: "https://example.com/path?X-Amz-Security-Token=secret1&X-Amz-Signature=secret&other=value&X-Amz-Date=123")
			)

		let redacted = try XCTUnwrap(span.defaultUrlRedaction(url))

		XCTAssert(redacted.contains("X-Amz-Security-Token=REDACTED"))
		XCTAssert(redacted.contains("X-Amz-Signature=REDACTED"))
		XCTAssert(redacted.contains("other=value"))
		XCTAssert(redacted.contains("X-Amz-Date=REDACTED"))
	}

	func testDefaultUrlRedactionPreservesRegularQueryParams() throws {
		let span = tracer.startSpan(name: #function)
		let url = try XCTUnwrap(URL(string: "https://example.com/path?foo=bar&baz=qux"))

		let redacted = span.defaultUrlRedaction(url)

		XCTAssertEqual(redacted, "https://example.com/path?foo=bar&baz=qux")
	}

	func testCustomUrlRedaction() throws {
		let span = tracer.startSpan(name: #function)
		let url = try makeURL("/sensitive/path?key=secret")
		let urlRequest = URLRequest(url: url)

		let customRedaction: (URL) -> String? = { _ in "https://redacted.example.com" }

		span.addRequestAttributes(urlRequest, urlRedaction: customRedaction)

		let attributes = try XCTUnwrap(span.attributes)
		XCTAssertEqual(attributes["url.full"], "https://redacted.example.com")
	}

	func testUrlSessionDidCreateTaskWithCustomRedaction() throws {
		let span = tracer.startSpan(name: #function)
		let url = try XCTUnwrap(URL(string: "https://user:pass@example.com/path"))
		let urlRequest = URLRequest(url: url)
		let task = urlSession.dataTask(with: urlRequest)

		let customRedaction: (URL) -> String? = { _ in "https://custom.redacted.com" }

		span.urlSession(urlSession, didCreateTask: task, urlRedaction: customRedaction)

		let attributes = try XCTUnwrap(span.attributes)
		XCTAssertEqual(attributes["url.full"], "https://custom.redacted.com")
	}

	func testUrlSessionDidCreateTaskUsesDefaultRedaction() throws {
		let span = tracer.startSpan(name: #function)
		let url = try XCTUnwrap(URL(string: "https://user:password@example.com/path"))
		let urlRequest = URLRequest(url: url)
		let task = urlSession.dataTask(with: urlRequest)

		span.urlSession(urlSession, didCreateTask: task)

		let attributes = try XCTUnwrap(span.attributes as? [String: String])
		XCTAssertEqual(attributes["url.full"], "https://REDACTED:REDACTED@example.com/path")
	}
}
