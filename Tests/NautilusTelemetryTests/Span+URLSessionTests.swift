// Created by Ladd Van Tol on 3/28/25.
// Copyright © 2025 Airbnb Inc. All rights reserved.

import Foundation
import XCTest

@testable import NautilusTelemetry

final class SpanURLSessionTests: XCTestCase {

	let tracer = Tracer()

	let urlSession = URLSession.shared

	func testName() throws {
		let url = try strategy.parse("/")
		var urlRequest = URLRequest(url: url)
		urlRequest.httpMethod = "GET"
		XCTAssertEqual(Span.name(forRequest: urlRequest), "GET")
	}

	func testNameWithTarget() throws {
		let url = try strategy.parse("/")
		var urlRequest = URLRequest(url: url)
		urlRequest.httpMethod = "GET"
		XCTAssertEqual(Span.name(forRequest: urlRequest, target: "/users/:id"), "GET /users/:id")
	}

	func testUrlSessionDidCreateTask() throws {
		let span = tracer.startSpan(name: #function)
		let url = try strategy.parse("/")
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
		let url = try strategy.parse("/")
		var urlRequest = URLRequest(url: url)
		urlRequest.addValue("application/json", forHTTPHeaderField: "Content-Type")

		let task = urlSession.dataTask(with: urlRequest)
		let error = NSError(domain: "test", code: 1, userInfo: [:])

		span.urlSession(urlSession, task: task, didCompleteWithError: error)

		XCTAssertEqual(span.status, .error(message: "test: The operation couldn’t be completed. (test error 1.) (code=1)"))
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
		let url = try strategy.parse("/")
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
		let url = try strategy.parse("/")
		let headers = ["Fruit": "Banana", "Content-Encoding": "gzip"]
		let urlResponse = try XCTUnwrap(HTTPURLResponse(url: url, statusCode: 200, httpVersion: "2", headerFields: headers))
		span.addHeaders(response: urlResponse, captureHeaders: Set(["fruit"]))
		let attributes = try XCTUnwrap(span.attributes)
		XCTAssertEqual(attributes["http.response.header.fruit"], "Banana")
		XCTAssertNil(attributes["http.response.header.content-encoding"])
	}

}
