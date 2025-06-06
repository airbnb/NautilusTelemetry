// Created by Ladd Van Tol on 3/28/25.
// Copyright © 2025 Airbnb Inc. All rights reserved.

import Foundation

import Foundation
import XCTest

@testable import NautilusTelemetry

final class SpanURLSessionTests: XCTestCase {
	let tracer = Tracer()

	let url = URL(string: "http://www.example.com")!
	let urlSession = URLSession.shared

	func testName() {
		var urlRequest = URLRequest(url: url)
		urlRequest.httpMethod = "GET"
		XCTAssertEqual(Span.name(forRequest: urlRequest), "GET")
	}

	func testUrlSessionDidCreateTask() throws {
		let span = tracer.startSpan(name: #function)
		var urlRequest = URLRequest(url: url)
		urlRequest.addValue("application/json", forHTTPHeaderField: "Content-Type")
		let task = urlSession.dataTask(with: urlRequest)
		span.urlSession(urlSession, didCreateTask: task, requestHeadersToCapture: Set(["content-type"]))

		let attributes = try XCTUnwrap(span.attributes as? [String: String])
		XCTAssertEqual(attributes["url.full"], url.absoluteString)
		XCTAssertEqual(attributes["http.request.header.content-type"], "application/json")
	}

	func testUrlSessionDidCompleteWithError() throws {
		let span = tracer.startSpan(name: #function)
		var urlRequest = URLRequest(url: url)
		urlRequest.addValue("application/json", forHTTPHeaderField: "Content-Type")

		let task = urlSession.dataTask(with: urlRequest)
		let error = NSError(domain: "test", code: 1, userInfo: [:])

		span.urlSession(urlSession, task: task, didCompleteWithError: error)

		XCTAssertEqual(span.status, .error(message: "The operation couldn’t be completed. (test error 1.)"))
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

			if let cipherSuiteName = cipherSuiteName {
				XCTAssert(cipherSuiteName.hasPrefix("TLS_"))
			}
		}
	}
}
