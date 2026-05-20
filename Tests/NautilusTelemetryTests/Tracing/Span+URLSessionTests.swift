// Created by Ladd Van Tol on 3/28/25.
// Copyright © 2025 Airbnb Inc. All rights reserved.

import Foundation
import Synchronization
import XCTest

@testable import NautilusTelemetry

// MARK: - SpanURLSessionTests

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

		let attributes = try XCTUnwrap(span.attributes)
		XCTAssertEqual(attributes["url.full"], .string(url.absoluteString))
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
		XCTAssertEqual(exceptionAttributes["exception.message"], .string(message))
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

		let upperBound = Duration.seconds(1000)

		span.addAttribute("duration_nils", span.elapsedNanoseconds(nil, nil, upperBound: upperBound))
		span.addAttribute(
			"duration_start_in_future",
			span.elapsedNanoseconds(NSDate.distantFuture, NSDate.distantPast, upperBound: upperBound)
		)
		span.addAttribute("duration_zero", span.elapsedNanoseconds(now, now, upperBound: upperBound))
		span.addAttribute("duration_one_second", span.elapsedNanoseconds(now, now + 1.0, upperBound: upperBound))
		span.addAttribute("duration_two_thousand_seconds", span.elapsedNanoseconds(now, now + 2000.0, upperBound: upperBound))

		let attributes = try XCTUnwrap(span.attributes)
		XCTAssertNil(attributes["duration_nils"])
		XCTAssertNil(attributes["duration_start_in_future"])
		XCTAssertEqual(attributes["duration_zero"], 0)
		XCTAssertEqual(attributes["duration_one_second"], 1_000_000_000)
		XCTAssertNil(attributes["duration_two_thousand_seconds"]) // exceeds upper bound
	}

	func testUrlSchemeAttributeCaptured() throws {
		let span = tracer.startSpan(name: #function)
		let url = try makeURL("/test")
		let urlRequest = URLRequest(url: url)

		span.addRequestAttributes(urlRequest)

		let attributes = try XCTUnwrap(span.attributes)
		XCTAssertEqual(attributes["url.scheme"], url.scheme.map { .string($0) })
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

		let attributes = try XCTUnwrap(span.attributes)
		XCTAssertEqual(attributes["url.full"], "https://REDACTED:REDACTED@example.com/path")
	}

	func testUrlPriority() throws {
		let span = tracer.startSpan(name: #function)
		let url = try makeURL("/")
		let urlRequest = URLRequest(url: url)
		let task = urlSession.dataTask(with: urlRequest)

		task.priority = 1.0
		span.urlSession(urlSession, didCreateTask: task)

		let attributes = try XCTUnwrap(span.attributes)
		XCTAssertEqual(attributes["http.priority"], .double(Double(task.priority)))
	}

	func testAddMetricsLive() async throws {
		guard TestUtils.testEnabled("liveNetworkTests") else { return }

		let url = try XCTUnwrap(URL(string: "https://api.airbnb.com/v2/ping"))
		let span = tracer.startSpan(name: #function)

		let delegate = MetricsCapturingDelegate()
		let session = URLSession(configuration: .default, delegate: delegate, delegateQueue: nil)
		let _ = try await session.data(from: url)
		let metrics = try XCTUnwrap(delegate.capturedMetrics)

		span.addMetrics(metrics)

		let attributes = try XCTUnwrap(span.attributes)

		// Byte counts
		XCTAssertNotNil(attributes["http.response.size"])
		XCTAssertNotNil(attributes["http.response.body.size"])

		// Network attributes always populated for a successful request
		XCTAssertNotNil(attributes["network.peer.address"])
		XCTAssertNotNil(attributes["network.type"])
		XCTAssertNotNil(attributes["network.protocol.version"])

		// TLS — api.airbnb.com speaks HTTPS
		XCTAssertNotNil(attributes["tls.protocol.version"])
		XCTAssertNotNil(attributes["tls.cipher"])

		// Timing: first-byte duration must be a positive nanosecond count
		let firstByte = try XCTUnwrap(attributes["http.first_byte.duration"]?.intPayload)
		XCTAssertGreaterThan(firstByte, 0)
	}

}

// MARK: - MetricsCapturingDelegate

private final class MetricsCapturingDelegate: NSObject, URLSessionTaskDelegate, Sendable {

	var capturedMetrics: URLSessionTaskMetrics? {
		mutex.withLock { $0 }
	}

	func urlSession(_: URLSession, task _: URLSessionTask, didFinishCollecting metrics: URLSessionTaskMetrics) {
		mutex.withLock { $0 = metrics }
	}

	private let mutex: Mutex<URLSessionTaskMetrics?> = Mutex(nil)

}
